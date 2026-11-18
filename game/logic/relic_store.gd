class_name RelicStore
extends RefCounted
## The real-money shop for reliquaries (estate boxes) and bound relics, as pure logic. Payment itself happens
## outside (Steam in-game purchase, or a web provider that allows paid random items); this class owns the rules
## around it: dollar prices on every product, odds shown on every sealed reliquary, a confirm step, an 18+ gate
## with acceptance of the Terms of Sale (binding individual arbitration, class-action waiver: docs/legal/terms_of_sale.md),
## a purchase log, and refunds that never lock the account.
## Flow: quote(id) -> show it -> player confirms -> take payment -> fulfill(id, payment_ref).
## Products: game/data/store.json {id, kind: sealed|scried|featured, count, price_cents, label, blurb}.

const STORE_PATH: String = "res://game/data/store.json"
const MIN_AGE: int = 18
const TERMS_VERSION: String = "2026-11-18"

var products: Array[Dictionary] = []
var collection: CurioCollection
var age_checked: bool = false
var age_ok: bool = false
var terms_accepted: String = ""  ## the TERMS_VERSION the player accepted, "" if none
var log: Array[Dictionary] = []  ## {n, id, price_cents, payment_ref, delivered, refunded}


static func create(coll: CurioCollection) -> RelicStore:
	var s := RelicStore.new()
	s.collection = coll
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORE_PATH))
	if parsed is Array:
		for d: Variant in parsed:
			if d is Dictionary:
				s.products.append(d)
	return s


## The gate, asked once before the shop opens: age (18+ only) and acceptance of the current Terms of Sale.
func set_age(years: int, accepts_terms: bool = false) -> void:
	age_checked = true
	age_ok = years >= MIN_AGE
	terms_accepted = TERMS_VERSION if accepts_terms and age_ok else ""


func is_open() -> bool:
	return age_checked and age_ok and terms_accepted == TERMS_VERSION


func product(id: String) -> Dictionary:
	for p: Dictionary in products:
		if p["id"] == id:
			return p
	return {}


static func dollars(cents: int) -> String:
	return "$%d.%02d" % [cents / 100, cents % 100]


## What the confirm dialog shows before payment: {id, label, price, odds?, shows?, tradeable, pity_left?}.
## Empty when the shop is closed or the product is unknown.
func quote(id: String) -> Dictionary:
	var p: Dictionary = product(id)
	if p.is_empty() or not is_open():
		return {}
	var q: Dictionary = {"id": id, "label": p["label"], "blurb": p.get("blurb", ""),
		"price": dollars(int(p["price_cents"])), "count": int(p["count"])}
	match str(p["kind"]):
		"sealed":
			q["odds"] = collection.odds()
			q["pity_left"] = collection.pity_left()
			q["tradeable"] = false
		"scried":
			q["shows"] = collection.appraised_offer()
			q["tradeable"] = true
		"featured":
			q["shows"] = collection.curio(collection.featured_id)
			q["tradeable"] = true
	return q


## Delivers a paid product. Call only after the payment provider confirms. Returns the log entry, or {} if the
## product cannot be delivered (closed shop, unknown product, no featured curio).
func fulfill(id: String, payment_ref: String) -> Dictionary:
	var p: Dictionary = product(id)
	if p.is_empty() or not is_open():
		return {}
	var got: Array = []
	match str(p["kind"]):
		"sealed":
			collection.add_boxes(int(p["count"]), true)
		"scried":
			got.append(collection.buy_appraised())
		"featured":
			if collection.featured_id == "" or not collection.grant(collection.featured_id):
				return {}
			got.append(collection.curio(collection.featured_id))
	var entry: Dictionary = {"n": log.size() + 1, "id": id, "price_cents": int(p["price_cents"]),
		"payment_ref": payment_ref, "delivered": got, "refunded": false}
	log.append(entry)
	return entry


## A refund or chargeback: takes back unopened sealed reliquaries where it can. Never locks the account.
func refund(n: int) -> bool:
	for entry: Dictionary in log:
		if int(entry["n"]) == n and not entry["refunded"]:
			entry["refunded"] = true
			var p: Dictionary = product(entry["id"])
			if str(p.get("kind", "")) == "sealed":
				collection.paid_boxes -= mini(collection.paid_boxes, int(p["count"]))
			return true
	return false


func spent_cents() -> int:
	var t: int = 0
	for entry: Dictionary in log:
		if not entry["refunded"]:
			t += int(entry["price_cents"])
	return t

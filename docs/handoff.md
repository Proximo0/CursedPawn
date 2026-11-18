# Cursed Pawn: handoff (18 Nov 2026)

Everything decided so far, so a new project or thread can start without the old conversation.

## Goal
A sellable game released 18 Dec 2026 (before Christmas). Sell first on our own website (no domain bought yet),
plus Steam and itch.io. Curtis will pay the $100 Steam app fee by 20 Nov (30-day wait for new developers;
a Coming Soon page must be public for 2 weeks, so by about 4 Dec).

## Engine and pipeline
Godot 4.7.2 + GDScript on Proximo0/game-starter-kit (scaffolded here, check_all green on day one).
Chosen over Unreal, Unity and a Three.js web kit because of Curtis's own projects: Skate Park and Sandblood
were built cheaply with every check in the cloud; Worldsunder (Unreal) was costly. Web export: Compatibility
renderer, single-threaded (works on iOS/Safari without COOP/COEP headers), GDScript only.
Full plan: "Game production pipeline" doc, https://claude.ai/artifact/UVzDwm55T274i1FEqVb2X7

## Concept (chosen by Curtis)
Spooky-funny roguelite in an occult pawnshop. One run = 5 nights, about 20 min.
- Customers bring objects one at a time. Inspect with 4 tools (UV lamp, scale, listen, touch); each costs
  time on the day clock. Haggle (customer patience), buy, sell to later customers' requests.
- Pay rising rent each night (quota). Miss it, the run ends.
- Curses: hidden traits that pay off and cost (e.g. lucky paw +50% sales, every 3rd customer is not who they
  seem). Curses combo. They raise Dread; at thresholds something wakes (shelves topple, objects drift,
  lights die, door locks): the main clip moment.
- Pass it on: at run end you hold your worst object; the game makes a link on our site. A friend opens it in
  the browser and starts with that object plus its history (holders, count, worst thing it did). Public page
  of the most travelled curses. Needs a tiny server (object, traits, chain); no accounts.
- Instant replay: the kit's flight recorder saves the last 10 s when a curse wakes.
- Look: one room, fixed camera, low-poly 3D at low resolution with palette and dither.

## Why this concept (research, 18 Nov)
- Clip research (How To Market A Game, GameDiscoverCo, Naavik, AppMagic): shared moments read in 3 s with sound
  off, are earned by the player's choice, show funny failure, include other people, and the game makes sharing easy.
- Steam tag data (games-stats.com, PureGameStats): Lovecraftian/occult 16-26% of games reach $100K; job and
  shopkeeper sims 11-15%. Gambling 6% (median $270) and cats 5%, so slots and cats were dropped.
- Strange Antiquities (occult shop puzzle game, two brothers, $18): 100k copies, about $1.6M on Steam in 3 months.
- Competition: The Pawn Broker (2 reviews), How Much For It? (Q1 2027), Pawn & Roll (unreleased). None is a
  roguelite; no game found that passes a curse to real friends by link (two searches, not exhaustive).

## v1 scope and price
One shop, about 40 objects, 8 curses, 4 tools, 12 customer types. Browser build on our site (first run free,
$7.99 unlock via a merchant of record such as Paddle, about 5% + 50c, handles VAT/sales tax), plus Windows and
Linux downloads for Steam and itch (itch browser games can only take donations).

## Feel targets (bot and lab measure these)
| Target | Number |
|---|---|
| Load to first customer in browser | <= 15 s; web build <= 30 MB |
| Run length | median 15-25 min (sim) |
| A curse wakes by night 3 | >= 80% of runs |
| Greed tempting but risky | greedy bot survives 25-40% and earns >= 1.5x cautious when it does; cautious survives 50-65% |
| Tool feedback | <= 1.5 s; every cursed object has >= 1 tell |
| Frame rate | p95 <= 20 ms in a mid laptop browser |
| Friend's link | in play with their curse within 10 s |

## Rules from Curtis
- Never claim an idea is uncontested without checking Steam, SteamDB, news and current Steam events; list what
  you found with sources, or say you didn't check.
- Research properly before recommending; he rejects choices anchored on earlier work.
- Don't push live voxels as a selling point.

## Next steps
1. Debug layer and Tuning for the shop numbers; lab measuring the feel targets.
2. Vertical slice by 23 Nov: one shop, about 10 objects, the 4 tools, one curse waking, browser + Windows builds.
3. Web export preset (Compatibility, single-threaded) and a test page; buy a domain.
4. Steam: GodotSteam, private branch, Coming Soon page by about 29 Nov.
5. Curse-link server (small worker + key-value store), then content rounds to 13 Dec, release 18 Dec.

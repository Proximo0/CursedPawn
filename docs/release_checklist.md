# Release checklist: Cursed Pawn v1 (ship 18 Dec 2026)

Owner of each line is in brackets. Nothing here spends money, creates an account or publishes: those lines are marked
**Curtis**. Dates are 2026.

## 1. Build (every release candidate)
1. `tools/version.sh --write` stamps `application/config/version` (1.0.0+yyyymmdd.sha); the diagnostics report reads it. Commit that change on the release branch only. [lead]
2. `tools/check_all.sh` green (unit, sims, lint, lab, bot), then `tools/loudness_report.sh` (0 out of tolerance). [lead]
3. `tools/export_web.sh` (size check under 30 MB raw) and `node tools/web_smoke.mjs` (first frame under 15 s; the play-bot
   run's hash equals the native one with `SMOKE_BOT=greedy SMOKE_BOT_HASH=<native hash>`). [lead]
4. `tools/export_windows.sh` and `tools/export_linux.sh --smoke` (the exported Linux binary plays a whole bot run headless).
   CI keeps both as artifacts; the web workflow also builds `linux`. [lead]
5. Open the web build on a phone (iOS Safari and Android Chrome): title, one night, wake, run end, copy a link. [Curtis]
6. Soak: ten back-to-back bot runs in one process (`tools/perf.sh --frames=3000`), watch the worst frame. [Lane D]
7. No credentials in git: `git ls-files | grep -i credentials` is empty. [lead]

## 2. Changelog (keep a draft in the PR; players see the short form)
- Format: one line per change, player words first ("The Collector's theme now follows Dread"). Sections: New, Changed, Fixed.
- v1.0.0 draft: New: 56 objects, 12 curses, 16 customer types, night events, five wake types, endings, a journal, original music
  and 74 sounds, Linux build. Changed: haggling moods and counter-offers, buyer offers on shelf items. Fixed: see the PR list.

## 3. Store text drafts (edit freely; Curtis publishes)
- **Tagline:** Buy cursed things. Sell them to someone else. Keep the lights on.
- **Short (Steam, 300 characters):** Run an occult pawnshop for five nights. Inspect strange objects with a UV lamp, a scale,
  your ears and your fingertips, haggle for a fair price, and pay the landlord before the shop wakes up. Cursed items pay best.
  They also make the shelves move.
- **Long:** Customers bring you objects: a music box, a hatpin, a portrait that will not stay in its frame. You have four
  tools, a clock and a dwindling pile of patience. Buy low, sell high, and pay a rising rent each night. Cursed objects pay the
  most and raise the shop's Dread until something wakes. At the end of a run you pass your worst object to a friend as a link:
  their run starts with it, and with everything it did to you. About twenty minutes a run, a new seed every time.
  Features: 56 objects, 12 curses, regulars with their own stories, the Midnight Table, spells, an altar of upgrades,
  daily seances, original music, a keyboard, mouse and gamepad.
- **Tags:** Roguelite, Horror, Management, Occult, Dark Humor, Pixel Graphics, Short, Singleplayer, Replay Value.
- **Content descriptors to state truthfully:** cartoon horror, no gore, no real-money gambling (the Midnight Table uses in-game cash
  only; the reliquaries sell cosmetic curios with odds shown, see below).

## 4. Age rating notes (IARC questionnaire for the store pages; answer from the game, not from this list)
- Violence: none shown. Horror: supernatural themes, ghosts, objects that move on their own, unsettling text. Expect a teen-level
  outcome, not mature.
- Simulated gambling: the Midnight Table (dice, hand, wheel, Tarot Pairs, item stake, sealed lot) with in-game cash only: answer
  "simulated gambling: yes". No cash-out of anything.
- In-game purchases with random items: sealed reliquaries are paid random curios with odds shown before purchase and pity. This
  triggers "includes random items" on ESRB and requires odds disclosure on Steam. The store is 18+ and US-only by the terms.
  Paid-box curios are locked from trade; shards from duplicates are locked (see docs/core_brief.md).
- Drugs, alcohol, tobacco: none. Language: mild. Online interaction: pass-it-on links carry a handle only (no chat); the handle
  must pass the profanity filter when the link server exists.
- Unrestricted web access: none. Data collected: none sent anywhere; diagnostics stay on the device until the player copies them.

## 5. Legal terms review (pending a lawyer) [Curtis]
- `docs/legal/terms_of_sale.md` is a DRAFT. A US games lawyer must review it before any reliquary can be sold, in particular
  section 1 (18+, US only), the odds and pity text, the arbitration clause and Washington State rules on chance plus payment plus
  a prize. Fill the [COMPANY LEGAL NAME] and other bracketed items. Bump `RelicStore.TERMS_VERSION` on every change.
- Privacy policy (needed by every store page): states that no personal data leaves the device, saves are local, the pass-it-on link
  holds a code and a handle, and the optional diagnostics copy is manual. Draft after the link server spec exists. [Curtis + lawyer]
- Music and sound are procedural and original (no samples, no third-party audio); fonts and art: confirm licences in docs/ before
  launch. [lead]
- Do not open the reliquary to real payments until the review is done (the age and terms gate is `RelicStore.is_open()`; payment code is not part of this run).

## 6. Coming Soon and launch dates [Curtis unless noted]
| Date | Step |
| --- | --- |
| Fri 20 Nov | Pay the Steam app fee. New developers wait about 30 days for the app, so **Steam may not be ready by 18 Dec**: the web build on our own site is the launch that cannot slip; Steam and itch follow when ready. |
| Sun 29 Nov | Store page assets in /mnt/project-files/store (Lane C step 38), trailer or GIFs from the screenshot step, store text from section 3. |
| Fri 4 Dec | Steam Coming Soon page public (needs the 2-week window before release); itch page and our site page up with the web build link. |
| Fri 11 Dec | Submit the release build for Steam review (a few days); web build frozen for last checks. |
| Mon 14 Dec | Release candidate: sections 1 to 5 all ticked; price and unlock flow decided (step 28 was skipped this run). |
| Fri 18 Dec | Ship: web first run free, $7.99 unlock; Windows and Linux downloads. Do not publish from Claude. |

## 7. Known weak spots to read before shipping
See "Lane D progress" below and the notes in docs/performance.md (web frame time could not be measured meaningfully on the
shared cloud host).

## Lane D progress
- Step 40 music: done. `MusicSynth` (pure, 4 tracks: title, shop with 3 layers, table, collector) and `MusicPlayer` (lazy, one
  stem per frame, layered by Dread, ducking). Build time native: title 0.67 s, shop 0.93 s, table 0.24 s, collector 0.30 s
  (all four 2.1 s, each under the 2.5 s per-track budget; `tests/unit/test_music.gd` asserts it). Preview:
  /mnt/project-files/audio/music_preview.zip (`tools/render_music.sh`).
- Step 41 sounds: done. 19 new sounds (74 total): curse_shift, curse_copied, whispered_away, 4 night events, 5 wake types, 2 moods,
  buyer_offer, 4 endings. Event mapping is in `SfxPlayer` (see hooks). Preview: /mnt/project-files/audio/sfx_preview.zip.
- Step 43 performance: done (numbers and caveats in docs/performance.md). `tools/perf.sh`, `tests/perf/perf.gd`. Native script p95
  12.4 ms headless; SpriteKit first call worst 4.4 ms (no cache needed). Software GL and web frame time not meaningful on the shared host.
- Step 44 load time: done. Audio warm-up paced and lazy, music lazy and delayed 2 s, dread bed lazy. Web first frame 5.8 to 8.3 s
  (limit 15 s now asserted in `tools/web_smoke.mjs`). Largest remaining boot cost: UiHud 0.8 s and ShopRoom2D 0.36 s (Lanes B, C).
- Step 45 Linux build: done. `tools/export_linux.sh [--smoke]` (zip 28 MB, the exported binary plays a whole bot run headless),
  preset "Linux" in export_presets.cfg, a `linux` job in `.github/workflows/web.yml` that uploads the zip as an artifact.
- Step 48 diagnostics: done. `game/debug/diag_log.gd` (ring of 200 lines, engine errors via the Logger hook, home folder scrubbed,
  report text, optional `user://diagnostics.txt` on errors, never in scripted runs), `tests/unit/test_diag_log.gd`.
- Step 49 release checklist: done (this file, sections 1 to 7; `tools/version.sh`).
- Step 42 mix pass: done. Every one-shot is normalised in `SfxSynth.au_finish` to a class target (stinger -17, sfx -21,
  ui under 0.25 s -25 dBFS active level) with a soft limiter (peaks under -0.9 linear). `tools/loudness_report.sh`: 0 of 69
  one-shots out of the +-2 dB window (the metric is active-signal RMS, a stand-in for LUFS on short sounds).
  Ducking: music dips 4 dB under the Dread shimmer at full intensity and 12 dB for 3 s on a wake (`MusicPlayer.duck`).

## Hooks for other lanes
- Music runs by itself from `SfxPlayer.on_events` (night_start: shop, table_open: table, collector_arrives: collector,
  run_won/run_lost: stop, wake: duck) and `set_dread` (layers). `start_ambient()` starts the title track.
- Settings (Lane B): a music slider calls `sfx.set_music_volume(0..1)`; master and mute already reach the music.
- Settings (Lane B): a "Copy diagnostics" button calls `DiagLog.copy_report()` (returns the text, so the button can show "Copied"
  or a text box on platforms with no clipboard). `shop_game` may set `DiagLog.context = func() -> String: return <run summary>`.
- Boot (Lane B/C): lazy-build the HUD's table, found and toast panels and the room's less-used textures (about 0.8 s of the boot).
- Title (Lane B): when returning to the title from a run call `sfx.music.play_track("title")`.
- Lane A events the sounds listen for (add the field if it is named differently, then tell Lane D): `curse_shift`,
  `curse_copied`, `whispered_away`, `buyer_offer`, `night_event {id|event}` (id contains blackout, storm, auction or moon),
  `wake {wake_type}` (contains drift, topple, light, door/lock, possess), `run_won {ending}` (contains debt, cursed,
  collector, regular), `customer {mood}` (nervous, greedy). Unmatched ids make no extra sound.

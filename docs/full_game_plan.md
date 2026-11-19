# Full game plan: 50 ordered steps to a complete v1

Curtis (2026-11-18 22:01 PT): "fleshing out the whole game in one run ... 40 or 50 ordered steps instead of 4 or 5
and more detailed." One round, four lanes. Each lane works its steps **in order**. A step is done when its check
passes; the lane then moves on. Every lane ends a step with a short verify: the unit tests it touched, plus
`tests/shots/playthrough.gd` when the step changes what a player sees. Cross-lane needs are marked (needs Ln.s). Read
CLAUDE.md, docs/core_brief.md, docs/round6_brief.md, docs/horror_polish_brief.md and docs/lessons_learned.md
first. Nothing in this plan spends money, creates accounts or publishes anything. Curtis (22:03): "leave the stuff to me for later". Steps 28, 46 and 47 (paywall,
Steam hookup, link server) are **skipped this run**. Step 38 makes the store art files only.

## Lane A: systems and content (game/logic, game/data, tuning, lab)
1. **Audit pass.** Run the lab and the playthrough at haunting 0, 5 and 10. Write the measured numbers into
   docs/balance_log.md (new). Check: the log exists, with today's numbers.
2. **Curses 9-12.** Add four new curses with distinct mechanics: one that swaps an object's category each night,
   one that copies itself onto the next object bought, one that pays out only if you never inspect it, and one
   that lowers rent but whispers customers away. Each has at least 1 tell per tool where sensible. Check: catalog
   problems() is empty, and there are tests per curse.
3. **Objects 41-56.** Add 16 objects, filling thin categories, each with name, value, category and flavour text
   (text is new: add `text` to all 56). Check: catalog tests pass, and every object has text.
4. **Customer types 13-16.** Add 4 types (a medium who can sense curses, a child sent on an errand, a debt
   collector who takes cash, a twin who returns as a different type). Check: tests and lines.
5. **Object history.** Every object you buy carries a short provenance line (seeded from its tags) that the UI can
   show. Pass-it-on history already exists, so merge the two. Check: the `item.provenance` field exists, with a test.
6. **Night events.** On some nights an event fires at dusk: a blackout (tools cost double), a storm (fewer
   customers, higher prices), an auction (a special lot), or a full moon (curses double). Data-driven
   `night_events.json`, seeded. Check: tests per event.
7. **Wake variety.** Today one physics wake fires. Add wake types keyed by the curse that tipped it: drift, topple,
   lights-out, door lock, possession (one object follows the cursor). The logic picks the type and the room acts it
   out (needs C.24). Check: the event carries `wake_type`, with tests.
8. **Haggling depth.** Customers get a mood (calm, nervous, greedy) that is readable from tells in their lines.
   Counter-offers are smarter: a nervous seller drops fast, a greedy one bluffs. Check: tests, and lab targets hold.
9. **Selling depth.** Buyers can make an offer on a specific shelf item, and the player accepts or counters. This
   replaces the auto-price. Check: tests, and the bot updated.
10. **Ending variants.** Winning ends differently by run: debt-free, the shop is cursed beyond saving, the Collector
    satisfied, or the regulars' arcs complete. `run_won` carries `ending`. Check: tests per ending.
11. **Deeds 31-40.** Add deeds for the new curses, events, endings and wake types. Check: tests.
12. **Balance sweep.** Rerun the lab at 0, 5 and 10 with all the new content and retune to the five targets.
    Update the balance log. Check: the lab is green.
13. **Save robustness.** Fuzz-load corrupted and old profile and run saves (truncated, wrong types, an older
    version). Nothing may crash, and the player gets a reset with a backup. Check: fuzz test.
14. **Daily rotation.** Daily Séance weekly themes (for example "Cursed Week", where every item is cursed). Check:
    test.

## Lane B: UI, UX and onboarding (game/ui, game/shop)
15a. **Test menu (Curtis 22:05: "a test menu that i can see the different parts of the game in action without
    playing the whole game").** A "TEST MENU" entry on the title, shown in debug and dev builds (the builds in
    /mnt/project-files/builds are debug, so Curtis sees it) and hidden in release unless launched with `--dev`. It
    is a grid of scenes, each set up instantly from a seeded state and playable from there:
    - The tutorial night and the omen draw.
    - Each spell cast, and each backfire.
    - Every Midnight Table game: dice, hand, wheel, Tarot Pairs, item stake, sealed lot.
    - A request delivered, a regular's visit (pick the regular and chapter), and the Collector on night 5 (pleased
      and refused).
    - Every wake type, at full and gentle scares.
    - Dread stages with a live slider.
    - Every night event.
    - Each ending screen.
    - The altar with 999 ectoplasm.
    - The journal with everything unlocked.
    - Found popups and deed toasts.
    - The run-end screens, won and lost.

    Esc always returns to the menu. Nothing it does writes the player's real profile: it uses a throwaway profile
    in memory. New scenes from later steps add a tile here as they land. Check: a test opens every tile, and
    a contact sheet shows one frame per tile.
15. **Playthrough at full length.** Extend playthrough.gd to cover the tutorial, a regular, a deed, the Collector,
    the altar and a loss. Fix every bug it shows. Check: a sheet with no fallbacks.
16. **Inspect panel.** Clicking a held or counter object opens a detail card: art at 2x, name, flavour text,
    provenance, the tells found so far, and its curse if known. Check: a sheet cell.
17. **Haggle UI.** Show the customer's mood, a patience meter as a guttering candle, and counter-offer speech
    (needs A.8). Check: a sheet cell.
18. **Buyer offers UI.** Accept and counter flow on shelf items (needs A.9).
19. **Night event cards.** A dusk card for each event (needs A.6), with its rule spelled out.
20. **Ending screens.** A distinct ending card and epilogue text per ending (needs A.10).
21. **Settings, complete.** Master, SFX and music volumes; screen shake 0-100; flash reduction; text speed; a
    colour-blind tell palette; fullscreen and window scale; key rebinding for every action; reset to default.
    Check: settings tests, and values persist.
22. **Controller and Steam Deck.** Full gamepad navigation with focus rings on every screen and button glyphs. Check:
    a test drives every screen by ui_* actions only.
23. **Accessibility text.** Scale the body font 1x/2x for menus, and log text readable at 1280x720. Check: a sheet at
    both sizes.
24. **Journal.** One book holds the Grimoire, Regulars, Deeds, Curio sets, and the Bestiary of curses and customers
    met. It is reachable from the title and pause. Check: a sheet.
25. **Run history.** The last 20 runs: seed, omen, haunting, nights, cash, ending, and the "replay seed" button. Check:
    test.
26. **Title polish.** A live shop scene behind the title, the menu with flame cursors, and a continue-run preview
    card. Check: a sheet.
27. **Feedback pass.** Every player action gets a visual and a sound response within 100 ms. Audit the playthrough
    and list any silent action, then fix it. Check: an audit list with every item closed.
28. **[LATER, Curtis] Web paywall shell** **[Curtis]**. After the first full run on the web build, show an "Unlock the full shop
    ($7.99)" screen. The store link is a placeholder, and there's a dev flag to unlock. No payment code. Check: the
    flow works with the flag.

## Lane C: art, room and animation (game/room2d)
29. **Sprites for new content.** Draw 16 objects, 4 curses' overlays and 4 customer types (needs A.2-A.4).
30. **Inspect art at 2x.** Objects have a 64x64 detail render (needs B.16).
31. **Customer moods.** Each customer gets an expression frame for each mood (needs A.8).
32. **Wake types in the room.** Drift, topple, lights-out, door lock and possession, each with its own look (needs
    A.7). Check: a room sheet cell each.
33. **Night events in the room.** Blackout (only the candle pools), storm (rain on the window, lightning), auction
    (a podium), full moon (a big moon, silver rim light).
34. **Ending tableaux.** One full-screen 640x360 illustration per ending (needs A.10).
35. **Title scene.** The live shop behind the title: slow parallax, a customer shadow passing the window, and a
    moth circling the lamp. No cat (the handoff dropped cats).
36. **Animation pass.** Customer walk cycles (4 frames), the door swing with a bell, the counter object landing,
    the coin toss, and the shelf object settling.
37. **Lighting pass 2.** Each torch flickers per frame with a seeded noise curve, Dread tints the light colour, and
    the window light follows the night (dusk, then night, then the pre-dawn grey on the last customer).
38. **Store art** **[Curtis]**. Steam capsules (header 920x430, small 462x174, main 1232x706, vertical 748x896,
    library 600x900 and hero 3840x1240, logo) rendered from the game's own art plus the DISPLAY font. Ready for
    upload, but not uploaded. Check: files in /mnt/project-files/store/.
39. **Screenshots.** Ten 1920x1080 screenshots of the best moments, from scripted captures. Check: files.

## Lane D: audio, music, performance and release (game/audio, tools, CI)
40. **Music.** A procedural, sequenced music system (patterns synthesized at load): a shop theme in 3 intensity
    layers that follows Dread, a table theme, a Collector theme and a title theme. Total build at most 2.5 s, with
    lazy load per track. Check: a preview zip and a timing test.
41. **Sounds for new content.** New curses, events, wake types, moods and endings.
42. **Mix pass.** Loudness-normalize every sound. Ducking: music dips under the Dread layer and under wake beats.
    Check: an offline loudness report, with every sound within ±2 LU of target.
43. **Performance.** Profile frame time in the web build under swiftshader and natively. Target p95 at or under
    20 ms. Cache the SpriteKit textures, so the first-call cost is under 50 ms. Check: a report in
    docs/performance.md.
44. **Load time.** First customer in at most 15 s on the web. Measure the boot phases and trim (lazy audio, a
    texture warm-up spread over frames). Check: the web_smoke number.
45. **Linux build.** `tools/export_linux.sh` to a zip in build/, and a CI artifact. Check: the zip runs headless
    smoke.
46. **[LATER, Curtis] Steam integration prep** **[Curtis]**. A GodotSteam-ready adapter (an interface with a no-op backend): deeds
    map to achievement ids, the daily score maps to a leaderboard id, and there's cloud-save path mapping. No
    Steam SDK download until Curtis has the app id. Check: tests on the no-op backend.
47. **[LATER, Curtis] Pass-it-on server spec** **[Curtis]**. A minimal API spec plus a static fallback (the link works with no
    server: the code already lives in the URL fragment). The server spec covers the public "most travelled curses"
    page. Check: docs/online.md section.
48. **Crash and error capture.** A local log ring buffer, a "copy diagnostics" button in settings, and nothing sent
    anywhere. Check: test.
49. **Release checklist.** docs/release_checklist.md: build, version stamp, changelog, store text drafts,
    age-rating notes, the legal terms review (pending a lawyer), and the Coming Soon steps by 4 Dec. Check: the doc.
50. **Final gate.** check_all, lab, playthrough, web smoke, the Windows and Linux builds and the size check all
    green, as one PR. Check: the PR is merged.

## Polish loop (every lane, after its last numbered step)
Run the playthrough capture and the lane's sheets, then list every rough spot: art that reads badly at 1x, a
missing sound or animation, unclear text, a balance number drifting, a visual glitch. Fix them, re-capture, and
repeat until the list is empty or only items for another lane remain (send those to the lead). Carry over and close
the known weak spots from earlier rounds:
- The Collector's face and case, the regular rim light, the portrait faces and the cabinet icon detail.
- The omen card art.
- The altar buy animation.
- Customer hands.

## Lane order and handoffs
Lane A runs 1-14. Lane B runs 15-28 and does steps that need A only after the A step lands. Until then it builds
against the stated contract (field and event names given here) and fills them in after. Lane C runs 29-39 in the
same way. Lane D runs 40-50, and step 50 is last for everyone. The lead integrates through one PR at the end, or
several PRs if the lanes finish far apart.

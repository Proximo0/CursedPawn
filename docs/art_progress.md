# Art progress (Lane C, full-game run, 19 Nov 2026)

Step log for docs/full_game_plan.md steps 29-39 and the polish loop. Files: `game/room2d/` (`art_content.gd`,
`room_scenes.gd`, `ending_art.gd`, `store_art.gd`, hooks in `sprite_kit.gd` and `shop_room_2d.gd`), tests in
`tests/unit/test_sprite_kit.gd`, `test_room2d_scenes.gd`, `test_room2d_tableaux.gd`, `tests/sim/sim_room2d_wake.gd`.
Sheets: `tests/shots/sprite_sheet.gd -- --c29` (steps 29-31), `--c34` (tableaux); `room2d_sheet.gd -- --c32` (32-37).

| Step | Status | Notes |
| --- | --- | --- |
| 29 Sprites | done | 16 objects for Lane A's ids (wind_up_frog ... wax_seal) plus 12 spares used for unknown ids by keyword then category; 4 curse overlays (`ArtContent.curse_overlay`: shift, echo, seal, hush); 4 customer types (errand_child basket, debt_collector hat+ledger, twin ghost hood, seer veil). `object_cursed_overlay(id, category)` now takes the category. |
| 30 Inspect art | done | `ArtContent.object_detail(id, category)` 64x64: outline redrawn 1 px, second light ramp, grain, glints. |
| 31 Moods | done | `look.mood` = calm / nervous / greedy changes the face (rings, brows, sweat, coin glints, grin); `ArtContent.mood_frames`. The room reads `customer.mood` (missing = calm). |
| 32 Wake types | done | `wake(seed, type)`; the event's `wake_type`. drift, topple (all units), lights_out, door_lock, possession (cursor-following). Sim row per type. |
| 33 Night events | done | blackout, storm (rain, lightning, gentle limits the flash), auction (podium on the counter), full_moon (moon, silver rim light). Read from `night_event {id}` or `run.night_event`. |
| 34 Tableaux | done | `EndingArt.tableau(id)` 640x360 for debt_free, cursed, collector, regulars, evicted. Not yet used by game/ui. |
| 35 Title scene | done | `room.set_title_mode(true)`: auto drift, shadow at the window, moth at the lamp. game/ui must call it. |
| 36 Animation | done | walk cycle (4 frames), door skew plus bell (`bell_rang`), counter landing (`object_landed`), coin toss (`coin_landed`), shelf settle. |
| 37 Lighting 2 | done | seeded noise torch flicker, Dread flame tint, window dusk / night / pre-dawn from the day clock. |
| 38 Store art | done | `tests/shots/store_art.gd` -> /mnt/project-files/store/ (7 files). Not uploaded. |
| 39 Screenshots | see report | `tests/shots/screenshots.gd` -> /mnt/project-files/store/screenshots/. |

## Polish loop
Renders used: room `--r6` (cabinet, rim light, Collector), sprite `--r6` (portraits, Collector, curio icons), `--c29`, `--c34`.
Closed this round:
- Regular rim light: now a mask of the lit top-left edge drawn over the figure (`ArtContent.rim_mask`), not a copy peeking out
  behind it; tinted amber for a regular, silver in a full moon. Verified by unit test only (the room cell was not re-rendered).
- Portrait faces: modelled cheek, jaw, eye bags, nose highlight and lips (`regular_portrait`); still a little noisy at 1x.
- Collector: smoked spectacle lenses with a red pinprick, thin mouth, hollow cheeks, darker brass rims; the case is now a case
  (handle, lid seam, lock plate, two latches, two drawer rows) instead of a box of drawers.
- Cabinet icons: 24 to 16 px by area mode that keeps the outline (`ArtContent.downscale_mode`), not nearest.
- Customer hands: pale nails instead of dark fingertips.
- Tableaux: faces for the regulars and the Collector, a smaller streetlamp glow. Twin ghost hood is denser.
Still weak: the omen card art and the altar buy animation were not touched (no budget left); the curse overlays read faintly at
1x; Lane B's title does not call `room.set_title_mode(true)` and no ui screen shows the `EndingArt` tableaux yet.

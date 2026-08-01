# Design QA — 墨卷行旅与人物戏剧

## Current design target

The core journey now follows one visual grammar: the world remains the primary stage, people appear inside that stage, choices enter as a contextual narrative sheet, and only decisive causal changes take over the full screen.

- Viewport: 1280 × 800 at density 1.
- Runtime video: `D:\C\Desktop\ai\fantu\artifacts\video\fantu-gameplay-demo.mp4`.
- Duration: 57.8 seconds at 20 FPS.
- Journal layering audit: `D:\C\Desktop\ai\fantu\output\audits\2026-08-01-journal-layering`.
- Key states: `01-causal-safe-zone.png`, `02-echo-summary.png`, `03-clues-summary.png`, `04-people-summary.png`, `05-gear-blockers.png`, and `06-gear-details.png` in that audit directory; `contact-sheet.png` combines all six.

## Findings

No actionable P0, P1, or P2 visual issue remains in the recorded MVP path.

- The permanent dashboard rail has been removed. Map mode uses the whole travel field; location mode reveals a single bottom-left narrative sheet only when choices are relevant.
- The header now behaves as a restrained game HUD. Day, place, and phase remain visible, while dossier, settings, save, and return actions step back as utilities.
- The route view no longer uses scenic thumbnail cards. One authored landscape carries curved routes, restrained duration marks, and hotspot-like destinations.
- Character portraits are borderless, larger, and edge-faded into the live location scene. Names and roles remain readable without restoring the old product-card frame.
- Default actions are contextual and limited to three immediate choices. Travel stays on the map and information transfer starts from a person, removing internal action taxonomies from the main path.
- Confirmation is an in-scene commitment sheet with fictional language such as “传出此话”, “即刻启程”, and “静候其变”. Secondary reasoning remains collapsed under “展开盘算”.
- The dossier now has four task-specific sections. Echoes summarize the consequence first, clues and people expose only current affordances, and gear promotes missing blockers into a red tab marker while completed checks remain collapsed.
- Zero-value support and injury metrics no longer consume the player summary. Compact status chips retain combat, spirit stones, carried essentials, and only exceptional states.
- The causal theatre now reserves the left 34% for the portrait and starts narrative copy at 39%. The seal occupies its own column instead of sitting behind the current-plan text.
- First causal change and ending retain their full-screen cadence, so the everyday shell and dramatic peaks now belong to the same experience.
- Focus treatments, text labels for color-coded states, reduced motion, sound settings, save, journal, cancellation, and back navigation remain functional.

## Remaining polish

- P3: source portrait images contain their own environment. The wider shader fade makes the join intentional at the MVP viewport, but true transparent painted cutouts would allow stronger parallax and lighting integration later.
- P3: the five-location map reads clearly, but a larger world will need route clustering or zoom before line density grows.
- P3: the full causal theatre still uses a literal before/after arrow, though its composition no longer overlaps. A later art pass can replace it with an ink-spread or rewritten-scroll transition.
- Platform QA still needs dedicated controller focus-order, screen-reader, text-scaling, and non-1280×800 validation.

## Verification

- `go test ./...` passes.
- `tools/verify-godot.ps1` passes integration, propagation, and contender journeys.
- The final recording contains 1157 rendered source frames and a 57.8-second H.264/AAC deliverable.

final result: passed

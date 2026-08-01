# Design QA — 品味升级与因果戏台收口

**Source visual truth**

- Path: `D:\C\Desktop\ai\fantu\docs\design\visual-target-causal-theatre.png`
- Source pixels: 1584 × 992.
- Normalization: source and implementation were both normalized to an exact 1280 × 800 frame for comparison; density 1, no device frame or browser chrome.

**Implementation evidence**

- Primary screenshot: `D:\C\Desktop\ai\fantu\output\audits\2026-08-01-taste-final\05-causal.png`
- Full-view comparison: `D:\C\Desktop\ai\fantu\output\audits\2026-08-01-taste-final\qa-full-comparison-pass2.png`
- Focused causal-region comparison: `D:\C\Desktop\ai\fantu\output\audits\2026-08-01-taste-final\qa-focus-comparison-pass2.png`
- Supporting state sheet: `D:\C\Desktop\ai\fantu\output\audits\2026-08-01-taste-final\contact-sheet.png`
- Ending state: `D:\C\Desktop\ai\fantu\output\audits\2026-08-01-taste-final\07-ending.png`
- Runtime video: `D:\C\Desktop\ai\fantu\artifacts\video\fantu-gameplay-demo.mp4`
- Implementation pixels / logical viewport: 1280 × 800 at density 1.
- Primary state: 沈砚秋收到已核实的成熟日消息，并在第 5 日形成第一次可见决断。

## Findings

No actionable P0, P1, or P2 issues remain.

- Fonts and typography: the existing Chinese serif display face and sans-serif body face preserve the target’s editorial hierarchy. The causal sentence, before/after headings, plan text, and CTA have distinct optical weight; the fixed copy and observed dynamic strings do not clip at 1280 × 800.
- Spacing and layout rhythm: the decisive actor occupies the left field while the causal sentence, timeline, decision note, and CTA form one readable vertical path over the world. Start, first causal change, and ending now share the same full-scene composition instead of switching back to generic centered report cards.
- Colors and visual tokens: black-green environmental tones, antique gold, warm white, and vermilion remain consistent across map, action rail, modal, causal change, and ending. Utility controls, ordinary actions, and the single commitment CTA no longer use the same surface treatment.
- Image quality and asset fidelity: map landmarks, start background, causal background, portraits, seal, timeline, and ornate frame all use the project’s production raster assets. No placeholder, handcrafted SVG, emoji, or code-drawn substitute replaces a target image asset.
- Copy and content: start-screen service diagnostics are hidden when healthy. The decision rail shows one action category at a time, confirmation leads with consequence and timing, and secondary reasoning is disclosed on demand. Later related causal events step down to “余波继续” instead of replaying the full ceremony.
- Interaction and accessibility: primary controls are functional and covered by integration tests. Focus treatments remain visible, the settings panel includes a reduced-motion mode, and outcome/state meaning is expressed with text as well as color. Keyboard traversal and screen-reader behavior remain a future platform-level test rather than a claimed result.

## Comparison history

### Iteration 1 — blocked

Evidence: `qa-full-comparison.png` and `qa-focus-comparison.png`.

- [P2] The causal content sat too far to the right and too high compared with the source, weakening the intended overlap between actor, world, and causal timeline.
- [P2] A redundant actor-status eyebrow and a long explanatory day sentence added dashboard-like copy to the cinematic state.
- [P2] The decisive portrait was brighter than the source and competed with the causal sentence.

Fixes made:

- Expanded the causal content field across the actor/world seam and moved its vertical start to match the source’s central composition.
- Removed the redundant visible eyebrow and condensed the day line to “由原本到现在，已有决断”.
- Applied a restrained portrait tint so the narrative text and vermilion seal remain dominant.

### Iteration 2 — passed

Post-fix evidence: `qa-full-comparison-pass2.png`, `qa-focus-comparison-pass2.png`, `05-causal.png`, and `07-ending.png`.

- The actor/world proportion, title placement, before/after line, seal, decision note, and CTA now preserve the selected visual truth at the native viewport.
- The supporting contact sheet confirms that the same hierarchy carries through start, map, location, actor focus, confirmation, compact ripple, journal, and ending states.

## Open Questions

- P3: actor images are rectangular environment portraits rather than transparent painted cutouts. The deliberate dark treatment makes the edge acceptable for MVP while preserving the correct live character and expression.
- P3: the route chart remains a functional data visualization, so line crossings are possible in dense future scenarios. The current five-location MVP remains readable.

## Implementation Checklist

- [x] Replace the debug-node map with production scene thumbnails and restrained route marks.
- [x] Separate utility, ordinary-action, category, primary, and ornate control levels.
- [x] Limit the default decision rail to one expanded category.
- [x] Put reasoning behind explicit disclosures in actor and confirmation states.
- [x] Use first-change full theatre and later-change compact ripple cadence.
- [x] Bring start and ending into the same full-scene narrative language.
- [x] Add reduced-motion behavior and automated coverage.
- [x] Verify the full Go and Godot suites and record the complete 1280 × 800 journey.

## Follow-up Polish

- P3: create transparent full-height cutouts for the three core actors if a later art pass needs softer portrait integration.
- P3: perform a dedicated keyboard/controller navigation pass before distribution outside desktop mouse users.

final result: passed

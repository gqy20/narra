# Design QA — 因果改写戏台

**Source visual truth**

- Path: `D:\C\Desktop\ai\fantu\docs\design\visual-target-causal-theatre.png`
- Original pixels: 1584 × 992.
- Normalization: proportionally scaled and padded to 1280 × 800 for the combined comparison; source and implementation are both 8:5 after normalization.

**Implementation evidence**

- Primary screenshot: `D:\C\Desktop\ai\fantu\output\design-qa\2026-08-01-causal-theatre\source-state-causal.png`
- Combined comparison: `D:\C\Desktop\ai\fantu\output\design-qa\2026-08-01-causal-theatre\comparison-source-implementation.png`
- Journal state: `D:\C\Desktop\ai\fantu\output\design-qa\2026-08-01-causal-theatre\implementation-journal.png`
- Ending state: `D:\C\Desktop\ai\fantu\output\design-qa\2026-08-01-causal-theatre\implementation-ending.png`
- Viewport and CSS-equivalent logical size: 1280 × 800 at density 1.
- State: 沈砚秋收到已核实的成熟日消息，并在第 5 日形成第一次可见决断。
- Runtime evidence: `D:\C\Desktop\ai\fantu\artifacts\video\fantu-gameplay-demo.mp4`, 1280 × 800, 20 FPS.

## Findings

No actionable P0, P1, or P2 fidelity issues remain.

- Fonts and typography: the implementation uses the project’s existing Chinese serif display face and sans-serif body face. The hierarchy matches the target: restrained actor meta, 30 px causal sentence, 28 px before/after headings, 18 px plan text, and a 20 px display CTA. Dynamic backend strings remain readable without clipping.
- Spacing and layout rhythm: the selected world-first composition is preserved. The actor occupies roughly the left 40%, the causal content uses the central/right field, and the timeline, decision note, and CTA form a single vertical reading path. The viewport is now native 1280 × 800 instead of a downscaled 1440 × 900 canvas.
- Colors and visual tokens: black-green environmental tones, antique gold, warm white, and vermilion map to the source. Ordinary UI continues to use the established project palette instead of introducing a second visual system.
- Image quality and asset fidelity: the location background and decisive actor portrait are production assets selected from the live game state. The seal, timeline, and button frame are real transparent raster assets generated from the selected target; no placeholder or code-drawn substitute remains.
- Copy and content: the visual grammar matches the target while copy comes from the actual causal payload: who heard what, the plan without the information, the plan with the information, and the day the change became visible.
- Interaction and accessibility: the causal state is modal and unscrollable, its primary action dismisses it, the same result remains available in the journal, focus styles remain visible, and state is communicated with explicit text in addition to color.

## Comparison history

### Iteration 1 — blocked

- [P1] The signature vermilion seal was not visible because a container overrode its anchors.
- [P1] The ending showed statistics as primary narrative and allowed a causal layer to bleed through behind it.
- [P2] The app rendered a 1440 × 900 logical canvas into 1280 × 800, making body text smaller than intended.
- [P2] Once the seal appeared, “现在” was duplicated by a separate heading.

Fixes made:

- Moved the seal into the fixed timeline canvas and layered text above it.
- Moved ending statistics into a closed “局势附录” and stopped action presentations once the ending is visible.
- Changed the project viewport to native 1280 × 800.
- Kept “现在” in the generated seal asset and removed the duplicate coded heading.

### Iteration 2 — passed

- Post-fix evidence: `source-state-causal.png`, `implementation-journal.png`, `implementation-ending.png`, and `comparison-source-implementation.png`.
- The selected visual hierarchy, custom assets, dynamic causal content, drawer state, and narrative-first ending are all visible at the intended viewport.

## Open Questions

- The production portrait contains its own environment crop, so its right edge is more editorial than the concept illustration’s painted blend. This is an accepted P3 difference because preserving the real actor identity and expression state is more important than replacing it with concept-only art.

## Implementation Checklist

- [x] Use real location and actor assets from the current game state.
- [x] Show message → original plan → changed plan without scrolling.
- [x] Use the generated seal, timeline, and ornate frame assets.
- [x] Dismiss the causal state with a working primary action.
- [x] Preserve the result in the journal.
- [x] Keep statistics collapsed behind a secondary ending control.
- [x] Verify at 1280 × 800 with a complete recorded journey.

## Follow-up Polish

- P3: create actor-specific full-height cutouts in a later art pass if the project needs an even softer portrait/background blend across every core character.

final result: passed

# Godot visual theme

`app_visual_theme.gd` is the authority for the shared client shell:

- bundled font roles;
- the readable type scale;
- stable semantic interface colors;
- reusable `StyleBoxFlat` construction;
- the root Godot `Theme` applied by the main screen.

Generic interface code should consume these tokens through `AppVisualThemeScript`.
The compatibility aliases on `main.gd` (`COLORS`, `TYPE_SCALE`, and the font
members) exist while screen controllers are migrated away from their broad
`host` dependency; they are not a second source of truth.

World-specific artwork, actor accents, map-token colors, and resource mappings
remain in each content package's `presentation.yml` and asset root. Procedural
illustrations may keep a private local palette when those colors describe the
artwork rather than an interface state.

Do not put player-facing story language or world IDs in this directory. Do not
add a content-package fallback theme here: a missing semantic presentation
value must continue to fail during scenario validation.

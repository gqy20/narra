# Godot UI boundaries

The client UI is split into three layers:

- `theme/` owns font roles, type scale, semantic colors, and primitive styles.
- `components/ui_factory.gd` creates reusable controls and applies shared states.
- `screens/game/` composes the game screen regions from explicit dependencies and callbacks.

`scripts/game_screen.gd` owns the live nodes returned by the game-screen builders and
implements rendering and interaction for that screen. Other controllers may use the
screen controller as their view interface; they must not add game-screen node fields
back to `main.gd`.

Region builders must remain independent from the application host. Pass scripts,
registries, and callbacks through their `dependencies` and `callbacks` dictionaries.
They may create nodes, but they must not read runtime story state or submit actions.

Generic components must not contain world IDs or player-facing story defaults. Story
language and presentation mappings remain in the content package. Missing visual
resources may fall back through the presentation registry; missing semantic content
must continue to fail validation.

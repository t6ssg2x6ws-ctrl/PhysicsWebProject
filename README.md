# Wizarding Castle 3D

A realistic 3D Harry Potter-inspired castle prototype built with **Godot 4.7** (Forward+ renderer). Explore two connected chambers, find a way through the enchanted locking door, and complete a Reparo restoration mission.

## Features

- Two connected, fully decorated chambers: the Antechamber and the Relic Chamber
- First-person player controller with mouse look, sprinting, and jumping
- Enchanted door that unlocks when you interact with the mission lectern
- Reparo repair mission at a workbench, tracked by an in-game HUD
- Lumos-style handheld light with flickering candle and sconce lighting
- Hand-authored PBR materials and textures for stone, wood, iron, brass, carpet, and parchment
- Pause menu and mouse-capture handling

## Requirements

- [Godot 4.7](https://godotengine.org/) or newer with the Forward+ renderer
- No external dependencies or build step

## Run it

```bash
git clone https://github.com/t6ssg2x6ws-ctrl/PhysicsWebProject.git
cd PhysicsWebProject
```

Open `project.godot` in the Godot editor, then press <kbd>F5</kbd> (or click **Run Project**).

## Controls

| Action | Input |
| --- | --- |
| Move | <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd> / arrow keys |
| Look | Mouse |
| Jump | <kbd>Space</kbd> |
| Sprint | <kbd>Shift</kbd> |
| Interact | <kbd>E</kbd> |
| Lumos | <kbd>F</kbd> |
| Pause | <kbd>Esc</kbd> |
| Show or hide the exploration controls | <kbd>H</kbd> |

The exploration controls scroll opens for the first 10 seconds. After it collapses, press **H** or click **Show Controls** when the cursor is available. A manually reopened guide stays open until you close it.

## Game 1 · Dumbledore's Triple Wand Trial

Run the project with **F5**. Enter the Gryffindor Chamber through the Serpent Arch, accept the Enchanted Lectern mission, and press **E** at the wand console. Read the three voltage clues on the chamber obelisks. Press **Begin Trial** to start the clock. Drag a physical knob left or right, scroll over it, or select it with **1–3** and adjust it with the arrow keys. All three wands must glow at the same time. **Retry** returns to the parchment for a fresh attempt. **Save Result & Continue** records the result, restores first-person controls, and opens the door toward Snape's Memory Trial.

The common room starts dim. Press **F** to use Lumos while exploring the wallpapered lounge and reading the obelisks. Calibrating all three wands lights the hearth, sconces, chandelier, and floating candles for the rest of that visit, including retries. Restarting the chamber restores the dark lighting.

In the Godot Inspector, select **StationWandTrial** in `scenes/props/station_wand_trial.tscn`. **Calibration** exposes the three target voltages and the shared ±0.15 V tolerance. If you change the targets, update the obelisk labels in the Gryffindor room as well. **Score Benchmarks** exposes the provisional 20 s fast benchmark and 90 s slow benchmark. The slow value must exceed the fast value, or scoring uses those defaults. An optional **Calibration Sound** accepts a local `AudioStream`.

The trial uses Godot's monotonic clock, including time paused during an attempt. The HUD shows whole seconds, while scoring uses the full elapsed time. Scores decrease linearly from 100 at the fast benchmark to 0 at the slow benchmark. Time beyond the slow benchmark does not end the trial.

Other gameplay systems can listen to `GameManager.wand_trial_result_accepted(result)` or retrieve a copy from `GameManager.get_wand_trial_result()`. The result stores `game_id` (`triple_wand_trial`), `completed`, `completion_time_seconds`, `performance_score`, and the four `*_points` fields. Replace the stored Game 1 result when accepting another attempt. Its contributions are 40% Gryffindor, 20% Slytherin, 15% Ravenclaw, and 25% Hufflepuff. The result lives in the current game session and clears on restart.

Run the Game 1 integration checks from the project root with Godot on your path:

```bash
godot --headless --path . res://tests/triple_wand_test.tscn
```

## UI typography and popups

New Godot UI controls inherit the shared readable serif from `assets/materials/wizard_ui_theme.tres`. Give popup warnings and titles the largest type, make the next action prominent, and keep supporting copy smaller but readable. Use high-contrast colors as a second cue alongside size, with burgundy for critical headings and dark ink for details on parchment. For new 3D signs, assign `assets/materials/wizard_serif.tres` to the `Label3D` font. Use `assets/materials/scroll_frame.tres` as the panel style for new prompts, notices, and dialogs.

## Project layout

```text
project.godot          Project configuration, input map, autoloads
scenes/main.tscn       Main scene
scenes/player/         First-person player
scenes/rooms/          Antechamber and Relic Chamber
scenes/props/          Door, lectern, workbench, quest item, candles, sconces
scenes/ui/             HUD and menus
scripts/               Game manager, player, interaction, and mission logic
assets/materials/      PBR materials
assets/textures/       Albedo, normal, and roughness maps
```

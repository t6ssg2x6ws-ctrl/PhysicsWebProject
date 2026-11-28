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

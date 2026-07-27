# Creature Runtime Bridge

Voxelverse Creature Lab V5 now uses one creature blueprint from editor to play mode.

## Flow

1. Run `creatures/editor/creature_editor.tscn`.
2. Generate a deterministic creature from a seed or edit it manually.
3. Use **Mutate** to create a related descendant.
4. Press **Play Creature**.
5. The main world loads the same saved blueprint as the player model and applies its core stats.
6. Press **F2** in play mode to return to the Creature Lab.

The V5 save is self-contained at `user://creature_editor_blueprint_v5.json`. Legacy V4 saves remain readable and are still written for compatibility.

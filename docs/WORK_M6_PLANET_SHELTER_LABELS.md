# M6-PLANET-PRESENTATION: distant shelter captions

Completed huts and tents created a permanent world caption. From a camera
over 100 m away, several small captions remained visible across a grown
village, even though the roofs and buildings themselves already provide the
visual landmarks. This focused presentation change hides shelter captions
beyond 70 m and restores them within 60 m. The 10 m gap prevents flicker at
the boundary. It reads only the current camera every 0.25 seconds while homes
exist; it changes no building meshes, collisions, beds or saved state.

The fixture on the base tree failed with a distant caption still visible.
After the change it checks near → far → near at fixed camera positions and
verifies that the building/collider node is reused. Godot 4.6.3 headless
source/import, the label test and the existing housing contract pass.

This is one independent slice of the planet-presentation backlog. A native
comparison of the integrated PT17 camera, village motion, shelter labels,
terrain and stockpiles at small/large planets and inclined views remains open,
as does target-PC frame-time and visual acceptance.

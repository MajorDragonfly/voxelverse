# Built-in building templates (INT30-25)

These are ordinary BuildingBlueprint / ModularAssembly schema-1 designs made
entirely from BuildingPartLibrary entries. They do not construct campaign
buildings, grant resources, unlock the editor, or introduce production logic.
The building editor remains a medieval-phase authoring tool.

| Template ID | Source revision | Type | Parts | Cost | Housing | Commerce | Industry |
|---|---:|---|---:|---:|---:|---:|---:|
| `building.template.residence` | 1 | residential | 12 | 54 | 15 | 0 | 3 |
| `building.template.warehouse` | 1 | commercial | 13 | 77 | 18 | 2 | 0 |
| `building.template.workshop` | 1 | industrial | 11 | 68 | 2 | 8 | 12 |

This table records the current part-catalog sums. Runtime selection calculates
all eight values through BuildingBlueprint.calculate_stats, without copied
balance constants. Part scale does not multiply statistics in the existing
contract. In particular, the long-hall warehouse has housing/commerce values
and **no catalog-defined storage capacity**; the house chimney contributes
industry/pollution. These remain authoring values, not new simulation effects.

## Identity and use

- `catalog.json` lists the three immutable source IDs and concrete revisions.
  A changed source keeps its template/design ID and increments both revisions.
  Part UIDs remain stable for unchanged placements; never recycle a removed UID.
- `BuildingTemplates.load_template` reads and validates the raw native data
  before existing compatibility normalization. Unknown IDs fail closed.
- `create_copy` creates a fresh design ID, fresh part UIDs, revision 0 and
  `metadata.source_template` with the exact source design/template/revision.
  Transforms and part IDs remain identical. The default name includes an ID
  suffix, so separate copies have separate default editor filenames.
- `save_copy` explicitly saves a new copy through the existing DesignStore and
  BuildingBlueprint revision path. It uses the full design ID as filename and
  refuses any existing file or managed snapshot entry. Revision 0 becomes 1.
  It does not save the whole campaign; existing editor/SaveService ownership
  remains responsible for that. Normal subsequent edits use the editor save.
- Browsing and selection do not write or replace a current editor design.
  Use-copy is an explicit action recorded in the existing undo history.

## Geometry and limits

All buildings have grounded structural masses, attached facade doors/windows,
roof overlap, and connected decorations. The current parts expose additive box
geometry, not subtractive openings or traversable interiors. They do not expose
building attachment sockets; the tests check geometric contact using the actual
transformed catalog boxes, not invented socket identifiers. The runtime mesh
and aggregate bounds use the unchanged ModularVoxelMeshBuilder/BuildingVisual.
The supplied designs have 11–13 placements, well below native 2048-part limits.

## Integration owners

The optional BuildingTemplatePicker and BuildingTemplateSelection bridge are
separate helpers. `docs/evidence/int30-building-templates/integration/` contains:

- `chat14-building-builder.patch`: a narrow optional editor picker hookup for
  Chat 14 (`git apply --unidiff-zero` on the fixed basis). Rebase the hook into the improved editor; no editor file is changed
  in this feature branch.
- `chat1-validation.patch` / `validation.append.json`: register
  `int30_building_templates_test` exactly once under `blueprints` via Chat 1.
- `localization.append.json`: DE/EN additions for the existing shared catalog
  and generator, also via Chat 1. The review fixture temporarily loads this
  exact append; it is not another production translation service.

No exchange adapter changes are needed; Chat 17 can roundtrip these ordinary
native designs using the existing IDs, revisions and metadata.

## Reproduce

After an ordinary Godot 4.6.3 import, run the focused review with isolated data:

```sh
python3 tools/review_int30_building_templates.py --godot GODOT --headless-only --output OUTPUT
# With a display, e.g. Xvfb:
python3 tools/review_int30_building_templates.py --godot GODOT --output OUTPUT
```

The rendered review runs genuine copy-use clicks and keyboard movement,
rotation and scaling, undo/redo, explicit native saving, existing editor reload,
DE/EN switching, and a second process reading the edited saved designs. It saves
15 PNGs: front/rear/top plus editor-open/edited-reloaded for each design.

Once the proposed registry append is integrated, use the repository runner:

```sh
python3 tools/validate_godot.py --godot GODOT --tests int30_building_templates_test modular_assembly_framework_test blueprint_contract_test --skip-main --output OUTPUT
```

Focused evidence covers this standalone authoring delivery. Shared integration,
native exports, target-PC performance and subjective visual approval remain
separate checks.

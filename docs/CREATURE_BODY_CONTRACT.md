# Körpervertrag B1 für Artenkatalog und spätere Ausrüstung

Ergänzung B2: [Geometrische Passprüfung und gezielte Korrekturen](CREATURE_BODY_FIT_CONTRACT.md). Die gespeicherten B1-Anschlüsse behalten ihr Schema.

Auftrag 2 · 9. September 2026 · gemeinsame Basis `3a3e0272375e556f3ff65b7370582af79a9d48b5`.

Dieser Vertrag liefert Körpergeometrie, gespeicherte Anschlüsse und messbaren Fußkontakt. **D1 besitzt weiterhin das Spezies-Eignungsmodell.** Ein vorhandener Sattelpunkt bedeutet weder „reitbar“ noch „zähmbar“. Milch, Zugkraft, Traglast, Ausdauer, Tierbesitz und Wirtschaft werden hier nicht eingeführt.

## Gespeicherte Daten

Die Erweiterung liegt in `blueprint.assembly.body_attachments`. Das äußere Kreaturenformat bleibt V7; Kampagnenschema und Spezies-IDs bleiben erhalten. Jeder Anschluss hat eine feste semantische Kennung, unabhängig von Teile-Reihenfolge und Node-Namen.

```json
{
  "schema": 1,
  "sockets": {
    "saddle.primary": {
      "enabled": true,
      "t": 0.52,
      "offset": [0.0, 0.0, 0.0],
      "rotation_degrees": [0.0, 0.0, 0.0]
    },
    "harness.left": {
      "enabled": true,
      "t": 0.32,
      "offset": [0.0, 0.0, 0.0],
      "rotation_degrees": [0.0, 0.0, 0.0]
    },
    "harness.right": {
      "enabled": true,
      "t": 0.32,
      "offset": [0.0, 0.0, 0.0],
      "rotation_degrees": [0.0, 0.0, 0.0]
    }
  }
}
```

| Feld | Bedeutung und Grenzen |
|---|---|
| `schema` | 1. Andere Versionen werden erhalten und zur Nutzung abgelehnt. |
| `enabled` | Explizites Ein-/Ausschalten dieses geometrischen Anschlusses. |
| `t` | Position auf der vorhandenen Wirbelsäule: vorn 0, hinten 1; zugelassener Bereich 0,12–0,88. |
| `offset` | X rechts, Y dorsal/oben, Z hinten im lokalen Wirbelsäulenrahmen; je −0,5 bis +0,5. Wird einmal mit `body.scale` multipliziert. |
| `rotation_degrees` | Zusätzliche lokale Eulerwinkel X/Y/Z in Grad, Godot-Standardreihenfolge YXZ; je −180 bis +180. |

Sattel liegt auf der dorsalen Mittelachse; die Geschirrpunkte liegen auf linker und rechter Flanke. Ein Strahl gegen **dieselbe Voxelhaut wie im Renderer** bestimmt den Oberflächenpunkt. Danach folgen 0,04 × Körpermaßstab Abstand und der eingestellte Versatz. Die Ausrichtung folgt der lokalen Rückenrichtung; +Y ist Körper-oben, −Z Körper-vorn, +X Körper-rechts. Der Ursprung von `saddle.primary` ist die Unterseite des Sattels, nicht das Becken des Reiters. Ausrüstung definiert ihren eigenen Versatz bis zum tatsächlichen Sitz; der sichtbare Probereiter verwendet 0,20 Entwurfseinheiten.

Die drei Posen werden abgeleitet, nicht als Weltkoordinaten gespeichert. Körperlänge, Krümmung, Breite und Maßstab dürfen sich ändern; Kennungen und gewählte Parameter bleiben erhalten. Änderungen am Auflösungsalgorithmus benötigen künftig eine bewusste Vertrags-/Migrationsentscheidung.

## Migration und Erhaltung

- `CreatureAssemblyBlueprintV7.normalize()` ergänzt ausschließlich ein bisher fehlendes Gesamtfeld mit deterministischen Standardparametern. Kein RNG-Aufruf, kein Neugenerieren von Arten oder Teilen, kein Phasenwechsel.
- Nur lesen (`Data.read`, `Contract.describe`, `Contract.resolve`) verändert auch alte Baupläne nicht. `attachment_source` unterscheidet `legacy_default` und `saved`.
- Vorhandene kaputte, unvollständige oder zukünftige Daten werden nicht durch Standardwerte überschrieben. Version, Feldtypen, endliche Zahlen und Grenzen werden geprüft; deaktivierte Punkte bleiben deaktiviert.
- `Assembly.save_to_file/load_from_file` bewahren das Feld im bisherigen JSON. Das bestehende Journal übernimmt `assembly` bereits; der modulare Einwegadapter führt die Anschlussdaten in seinen Metadaten mit. Undo/Redo verwendet die vorhandene Bauplanhistorie.
- Reiter-/Geschirransicht, Fußposen, globale Transformationen und Laufzeit-Node-Referenzen gehören nicht in den gespeicherten Körpervertrag.

## API für Chat 3 / D1

```gdscript
const BodyContract = preload("res://creatures/runtime/creature_body_contract.gd")
const BodyData = preload("res://assembly/core/creature_body_attachments.gd")

var evidence: Dictionary = BodyContract.describe(species_blueprint)
# JSON-fähig: schema, design_id, frame, forward, up, units,
# attachment_source, attachment_schema, sockets, body_bounds,
# authored_leg_count, errors, requires_runtime_contact_check, suitability_owner.

var rest: Dictionary = BodyContract.inspect_rest(runtime_preview)
# Nur im unveränderten Ruhestand auswerten, z. B. nach set_motion("edit").
# leg_count, feet [{part_uid, side, position, gap}], max_contact_error,
# max_rest_stretch, all_feet_on_plane; Koordinaten relativ zur Vorschau.
```

`describe` gibt Anschlussposition und drei Basisvektoren im Rahmen `BodyV4` aus. `body_bounds` enthält Position und Größe der wirklichen Voxelhaut-AABB. `authored_leg_count` ist eine Aussage über platzierte Beine; **erst `inspect_rest` bestätigt tatsächlich gebaute Beinrigs und Kontakte**. `max_rest_stretch` macht die vorhandene Längenanpassung beim Nivellieren sichtbar. D1 muss selbst entscheiden, welche Körperdimensionen, Beinzahl, Stützweite, Dehnungsgrenze und später Last-/Freiraumprüfung seine Tierrolle verlangt. Der B1-Test enthält bewusst verschieden lange Beinpaare und erreicht dabei bis etwa 1,49-fache Ruhelänge; daraus folgt keine automatisch geeignete Reittierart.

`describe` baut bei Bedarf eine Voxelhaut. Es ist eine Prüfung bei Erzeugung/Änderung/Abnahme, kein Aufruf für jede Tier-KI pro Frame. Eine Vorschau verwendet beim Aufbau ihre bereits vorhandene Haut.

Fehlercodes: `unsupported_body_attachments`, `missing_socket:<id>`, `invalid_enabled:<id>`, `invalid_t:<id>`, `invalid_offset:<id>`, `invalid_rotation_degrees:<id>`, `surface_missing:<id>`, `socket_inside_skin:<id>`. Ein fehlerhafter Datenblock stellt keine Anschlüsse bereit. Ein geometrisch fehlerhafter Einzelpunkt wird ausgelassen; die übrigen Punkte bleiben verfügbar. D1 muss Fehler und benötigte Kennungen explizit prüfen. Der Schutz gegen einen Punkt innerhalb der Haut ist keine Kollisionsprüfung der vollständigen Ausrüstung gegen Hörner, Panzer, Beine oder den Reiter.

## API für Laufzeit / spätere D4-Anbindung

Jede aktive `CreatureRuntimePreview` mit Voxelhaut stellt `body_socket(id)` bereit. Rückgabe bei Verfügbarkeit:

```gdscript
{"id": "saddle.primary", "schema": 1,
 "body_transform": Transform3D(...), "world_transform": Transform3D(...)}
```

Unbekannt/deaktiviert/ungültig/nicht im Szenenbaum: `{}`. `world_transform` enthält sämtliche übergeordneten Drehungen und Skalierungen einschließlich unabhängig bewegtem `BodyV4`. Kein globales Welt-Y wird für die Ausrüstungsposition verwendet. Die Node-Namen sind interne Details und dürfen nicht als Speicher-IDs verwendet werden.

```gdscript
const Attachment = preload("res://creatures/runtime/creature_body_attachment.gd")
var fitting := Attachment.new()
scene_root.add_child(fitting)
fitting.bind(creature_preview, "saddle.primary")
fitting.add_child(rider_visual)
```

Dieser separate Ausrüstungswurzelknoten löst die Kennung nach jedem Vorschau-Neuaufbau erneut auf. Er übernimmt Position, Orientierung und Skalierung nach der normalen Animation (Prozesspriorität 100); `sync_pose()` ist auch unmittelbar aufrufbar. Fehlende/deaktivierte Anschlüsse verbergen ihn und setzen `available=false`. Nach Wiederherstellung wird er erneut sichtbar. Wird die gesamte Vorschauinstanz ausgetauscht, muss ihr Besitzer erneut `bind` aufrufen. Ein späteres Gerät oder ein Reiter bekommt daraus **keine** automatische Physik, Kollisionsform, Steuerung, Animation, Zugehörigkeit oder gespeicherte Tierbindung. Dafür ist der jeweilige Simulationsbesitzer zuständig.

## Werkstatt und Prüfbarkeit

F2 → **Körper** → **Sattel & Geschirr prüfen**. Sattel oder Geschirrseite auswählen; Lage, Versatz und Winkel einstellen. Geschirr lässt sich auf die Gegenseite spiegeln. Alles verwendet vorhandenes Speichern, Rückgängig und Wiederholen. Im Reiter **Testlauf** bleiben Probereiter und Zugleinen auch auf Rampe/Stufen sichtbar; die eigentlichen Anschlussparameter werden im Reiter Körper eingestellt. Die Prüfkörper beeinflussen weder Körpergrenzen, Bodennivellierung noch Kollisionsabfragen.

```bash
python3 tools/validate_godot.py --godot /pfad/zu/Godot_v4.6.3-stable_linux.x86_64 --tests creature_body_contract_test creature_joint_studio_test --skip-main --output /tmp/body-checks
```

Der neue Test prüft Migration, fehlerhafte/future Daten, JSON/Journal/Adapter, Neustart in einem **zweiten Godot-Prozess**, Zwei-/Vier-/Sechsbeiner, geneigte und nicht einheitlich skalierte Bezugssysteme, Körperbewegung, Neubau, deaktivierte/freigegebene Anschlüsse, verlorene Ziele, echte UI-Eingabe, Undo/Redo und gespiegeltes Geschirr. Die vorhandene Gelenkprüfung deckt zusätzlich native Rampen-/Stufenkollisionen ab. Der eigene Workflow `Creature body contract` rendert die echte Werkstatt mit Compatibility und Forward+ und liefert Bilder/Logs als Artefakt.

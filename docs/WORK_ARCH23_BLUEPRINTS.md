# Übergabe ARCH-23 – Baupläne und Originale absichern

10. September 2026 · Branch `agent/arch23-blueprint-contract-2026-09-10`
· gemeinsame Basis `ea900f2e09946660694a9e59399b4680a5655a85`.

## Lieferung

Der bisherige Code konnte unbekannte neuere Bauplanschemata beim Normalisieren
herabsetzen. Die neue read-only Prüfung schützt generische Baupläne, Gebäude und
Kreaturen einschließlich verschachtelter B1/B3-Verträge. Prüfung, Kopiermigration
und Normalisierung sind getrennt. Bestehende Altstände, IDs und Teilplatzierungen
bleiben lesbar. Originaldateien und gemeinsame Slotinhalte werden vor Schreibversuchen
geschützt. Das Gebäudespeichern verändert die Revision erst nach erfolgreichem Commit;
Undo darf beim nächsten Speichern keine bereits gespeicherte Revision wiederverwenden.

Vertrag, Besitzer, Grenzen und der spätere portable Anschluss stehen in
[BLUEPRINT_CONTRACT.md](BLUEPRINT_CONTRACT.md). Kampagne/Save bleiben Schema 3/9,
Kreaturen V7, Baupläne/Gebäude Schema 1. Keine Onlinegalerie, keine neuen Körperteile,
keine Gebäude-/Fahrzeugspielphase und keine zweite Speicherarchitektur.

## Geänderte Bereiche

- `assembly/core`: neue reine Vertragsprüfung und begrenzter modularer Codec.
- `assembly/adapters`, `assembly/runtime`: Versionsprüfung und erhaltene Design-ID.
- `creatures/editor/*blueprint*`: geprüfte Lese-/Schreibwege, explizite Kopiermigration,
  Erweiterungsdaten; V5 nutzt den vorhandenen atomaren Store.
- `civilization/buildings/*blueprint*`, `building_runtime_visual`: geschützte Versionen,
  transaktionale Speicherung und unveränderte Vorschau bei abgewiesenen Daten.
- `core/persistence/design_store.gd`: gemeinsame Schreibsperre vor Dateimutationen.
- `autoload/save_game_service.gd`: ausschließlich Entwurfsversionsprüfung, ID-Migration
  und Entwurfsreferenzen; keine neue Save-Struktur oder Wirtschaftsfunktion.
- `main/spherical_campaign.gd`: ein früher Ladeabbruch für geschützte Ersatzvorschauen,
  bevor der Start einen leeren/neuen Entwurf in den Slot übernehmen könnte.
- Neuer `tests/blueprint_contract_test.gd`, Anschluss in vorhandener Assembly-CI,
  Vertrag, Übergabe und enger ARCH-23-Status in den Planungsdateien.

## Nachweise

Godot 4.6.3, Linux, Headless. Gezielte reale Engineprüfungen mit isolierten
Spielständen bestanden:

| Prüfung | Ergebnis |
|---|---|
| `blueprint_contract_test` | Zukunftsschema auf allen geprüften Ebenen; Original-/Backupbytes; Struktur-/Aufwandsgrenzen; alte fehlende UIDs; Erweiterungen; Undo/Redo; Revisionsschutz bei Schreibfehler; echte Gebäudevorschau; separater Neustartprozess; Kampagnenladung mit neuerem Gebäude und vorhandenem älterem Backup |
| `modular_assembly_framework_test` | bestehende Gebäude-/Baukasten-/Adapterverbraucher |
| `creature_body_contract_test` | bestehende Körperanschlüsse und Altentwürfe |
| `campaign_foundation_test` | Migration, gemeinsame Entwurfssnapshots, Ereignisse, Neustart und Fehlerfälle |
| `save_slots_test` | bestehende Slotkopien und Speicherwege |
| `creature_studio_test`, `creature_builder_v7_test` | bestehende Werkstatt, Farben, Platzierungen, Revisionsobergrenze und Undo nach Speichern |
| Frischer Import / vorhandene Quellenprüfung | keine Parserfehler; vorhandene generierte Kunstquellen konsistent |

Die maschinenlesbaren Ergebnisse stehen in [ARCH23_VALIDATION.json](ARCH23_VALIDATION.json). Auch `spherical_campaign_contract_test` bestand.

Die Schlussprüfung für den neuen Vertrag benötigte rund 2,6 Sekunden einschließlich
eigenem Neustart, die Werkstattprüfung 5,3 Sekunden und die Kampagnenprüfung 2,6 Sekunden.
Das sind Testlaufzeiten, keine Spiel-FPS. Keine sichtbare Neugestaltung; keine
Windows-/Ziel-PC-Abnahme behauptet. Die vorhandene gemeinsame CI entdeckt den neuen
Test zusätzlich automatisch; ihr konkretes Ergebnis gehört zum PR-Commit.

Reproduktion:

```bash
python3 tools/validate_godot.py --godot /pfad/zu/godot \
  --tests blueprint_contract_test modular_assembly_framework_test \
  creature_body_contract_test campaign_foundation_test save_slots_test \
  creature_studio_test creature_builder_v7_test --skip-main
```

## Paralleler Folgeauftrag

**ARCH-20 – Ressourcen und Produktion vereinheitlichen** kann auf dem gemeinsamen
main unabhängig beginnen: vorhandene Milchproduktion, Ressourcenbatch, Transport,
Annahme und Verbrauch; Altstände und Einmaligkeitsbelege erhalten, noch keine Eier
erzeugen. Seine Schreibbereiche sind Dorfwirtschaft/Tierhaltung. ARCH-23 besitzt
die oben genannten Bauplan-/Speicheranschlüsse bis zur Integration.

ARCH-24 kann anschließend auf diesen Vertrag aufsetzen. Seine Katalog-/Geometriearbeit
bleibt eine eigene Lieferung. ARCH-13/14 bleibt das priorisierte größere Skalierungspaket
und muss Änderungen am gemeinsamen SaveGameService nacheinander integrieren.

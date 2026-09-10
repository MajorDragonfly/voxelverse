# ARCH-21 – zusätzliche Eierart

**Status:** implementiert und geprüft; zur Integration bereit. Eigener Branch `agent/arch21-egg-species-2026-09-10`, [PR #63](https://github.com/MajorDragonfly/voxelverse/pull/63). Auftrag nach Lars' Bestätigung vom 10. September 2026. Basis: veröffentlichtes `main` `ea900f2e09946660694a9e59399b4680a5655a85`. Implementierungscommit: `9322ac7a7a6c5129558bdedf348ba038afe4ba6d`.

## Lieferumfang

Belebte Kugelplaneten und -monde erhalten additiv eine eigene Eierart („Nestläufer“). Die drei vorhandenen Milch-, Arbeits- und Begleitarten behalten ihre IDs, Seeds, Entwürfe und gemessenen Körpernachweise. Der zweibeinige Nestläufer verwendet den bestehenden Kreaturenrenderer, Beinrig und Ballenfüße; neue Körperteil-IDs oder Geometrieanbieter werden nicht eingeführt. Die Scanansicht zeigt die Rolle über das bestehende Entdeckungsbuch und macht deutlich, dass Eiergewinnung noch nicht verfügbar ist.

D1 bleibt Besitzer der Art-Eignung, D2 Besitzer gezähmter Individuen und der vorhandene Regionsspeicher Besitzer der Wildtier-/Nahrungsänderungen. ARCH-22 ergänzt später Legestelle, Produktion, Sammlung und Fracht über ARCH-20. In dieser Lieferung entstehen keine Eier, neue Vorratsfelder, Tierbesitzer oder Produktionsdienste. Die historischen Flachwelt-Prüfszenen behalten ihre drei ursprünglichen Arten; normale neue Abenteuer starten bereits auf Kugeln.

## Versionierter Anschluss

| Teil | Alt | Neue Eierart / Ergänzung |
|---|---|---|
| Katalog | Schema 1 planar, 2 radial, 3 migriert | Schema 4 mit `role_policy = 2` für vier Pflichtarten |
| Art-Eignung | Schema 1, unverändert für alte Rollen | Schema 2 ausschließlich für die eigene Rolle `eggs` |
| Produktionsfähigkeit | Alte Milchwerte bleiben identisch | `egg_yield = 1`, `egg_interval = 300` aktive Spielsekunden als deklarierter D1-Anschluss für ARCH-22 |
| Anatomie | Mindestens 4 Standbeine für die vorhandenen Rollen | Mindestens 2 bei der reinen Eierrolle; `egg_laying = true` |
| Körpernachweis | `domestic_body_v1` bleibt erhalten | `domestic_egg_body_v1`; echter gerenderter Körper und beide Bodenkontakte |
| Habitatdaten | Höchstens 24 gespeicherte Vorkommen | Höchstens 25: alle alten plus ein zusätzliches Vorkommen |
| Laufzeit | 12 nahe Kampagnentiere, 16 Nahrungspflanzen | Grenzen bleiben gleich; fehlende Pflichtart erhält Vorrang vor gewöhnlichen Tieren oder mehrfach dargestellten Vertretern anderer Pflichtarten |

`Contract.GROUPS` bleibt die ursprüngliche Dreierpolitik für alte Erzeugung und Prüfszenen. `Catalog.groups_for(catalog)` liefert die durch die gespeicherte Politik verlangten Gruppen. `generator_version = domestic_fauna_v1` bleibt der Ursprung der alten Seeds; die zusätzliche Gruppe `eggs` erhält einen eigenen deterministischen, körpergebundenen Seed. Bereits verwendete Katalog-/Entdeckungsseeds werden bei der Ergänzung berücksichtigt.

`Catalog.upgrade_surface(catalog, descriptor, used_seeds)` validiert zuerst, arbeitet auf einer Kopie und liefert bei unlesbaren/neuen Pflichtversionen keine Ersatzdaten. Schema 4 verhindert, dass der ältere Leser mit maximal Schema 3 die neue Rolle unbemerkt überschreibt. Die bestehenden zentralen Sperren für unbekannte Verträge, Backup-Rückfall und Schreiben werden weiterverwendet; das globale Save-Schema bleibt unverändert.

## Erhaltung und Vorkommen

Die Ergänzung übernimmt alte Arten einschließlich ihrer vollständigen eingefrorenen Körper und Nachweise. Bestehende Habitat-IDs, Regionszuordnung, Positionen, Spawnpositionen, Generationen, Ersatzfristen und Nahrungsstände bleiben bestehen. Bei migrierten Katalogen bleibt auch `migration_source.catalog` unverändert; die vierte Art muss deshalb nicht im alten Dreierarchiv stehen.

Ein vorhandener Suchcursor wird beim einmaligen Politikwechsel durch eine neue begrenzte Suche am gespeicherten Anker ersetzt. Bestehende Vorkommen werden dabei nicht neu angelegt. Nach Speichern während der neuen Suche kann derselbe Cursor weiterlaufen. Endpunktprüfung vergleicht kanonische Adressen, damit JSON-Zahlen für Cube-Flächen und Laufzeit-Integer dieselbe gespeicherte Position bezeichnen. Mehrere alte Vorkommen derselben Art zählen bei der Vollständigkeitsprüfung nur einmal.

Die vierte Route verwendet denselben radialen Suchraum, Neigungs-/Wasser-/Wegtest und tatsächlichen Kollisionscheck beim Platzieren wie die bestehenden Arten. Ein Katalog ohne erreichbares Vorkommen gilt nicht als fertig. Überflutete oder vollständig blockierte Ausgangsgebiete werden weiter als nicht verfügbar gemeldet. Nahrung wird über die bestehenden endlichen Pflanzen bereitgestellt. Die vorhandene Wasserregel `requires_transport` bleibt ausdrücklich bestehen; Ozeanwasser wird nicht als nahe Süßwasserversorgung ausgewiesen.

Bei vollem Nahbestand kann ein gewöhnliches Tier oder ein mehrfach vertretener Pflichtartvertreter über den vorhandenen Capture-/Entladeweg Platz machen. Die jeweils letzten sichtbaren Vertreter der übrigen Pflichtarten werden erhalten. Vollständig abgeerntete tote Tiere erhalten keinen Vorrang und lösen keine Entladung lebender Tiere aus. Das ist ein Wechsel geladener Szenen; die individuelle Region-/Begegnungsakte wird nicht gelöscht.

Die neue Zweibeinprüfung verlangt echte Standfüße, Bodenkontakt, begrenzte Beinstreckung, ausreichenden seitlichen Abstand und ein mittig liegendes Beinpaar. Sie ist ein geometrischer Ruhelagennachweis. Eine dynamische Gleichgewichtssimulation oder Reiteignung wird daraus nicht abgeleitet. Die bisherige Vierbein-/Last-/Sattel-/Geschirrprüfung bleibt für Arbeitsarten wirksam.

## Nachweise und Reproduktion

Alle neun gezielten Spiel-/Vertragstests sowie Import und Kunstquellenprüfung sind erfolgreich. Sie wurden auf `9322ac7` ausgeführt. Der kleine Nachtrag `2821ee1` schützt den vollen Nahbestand vor einer Reservierung für vollständig abgeerntete Kadaver und korrigiert die Diagnose-Aufnahmefläche; der ergänzte `egg_species_contract_test` wurde danach erneut erfolgreich ausgeführt. Die gesamte Neunergruppe wurde für diesen Nachtrag nicht wiederholt. Die endgültigen Ergebnisse stehen in [ARCH21_VALIDATION.json](ARCH21_VALIDATION.json); Rohprotokolle liegen komprimiert unter `docs/evidence/arch21/`.

```bash
python tools/validate_godot.py --godot /pfad/zu/godot-4.6.3 --skip-main \
  --tests domestication_contract_test domestic_body_evidence_test \
  domestic_surface_catalog_test egg_species_contract_test egg_species_campaign_test \
  domestic_surface_runtime_test interface_task7_test domestication_campaign_test \
  spherical_gameplay_test --output ../arch21-validation

# Native Körperansicht; benötigt eine Grafik-/Fensterumgebung:
/pfad/zu/godot-4.6.3 --path . --audio-driver Dummy --rendering-method gl_compatibility \
  --script res://tools/egg_species_preview.gd -- /absoluter/pfad/arch21-preview.png
```

- `egg_species_contract_test`: eingefrorene Altkataloge für drei Seeds, unveränderte alte Generatorergebnisse, additive/idempotente Ergänzung, angefangene Suche mit JSON-Neustart, migrierter Altarchiverhalt, 24 → 25 Vorkommen, gleiche Seeds auf verschiedenen Körpern und andere Besuchsreihenfolge. Dazu tatsächliche Zweibeingeometrie und negative Stand-/Reitfälle, voller Nahbestand, positive D2-Eignungsabfrage und Scanfreigabe im Buch.
- `egg_species_campaign_test`: echter alter Kugelspielstand, normale Slotkopie und SessionFlow, drei vorhandene Individuen, bereits gescannte Art und teilweise geerntete Pflanze. Dann vier reale Rollen, Eierart mit Bodenkontakt, einmalige Scanbelohnung, Ursprungskorrektur, Titelwechsel/Wiederbesuch, frischer Engineprozess und bytegleicher Schutz einer neueren Primärdatei samt gültigem älterem Backup. Originalslot bleibt unverändert.
- `domestic_surface_runtime_test`: vier Arten und vier Nahrungsquellen im bestehenden Vier-Tiere-Laborbudget, reale Laufbewegung, physische Annäherung an alle vier Vorkommen, Speichern/Laden, Reservierung, Entladen und Ursprungskorrektur.
- Vorhandene Körper-, Oberflächen-, Buch-, D2- und vollständige Kugelspielprüfungen decken die betroffenen Anschlusswege ab. Die vollständige Kugelkette enthält Stammesaufstieg, Tierhaltung und reale Milchfracht mit Neustart; sie bleibt von der neuen Eierproduktion getrennt.

Die Altkataloge und der alte Kampagnenstand wurden mit dem unveränderten D1-/Kampagnencode im lokalen ARCH-02-Lieferstand `905e524003c5f782f7b7daab09f0e23a1b632756` erzeugt. Dessen GitHub-Abbild ist `ed529a2cc19fd6daece1a65e3e64fb611d6b8629` aus PR #58 (identischer vollständiger Dateibaum). Die betroffenen Fachquellen entsprechen `main ea900f2`; beide Revisionen sind in den Fixtures getrennt als `source` und `gameplay_base` angegeben. Es handelt sich um synthetische Ausgangsstände, nicht um einen privaten Nutzerspielstand.

[Native Vergleichsansicht](evidence/arch21/egg-species-preview.png): vorhandene Arbeitsart und neue Eierart, Godot/OpenGL unter Linux mit Software-Renderer. Dient der Körper-/Darstellungskontrolle, ist keine Ziel-PC-/GPU-/FPS-Abnahme. Nach dem geprüften Nachtrag `2821ee1` werden ausschließlich Dokumentation und Nachweise ergänzt; Spielcode und Tests bleiben unverändert.

## Integration

- **ARCH-24 / PR #55:** `planet_fauna_catalog.gd` erhält dort `Feet.supports(..., "domestic_support")` anstelle der festen Fuß-ID-Liste. Hier wird die erforderliche Beinzahl in der benachbarten Zeile aus der Art-Eignung gelesen. Beide Änderungen übernehmen. Die hier verwendeten `feet_pads` sind im gelieferten ARCH-24-Katalog ausdrücklich als `domestic_support` freigegeben. Dessen Geometrie-/Katalogdateien wurden hier nicht übernommen oder verändert.
- **ARCH-17 / PR #56:** dessen portionierter Aufbau und begrenzte Platzierungsversuche bleiben erhalten. In `campaign_population.gd` kommt hier `_prioritize_catalog(candidates)` vor der bestehenden Spawn-Schleife sowie `_upgrade_catalog()` bei Start/Laden hinzu. Beide Pakete nacheinander integrieren und die vier Rollen bei voller Population prüfen.
- **ARCH-29 / PR #53:** die zwei neuen `egg_species_*_test`-Tests bei Integration dem passenden Fachvertrag zuordnen. Keine parallele Änderung des neuen zentralen Testregisters.
- **ARCH-20/22:** `eggs` ist der neue Rollenanschluss. Produktion benötigt weiterhin einen eigenen geprüften Ressourcen-/Rezept-/Haltungsablauf. **ARCH-25:** die kleine Rollenanzeige liegt in `animal_suitability.gd`; die vollständige Buchlokalisierung bleibt beim dortigen Fachpaket.
- Gemeinsame Roadmap, Integrationsdateien, zentrale Save-Implementierung und fremde laufende Branches wurden nicht verändert. Übergabe als eigener Entwurfs-PR; kein automatischer Merge nach `main`.

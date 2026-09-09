# Kampagnenverträge – M0

Stand: 8. September 2026. Implementierung: `3f7f2252e3cbce868920dcf7c86beb3b47d17354`. Grundlage: `e1b0b7f` auf `agent/meta-runtime-v8`.

## Ergebnis und Grenzen

M0 ist technisch geprüft. Die bisherige Kreaturenwelt läuft weiter auf der V9-Ebene. Dieser Schritt liefert keine Kugelgeometrie und keinen spielbaren Stamm. Der nächste Entwicklungsauftrag ist M1 aus der zentralen [Roadmap](../ROADMAP.md).

## Zuständigkeiten

| Zustand | Besitzer | Vertrag |
|---|---|---|
| Phase, Kampagnenzeit, Identitäten, Ereignisfortschritt | `GameState` mit `CampaignState` | Eine Kampagnenphase; bestehende Enum-Werte 0–5 unverändert |
| Entdeckungen, Insight und Teilfreischaltungen | `ProgressionService` | Teil der Kampagnensicherung; vorhandene Entdeckungsschlüssel werden bei der Migration erhalten |
| Kreaturen- und Gebäudeentwürfe | `CampaignDesignStore` und bestehende Blueprint-/Registry-Klassen | Eigene Entwurfs-ID und Revision; Instanzen referenzieren ID + Revision |
| Regionale Ökologie | Regionensimulation | Region und Arten erhalten körperbezogene IDs; alte Seed-/X/Z-Schlüssel bleiben Kompatibilitätsadapter |
| Gemeinsamer dauerhafter Stand | `SaveGameService` | Ein Schema-3-Snapshot enthält Kampagne, Spieler, Entdeckungen, besuchte Welten und Editor-Dateien |

`CampaignIds.create()` erzeugt neue Identitäten unabhängig vom Seed. `scoped()` dient der reproduzierbaren Übernahme vorhandener/prozeduraler Identitäten innerhalb eines benannten Besitzers. Anzeigenamen und Planetenkatalog-Indizes gehören nicht in persistente Referenzen. Ein neues Spiel mit demselben Weltseed erhält eine neue Kampagnenidentität.

Der Körperbezug enthält `id`, `system_id`, Seed, `generator_version = planetary_v9` und `surface_mode = legacy_plane_v9`. Die gespeicherte Spieleradresse enthält Körper-ID, Modus, bisherige X/Y/Z-Position und Orientierung. **Diese Adresse behauptet noch keine Kugelkoordinaten.** M1 ergänzt ein eigenes geprüftes Oberflächenmodell und erhält den Kompatibilitätsadapter.

Spieler, prozedurale Tierinstanzen und Entdeckungen können stabile Objekt-/Spezies-/Regionsreferenzen liefern. Die laufende 3D-Szene ist damit noch keine vollständige persistente Objektwelt: Einzeltierschaden, geerntete Ressourcen und spätere Bewohner-/Bauinstanzen benötigen ihre jeweiligen Zustandsbesitzer in M4–M6. Der hier eingeführte ID-Vertrag ist dafür die Basis.

## Speichern und Migration

Schema 1/2 wird vor dem Import zusammen mit den exakten vorhandenen Editor-Dateien in `voxelverse_save.json.schemaN.backup.json` gesichert. Dazu gehören V7-Kreatur, ältere Kreaturendateien, das frühere Wirbelsäulenprofil, Gebäude-Autosave und alle benannten Gebäudeentwürfe. Abweichende weitere Altdaten erhalten eine eigene Sicherung; die erste wird nicht überschrieben. Die ursprünglichen Dateien bleiben bei der Migration erhalten.

Der neue Snapshot bettet die Editor-Dateien als Text ein. Beim Laden lesen Kreatureneditor, Gebäude-Registry und Laufzeit dieselbe gesicherte Version. Fehlt eine lose Editor-Datei oder enthält sie einen späteren Stand, bleibt der geladene Snapshot maßgeblich. Speichern im Editor aktualisiert dessen Entwurfsbestand und den Kampagnen-Snapshot. Ein expliziter Import außerhalb des Snapshots bearbeiteter Entwürfe bleibt eine Editoraufgabe für M2.

Dateien werden zunächst neben dem Ziel geschrieben, gespült und auf vollständigen Text geprüft. Erst dann ersetzt `DirAccess.rename_absolute` das Ziel; die alte Datei wird nicht vorher gelöscht. `.bak` enthält den vorherigen vollständigen Stand. Auch der erste migrierte Wiederherstellungsstand enthält die Entwürfe gemeinsam mit der Kampagne. Die ursprüngliche Schema-1/2-Sicherung bleibt zusätzlich erhalten. Die [Godot-Dokumentation zu DirAccess](https://docs.godotengine.org/en/4.6/classes/class_diraccess.html#class-diraccess-method-rename-absolute) beschreibt das Ersetzen vorhandener Dateien.

Ein unvollständiges `.tmp` verdrängt keinen gültigen Stand. Bei beschädigtem Hauptstand wird ein gültiges `.bak` geladen. Eine unbekannte neuere Speicher-/Kampagnen-/Generatorversion blockiert das Überschreiben und fällt nicht still auf eine ältere Landschaft zurück. Migration und Wiederherstellung werden in `last_migration_report` bzw. im Snapshot vermerkt. Dies wurde mit Prozessneustart und simulierten Schreibabbrüchen geprüft; ein harter Stromausfall auf jedem Dateisystem ist damit nicht bewiesen.

Fehlende Körper-, Farb- oder Anbauteile erhalten einen verfügbaren Ersatz. `missing_part_id`, Position und übrige Platzierungsdaten bleiben erhalten und überstehen erneutes Speichern. Der Editor zeigt die Ersetzung an. Ist das Original später wieder verfügbar, kann es wieder zugeordnet werden. Unlesbare Entwurfsdateien werden im Sicherungsbestand beibehalten und im Migrationsbericht genannt.

## Ereignisse und Fortschritt

`CampaignGameEvent` definiert Entdeckung, abgeschlossene soziale Interaktion, Konfliktergebnis und Phasenabschluss. Es enthält Kampagne, Quelle, Ziel, Phase, Ergebnis und eine fortlaufende Sequenznummer. Ein Klick oder Schadenspunkt ist kein abgeschlossenes Verhalten.

Die aktuelle Entdeckungslogik meldet solche Ereignisse und behält ihre bereits vorhandene Prüfung auf erstmalige Entdeckung. Die ID einer bereits bekannten Art/Region und ihre Insight-Belohnung bleiben beim Laden erhalten. Der neue Ereignisempfänger akzeptiert innerhalb jedes Produzenten/Kanals nur aufsteigende Sequenzen. Derselbe oder ein älterer Eintrag wird auch nach Laden nicht erneut angenommen. Die letzten 32 Ereignisse dienen der Diagnose; die dauerhaft gespeicherten Sequenzstände werden nicht zusammen mit dieser Historie gelöscht.

Produzenten müssen Ereignisse geordnet übergeben. Der derzeitige Produzent ist das Spielerobjekt; die Anzahl der Sequenzstände wächst nicht mit jeder einzelnen Begegnung. Spätere verteilte Produzenten benötigen einen ausdrücklich geregelten Lebenszyklus. **Es werden hier noch keine Sozial-/Aggressionspunkte oder Skilltree-Knoten eingeführt.** Deren Transaktion, Begegnungsregeln und Boni folgen in M2/M4. Der M0-Test löst soziale/Konfliktereignisse gezielt aus und prüft zusätzlich echte Entdeckungsbelohnungen.

## Phasenübergang und Zeit

Der normale Einstieg `request_phase_transition()` fragt Voraussetzungen ab. Weil die Stammes-Spielschleife noch fehlt, wird sie erklärbar abgelehnt. `debug_set_phase()` ist ausdrücklich eine direkte Debug-Schnittstelle; der alte Name `set_phase()` bleibt als Kompatibilitätsalias erhalten. Normales Spiel soll ihn nicht verwenden.

`debug_prepare_phase_transition()` sichert den nächsten Schritt mit Übergangs-ID, alter/neuer Phase und Übergabedaten (Spezies, Fraktion, Ort, Spieler, Entwurfsreferenzen). Die Phase bleibt dabei zunächst unverändert. `resume_phase_transition()` schreibt den Abschluss gemeinsam mit Ereignis und neuer Phase. Erst nach erfolgreichem Schreiben werden Beobachter informiert. Ein fehlgeschlagener Abschluss stellt den vorherigen Zustand wieder her; Laden einer vorbereiteten Transaktion nimmt sie wieder auf. Erneutes Laden eines abgeschlossenen Übergangs vergibt keinen zweiten Abschluss. Bevölkerung, Besitz und Verhaltenserbe werden im M5-Spielablauf in diesen Vertrag aufgenommen.

Kampagnenzeit läuft nur bei aktiver Spielerphysik, stoppt bei SceneTree-Pause und läuft im Editor nicht weiter. Sie verwendet keine Offline-Zeitdifferenz. Die API unterstützt 0×, 1×, 2× und 4× für Kampagnenzeit und regionale Ökologie; dies ist noch keine globale Geschwindigkeitssteuerung aller Physik-/Animationssysteme und hat noch kein Bedienmenü. Orbits und spätere Wirtschaft verwenden diesen Zeitvertrag.

## Nachweise

- `tests/campaign_foundation_test.gd`: Migration eines aus den vorhandenen APIs erzeugten Schema-2-Beispiels mit Kreatur, zwei Gebäuden, Entdeckungen und Ökologie zweier besuchter Planeten; exakte Sicherung der alten Dateien; gleiche Orte/IDs/Revisionen nach Laden und in einem zweiten Godot-Prozess.
- Derselbe Test: doppelte Entdeckung und wiederholtes Ereignis, ungültige Ergebnisse/fremde Kampagne, begrenzte Ereignishistorie, Zeit/Pause, vorbereiteter Phasenwechsel nach Neustart, fehlgeschlagener Abschluss mit Wiederholung, unvollständige temporäre Datei, beschädigter Hauptstand, Schutz neuerer Versionen, fehlende Teile und deterministische Tierentwürfe.
- Vollständiger bestehender Godot-Prüflauf: **46/46 erfolgreich**. Abschließende gezielte Prüfung von M0, Editor, Assembly und Laufzeit: **4/4 erfolgreich**. Nativer Linux-Export: **9/9 erfolgreich**, einschließlich Start außerhalb des Quellverzeichnisses und drei Planeten-Proben. Godot **4.6.3**; [maschinenlesbare Ergebnisse](validation/m0.json).

Lars' manueller Windows-Spieltest ist separat offen. Sinnvoller kurzer Test: vorhandenen Stand starten, Kreatur bearbeiten/speichern, Gebäude speichern und laden, mit P den Planeten wechseln, Spiel schließen und denselben Stand erneut öffnen. Danach kann die M1-Technikszene entstehen; eine Migration bestehender Landschaften auf die Kugel ist damit nicht beauftragt.

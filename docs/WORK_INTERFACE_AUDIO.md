# Auftrag 7 – Entdeckungsbuch, Gruppenrückmeldung und Klang

Stand: 9. September 2026. Abgeschlossenes Teilpaket auf
`agent/interface-audio-task7`.

- Gemeinsame Basis: `3a3e0272375e556f3ff65b7370582af79a9d48b5`.
- Veröffentlichter Codecommit: `5f77966a9dc7e5b8739dc1f4519e558c45685cab`.
- Geprüfter lokaler Codecommit: `b50d290364cd53301056d7819555aed07a65ebf7`.
  Beide besitzen denselben Dateibaum `cf6d9cad730eafc86ca39d052d37ddbca87bd98b`.
- Der nachfolgende Dokumentationscommit ergänzt nur diesen Bericht und Prüfnachweise.
- Kein Merge nach `main`, keine fremden unfertigen Arbeiten übernommen.
- Lars hat nach der lokalen Abnahme den öffentlichen Upload dieses Branches nach
  `MajorDragonfly/voxelverse` und die Erstellung eines PR ausdrücklich bestätigt.
  Der Integrationschat entscheidet weiterhin über die Übernahme nach `main`.

## Geliefertes Verhalten

Das gemeinsame Buch zeigt weiterhin Arten, Körperteile, Regionen, Forschung und
Vergleich. J und der Entwicklungseinstieg verwenden dieselbe Instanz. Das Stammes-HUD
hat zusätzlich einen sichtbaren Einstieg **Buch · J**.

Gescannte Arten können ihre D1-Eignung als Milchtier, Zugtier, Reittier und Begleittier
anzeigen. Der kompakte Rollentitel klappt die Einzelwerte auf. Nahrung, Wasserbedarf,
Lernfähigkeit, Sozialverträglichkeit, Bindungsfähigkeit, Ausdauer, Tempo, Wahrnehmung,
Milchmenge/-intervall, Zugkraft und Traglast verwenden die Einheiten aus D1.
Sattel/Geschirr erscheinen als Anforderungen, nicht als freigeschaltete Aktionen.
Suche und Rollenfilter berücksichtigen ausschließlich vorhandene, vollständig
gescannte Einträge. Ökologische Lebensweise und Tierrolle bleiben getrennt.

Eine Freundschaft und eine unvollständige Beobachtung zeigen keine Tierrollendaten.
Alte, fehlende, ungültige und unbekannte Vertragsstände bleiben ohne erfundene Werte
lesbar. Das Öffnen des Buches erzeugt weder Arten, Tiere noch Belohnungen.

Die Gruppenrückmeldung zeigt die Zahl und Namen ausgewählter Bewohner sowie
mitgeführtes Transportgut. Ein angenommener Auftrag heißt ausdrücklich **gespeichert**;
damit wird keine abgeschlossene Arbeit behauptet. Ablehnungen nennen den tatsächlichen
Grund, einschließlich leerer Auswahl, fehlendem Werkzeug, ungeladenem Boden und
Schreibfehlern. Die bisherige Speicherung entscheidet weiterhin über den Erfolg.

Die Klänge hören auf dasselbe `order_resolved`-Ereignis. Eine unmittelbare Ablehnung
nach einem erfolgreichen Befehl bekommt ihren Fehlerklang. Durch die kurze
Ratenbegrenzung unterdrückte Ereignisse können nicht durch spätere Duplikate erneut
klingen. Kein Ton läuft pro Gruppenmitglied oder allein wegen eines Buttonklicks.

Das Stammes-HUD verdeckt fremde Pausenfenster nicht mehr. Sein eigener Pausezustand
bleibt erhalten; es entsteht kein weiterer Pauseverwalter. Scrollbare Gruppenaufträge,
ein kompakter Reiterauswahlschalter und kleinere Vorschauen halten die Bedienung bei
kleinen Fenstern erreichbar.

## D1: geprüfter Anschluss, getrennte Lieferung

Vertragsgrundlage ist der abgegrenzte Commit
`bb43b61482ab129b72a66b5299a6bfec80a1e128` aus Auftrag 3 mit
`docs/D1_DATA_CONTRACT.md` und
`world/fauna/domestication/domestication_contract.gd`.

Der Reader lädt diesen **vorhandenen** Validator optional. Ohne D1 im gemeinsamen
Projekt bleibt das Buch funktionsfähig und meldet fehlende Eignung. Es enthält keine
Kopie des D1-Validators und ruft niemals dessen Generator `suitability()` auf.
Gelesen wird ausschließlich
`discovered_species[...].journal.visual.species.domestication`, nach Dekodierung durch
die vorhandenen `DiscoveryRecords` und Prüfung von `scan.version == 1` sowie
`scan.complete == true`. Der D1-Validator besitzt weiterhin alle Eignungsregeln.

Die positive Integrationsprüfung lädt die exakte Vertragsdatei des genannten Commits
in einem isolierten Testpfad und speichert Testbeobachtungen über die vorhandenen
Services. Das ist kein Nachweis des noch getrennt entwickelten planetaren Generators,
seiner Morphologie oder seiner erreichbaren Vorkommen. Produktive D1-Werte erscheinen
erst, wenn D1 integriert ist und die entsprechenden Tiere tatsächlich gescannt wurden.

## D2: ausschließlich abgegrenzte Prüfansicht

Zum Abschluss dieses Codepakets lag noch kein geprüfter D2-Datenvertrag vor. Deshalb ist
`ui/discovery/owned_animal_register.gd` noch nicht mit Kampagnendaten verbunden und
erzeugt keinen zusätzlichen Reiter im produktiven Buch.

Die Szene `tests/fixtures/owned_animal_register_preview.tscn` zeigt ausdrücklich
markierte Beispieldaten für Name, Art, Besitzer, Vertrauen, Auftrag und Aufenthalt.
Das Widget nimmt lediglich fertig formatierte Anzeigetexte entgegen. Es definiert
keine Tier-IDs, Vertrauenseinheiten, Besitzregeln, Befehle oder Speicherschemata.

Nach der D2-Freigabe soll ein lesender Adapter dessen vorhandenen Service verwenden,
Besitzerfraktion und Kampagne berücksichtigen und das Widget als Ansicht im
bestehenden Buch einbauen. Keine Rekonstruktion eigener Tiere aus sichtbaren Nodes,
Freundschaften oder der Heimatgruppe. Save/Load und Befehle bleiben bei D2.

## Dateien und gemeinsame Anschlüsse

| Dateien | Änderung |
|---|---|
| `ui/discovery/animal_suitability.gd` | Lesende D1-Präsentation, zentrale D1-Validierung, Scanvoraussetzung, deutsche Einheiten |
| `ui/discovery/discovery_journal.gd` | Bestehendes Buch erweitert, Rollenfilter, aufklappbare Details und kleine Fenster |
| `ui/discovery/owned_animal_register.gd` | Noch unverbundenes D2-Präsentationswidget |
| `ui/frontend/group_feedback.gd` | Lesende Auswahl-/Ergebnisanzeige und Einstieg ins bestehende Buch |
| `ui/tribe/tribe_panel.gd` | Gezielter UI-Anschluss, Scrollbereich, Rücksicht auf vorhandene Pausebesitzer; Bewohnerzahl nicht mehr fest in der Anzeigeschleife |
| `world/tribe/tribe_controller.gd` | Gezielter Ereignisanschluss für ungeladenen Boden und präzise Ablehnungsgründe; Wirtschaft unverändert |
| `audio/runtime/order_audio.gd` | Fehlerfeedback und Duplikatverhalten innerhalb der vorhandenen Klang-API |
| `tests/interface_task7_test.gd` | Reale Buch-/Gruppen-/Save-/Audio-Anschlüsse auf der vorhandenen Stammesprüfszene |
| `tests/fixtures/owned_animal_register_preview.*` | D2-Prüfszene, ausdrücklich ohne Kampagnenanschluss |

Hinzu kommen die UID-Dateien der neuen Skripte und die nachstehenden Nachweise.
**Keine Schemaänderung, kein neuer Speicherpfad, kein neuer Autoload.**
`ROADMAP.md`, `project.godot`, globale Speicher- und Fortschrittsservices sowie
Tiergeneratoren wurden nicht geändert. Die beiden `tribe`-Dateien bei der späteren
Integration mit Auftrag 5 abgleichen; ausschließlich die oben genannten UI-/Ereignis-
Anschlüsse übernehmen und dessen neue Versorgungslogik erhalten.

## Prüfung

Godot `4.6.3.stable.official.7d41c59c4`: Import, Kunstquellenprüfung und sechs gezielte
Testläufe bestanden. Ergebnisse und Protokolle unter
[`validation/interface-task7/`](../validation/interface-task7/).

- Buch mit echter Speicherung und Neustart, Forschung und Vergleich unverändert nutzbar.
- Bestätigter Stammeswechsel, Transporte, Bauaufträge, fehlgeschlagene Speicherung,
  Pause und erneutes Laden über die vorhandene vollständige Stammesprüfung.
- D1-Vertrag positiv für Milch-, Arbeits- und Begleittiere; fehlende Daten, unvollständiger
  Scan und Zukunftsversion bleiben ohne Eignungswerte. Keine zweite Scanbelohnung.
- Erfolgs-/Fehlerklänge, sofortige Ablehnung nach Erfolg, unterdrückte Duplikate,
  Scanner-Lebenszyklus und bestehende Komfort-Audioprüfung bestanden.
- Zusätzlich grafisch mit Mesa/llvmpipe: echte Klicks auf scrollbare Befehle und den
  Buchbutton; alle fünf Reiter, Rolle aufklappen, fremde Pausen und Rückkehr zur Gruppe
  bei 1280 × 720, 800 × 600 und 640 × 480 geprüft.

Reproduktion der gezielten Suite:

```sh
python tools/validate_godot.py --godot /pfad/zu/godot --skip-main \
  --tests interface_task7_test discovery_journal_test research_goals_test \
  species_comparison_test tribal_age_test audio/interface_audio_test
```

Solange D1 noch nicht integriert ist, kann die **exakte** oben genannte Vertragsdatei
über `VOXELVERSE_D1_CONTRACT=/absoluter/pfad/domestication_contract.gd` nur dem Test
bereitgestellt werden. Der Test meldet `d1_checked: true` für den positiven Nachweis;
ohne verfügbaren D1-Validator meldet er ausdrücklich `false` und prüft den Rückfall.

Windows-Zielgerät, endgültige Hörabnahme und echte D1-/D2-Spielschleifen bleiben offen.
Es wird kein neuer Windows-Build und keine komplette D2-Integration behauptet.

## Bildnachweise

D1-Vertragsdaten an einer gespeicherten **Testbeobachtung**, kein Beleg eines
produktiven D1-Spawns:

![Gemeinsames Buch bei 800 × 600](../art/review/interface_task7/book_800x600.png)

![Aufgeklappte D1-Vertragswerte bei 800 × 600](../art/review/interface_task7/roles_800x600.png)

Echte Gruppenbefehle in der vorhandenen Stammesprüfszene:

![Gruppenbedienung bei 640 × 480](../art/review/interface_task7/group_640x480.png)

## Nächster Anschluss nach Veröffentlichungsfreigabe

D2 liegt inzwischen als getrennte Prüflieferung in PR #30 vor, Commit
`da6dbd62f505a688aba439cefe42ac8f029da4d4`. Der dortige Vertrag bietet
`owned_animals(faction_id, include_dead=false)` und `record(object_id)` als
lesende Kopien sowie `animal_changed(object_id, code)` nach bestätigter Speicherung.
Vertrauen liegt bei 0–100; Folgen, Warten und Heimkehr verwenden die Aufträge
`follow`, `wait` und `home`.

Der nächste UI-Schritt ist ein Adapter von diesem geprüften D2-Vertrag in das
vorbereitete Tierregister, zunächst mit gemeinsamer Prüfszene und Save/Load-Nachweis.
Die produktive D2-Kampagnenfreigabe und Integration der D1-Spawnlieferung stehen
weiterhin aus. PR #30 wurde weder übernommen noch verändert.

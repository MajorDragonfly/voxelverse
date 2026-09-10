# Voxelverse – Integration vom 10. September 2026

Basis: `main` bei `ea900f2e09946660694a9e59399b4680a5655a85`. Integrationsbranch: `agent/integration-2026-09-10`. Die 28 veröffentlichten Übergaben aus PR #42 und #49–75 sind auf dem Integrationsbranch zusammengeführt; ihre vollständigen Commit-IDs stehen in [integration-sources-2026-09-10.json](integration-sources-2026-09-10.json). Die Rücknahme einer doppelten ARCH-13-Reservierung enthält keine zusätzliche Implementierung. Historische, bereits anderweitig integrierte Weltbranches und ungespeicherte Fremdarbeit wurden nicht erneut übernommen.

## Ergebnis

| Bereich | Zusammengeführte Änderungen | Quellen |
|---|---|---|
| Planung und Datenbesitzer | Vollständige Ideenplanung und vorhandene Modul-/Speicheranschlüsse | #42, #49 |
| Baupläne und Vorlagen | Versions-/Originalschutz, portables Kreaturenformat, lokale Bibliothek, Editorübernahme, Startvorlagen | #50, #61, #75 |
| Produktion und Dorf | Ressourcen-/Rezeptkatalog, erhaltene Milchbatches, gezielte Arbeitsbeobachtung, bestätigte Epochenübergabe | #52, #57, #68, #73 |
| Oberfläche und Leistung | Zulässige Radien, verlässliche Bodenkollision, Kugelmessrouten, portionierte Pflanzen-/Tierarbeit, Wasser-Audio | #54, #56, #58 |
| Arten und Körperteile | Vierte Eierart, Körperfähigkeiten, gemeinsame Fuß-/Handgeometrie, Pfoten/Tatzen/Hufe/Krebsscheren | #55, #63, #66, #70 |
| Karte und Sicherungen | Dauerhafte Kacheln und bekannte Orte, begrenzte Seiten, vollständige Population-/Atlas-/Ortsarchive | #59, #62, #65, #71, #74 |
| Sprachen | Nachbarstämme, Weltkarte, Heimat/Gruppe und eigene Tiere auf DE/EN | #51, #60, #64, #72 |
| Reisen | Tatsächliche Tierhaltung und Milchfracht während A → B → A und Neustart erhalten | #69 |
| Gemeinsame Abnahme und Raumfahrtentwurf | Vertragsgate, vollständige Testregistrierung und begrenzter Schiffs-/Übergabenentwurf | #53, #67 |

## Aufgelöste Überschneidungen

- **ARCH-15:** #68 und #73 änderten dieselbe Snapshot-Funktion mit verschiedenen Signaturen. Die Laufzeit verwendet die stärker eingegrenzte und tief geprüfte Variante `snapshot(data, member)` aus #73. Der zusätzliche Vergleich aus #68 bleibt unter `village_work_observation_test` erhalten; seine Messhilfe und historische Übergabe wurden entsprechend zugeordnet. Ressourcenbatches aus ARCH-20 bleiben angeschlossen.
- **ARCH-17/21:** Die Priorisierung fehlender Pflichtarten läuft vor der begrenzten Spawnwarteschlange. Ein nach Eviction freigewordener Platz beginnt beim fehlenden Rollenkandidaten; ein alter Warteschlangencursor darf ihn nicht wieder mit einer gewöhnlichen Art besetzen. Der gemeinsame Test prüft Budget und vierte Rolle zusammen.
- **ARCH-14/25:** Paging, Auswahl und DE/EN-Aktualisierung bleiben im selben Kartenpanel. Die kompakte Ortsansicht erhält eine vollständige erreichbare Zeile. Die Lokalisierungsprüfung verwendet jetzt 128 zusätzliche Orte und wechselt Sprachen auf der zweiten Seite eines ausgelagerten Registers.
- **Sprachkatalog:** Alle neuen Schlüssel wurden mit Konfliktprüfung vereinigt und die PO-Dateien neu erzeugt. Der gemeinsame Katalog enthält 436 Nachrichten je Sprache.
- **ARCH-13/14:** Die Archive prüfen beide Atlaswurzeln, Ortswerte und gegenseitige Indexverweise. Das CI-Gate verwendet für Schema 3 den aktuellen Integrationscheckout; die gepinnte Schema-2-Referenz bleibt als Altformatprüfung erhalten.
- **ARCH-29:** Sämtliche 151 Godot-Tests sind genau einem von 17 Fachverträgen zugeordnet. Zukunftsbaupläne, Atlasgrößen und die reale Tier-/Frachtreise sind in den Szenarien aktualisiert.
- **Spielprüfungen:** Die Eierart muss innerhalb einer begrenzten Wartezeit drei aufeinanderfolgende echte Bodenkontakte nachweisen; ein beliebiger Bewegungsframe ist kein belastbarer Nachweis fehlender Kollision. Die Tier-Reise prüft nun absichtlich langsame gespielte Frames und die exakte Bilanz noch geschuldeter Kampagnenzeit. Die Rückkehr darf weder Zeit erzeugen noch Verarbeitung verlieren/doppeln; Tieridentität, Rezept, Chargen, Lager und wartende Fracht bleiben geschützt.
- **Planung:** Der aktuelle Kugelstart und bereits vorhandene radiale Funktionen bleiben erhalten. Neuere Ideen ergänzen die Planung, ohne ältere Statuszeilen über die aktuelle Umsetzung zu stellen.

## Gemeinsame Prüfungen

Die breite Prüfung verwendet Godot `4.6.3.stable.official.7d41c59c4` mit isolierten Nutzer-/Speicherverzeichnissen. Spielcode und gemeinsame Konfliktkorrekturen sind in `9ba2becdebf67e11fd94aac9f3aafd6bf1f56ed7` enthalten. Die gezielt korrigierten Prüfabläufe folgen in `da58436`, `ffe120e` und `3ca7e5a70dc7230b266f2a509f945c4cbd87f1db`. Letzterer ist der abschließend geprüfte Quellstand; danach folgen nur Dokumentation und Evidenz.

Im ersten Lauf bestanden 149 von 151 Godot-Tests. Zwei Prüferwartungen waren zu streng:

1. `egg_species_campaign_test` traf die gültige laufende Eierart genau in einem Frame ohne Bodenkontakt. Drei aufeinanderfolgende tatsächliche Kontakte werden jetzt innerhalb von höchstens 180 weiteren Physikticks verlangt. Der korrigierte Lauf besteht in 45,334 Sekunden einschließlich Wiederbesuch, Neustart und Schutz des alten Originals.
2. `spherical_gameplay_test` verglich den noch nicht vollständig fortgeschriebenen Fernzustand mit dem Rückkehrzustand. Die vollständige Diagnose zeigte 0,006655 Sekunden offene Kampagnenzeit; eine gezielte Wiederholung mit zwei Frames je Sekunde reproduzierte 5,436437 Sekunden. Produktionsfortschritt und Futter-/Wasserverbrauch änderten sich exakt um diese geschuldete Zeit. Der Rückkehrpfad arbeitete korrekt. Die Prüfung vergleicht jetzt Uhr, Cursor und Verbrauch unabhängig rechnerisch, prüft alle übrigen Haltungswerte weiterhin exakt und erzeugt langsame Frames gezielt. Ein weiterer Diagnoselauf zeigte eine reguläre Trinkpause des Tierpflegers während dieser Zeit (ein Wasser weniger, ein Getränk mehr). Für die exakte Lager-/Frachtprüfung werden die übrigen Bewohneraufträge deshalb vor Abreise über normale Befehle angehalten; das vorher tatsächlich versorgte Tier produziert weiter.

Ein diagnostischer Wiederholungslauf wurde durch den Neustart des Ausführungsdienstes unterbrochen und zählt nicht als bestanden. Nachweise der ursprünglichen Fehler bleiben im Evidenzmanifest erhalten. Frühere Fachbranch-Messwerte bleiben historische Nachweise ihrer jeweiligen Quellen.

| Prüfung | Ergebnis |
|---|---|
| Fachtests | **151/151 Godot-Tests bestanden** nach gezielter Wiederholung der beiden korrigierten Prüfabläufe |
| Spielstart, Abschaltung und Streaming | **23/23 bestanden**, einschließlich Abschaltung in Ressourcen-/Terrain-Ladestufen |
| Python-Werkzeuge und Archivwiederherstellung | **43/43 bestanden** in 54,303 Sekunden; tatsächliche Godot-Neustarts für Population, Atlas Schema 2 und Orte Schema 3 enthalten |
| Import und Art-Quellen | **2/2 bestanden** mit Godot 4.6.3 |
| Vertrags-/Sprachgate | **Bestanden:** 151 Tests genau einmal in 17 Verträgen, 436 Nachrichten je Sprache |
| Vollständige Kugel-Spielkette | **Bestanden in 443,385 Sekunden:** Dorfaufbau → Zähmung → Tierplatz → Versorgung → reale Milchproduktion → blockierter Träger → fehlgeschlagener Save → A–B–A → Neustarts → körperliche Milcheinlagerung |

Bei der abschließenden Rückkehr wurden 5,712036 Sekunden bereits gespielter Zeit genau einmal nachgeholt. Der gezielte Replay mit einem zuvor tatsächlich erspielten Zwischenstand bestand ebenfalls. [Evidenzübersicht und Wiederholung](evidence/integration-2026-09-10/README.md), [Ergebnismanifest](evidence/integration-2026-09-10/summary.json), [alle Checks](evidence/integration-2026-09-10/godot-checks.json).

## Verbleibende Grenzen

ARCH-13/14 sind mit den Atlas-/Archivpaketen nicht insgesamt abgeschlossen: globales Manifest, Aufbewahrung/Bereinigung und weitere Langzeitregister bleiben offen. Die vierte Tierart besitzt Eier-Eignung, aber noch keine fertige Eierproduktionskette; diese folgt in ARCH-22. Schiffsflug, spätere Epochen, Online-Communitykatalog und der vollständige Tierformenkatalog bleiben eigene Arbeitspakete.

Der ARCH-30-Entwurf meldet weiterhin die Präzisionsgrenze des gemeinsamen JSON-Schreibers bei sehr großen Double-Koordinaten. Die längere ARCH-02-Rückroute und die Ziel-PC-/GPU-/60-FPS-Abnahme bleiben offen. Eine erfolgreiche technische Integrationsprüfung ist keine grafische oder Windows-Abnahme.

## Veröffentlichung

Der erste Uploadversuch wurde durch die automatische Freigabeprüfung bis zur ausdrücklichen Zustimmung blockiert. Lars hat anschließend den Upload nach `MajorDragonfly/voxelverse` und die Übernahme in `main` ausdrücklich freigegeben. Die Veröffentlichung erfolgt auf Grundlage dieser Freigabe; der GitHub-PR-/Commit-Verlauf dokumentiert den tatsächlichen Abschluss. Die oben genannten grafischen und nativen Prüfgrenzen bleiben bestehen.

Nächste Aufgaben und abgegrenzte Anschlüsse: [NEXT_PARALLEL_WORK.md](NEXT_PARALLEL_WORK.md).

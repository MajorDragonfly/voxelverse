# INT30-17-BUILDING-EXCHANGE: Fachübergabe

Basis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`.
Branch: `agent/int30-17-building-exchange-20260930`.
Ziel: `agent/integration-pt19-20260930`.

## Ergebnis

Zwei neue Adapter unter `assembly/exchange/`: geschlossenes Building-Paket und
Dateitransport mit unabhängiger Inbox. Unveränderliche Design-ID/Revision,
bekannte Teile, Ursprung und Geometrie bleiben erhalten. Unversionierte lokale
Entwürfe werden reproduzierbar vorbereitet; neuere/unbekannte Pakete bleiben
geschützt. Import verändert keine Kampagne, Freischaltungen, Bestände oder
Gebäudeinstanzen. Bearbeitung erfolgt über vorgeschlagene Kopie mit neuer ID
und Herkunft; keine automatische Übernahme oder kostenlose Platzierung.

Originale und alle gemeinsam besessenen Produktdateien sind unverändert.
Enthaltene UI-, Registry- und Runner-Anhänge werden separat durch die jeweiligen
Besitzer integriert. Keine zweite Vorlagenverwaltung oder Community-Service-
Erweiterung. Produkt-UI bei Chat 14, Vorlagen bei Chat 25.

## Nachweise und Quellstände

Godot `4.6.3.stable.official.7d41c59c4`, Linux x86_64, isolierte Nutzerdaten.
Fachcode unverändert seit `3e297ddc7567270968d0568a5bd3049193a8bc2b`
(Tree `2f8ea9e23ca08778ce28e16b882eabed2acacbd6`). Spätere Fachcommits
enthalten ausschließlich Anhänge/Dokumentation/Nachweise.

- Isolierter direkter Fachlauf auf sauberem `3e297dd`: Exit 0, **125 Kontrollen**,
  Quelle/Empfänger/Offline-Neustart erfolgreich; 100,974 s auf CPU 2/3 mit
  `--headless --single-threaded-scene --rendering-method gl_compatibility
  --audio-driver Dummy --script res://tests/building_design_exchange_test.gd`.
- Regulärer Validator mit den **zwei zentralen Anhängen** in separater sauberer
  Prüfkopie: Commit `75bff5d29d2c8a0fae8330f7e4e00eede3ba2be3`,
  Tree `6344007ff39c245aa0cc6b1d845705ee1e108982`, vollständiger Quellhash
  `6f36cae7406b12b4cb1e8f76f1741b5e32161d3bdec3f7ba8aeb272c41f7166d`.
  Produkt-/Testcode entspricht dem Fachbranch; einzige zusätzliche Änderungen
  sind Registrierung und neues Persistenzbudget. `validate_godot.py --tests
  building_design_exchange_test --skip-main --skip-import` mit Godot-Pfad und
  separatem Ausgabeordner, CPU 2/3: **Quellvertrag, Fachtest (26,463 s, 125
  Kontrollen) und Quellenintegrität grün**, sauberer unveränderter Stand,
  wiederverwendbarer Quellnachweis. `--skip-import` verwendet den vorher
  erfolgreich importierten identischen Ressourcenbestand dieser Prüfkopie.
- Erweiterter Bauplanvertrag auf `22dd5e776ea31466066d62b63d44b8867ffd1a7f`
  plus Registry-Anhang, CPU 0/1: Import, Quell-/Ressourcenprüfung sowie
  blueprint_contract, community_blueprint_package, community_catalog_client,
  creature_design_library, creature_library_favorites und
  modular_assembly_framework erfolgreich. Dies ist ein historischer Teilnachweis
  dieses genau bezeichneten Standes, keine Behauptung einer grünen Gesamtsuite.
  Neuer Fachtest und unveränderter creature_library_ui liefen jeweils ins
  damalige 120-s-Limit. Der Fachtest wurde oben vollständig erneut geprüft;
  der erste Zeitüberschreitungsbeleg bleibt im Archiv.
- Ein gezielter unveränderter Bibliotheks-UI-Lauf auf der sauberen Prüfkopie
  `75bff5d`/CPU 2/3 erreicht ebenfalls das 120-s-Limit (120,086 s), diesmal beim
  Laden der bestehenden Kugelkampagne. Keine Aussage über die Ursache oder
  eine erfolgreiche Bibliotheks-UI-Abnahme; an Chat 1/12 weitergegeben.
- `building-editor.patch` lässt sich auf die feste Editorbasis anwenden;
  Godot `--check-only --script res://civilization/buildings/building_builder.gd`
  auf der gepatchten Prüfkopie: Exit 0, keine Parserfehler. Dies ist ausschließlich
  Syntaxprüfung, keine echte Maus-/Phasen-/Speicherbedienung des Editors.

`proofs.tar.gz` enthält Befehle, vollständige SourceRun-Berichte/Manifeste und
Logs mit ihren SHA256-Digests. `evidence.json` ordnet die Läufe und tatsächlichen
Ergebnisse zu. Keine fehlgeschlagenen Läufe werden als bestanden gezählt.

## Integration und Grenzen

Chat 1 übernimmt `test-registration.patch` und `runner-budget.patch` vor der
gemeinsamen Prüfung. Der konservative Änderungsplan erweitert wegen der
gemeinsamen Registry/Anhänge auf volle Prüfung; diese 248 Tests, Main-/Runtime-
Kette, vier Pflichtgates und native Exporte wurden **nicht** lokal ausgeführt.
Hier wurde ausdrücklich der abgegrenzte Bauplanvertrag geprüft.

`building-editor.patch` ist ein Anschlussangebot an Chat 14; keine produktive
UI-Adoption oder gerenderte Abnahme behauptet. Bewusste Übernahme mit vorhandener
Historie, freie Kopier-Zieldatei und Mittelalter-Grenze bleiben im Editorauftrag.
Die aktuelle Spieltest-Abnahme und Ziel-PC-Leistung der Chats 2–10 bleiben
unverändert offen. Fach-PR als Entwurf für die separaten Folgefunktionen;
kein Auto-Merge und kein main-Merge.

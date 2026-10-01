# INT30-17: Gebäudeentwürfe austauschen

Fachbasis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`, Tree
`5f815f478ceeabefcfc50a6388e3e4b0daa2ac45`.
Lieferbranch: `agent/int30-17-building-exchange-20260930`.
Integrationsziel: `agent/integration-pt19-20260930`. Die Zuständigkeit steht
ausschließlich in #137; dieses Dokument ist ein datierter Fachvertrag/Nachweis.

## Adaptervertrag

- `BuildingDesignExchange.export_file(blueprint, destination, metadata)` exportiert
  den lokalen Entwurf ohne ihn zu verändern. Metadaten: optional title,
  description, author und tags. Keine Kampagnen-, Eigentümer-, Freischaltungs-,
  Inventar-, Produktions-, Statistik- oder externen Ressourcen-/Scriptdaten.
- `import_file(source, directory)` / `import_package(package, directory)` prüft
  zuerst vollständig und speichert dann eine unveränderliche portable Revision
  in `user://building_exchange`. Diese Inbox ist **kein Vorlagenregister** und
  gehört nicht zu `CampaignDesignStore` oder dem Kampagnensnapshot. Ergebnisse
  enthalten path, key, package und eine unabhängige BuildingBlueprint-Vorschau.
- Identität ist das Paar `design_id@revision`. Dateinamen sind dessen SHA256;
  fremde Anzeigenamen/IDs bestimmen keine Pfade. Gleicher geprüfter Inhalt ist
  idempotent; abweichender Inhalt derselben Revision ergibt `revision_conflict`.
  Eine neue Revision erhält einen eigenen Pfad. Andere vorhandene Zieldateien,
  Zukunfts-/Fehlerversionen, leere Dateien und fremde `.tmp` bleiben erhalten.
- `BuildingBlueprintPackage.prepare_working_copy(package)` liefert einen
  **vorgeschlagenen**, unabhängigen Entwurf mit neuer Design-ID, Revision 0,
  erhaltenen Bauteil-IDs und Herkunft einschließlich exakter Quellrevision.
  Kein automatisches Speichern, keine Übernahme in laufende Editorhistorie,
  keine Platzierung und keine kostenlosen Gebäude. Lokale Kosten/Statistik
  werden aus der bestehenden Bauteilbibliothek berechnet.
- Unversionierte lokale Gebäudeentwürfe sind gemäß BlueprintContract lesbar:
  fehlende Design-/Teile-IDs werden reproduzierbar aus dem Entwurfsinhalt
  ergänzt. Vorhandene IDs/Revisionen bleiben erhalten. Portable Pakete haben
  ausdrücklich Schema 1; alte lokale Entwürfe zuerst über export_blueprint
  vorbereiten. Rohdateien werden nicht als portable Pakete fehlinterpretiert.
- Alle Paketfelder sind geschlossen. Vorhandener Schema-Walker wird nur gelesen;
  BuildingBlueprint.validate und Assembly/BlueprintContract bleiben maßgeblich.
  Fehlende Teile werden vor jeder Fallback-Normalisierung zurückgewiesen;
  ihr Original wird weder repariert noch überschrieben. Generische vorhandene
  part_revision/catalog_revision-Verweise bleiben als Entwurfswerte erhalten;
  die vorhandene Gebäudebibliothek hat keinen separaten Versionsresolver.
- Transportgrenzen v1: 2 MiB, 2048 Teile, Namen/Autor/Stil 120 UTF-8-Bytes,
  Beschreibung 2000 Bytes, maximal 12 Tags à 40 Bytes, acht Herkunftseinträge.
  Positionen ±4096, Drehungen ±36000°, Skalierung 0,05–20, Raster 0,03125–4.
  Dies sind Adaptergrenzen, keine zusätzlichen Baukapazitäten/Freischaltungen.
  Ungeeignete Geometrie wird beim Export vor lokalem Clamping zurückgewiesen.
- Veröffentlichung nutzt unverändert AtomicJson einschließlich genauer
  JSON-Zahlen und userdata lease. Eine eigene Zielpfad-Mkdir-Sperre serialisiert
  zusätzliche Adapter-Schreiber. Bestehende Sperren ergeben `writer_busy`;
  ein unterbrochener Schreiber wird nicht automatisch übergangen.

## Integrationsanhänge

`test-registration.patch` fügt `building_design_exchange_test` **genau einmal**
zum vorhandenen Vertrag `blueprints` hinzu. Chat 1 übernimmt ihn in die zentrale
Registry; der Fachbranch ändert Registry, CI, Übersetzungen und Statusdaten nicht.
Ohne diese Übernahme meldet der zentrale Source-Check den neuen Test zu Recht
als unregistriert. Fachnachweis wird in einer separaten lokalen Prüfkopie mit
genau diesem Patch erstellt; deren abweichende Registry wird explizit genannt.

`runner-budget.patch` ordnet ausschließlich den neuen Test dem vorhandenen
begrenzten Persistenzbudget des Runners zu. Er startet drei zusätzliche frische
Prozesse; der erste Standardlauf erreichte auf zwei CPU-Kernen nach Quelle und
Empfänger 120 Sekunden. Der isolierte finale Fachlauf besteht in 100,974 s;
Erwartungen und Neustartfälle werden nicht reduziert. Chat 1 übernimmt diese
kleine Runner-Ergänzung zusammen mit der Registrierung; beide gemeinsamen
Produktdateien bleiben im Fachbranch unverändert.

`building-editor.patch` bietet Chat 14 drei aufrufbare Brücken für dessen
Dateidialog-/Vorschauoberfläche. Der Vorbereitungspfad prüft echte Kampagne,
Phasenwechsel, Mittelalter oder später und geschützten aktuellen Entwurf.
Er verändert das Editorobjekt nicht. Chat 14 integriert nach bewusster Vorschau
mit der vorhandenen Undo-Historie und einer **neuen, freien Kopier-Zieldatei**;
der bestehende namengebundene save_design-Pfad darf dafür kein Original ersetzen.
Die Inbox kann Chat 25 lesen, ohne eine zweite Vorlagenverwaltung aufzubauen.
Die Brücken enthalten keine neuen sichtbaren Texte; Fehlercodes übersetzt die
zuständige Oberfläche über ihren vorhandenen DE/EN-Sprachweg.

## Fachprüfung

`tests/building_design_exchange_test.gd` prüft echte Export-/Importdateien,
geometrischen Rundlauf, alte und unbekannte Versionen, stabile Identitäten,
Herkunft, lokale Kosten, fremde Felder/Ressourcen, fehlende Teile, Limits,
doppelte/geänderte Revisionen, geschützte Originale, Staging-/Schreibfehler und
eine gehaltene Schreibsperre. Drei frische Godot-Prozesse führen Quelle →
getrennten Empfänger → Offline-Neustart aus. Der Empfänger beginnt mit eigener
Kampagne: Zustand, Freischaltungen und Kampagnenentwürfe werden vor/nach Import
und nach Neustart verglichen. Das fremde Original bleibt bytegleich; der
Rückexport erhält dieselbe portable Revision. Der Neustart läuft nach Entfernen
der Transferdatei.

Adapter ohne Produkt-UI: keine gerenderte Sichtabnahme behauptet.
Gebäudeeditor-/Vorlagenbedienung bleibt bei Chats 14/25. Volle Integration,
gemeinsame Produktionskette, native Exporte und Spieltest-Abnahme sind separat.

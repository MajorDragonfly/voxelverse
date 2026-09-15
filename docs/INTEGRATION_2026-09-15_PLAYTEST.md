# Gemeinsamer Spieltest vom 15. September 2026

Branch: `agent/playtest-latest-20260915`. Basis ist PR #110 bei
`1d6573d9551c3f24bf1dd6fa64e5c301583a26c8`, einschließlich #93–109.
Die ausdrücklich übergebenen dreizehn neuen Lieferungen werden mit festen Commits
integriert. `main` bleibt außerhalb dieser Zusammenführung.

## Eingänge

| PR | Fester Übergabestand | Lieferung |
|---|---|---|
| [#111](https://github.com/MajorDragonfly/voxelverse/pull/111) | `cc25427d028e92435de989b06c48cd8150d05afa` | Tierhaltung und Epochenbestätigung DE/EN |
| [#112](https://github.com/MajorDragonfly/voxelverse/pull/112) | `9b502ef121a49bcdf2e7c0d0995b8075b61469c9` | Gespeicherte Modellrevisionen |
| [#113](https://github.com/MajorDragonfly/voxelverse/pull/113) | `122a7eb380d87fdaab07a9d1ec849906f2999ce9` | Terrain-Cachepflege |
| [#114](https://github.com/MajorDragonfly/voxelverse/pull/114) | `69eed2823fb3aa7276547552b01938545446374f` | Archiv- und Schreiberlebensdauer |
| [#115](https://github.com/MajorDragonfly/voxelverse/pull/115) | `943be0a232c2d1ff3ec161b84698986d1a31892f` | Tieremotionen und korrigierte Augenlider |
| [#116](https://github.com/MajorDragonfly/voxelverse/pull/116) | `77eb3c0d99180615056c10e74e06f6b8a3b3fc9c` | Getrennter Stammes-Spieltest |
| [#117](https://github.com/MajorDragonfly/voxelverse/pull/117) | `bf1afe856a2eff56a7d881f15f7bba50098ce21d` | Atmosphäre und Grafikpresets |
| [#118](https://github.com/MajorDragonfly/voxelverse/pull/118) | `fec14052265223b08caf9f28187bf23a231ea61d` | Regionales Wetter und sanfter Schnee |
| [#119](https://github.com/MajorDragonfly/voxelverse/pull/119) | `faf6b5d53be052bb36cdb0bff582b967a7140b2a` | Transport zwischen Ortslagern |
| [#120](https://github.com/MajorDragonfly/voxelverse/pull/120) | `365c402d4e5635c024e96f4299e8b85561c35cd0` | Quellnachweise im Prüfläufer |
| [#121](https://github.com/MajorDragonfly/voxelverse/pull/121) | `aed0f9a24cb78dceedbe536aa0d2686bc8669e76` | Vier weitere Schwanzfamilien |
| [#123](https://github.com/MajorDragonfly/voxelverse/pull/123) | `4385501d05491da8f514a3397738dadd65082ef0` | Zwei gleichartige Arbeitsplätze pro Ort |
| [#124](https://github.com/MajorDragonfly/voxelverse/pull/124) | `535bf4d7c585d79c9144d1cc7ec3c3c80135ff29` | Export-Quellnachweise und ZIP-Freigabe |

PR #122 (`3689bddb01117984e0cc5609e2958b4feb8f7b21`) ist eine alternative
Implementierung desselben ARCH-29-Folgeauftrags wie #120. Beide ersetzen dieselben
Werkzeugdateien und werden nicht übereinandergelegt. #120 bleibt die gemeinsame
Implementierung: vollständige Dateiinventare, begrenzte Lesevolumina, Endprüfung
aller Bytes und exklusiv besessene Ausgabeordner. #122 bleibt als Alternative
unverändert bestehen. Noch nicht veröffentlichte Renderarbeiten gehören nicht
zu dieser festen Paketliste.

## Gemeinsame Korrekturen

- Katalogmeldungen nach Schlüssel vereinigt; 1.401 Meldungen in DE/EN. Alle 194
  registrierten Godot-Tests haben genau einen zuständigen Vertrag.
- Warenbilanz summiert alle Arbeitsplatzquellen, berücksichtigt echte Ein- und
  Ausfuhren und zählt reservierten Lagerraum nicht als Ware. Ein gebundener
  Transportbewohner kann auch keinem neuen Arbeitsplatz zugeteilt werden.
  Zusätzlicher gemeinsamer Save-/Lieferfall mit zwei Brunnen an beiden Orten.
- Atmosphärenhimmel liest Bewölkung, Niederschlag und Sichtweite des Wettermodells;
  Wetter behält Regen/Schnee, der Shader übernimmt die Wolken. Sonne und Dunst
  reagieren auf den gemeinsamen Wetterstand, Unterwasser bleibt kamerageführt.
- Der Wetter-Prüfplan verweist ausschließlich auf Verträge; keine zweite Liste
  einzelner Tests neben `contracts.json`.
- Bestehender Windows-Exportblocker: deutsche UI-Textprüfungen erhalten ausdrücklich
  Deutsch, unabhängig von der Betriebssystemsprache. Der Eierrollen-Test prüft
  die inzwischen vorhandene Stammes-Eierhaltung statt des überholten Hinweises.
- Der historische D1.2-Test rekonstruiert die vollständigen begrenzten alten
  Inline-Tierdaten aus dem Archiv, bevor er Schema 1 schreibt. Wiederbesuch
  vergleicht dieselben Individuen. Neustartwerkzeuge nutzen isolierte Daten auch
  bei einer selbstenthaltenen Godot-Installation.
- Durch den erfolgreichen Import erzeugte Skript-UIDs sind mit versioniert.
- Gemeinsame Neustart-Prüffälle berücksichtigen jetzt explizite Modellrevisionen
  und die beiden neuen, vom bereits freigeschalteten Balanceschwanz abgeleiteten
  Formen. Vorhandene Fußtransformationen, historische Freischaltungen,
  Entdeckungen und Punkte werden weiterhin vollständig verglichen.
- Windows-Quellprüfung: Pfad- und Dateideskriptor-APIs liefern unterschiedliche
  Bedeutungen für `ctime`. Ihr Vergleich nutzt deshalb die gemeinsame
  Dateiidentität; vollständige Zeitstempel bleiben innerhalb derselben API vor
  und nach dem Lesen sowie an den Prüfgrenzen erhalten. Dateiaustausch und
  Änderungen während des Lesens bleiben harte Fehler.

## Prüflage

Godot 4.6.3, Linux/headless, synthetische isolierte Nutzerdaten.
Import, Art-/Quellgate, Atmosphäre, Arbeitsplatzmodell sowie Transport inklusive
Mehrfach-Arbeitsplätzen erfolgreich. Vollständiger lokaler Lauf auf `1f0b292`:
191 von 194 Godot-Tests bestanden. Zwei alte Neustartorakel wurden an die neuen
Modellverweise angepasst und bestehen im gezielten Nachlauf. Der Wettertest
erfüllte seine Funktionsprüfungen, meldete einmal ein RefCounted-Objekt beim
Beenden und bestand den unveränderten Wiederholungslauf. Dieser einzelne Hinweis
ist nicht als behobener Programmfehler deklariert. Alle Originalbefunde bleiben
im begleitenden Prüfarchiv erhalten.

Die Milch- und Eierketten mit Tier/Fracht über A–B–A, 25 zusätzliche Prüfungen
zu Start/Laden/Beenden und Quellintegrität sowie der historische D1.2-Fall in
zwei Prozessen bestehen. 149 Python-Fälle: 142 bestanden, 7 optionale ausgelassen.
Menü und Kugelkampagnenstart wurden im exportierten Linux-Spiel geprüft. Die
GitHub-Menüprüfung auf `84e7e8f` ist erfolgreich.

Die nativen Windows-/Linux-Exporte werden am veröffentlichten Integrations-PR
geprüft. Ein erster Windows-Lauf stoppte am oben korrigierten Quellzeitstempel-
Vergleich, noch vor dem Export. Maßgeblich sind abgeschlossene Actions-Läufe
und ihre Quellrevisionen. Das lokal unter Linux exportierte Windows-Paket ist
ein vorläufiger Spieltest; es ersetzt die native Windows-Abnahme nicht.
Ziel-PC-Grafik, Spielgefühl und FPS bleiben Lars' Spieltest.

## Spieltest

1. Windows-ZIP vollständig in einen neuen Ordner entpacken; EXE und PCK zusammen
   lassen. Hauptmenü → **Stammeszeitalter testen** legt einen getrennten Slot an.
2. **Testwelt vorbereiten**, dann den regulären Aufstieg ausdrücklich bestätigen.
   Dorfbewohner auswählen, Sammeln/Bauen, zweiten Arbeitsplatz und Lagertransport
   ausprobieren; unterwegs speichern, neu laden und Warenbestände vergleichen.
3. Im Kreaturenmodus Tiere beobachten/befreunden/begrüßen; Blinzeln und Augenlider
   aus der Nähe prüfen. In der Werkstatt neue Schwanzformen und vorhandene
   Entwürfe prüfen.
4. F8 → **Grafik**: Basis, Atmosphärisch, Cineastisch wechseln und speichern.
   Himmel, Regen/Schnee und Unterwasserübergang prüfen. Vorschau optional über
   `voxelverse.exe -- --weather-preview=rain` oder `--weather-preview=snow`.
5. Startplanet und alle derzeitigen Kampagnenkörper bleiben wetterseitig mild.
   Feuer-/Sandstürme sowie individuelle Grafikregler bleiben Roadmap-Folgearbeit.

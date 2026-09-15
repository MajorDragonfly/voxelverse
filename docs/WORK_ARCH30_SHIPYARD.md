# ARCH-30-SHIPYARD — erster modularer Schiffseditor

Basis: `d378ca0ecd7f03429a5150df6358e0646ec06689` (main nach PR #92).
Branch: `agent/arch30-shipyard-20260915`. Eigenständiger Teilauftrag aus
M9.1; die Roadmap erlaubt den vorgezogenen Daten-/Editoranschluss. ARCH-25
und ARCH-26 bleiben bei den parallel arbeitenden Besitzern. M9.1 und ARCH-30
als gesamte Kampagnenlieferungen bleiben offen.

## Benutzung

In Godot 4.6.3 `space/ships/shipyard.tscn` öffnen und F6 drücken, oder:

```sh
godot --path /pfad/zu/voxelverse res://space/ships/shipyard.tscn
```

1. Expedition oder Beiboot als eigene Vorlage öffnen. Der Eigenbau ist optional.
2. Links Module hinzufügen, in der Liste oder per Linksklick am Modell auswählen.
   Rechts X/Y/Z im 1-m-Raster ändern, um 90° um die Hochachse drehen,
   eine Spiegelkopie erstellen oder entfernen. Neue Module erscheinen rechts
   neben der Auswahl. Rotationen, Ergänzungen und Verschiebungen müssen erneut
   die Verbindung und Passung erfüllen.
3. Mit rechter Maustaste die Ansicht drehen; Mausrad zoomt; „Ansicht zentrieren“
   rahmt den gesamten Entwurf. Die Maßreihenfolge ist X × Y × Z.
4. Unter eigenem Namen speichern. „Entwürfe öffnen“ lädt die lokalen Entwürfe.
   Auch unvollständige Entwürfe sind speicherbar und deutlich gekennzeichnet.
5. Eine Expedition und ein Beiboot speichern. „Hangar mit Entwurf prüfen“
   vergleicht den offenen Entwurf mit dem ausgewählten gespeicherten Gegenstück.
   Die Prüfung versucht 0° und 90° und zeigt den verbleibenden Freiraum pro Seite.

Änderungen vor Vorlagenwechsel, Laden oder Schließen werden bestätigt. Undo/Redo
nutzt die vorhandene begrenzte Assembly-Historie. Ein Ladefehler lässt den
geöffneten Entwurf unangetastet; ein Schreibfehler behält Inhalt und Revision.

## Lieferung und Regeln

- 15 lokale Modultypen: zwei Rümpfe, Cockpit/Brücke, zwei Antriebe und Reaktoren,
  Batterie, zwei Frachträume, Landegestell, Hangar, Labor und Quartier.
- Eigene stabile Entwurfs- und Modul-IDs bei jeder neuen Vorlage. Die Expedition
  „Pionier“ misst 36 × 13 × 42 m, das Beiboot „Späher“ 4 × 6 × 10 m.
- Der bestehende `ModularAssetAssembler` rendert dieselben Kataloggeometrien,
  auf denen Auswahl und Prüfung aufbauen. Die Blockgeometrie ist die erste
  Modulansicht; detaillierte Schiffsmodelle und Innenräume folgen separat.
- Katalogrevision 1 leitet Masse, Schub, Leistung/Verbrauch, Energiespeicher,
  Fracht, Sitze, Labore und Kosten ab. Mitgespeicherte angebliche Statistiken
  verändern keine Fähigkeiten. Kosten/Schub sind vorläufige Entwurfswerte;
  sie verbrauchen keine Ressourcen und simulieren weder Flug noch Forschung.
- Maximal 128 Module; Ausdehnung Beiboot 16 × 12 × 24 m, Expedition
  96 × 48 × 160 m. Die begrenzte Paarprüfung erkennt Überschneidungen und
  verbindet Module nur über echte Flächenkontakte. Kanten und einzelne Punkte
  reichen nicht. Alle Module müssen denselben Rumpfverbund erreichen.
- Typbindung, genau eine Kommandoeinheit, Energie, Antrieb/Masse, Frachtraum und
  rollenabhängig Landegestell/Hangar entscheiden über einen vollständigen Entwurf.
  Module lassen sich nicht durch Skalieren leistungsfähiger machen.
- Die Hangarbox reserviert die gesamte Modulhülle gegen Fremdmodule. Der
  nutzbare Innenraum beträgt 12 × 8 × 16 m. Das ist eine geometrische
  Passungsprüfung, keine physische Andock- oder Anflugfreigabe.

## Bauplan- und Speicheranschluss

Neue Dateien liegen unter `space/ships/`; gemeinsame Laufzeitbesitzer bleiben
unverändert. `ModularAssembly` Schema 1, bestehender Codec und `DesignStore`
mit `AtomicJson` werden wiederverwendet. Das zusätzliche `ship`-Fachfeld hat
Schema 1, Rolle und Katalogrevision. Jede Platzierung pinnt `part_revision=1`.
Unbekannte Module, neuere/ungültige Versionen und übermäßige Daten werden vor
Normalisierung abgewiesen. Es gibt keinen stillen Backup-Rückfall.

Lokale Entwürfe liegen in `user://ship_designs/`, mit Dateinamen aus dem Hash
der Design-ID. Namen mit Pfadzeichen bestimmen keinen Speicherpfad.
`save_design` prüft auch das vorhandene Original gegen den Schiffsvertrag,
verhindert die Überschreibung einer fremden Design-ID und erhöht die Revision
erst nach erfolgreichem Schreiben. Undo erhält die bereits gespeicherte
Revisionsuntergrenze am geöffneten Pfad. `load_design` liest höchstens 2 MiB.

`pin_saved(path)` liest ausschließlich einen gespeicherten vollständigen Entwurf.
Die Ausgabe enthält `blueprint`, `capabilities` im vorhandenen ARCH-30-Format
sowie `design_center` und lokale `bay_frames`. Bay-ID ist die stabile UID der
Hangarplatzierung. Zukünftige Szenen müssen den Entwurfsursprung um
`design_center` korrigieren; die Boxgrößen des alten Entwurfsvertrags beziehen
sich auf eine zentrierte Schiffshülle. Das Ergebnis ist eine abgeleitete Kopie,
kein neues Schiffsregister. Ungespeicherte Änderungen verändern keinen Pin.

Die Dateien sind eine lokale Autorenbibliothek, kein zweiter Kampagnensave.
Vor M9-Kampagnenintegration fehlen Save-Teilnahme/Backupinventar für verwendete
Schiffsentwürfe, dauerhafte Instanz-/Bauplan-Pins, Weltorte, Kosten/Forschung,
Besitz, physische Übergaben und Flug. Bibliotheksauflistung und Autorenspeicherung
sind synchron; Langzeitpaging der lokalen Entwurfsbibliothek ist nicht enthalten.
Der im alten ARCH-30-Dokument genannte Writer-Präzisionsmangel ist auf dieser
Basis bereits im gemeinsamen `AtomicJson.stringify` behoben; hier wird kein
Koordinatensave oder neues Präzisionstor eingeführt.

## Prüfung und Integration

`shipyard_test` ist genau einmal im bestehenden Vertrag `expedition_design`
registriert. Direkte Verbraucher: `expedition_contract_test` und
`modular_assembly_framework_test`. Der neue Test prüft insbesondere fehlerhafte
Eingaben, Modulwirkungen, Verbindung/Größe, gedrehte Hangareignung, Revisionen
nach Undo, Original-/Backupbytes bei Schreibfehlern, neues Godot-Lesen im
separaten Prozess, echte Editorszene und Passung der abgeleiteten Fähigkeiten
zum vorhandenen Expeditionsvertrag.

```sh
python3 tools/validate_godot.py --godot /pfad/zu/godot --skip-main \
  --tests shipyard_test expedition_contract_test modular_assembly_framework_test
python3 tools/review_shipyard.py --godot /pfad/zu/godot --output /tmp/shipyard-review
```

Der Grafikrunner benötigt eine Anzeige, etwa Xvfb unter Linux, und nutzt
isolierte Benutzerdaten. Er prüft echte Eingaben und erstellt sieben Bilder
der beiden Vorlagen und der Hangarprüfung. Die abschließenden Logs und
Quellreferenzen stehen unter `docs/evidence/arch30-shipyard/`.

Gemeinsamer Schreibbereich: ausschließlich die zusätzliche Testregistrierung
in `tools/validation/contracts.json`. Keine Änderungen an Kampagne, SaveService,
Kreatureneditor, Übersetzungen, Siedlungslogik oder zentralen Statusseiten.
Die Integration übernimmt den Registry-Eintrag einmal und aktualisiert die
zentralen Projektstände. Kein Merge, Windows-Export oder Ziel-PC-FPS-Nachweis.

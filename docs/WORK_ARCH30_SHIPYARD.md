# ARCH-30-SHIPYARD — modularer Schiffseditor und Ausbau

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
2. Links Module nach Name und Kategorie suchen. Einen Anker in der Modulliste
   oder per Linksklick am Modell auswählen, Anbauseite und Drehung festlegen.
   Die grüne/rote Vorschau zeigt die tatsächliche Modulgeometrie und blockiert
   unzulässiges Anfügen. „Symmetrisch (X)“ fügt beide Seiten in einem Schritt an;
   auf der Mittellinie entsteht nur ein Modul. Beide Seiten müssen frei sein.
   Die sechs Anbauseiten beziehen sich auf die globalen Entwurfsachsen.
3. Rechts X/Y/Z im 1-m-Raster ändern, um 90° um die Hochachse drehen,
   spiegeln oder entfernen. Freie Verschiebungen und Rotationen werden als
   Entwurfsänderung übernommen; die Prüfung zeigt dabei entstehende Probleme.
4. Mit rechter Maustaste die Ansicht drehen, mit mittlerer Maustaste verschieben,
   mit dem Mausrad zoomen. Oben/Vorne/Seite sind orthografische Ansichten.
   „Ansicht zentrieren“ rahmt den Entwurf. Die Maßreihenfolge ist X × Y × Z.
5. Unter eigenem Namen speichern oder „Als Kopie“ mit eigenen IDs sichern.
   „Entwürfe öffnen“ zeigt eine durchsuchbare Bibliothek mit zwölf Einträgen pro
   Seite. Auch unvollständige Entwürfe sind speicherbar und gekennzeichnet.
6. Eine Expedition und ein Beiboot speichern. „Hangar mit Entwurf prüfen“
   vergleicht den offenen Entwurf mit dem ausgewählten gespeicherten Gegenstück.
   Die Prüfung versucht 0° und 90° und zeigt den verbleibenden Freiraum pro Seite.

Vor Vorlagenwechsel, Laden oder Schließen können Änderungen gespeichert,
verworfen oder der Wechsel abgebrochen werden. Ein Schreibfehler hält den
Dialog und den Entwurf offen. Undo/Redo nutzt die vorhandene begrenzte
Assembly-Historie; eine Namenseingabe und ein symmetrisches Paar sind jeweils
ein Schritt. Eine gespeicherte Kopie beginnt eine eigene Historie.

Tastatur: Strg+S speichern, Strg+Umschalt+S als Kopie, Strg+Z rückgängig,
Strg+Y oder Strg+Umschalt+Z wiederholen, R drehen, Entf entfernen, F zentrieren.
Texteingaben behalten ihre normalen Bearbeitungstasten. Die Seitenleisten sind
auch im kleinen Fenster scrollbar. Ein Ladefehler lässt den geöffneten Entwurf
unangetastet; ein Schreibfehler behält Inhalt und Revision.

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
`save_copy` kopiert den Bauplan mit neuer Design-ID und neuen Modul-UIDs,
leeren Spiegelgruppen und Revision 1. Das Original wird nicht verändert; erst
nach erfolgreichem Schreiben wechselt der Editor zum neuen Pfad.

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
Besitz, physische Übergaben und Flug. Die UI-Bibliothek arbeitet schrittweise:
höchstens 32 Verzeichniseinträge und zwei JSON-Lesevorgänge pro Frame, mit einem
kooperativen Zeitbudget von 3 ms. Ein einzelner Lesevorgang und Speichern bleiben
synchron; das ist keine harte Latenzgarantie. Pro Seite bleiben nur zwölf
Metadateneinträge im Speicher. Suche und Hangarauswahl filtern beim Lesen;
ein Neustart der Suche oder Schließen verwirft den laufenden Cursor.
Seiten werden in Verzeichnisreihenfolge anhand von Offsets gelesen; es gibt
keinen stabil sortierten Index oder Snapshot bei externen Dateiänderungen.
Der bisherige synchrone `list_designs`-API bleibt für bestehende Aufrufer erhalten.
Der im alten ARCH-30-Dokument genannte Writer-Präzisionsmangel ist auf dieser
Basis bereits im gemeinsamen `AtomicJson.stringify` behoben; hier wird kein
Koordinatensave oder neues Präzisionstor eingeführt.

## Gezielte Optimierung

Auswahlwechsel ändern nur Umriss, Detailfelder und Anbauvorschau. Sie bauen
weder den gesamten Schiffsmesh neu auf noch berechnen sie seine Fähigkeiten
erneut. Der Editor hält die Auswertung bis zur nächsten Bauplanänderung vor;
Katalogdefinitionen werden wiederverwendet. Namenseingaben und Speichern ohne
Geometrieänderung lösen ebenfalls keinen vollständigen Mesh-Neuaufbau aus.

Das 3D-Bild liegt in einer `TextureRect` mit eigenem `SubViewport`. Kamera-,
Auswahl-, Vorschau-, Größen- und Modelländerungen fordern `UPDATE_ONCE` an;
im Leerlauf bleibt das letzte Bild erhalten. Die reguläre UI-Verarbeitung und
laufende Bibliothekssuche bleiben aktiv. Vorschauplanung ist begrenzt und
vergibt keine dauerhaften IDs. Der Anfügebefehl prüft die aktuelle Belegung
erneut und übernimmt ein symmetrisches Paar nur vollständig.

Diese Erweiterung ändert weder das Speicherformat noch Modulrevisionen oder
Balancingwerte. Kategorien sind reine Präsentationsdaten.

## Prüfung und Integration

`shipyard_test` ist genau einmal im bestehenden Vertrag `expedition_design`
registriert. Direkte Verbraucher: `expedition_contract_test` und
`modular_assembly_framework_test`. Der neue Test prüft insbesondere fehlerhafte
Eingaben, Modulwirkungen, Verbindung/Größe, gedrehte Hangareignung, Revisionen
nach Undo, Original-/Backupbytes bei Schreibfehlern, neues Godot-Lesen im
separaten Prozess (einschließlich aller neuen Kopie-IDs), echte Editorszene und
Passung der abgeleiteten Fähigkeiten zum vorhandenen Expeditionsvertrag.
Hinzu kommen sechs Anbauseiten, atomare Symmetrie/Undo, veraltete Vorschau,
seitengenaue Bibliothekssuche, echte Schreibfehler beim Speichern vor Wechsel,
ein Auswahl-Probe mit 56 Modulen und tatsächlich erhaltene 3D-Bildpixel im
Leerlauf. Der Probe zählt Mesh-Neuaufbauten und Fähigkeitsauswertungen, keine FPS.

```sh
python3 tools/validate_godot.py --godot /pfad/zu/godot --skip-main \
  --tests shipyard_test expedition_contract_test modular_assembly_framework_test
python3 tools/review_shipyard.py --godot /pfad/zu/godot --output /tmp/shipyard-review
```

Der Grafikrunner benötigt eine Anzeige, etwa Xvfb unter Linux, und nutzt
isolierte Benutzerdaten. Er prüft echte Eingaben und erstellt neun Bilder
der beiden Vorlagen, Hangarprüfung und grünen/roten symmetrischen Vorschau.
Die ursprünglichen Nachweise unter `docs/evidence/arch30-shipyard/` bleiben
historisch. Quellreferenzen, Logs und Bilder des Ausbaus stehen unter
`docs/evidence/arch30-shipyard-expansion/`.

Gemeinsamer Schreibbereich: ausschließlich die zusätzliche Testregistrierung
in `tools/validation/contracts.json`. Keine Änderungen an Kampagne, SaveService,
Kreatureneditor, Übersetzungen, Siedlungslogik oder zentralen Statusseiten.
Die Integration übernimmt den Registry-Eintrag einmal und aktualisiert die
zentralen Projektstände. Kein Merge, Windows-Export oder Ziel-PC-FPS-Nachweis.

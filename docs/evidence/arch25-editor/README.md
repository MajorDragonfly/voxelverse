# Prüfnachweise ARCH-25-EDITOR

Godot **4.6.3.stable.official.7d41c59c4**, Linux, getrennte synthetische Nutzerdaten.
Das Paket wurde auf dem eigenen Branch `agent/arch25-editor-20260915` umgesetzt.
Lars hat die Veröffentlichung als GitHub-Branch mit Entwurfs-PR ausdrücklich
freigegeben. Ein Merge ist nicht Teil dieser Übergabe.

Die Veröffentlichung über die GitHub-App erzeugt neue Commit-IDs. Die Git-Trees
wurden bei der Übertragung auf exakte Übereinstimmung mit den geprüften lokalen
Commits kontrolliert; Quellcode und Nachweise sind unverändert.

| Geprüfter lokaler Commit | Veröffentlichter Commit | Identischer Git-Tree |
|---|---|---|
| `71db7458a53fe8b611b46f05d785f3487e39fed6` | `d926166321642b17fd20a29e405c15fcc8ab89c2` | `cb2fb3ef02a4c6e35c5d4e13d8c4e87e40da8763` |
| `bdc922d14b617e10189b09b55ad6f3e41dc6a874` | `9e3fb7523793b5bfe57380cd46343eea0305c105` | `ad2f3d1587abfc4d2ffb87b57e057c13b9e8d0ae` |

| Quellstand | Prüfungen | Ergebnis |
|---|---|---|
| `71db7458a53fe8b611b46f05d785f3487e39fed6` | Acht ausgewählte Godot-Fachtests; Import, Quellenverträge und Art-Quellen | Bestanden; `headless/results.json` und zugehörige Logs |
| derselbe Stand | 48 Layoutkombinationen, DE/EN, 800×600 / 1280×720 / 1920×1080, 100/150 % Text, vier Modi | Bestanden; 1.146 Prüfungen, 16 erstellte Aufnahmen, fünf repräsentative Bilder unter `matrix/` beigefügt |
| `bdc922d14b617e10189b09b55ad6f3e41dc6a874` | Ausschließlich Umbruch der Transformationsbeschriftung korrigiert und entsprechende Regression ergänzt; Editor-Sprachtest und Teile-Werkstatttest erneut ausgeführt | Bestanden; `layout-final/results.json`, 1.182 Prüfungen im Sprachtest |
| derselbe abschließende Quellstand | Echte Zahlenfelder sichtbar gescrollt: DE/EN, 800×600 bei 150 % und 1920×1080 bei 100 % | Bestanden; vier neue Aufnahmen und Bericht unter `transforms/` |

Die letzte Korrektur verhindert, dass eine zu schmale erste Rasterspalte die Wörter
„Position“/„Drehen“ buchstabenweise untereinander setzt. Der Sprachtest begrenzt
nun auch die resultierende Höhe der Eingabezeilen. Das frühe Sitzungsproblem am
Zahlenfeld war ein Testaufbaufehler: Der Test tippte vor Abschluss der nativen
Fokusverarbeitung. Mit echten Tastenereignissen nach Fokusübernahme besteht die
Prüfung ohne zusätzlichen Eingabepuffer im Produkt.

Während der Entwicklung gefundene Indexfehler bei Entwurfswechsel und ein nach
Editorabbau fortgesetztes Layout wurden korrigiert. Die bestehenden Gelenk-,
Körper-/Sattel- und Vorlagentests bestehen anschließend unverändert. Die
Layoutfortsetzung verwendet eine an die Lebenszeit des Editors gebundene
Signalverbindung.

Die Grafikprüfung verwendet Xvfb und OpenGL-Kompatibilität mit Mesa llvmpipe.
Repräsentative Bilder wurden visuell geprüft; darunter die ursprüngliche
problematische Zahlenansicht sowie die korrigierten DE/EN-Ansichten. Gespeicherte
Modellgeometrie, Namen und IDs wurden durch Übersetzungen nicht verändert.

Der ergänzende Bildtest ist reproduzierbar:

```sh
xvfb-run -s '-screen 0 1920x1080x24' GODOT --path . \
  --rendering-method gl_compatibility --audio-driver Dummy \
  --script res://docs/evidence/arch25-editor/transforms/capture_editor_transform_layout.gd \
  -- --capture /tmp/editor-transform-review
```

Vorher das Ausgabeziel anlegen. Der vorhandene Python-Grafikrunner in `tools/`
führt die vollständige Matrix mit isolierten Nutzerdaten aus; auch bei manueller
Wiederholung einen getrennten Benutzerpfad verwenden.

Die Berichte behalten ihre tatsächlich geprüften Commit-IDs. Der Folgecommit mit
diesen Nachweisen ändert keinen Spielcode. Keine Windows-, gemeinsame Kampagnen-,
Export- oder Ziel-PC-/FPS-Freigabe. Die Grafikprüfung belegt ausdrücklich die
Textskalierung; sie ersetzt keine Abnahme sämtlicher Betriebssystem-DPI-Einstellungen.

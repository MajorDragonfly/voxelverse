# ARCH-25-EDITOR: Kreaturenwerkstatt DE/EN und nutzbare kleine Layouts

Die aktive Kreaturenwerkstatt mischt bislang Deutsch und Englisch. Bei kleinen
Fenstern beanspruchen die Seitenleisten fast die gesamte Arbeitsfläche; lange
Texte und Rückmeldungen passen nicht zuverlässig in die vorhandenen Bereiche.

Dieses Paket stellt Grundbedienung, Teilkarten, Farbe/Hauttyp, Gelenke,
Sattel/Geschirr und Bewegungstests auf den vorhandenen Sprachdienst um. 354
Nachrichten decken unter anderem die Namen und Beschreibungen von 53 Teilen ab.
Sprachwechsel erhalten laufenden Entwurf, Auswahl, Fokus, Undo/Redo, Sitzvorschläge
und Prüfungen. Gespeicherte Fachrückmeldungen werden erneut dargestellt, ohne
Befehle, Prüfungen oder Speicheraktionen zu wiederholen.

Die vollständigen Seitenleisten scrollen. In schmalen Fenstern wechselt eine
Schaltfläche zwischen Palette und Eigenschaften; Modusreiter, Speichern/Laden
und Weltzugang bleiben erreichbar. Teilnamen umbrechen, das Zahlenraster behält
lesbare Zeilen und die Kamera berücksichtigt die verbleibende Arbeitsfläche.

**Nachweise:** Acht Fachtests sowie Import und Quellgates bestanden auf `71db745`.
Die abschließende Umbruchkorrektur auf `bdc922d` ist zusätzlich mit zwei Fachtests
(Sprachtest: 1.182 Prüfungen) und vier gezielten Grafikaufnahmen geprüft.
Die umfassende Grafikmatrix hat zuvor 48 Kombinationen und 16 Aufnahmen bestanden;
alle Läufe verwenden Godot 4.6.3 und getrennte Nutzerdaten. Renderer:
OpenGL-Kompatibilität/Mesa llvmpipe, kein Windows-/Ziel-PC-Nachweis.

Basis: `d378ca0ecd7f03429a5150df6358e0646ec06689`. Abschließender Quelltree:
`ad2f3d1587abfc4d2ffb87b57e057c13b9e8d0ae`.

[Übergabe](WORK_ARCH25_EDITOR.md) · [genaue Prüfrevisionen, Logs und Bilder](evidence/arch25-editor/README.md)

ARCH-26 wurde nicht bearbeitet. Änderungen betreffen die aktive Editorvererbung,
Teilkarte, einen Darstellungshelfer, Sprachkatalog/PO-Dateien und Fachprüfungen.
Bei Integration die Rüsselerweiterungen aus #96 erhalten und deren neue Texte
anschließen; Katalogergänzungen aus #95/#97 zusammenführen und PO-Dateien erneut
generieren. Der neue Sprachtest ist einmal unter `frontend_locale` registriert.
Zentrale Statusseiten und gemeinsame Kampagnen-/Exportabnahme bleiben bei der
Integration. Keine Änderungen an Saveformaten, kanonischen Körperdaten oder
Spielregeln. Unbekannte technische Kompatibilitätsdiagnosen und native
Farbwahldialoge behalten ihre bestehende Darstellung.

Lars hat den Push zu `MajorDragonfly/voxelverse` und den anschließenden
Entwurfs-PR ausdrücklich freigegeben. Kein Merge vorgesehen.

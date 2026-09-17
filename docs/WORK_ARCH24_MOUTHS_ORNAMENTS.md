# ARCH-24: Mundüberarbeitung, Geweihe und Kämme

Nutzerauftrag vom 16.09.2026: nächste Pakete umsetzen, Münder überarbeiten;
Hände und Füße gefallen und sollen ihre Gestaltung behalten.

Drei abgegrenzte Lieferungen auf gemeinsamem Branch:
`ARCH-24-MOUTH-REFRESH`, `ARCH-24-ANTLER-FAMILIES`, `ARCH-24-CREST-FAMILIES`.
Basis: `176d088d34324de14952bc7506fe9763a22cf4b0` auf main nach #144.
Branch: `agent/arch24-mouths-antlers-crests-20260916`.
Die bestehende ARCH-24-Zuordnung in Issue #137 bleibt maßgeblich.

## Mundüberarbeitung

Zehn vorhandene Mundformen erhalten ausdrücklich Modellrevision 2:
Weidermund, breiter Schnabel, Raubkiefer, Filterschnauze, Hunde-, Krokodil-,
Katzen-, Bären- und Schweineschnauze sowie Oktopusmund. Zwei zusammenhängende
Voxeloberflächen ersetzen die überlappenden Einzelkörper der aktuellen Form.
Ober- und Unterkiefer haben einen echten freien Mundspalt, dunkle Innenflächen,
modellabhängige Nasen und fest im Oberkiefer sitzende Zähne. Der Oktopus besitzt
einen zusammenhängenden Mundring und innenliegenden Hakenschnabel. Die
Unterkiefer bewegen sich über den vorhandenen Mundkanal beim Fressen/Beißen;
der Oberkiefer bleibt am Körper. Meshes werden dafür nicht neu aufgebaut.

Neue V7-Entwürfe und neu im Editor angebaute Mundteile wählen Revision 2.
Die Teilevorschau im Buch zeigt dieselbe aktuelle Geometrie. Gespeicherte und
implizite alte Referenzen bleiben Revision 1 mit ihrer bisherigen Geometrie.
Im Editor: vorhandenen Mund auswählen → **Neue Mundform übernehmen**.
Die Übernahme verändert die Modellrevision, erhält ID, UID, Anker, Drehung,
Größe, Form und Werte und lässt sich rückgängig machen und wiederholen.
Eine globale automatische Umformung gespeicherter Kreaturen findet nicht statt.

Der Revisionsresolver akzeptiert 2 nur für diese zehn Mund-IDs. Körper-,
Katalog-, Endstück- und Rüsselrevision bleiben bei 1. Das bestehende
Vorlagenformat erlaubt Mundrevision 2 über dieselbe strikte ID-Prüfung.
Zukünftige Revisionen werden vor Speichern/Export/Übernahme abgewiesen;
Entwurfsdateien, Kampagnenoriginal und Backups bleiben geschützt. Die
empfangende eigene Spezies behält beim Vorlagenimport ihre Identität.

## Geweihe und Kämme

| ID | Editor-Kategorie | Neue Form | Vorhandenes Werte-/Freischaltprofil |
|---|---|---|---|
| `horns_stag_antlers` | Hörner | Verzweigte Stange mit mehreren Sprossen | `horns_antlers` |
| `horns_moose_antlers` | Hörner | Breite Schaufel mit vier Randspitzen | `horns_antlers` |
| `decor_low_crest` | Verzierungen | Flacher durchgehender Rückenkamm | `decor_feathers` |
| `decor_saw_crest` | Verzierungen | Hoher gezackter Rückenkamm | `decor_feathers` |
| `decor_head_crest` | Verzierungen | Kleiner Kopfkamm | `decor_feathers` |
| `decor_frill` | Verzierungen | Breiter Nackenschild | `decor_feathers` |

Geweihe starten paarweise, Kämme und Nackenschild auf der Mittelachse.
Einzel-/Paar-/Mittelplatzierung und XYZ-/Drehregler bleiben verfügbar.
Kopfkamm und Nackenschild erhalten passende vordere beziehungsweise hinter
dem Kopf liegende Standardanker. Der gemeinsame Anbieter liefert jeweils
ein zusammenhängendes Voxelmesh je Seite, einschließlich des Hautsockels.
Die sechs Teile nutzen Revision 1 und sind in Werkstatt, Entdeckungsbuch,
Freischaltungen, Suche und Offline-Vorlagen angeschlossen. DE/EN-Namen und
Beschreibungen sind enthalten; bestehende Werte und Freischaltquellen gelten.
Sie bringen keine neuen Fähigkeiten oder eigenen Bewegungsbesitzer mit.

## Erhaltene Anschlüsse und Grenzen

Hand- und Fußkataloge, deren Geometrieanbieter sowie bestehende Gliedmaßen-
und Endstückdarstellung bleiben unverändert. Historische Mundmodelle bleiben
im bisherigen Anbieter erhalten. Der deterministische V7-Generator hält seine
bisherigen Auswahlmengen für Hörner und Verzierungen fest, ebenso die bisherigen
Münder und Schwänze. Die festgehaltenen Altarten bleiben unverändert. Eine
neue prozedurale Verteilung der hinzugefügten Teile ist Folgearbeit.

Die Geometrieanbieter prüfen den erlaubten XYZ-Bereich 0,4–2,5 und endliche Werte.
Ein konservatives Volumenbudget begrenzt den Aufwand auch bei extremen Formen;
die Detailstufe normaler Modelle bleibt dabei gleich. Ihre Caches sind begrenzt: 32 Mundvarianten (je zwei Meshes), 24 Geweih-/Kamm-
varianten (je ein Mesh). Freie Formen und Drehungen können weiterhin manuelle
Platzierung benötigen. Das alte Blockfeld der neuen Verzierungen beschreibt
die konservative Ausdehnung; aktive Verbraucher verwenden den detaillierten
Geometriepfad.

Die vorherigen lokalen Horn-, Fuß-, Schnabel-, Panzer-, Ohr- und Fühlerpakete
sind keine versteckten Abhängigkeiten dieser Lieferung. Insbesondere werden
Hände und Füße hier nicht durch eine neue Variante ersetzt.

## Prüfung und Übergabe

[Prüfprotokolle, exakte Quellstände und Modellansichten](evidence/arch24-mouths-ornaments/README.md).
Zwei neue Familientests stehen einmal in `creature_body`. Die passenden direkten
Verbraucher prüfen historische Geometrie/Arten, neue Modellrevision, Editor-
Übernahme mit Undo/Redo, Symmetrie, Körperkontakt, Kieferbewegung, tatsächliches
Speichern, fehlerhafte Zukunftsstände, Offline-Vorlagen und frische Prozesse.
Die Bilder sind CPU-Ansichten tatsächlicher Godot-Meshes; keine native Grafik-
oder Ziel-PC-Leistungsabnahme. Windows-Spieltest und gemeinsame Integration
brauchen den entsprechend geprüften Build.

Gemeinsame Schreibbereiche: Teilekatalog und Geometrieverteilung, Mundrevisionen,
Anker, neue Standardmundwahl, Editor-Übernahme, Buchvorschau, Vorlagenschema,
Variantenfreischaltung, V7-Auswahlpools, dreizehn Sprachschlüssel samt PO-Dateien,
direkte Prüfkonsumenten und zwei Testregistrierungen. Gegenüber dieser Basis
steigt der platzierbare Katalog von 40 auf 46; Endstücke bleiben elf.
Bei Zusammenführung mit früheren ARCH-24-Paketen additive Anbieter/Listen und
Zähler zusammenführen, PO-Dateien aus dem gemeinsamen Katalog neu erzeugen.
Die parallel überarbeitete Vorschaukamera bleibt beim dortigen Fachchat; hier
ändert sich nur die explizite aktuelle Mundrevision im Teilvorschauaufruf.
Zentrale Statusdaten und Dashboard bleiben beim Integrationsbesitzer.

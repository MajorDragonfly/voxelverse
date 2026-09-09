# Zielmaßstab: reale Planetengrößen und eine Galaxie

9. September 2026 · Anforderung von Lars · **Anforderungsstand vor M1b.**

**Fortschritt:** Der [M1b-Referenzbetrieb](REAL_SCALE_PLANETS.md) setzt die Größenprüfung inzwischen bis 12.742 km Durchmesser um. Die folgende Bestandsanalyse dokumentiert den Ausgangspunkt `94b4dd3`; Galaxiekatalog und Galaxiereisen bleiben kommende Arbeit. Die Architektur- und Abnahmeanforderungen gelten weiter.

Lars stellt klar: Die späteren Planeten sollen Originalgrößen besitzen; die Weltraumphase soll eine ganze Galaxie mit bereisbaren Sternsystemen darstellen. Die bisher in der Roadmap vorgeschlagenen komprimierten Spielgrößen werden als Produktionsziel ersetzt. Die Körper mit 1–8 km Durchmesser bleiben schnelle Testfälle. Sie belegen weder erdgroßes Gelände noch eine funktionierende Galaxie.

## Warum kleine Testkörper bleiben

Auf einem kleinen Körper lassen sich Polregionen, Würfelflächenkanten, Umrundung und Orbitwechsel in einem kurzen Prüflauf erreichen. Dieselben Fehler müssten auf einem großen Planeten mit gezielten Platzierungen und längeren Fahrten gesucht werden. Beide Prüfarten werden gebraucht: kleine Körper für schnelle wiederholbare Fehlerkontrolle, große Körper für Auflösung, Genauigkeit, Gelände und Leistung im Zielmaßstab.

## Ausgangspunkt vor M1b

| Bereich | Im aktuellen Code nachgewiesen | Offene Arbeit für den Zielmaßstab |
|---|---|---|
| Ortsgenauigkeit | Körperbezogene Kugeladressen; globale Komponenten als skalare Double-Werte; Abzug eines lokalen Ursprungs vor Übergabe an die Physik. Rechenproben bei 6.371.000 m Radius. | Vollständiger Pfad durch Geländeabfragen, Normalen, Kamera, Wasser, Kollision und Speicherung auf dem großen Körper. Der Koordinatentest allein beweist diesen Pfad nicht. |
| Begehbares Gelände | Vier adaptive Testkörper bis 8,192 km Durchmesser; Voxelstufen, Kollision und begrenzte Kachelzahlen. | Beibehalten der Meterauflösung und geschlossenen Nähte bis zum erdgroßen Referenzkörper. |
| Geländequelle | Gemeinsames Höhenfeld für Oberfläche und Orbit. | Kontinente, Gebirge, Klima und Gewässer in passenden räumlichen Größenordnungen; präzise lokale Details bei großen Radien. |
| Sternsystem | Vorgegebene Labor-Körper, Kreisbahnen, ein oder zwei Sterne, Orbit- und Systemansicht. | Astronomische Koordinaten und körperabhängige Größenprofile; begrenztes Laden und Entladen besuchter Systeme. |
| Galaxie | Allgemeine Universum-/Systemhierarchie im bisherigen Konzept. | Sektoradressen, reproduzierbarer Sternsystemkatalog, Galaxiedarstellung, Auswahl/Reise und dauerhafte Wiederbesuche. |

Ein konkretes Hindernis steht in `planet_tile_layout.gd`: Die Unterteilung ist derzeit auf Stufe 16 begrenzt. Der erdgroße Referenzkörper benötigt für die angestrebten etwa 32 m breiten Kacheln rechnerisch Stufe 19. Bei Stufe 16 beträgt die Zellenbreite im Würfelraum rund 12 m; damit greift auch der aktuelle Voxelpfad für Zellen bis 8 m nicht mehr. Die tatsächlichen Abstände variieren durch die Kugelprojektion. Einfach nur den Radius zu erhöhen erfüllt die Anforderung deshalb nicht.

Weitere Prüfstellen sind die `Vector3`-Abfragen in `planet_surface.gd` und die Systempositionen in `celestial_system.gd`. Die hochpräzise Oberflächenadresse beseitigt mögliche Präzisionsverluste in nachfolgenden Abfragen nicht automatisch. Auch die Geländeparameter sind bisher auf das Labor abgestimmt.

## Verbindliche Architektur für den weiteren Ausbau

Die geplante Adresse lautet Universum → Galaxie → Sektor → Sternsystem → Himmelskörper → Oberflächenregion → lokales Objekt. Galaxie- und Sektorpositionen erhalten stabile, versionierte Adressen; lokale Darstellung und Physik rechnen in einem begrenzten Bezugssystem. Sektorindizes und präzise lokale Versätze müssen erhalten bleiben, bevor Werte in Renderkoordinaten umgerechnet werden.

Ein versionierter Galaxie-Seed und eine stabile Adresse bestimmen die unveränderten Ausgangsdaten eines Systems. Ein angefragter Sektor muss unabhängig von Besuchsreihenfolge und Zahl bereits geladener Systeme wieder dieselben IDs und Körper liefern. Entdeckungen, Spielerbauten, Kolonien und andere Veränderungen werden zusätzlich gespeichert. Unbesuchte Systeme brauchen keine fertig erzeugten Voxeloberflächen im Speicher. Der vorhandene Seedkatalog der Hauptwelt bleibt bis zu einer ausdrücklich entwickelten Migration kompatibel.

Die Galaxieansicht verwendet Sterne, Gruppen oder Dichteübersichten entsprechend ihrer Bildschirmgröße. Die Systemansicht zeigt Himmelskörper und Bahnen; die Bodenansicht lädt präzises Gelände und nahe Objekte. Alle Ansichten beziehen sich auf dieselben IDs, Radien und Positionen. Sichtbare Details und aktive Simulation bleiben begrenzt. Entfernte bewohnte Regionen erhalten zusammengefasste Zustände und begrenzte Fortschreibung.

Reale Körpergrößen und astronomische Adressen sind das Ziel. Reisegeschwindigkeit, Zeitsprünge und die Gestaltung der Galaxiekarte werden als eigene Spielregeln festgelegt. Eine verkleinerte Kartenansicht ändert den gespeicherten Körperradius nicht. Konkrete Galaxieausdehnung, Systemzahl, Dichte und obere Größen je Körperklasse sind noch festzulegen; die heutige Labor-Konfiguration setzt dafür keine Produktionsgrenze.

## Nächste Arbeitspakete und Abnahme

1. **M1b – große Planeten tatsächlich betreiben.** Referenzkörper mit etwa 100 km, 1.000 km und rund 12.700 km Durchmesser prüfen. Detailauflösung, Terrainabfragen und Koordinaten durchgängig ertüchtigen. Auf dem erdgroßen Körper reale Lauf-/Kollisionsproben, Pol-/Kantenplatzierungen, Wasser, Ursprungswechsel, Orbit/Rückkehr und Sichern/Laden ausführen. Messungen erfassen Speicher, aktive Kacheln, Ladezeiten und Framezeiten. Das bestehende begrenzte Laden bleibt Anforderung; ein unbemerkter Verlust der Nahauflösung zählt als Fehler. Die endgültige obere Größe weiterer Körperklassen bekommt eigene Referenzen.
2. **M1c – Galaxieadressen und Systemkatalog vor weiterer Raumfahrtintegration.** Versionierte Sektor-/System-IDs und reproduzierbare Abfragen bauen. Einen Katalog über weit auseinanderliegende Sektoren abfragen; Reihenfolge, Wiederbesuche, Speichern/Laden und begrenzte Caches prüfen. Ein Datenkatalog ist noch keine spielbare Weltraumphase.
3. **M9 – Galaxie bereisbar darstellen.** Zoomfähige Galaxieansicht, Systemauswahl, Reisen und die bereits geplanten Landungs-/Kolonieabläufe verbinden. Mindestens mehrere Systeme in verschiedenen Sektoren besuchen, dort Änderungen vornehmen und nach erneutem Programmstart zuverlässig zurückkehren. Anschließend Leistung und Inhalte schrittweise bis zum vereinbarten Galaxieumfang prüfen.

M1b und M1c sind die nächsten Arbeiten dieses Planeten-/Weltraumzweigs. Das parallele Sozialsystem und die Kreaturenarbeit können an ihren vorhandenen Verträgen weiterarbeiten. Der große Maßstab muss vor Übernahme globaler Siedlungen und Kampagnenorte praktisch belegt werden; seine erste Prüfung wird nicht bis M9 verschoben.

Codebezug: `94b4dd3`, dokumentiert in [Unterwasseransicht und Voxelplaneten](UNDERWATER_VOXEL_PLANETS.md). Diese Anforderungsänderung verändert den vorhandenen Test-Build nicht.

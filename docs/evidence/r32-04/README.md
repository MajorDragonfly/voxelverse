# R32-04 · Stammeskamera und Trinkkontext

Feste Basis: `2a738a4891a8de11d682c469833ade4dc9b01dfb`, Tree
`f2bda4f815df1c73b9d740ca5282917523faf618`. Auftrag #179/#210;
Zuordnung ausschließlich in #137. #189 bleibt geschützt und unverändert.

## Belegter Bildrandfehler und Korrektur

Die Stammkamera prüfte ihre Near-Plane nur bei `low_view > 0.01`.
Bei 25° beginnt jedoch die orthografische Projektion, deren großes unteres
Bildfenster trotz freiem Kamerapunkt unter das Gelände geraten kann.
Die Seed-15838-Geometrieprobe reproduziert dies bis −14,541 m.
Bei identischen Positionen/Zooms bleibt nach der Korrektur die schlechteste
Near-Plane-Freigabe bei +1,655 m. Die Körperhöhe/Quelle wird tatsächlich
vom bestehenden Kugelsampler gelesen; die Publikation und leere Physikwelt
dieser isolierten Geometrieprobe sind ausdrücklich Fixtures.

Der enge Produktfix prüft beide Projektionen und alle neun Punkte des
Near-Plane-Rasters einschließlich exakter Bildränder. Er verändert weder
Steuerungsverzögerung noch Fokus, Spieler-/Gebäudekollisionen, Masken,
Erkundung, Arbeitsradius oder Streamingbudgets.

Die ursprüngliche Welttestgrenze `abs(forward · up) < 0.15` ist wiederhergestellt.
`<0.55` erlaubt bis ca. 33,37° und genügt nicht für den verlangten nahezu
horizontalen Blick. Die isolierte reale Oberflächenprobe erreicht bei 3°
Anforderung und Nahzoom 3,0–5,204°. Dies allein ersetzt noch keine reale
Kampagnenansicht. Der Welttest prüft jetzt echte Near-Plane-Punkte mit
`project_position`, denn `project_ray_origin` liefert im Perspektivmodus
nur das Auge. Die 24°/25°/26°-Grenze wird über alle drei Zoomstufen geprüft.

## Fokussierte Prüfungen

Godot `4.6.3.stable.official.7d41c59c4`, Linux-Workhost `db514e109ac6`.
`focused-controls/results.json` enthält Originalbefehle, Engine, Quellen,
Loghashes sowie Start-/Endmanifeste; alle dort aufgeführten Prüfungen positiv.

- Bestehende InputPreferences, Kameraeinstellungen und Minimap auf der Basis.
- Erweiterte Kameraeinstellungen: Migration alter Pfeilprofile; Z/X-Rebinding
  mit erhaltenen Pfeilen, entferntem Q/E-Turn und unveränderten Q/E-Kreaturaktionen;
  Konfliktablehnung; tatsächlicher frischer Godot-Prozess mit gespeicherten
  Bindungen, Geschwindigkeit, 3°-Neigung und FPS-Einstellung.
- Kamera-Fixture: Q/E, Kamerarichtung, Schnellmodus, Zoominterpolation,
  UI-Klickschutz, Pause/Fokusverlust, Bewohner-/Vorrats-/Save-Invarianz.
- Bereits vorhandene Stationärkollisionsprobe: neuer physischer Gebäudecollider
  bewegt das Auge um 7,15 m; Entfernen stellt den Blick wieder her;
  perspektivische Bewohnerauswahl/Minimap bestehen.
- Trinkprobe mit echten Wasser-/Spieler-/HUD-Modulen und realem Kugelsampler:
  erreichbares Süßwasser, physischer Reichweitenrand, unerreichbares Wasser,
  fehlende Publikation, trockener Boden/Salzwasser sowie Schwimm-Primary-Action.
  Publikation und Untergrund dieser Probe sind Fixtures, kein regulärer Weltbeleg.

Alle vorhandenen Assertions/Deadlines bleiben erhalten; keine neue Testregistry
und kein gemeinsamer Controller werden im Fachbranch geändert.
Die vorhandenen Tests werden weiterhin genau einmal zentral registriert.

## Noch ausstehend

Regulärer Kugel-Welttest und identische 1080p-Vorher-/Nachher-Captures warten
auf den seriellen Hostslot von R32-02. Jeder folgende Godot-Lauf hält
`/tmp/voxelverse-r32-db514e109ac6-heavy.lock`. Frühe leichte Tests können
mit dem Messanlauf überlappt haben; kein isolierter Leistungsnachweis.

Sicht-/Spielkomfort, Ziel-PC, native Exporte und volle R32-Pflichtgates sind
nicht abgenommen. #179/#210 und #189 werden hier nicht geschlossen.
Das endgültige geprüfte Commit/Tree und die tatsächlichen noch folgenden
Weltbelege werden vor der fachlichen Übergabe ergänzt.

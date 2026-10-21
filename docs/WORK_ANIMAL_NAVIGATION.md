# NAV-02-LIVING-TARGETS: eigene Tiere wiederfinden

Basis: `bc024eb182b178d0dac873141a13a420e534d3a9` auf main.
Branch: `agent/nav02-living-targets-20261021`. Vergabe und Übergabe in #137.

## Bedienung

In der Weltkarte öffnet **Eigene Tiere** die Liste der lebenden, gezähmten eigenen
Individuen auf dem aktuellen Himmelskörper. Eine Zeile oder ein Tiermarker wählt
das Tier aus und zentriert die Karte. **Als Ziel verfolgen** ersetzt das bisherige
Ziel. Auf der Minimap folgen Richtung und Entfernung dem geladenen Tier. Ein
Klick auf die Zielzeile öffnet die Tierverwaltung. Escape führt aus der Liste
zur Karte und schließt sie beim zweiten Druck. **Verfolgung beenden** erhält
alle eigenen Wegpunkte und ändert keinen Tierauftrag.

**Aktuelle Position** stammt vom geladenen D2-Actor, auch bei 0× Geschwindigkeit.
Ohne geladenen Actor ist nur der gespeicherte **letzte bekannte Standort** bekannt.
Er wird ausdrücklich so bezeichnet und löst keine Ankunftsmeldung aus. Tod,
fehlender Datensatz oder Verlust des eigenen Besitzes entfernt Richtung und
Entfernung. Die Zielzeile erklärt den Ausfall und lässt das Beenden weiterhin zu.

## Daten und Lebenszyklus

`OwnedAnimalMarkers.collect()` bleibt die einzige Kartenprojektion des bestehenden
D2-Registers. Sie ergänzt nur `own` und `live` in ihren Lesekopien. Keine neue
Tierhaltung, kein Scan der Wildpopulation, keine Kopie beweglicher Positionen
im Navigationsstand und keine Geländeaufdeckung. Es gelten weiter maximal sechs
eigene D2-Tiere. Körper-ID, gültige Oberflächenadresse, Besitzer, Zähmstatus und
Gesundheit begrenzen die sichtbare Liste. Kartenfilter verändern keinen Besitz.

`map_navigation` Version 2 erlaubt zusätzlich den Zieltyp `owned_animal` und
speichert ausschließlich dessen stabile ID. Version 1 bleibt unverändert lesbar.
Erst eine erfolgreiche Änderung hebt einen alten Datensatz auf Version 2.
Abgewiesene Schreibvorgänge stellen den vorherigen Datensatz einschließlich
Version, Ziel und Wegpunkten wieder her. Unbekannte Versionen bleiben über den
gemeinsamen Speicherteilnehmer geschützt. Alte Programmstände lehnen Version 2
ab, statt die neue Zielart still zu verlieren.

Die realen UI-Tests reproduzierten einen bestehenden Anschlussfehler: Die
Stammeskarte verlor beim Speichern in Pause ihre Quellen, weil `is_active()`
absichtlich nur laufende Simulation bestätigt. `has_loaded_village()` benennt
jetzt den engeren lesenden Bereitschaftsvertrag. Beide Kartenquellen und der
Kugelsnapshot verwenden ihn. Simulations- und Befehlsgates bleiben bei `is_active()`.
Eine pausierte Karte behält somit tatsächliche Bewohner und verändert weder
Erkundung noch Zielentfernung durch den freien Kamerafokus.

## Prüfung

Der bestehende `navigation_state_test` prüft zusätzlich alte Navigation,
JSON-Rundlauf, zukünftige Versionen, bewegte Ziele, 0×, Tod, Ausladen, fremde IDs
und Großkreisentfernung über Würfelflächen. Neue Tests werden nicht doppelt registriert.

`domestication_campaign_test` prüft die Funktion nach seiner tatsächlichen
D1-Zähmung: reale Mausbedienung mit Hover-/Scrollprüfung, Version-1-Rollback und
zwölf Kombinationen (800×600, 1280×720 und 1920×1080, je DE/EN und 100/150 %).
Auswahl, Abbruch, Fokus, unveränderte Erkundung, echter Tier-Folgeweg,
Kopie, frischer Prozess und tatsächlich gespeicherter Tod bleiben in derselben
Kampagnenroute. Die UI-Matrix und Versionsfälle erweitern bestehende Assertions.

Grafische Wiederholung mit zwölf Originalbildern und Quellenmanifest:

```sh
xvfb-run -a -s '-screen 0 1920x1080x24' python3 tools/review_animal_navigation.py --godot GODOT_4_6_3 --output OUTPUT
```

Der bestehende native Feature-Workflow führt diese Route als eigenes
`animal-navigation`-Feld aus. Der Lauf ist eine begrenzte planare Kampagnenfixture
mit produktiver D2-Simulation und produktiver Kartenoberfläche. Die bestehende
`navigation_world_test`-Route prüft zusätzlich den öffentlichen Kugelstart und
echte A-B-A-Reise für Navigation. Ein physischer Tiertransport zwischen Planeten
ist kein neuer Bestandteil. Vollsuite, Exporte, vier aktuelle Pflichtgates und
Lars' Hardware-/Spielkomfortabnahme werden getrennt ausgewiesen.

Der zusätzlich ausgelöste D1-Neustartgate reproduzierte auch auf der unveränderten
Basis einen vorhandenen Prüfvergleichsfehler. Die Erwartungsdaten benutzten den
normalen Godot-JSON-Parser, der Speicherleser dagegen die bestehende exakte
Zahlenrekonstruktion. Bei zwei Katalogen unterschieden sich einzelne letzte
Dezimalstellen, einschließlich gespeicherter Routen. Der D1-Prüfhelfer erzeugt
seine Erwartungsdaten jetzt mit `AtomicJson.parse_dictionary`, einschließlich der
bestehenden Ausnahme für eingefrorene Anatomie. Die Inhalts-/Migrationsvergleiche,
Zukunftsschutzfälle und Grenzen bleiben unverändert. Produktionsparser, Generator,
Tierkörper und Nutzerdaten werden dafür nicht geändert. D1.1 bleibt unverändert.
Der Kugel-D1.2-Wiederanlaufvergleich verwendete ebenfalls den normalen Parser
gegen eine mit `AtomicJson` gelesene Referenzdatei. Beide Seiten dieses exakten
Vergleichs verwenden jetzt denselben Produktionsparser. Katalog, Lebensräume,
Identitäten, Suchcursor, acht Zukunftsschutzfälle und native Körperprüfungen
behalten ihre bisherigen Assertions und Grenzen.

Ein zweiter nativer Lauf erreichte beim bisherigen Warten auf 25 gerenderte
Bilder bereits das reguläre Ende der zweisekündigen Fütterung. Der Prüfer
beobachtet diesen tatsächlichen Zwischenstand jetzt innerhalb derselben
25-Bilder-Grenze, statt die volle Anzahl abzuwarten. Zusätzlich muss der
gespeicherte Fortschritt strikt zwischen null und zwei Sekunden liegen. Der
Mauspfad, Speichern/Laden, alle bisherigen Assertions und die echte weitere
Zähmung bleiben erhalten. Die Fortschrittszeit steht im Originalprotokoll.

# WEATHER-02B – gespeicherte Planetenklimata und geschützte Heimat

Basis: `d57b1ef385728728b132518a1ea05683888dcae0`, Spieltest-PR #125.
Branch: `agent/weather02-planet-climates-20260916`.
Atmosphere Detail bleibt beim parallelen Fachchat. Keine Änderungen an dessen
Environment-, Shader-, Grafikregler- oder Lokalisierungsdateien.

## Verhalten

Neue Kampagnen erfassen die Herkunft beim ersten erfolgreich angelegten Körper.
`campaign.weather_policy` (Schema 1) enthält die stabile Herkunfts-ID, den Status
`known` und die geschützte Körper-ID. Die Vorbereitung einer fehlgeschlagenen
Körperanlage verändert diese Kennung nicht. Aktiver Planet, Planetennummer,
Listenreihenfolge und später errichtete Heimatplätze können sie nicht versetzen.

Jeder Körper besitzt `weather_climate` (Schema 1): Körper-ID, Profil-ID, Revision
und `home_protected`. Neue Reiseziele erhalten ihre feste Revision-1-Auswahl aus
Körper-ID und Seed; sie wird gespeichert und beim Laden nicht neu berechnet.
Die Auswahl ist unabhängig von Besuchsreihenfolge und globalem Zufallsgenerator.

| Profil | Wirkung auf das bestehende regionale Wetter |
|---|---|
| `earth_temperate` | Unveränderte milde Fronten; regionale Feuchte und Kälte bestimmen Regen/Schnee. |
| `arid` | Wärmere, deutlich trockenere Wetterwerte; weniger Wolken und Niederschlag. |
| `frozen` | Kalte Wetterwerte; vorhandener Niederschlag fällt als Schnee. |
| `volcanic` | Heißes, trockenes Basisprofil ohne Wasserniederschlag. Noch keine Asche oder Feuerstürme. |
| `airless` | Keine Wetterwolken, kein Regen/Schnee, kein Wind; auch nicht in Vorschau oder Prognose. |

Alle gelieferten Basisprofile bleiben ohne Wetterschaden. Die reservierten
`*_extreme`-Profile bleiben nicht implementiert und werden weiterhin abgewiesen.
Das Paket verändert Wetter und den Atmosphärenhinweis des Körperdeskriptors,
nicht Terrainform, Biome, Flora, Fauna, Atemluftmechanik oder Planetenfarbe.
Vollständig zusammenpassende Extremwelt-Biosphären und ihre Inszenierung sind
weitere Arbeit. Die Heimat erhält immer `earth_temperate`; der Validator lehnt
ein abweichendes Profil oder fehlende Schutzreferenzen ab.

## Bestehende Spielstände

Historische Stände belegen keinen Herkunftsplaneten. Ihre Herkunft bleibt daher
`legacy_unknown` mit leerer Herkunfts-ID; alle bereits vorhandenen Körper werden
mild geschützt. Kein Raten anhand des aktuellen Planeten oder erster Einträge.
Erst künftig neu angelegte Reiseziele erhalten die übrigen Basisprofile.

Die additive Übernahme erfolgt in einer Kopie über den vorhandenen Registerimport;
Laden/Inspektion schreiben die Quelldatei nicht um. Alte Saves vor der Einführung
der Kampagne verwenden dieselbe konservative Regel. Slotkopien behalten die
Körper- und Herkunftsreferenzen trotz neuer Kampagnen-ID. Die Flachwelt-Kugelkopie
übernimmt die ortsunabhängigen Klimareferenzen ausdrücklich und unverändert.

Die Körpererweiterung ist bei `SaveParticipants` registriert; die Politik wird
über dessen GameState-Teilnehmer geschützt. Unbekannte Politikversionen,
Herkunftsmodi, Profilnamen oder Profilrevisionen blockieren Laden und Schreiben
vor einem Rückgriff auf `.bak`. Ungültige Körperbindungen und verletzter
Heimatschutz werden validiert; es gibt keine stille Neugenerierung.

## Laufzeitanschluss und Integration

`Surface.descriptor()` reicht die Klimareferenz und `atmosphere` weiter.
`CampaignWeather` kombiniert die gespeicherte Referenz mit örtlichen
Temperatur-/Feuchteproben. Snapshot und Prognose verwenden dasselbe Profil.
Neu sind `climate_revision` und `home_protected`; `climate_id` kann nun alle fünf
Basisprofile enthalten. Unbekannte Referenzen liefern einen leeren Snapshot.
Verbraucher müssen diesen schon bestehenden Lade-/Fehlerfall weiter tolerieren.

Wetterfronten, Böen und Prognosen bleiben reine Ableitungen aus dem vorhandenen
`campaign.elapsed_seconds`. Keine zweite Wetteruhr, Echtzeitfortschreibung,
zusätzliche Wetterdatei oder neue Partikel-/Nodebudgets. Körperfeste Fronten und
Cube-Nahtstetigkeit bleiben erhalten.

Gemeinsame Anschlüsse: BodyRegistry, CampaignState, SurfaceContext,
SaveParticipants, der alte Save-1/2-Adapter und die Migrations-Whitelist.
Test `planet_climate_test` genau einmal unter `weather` registrieren; der
bestehende `weather_runtime_test` enthält zusätzlich echte A–B–A-Klimareisen.
Zentrale Status-/Roadmapeinträge bleiben beim Integrationschat.

Atmosphären-Handoff: Wetter liefert auf `airless` null Wolken/Niederschlag/Wind
und `atmosphere_present=false`; der Descriptor liefert `atmosphere=none`.
Die bestehende Himmels-/Nebelkomposition verwendet diesen Atmosphärenstatus noch
nicht vollständig. Ihre Vakuumdarstellung gehört zum Atmosphärenbesitzer und
wird hier nicht als bereits fertig behauptet.

## Prüfung

Nachweise und ursprüngliche Entwicklungsbefunde stehen unter
`docs/evidence/weather02-planet-climates/README.md`. Gezielte Prüfung mit Godot
4.6.3, Linux/headless und isolierten synthetischen Nutzerdaten. Keine native
Windows-, Grafik-, Vollintegrations- oder Ziel-PC-FPS-Freigabe.

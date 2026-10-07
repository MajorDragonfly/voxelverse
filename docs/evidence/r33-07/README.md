# R33-07: erster regulärer Sandsturm

Feste Produktbasis: `94de70cacd250337976b8f63031fff4afc72e2bb`, Tree
`58506a6feba11be547197223fa319e7265cf4d99`. Fachbranch:
`agent/r33-07-extreme-weather`. Bezug: #137 (R33-Zuordnung), #205 und #263.
Der reguläre schadensfreie Regensturm der Basis bleibt erhalten.

## Familienwahl und fachlicher Umfang

Sand passt zu den vorhandenen Anschlüssen: gespeichertes ungeschütztes `arid`,
wirkliche Feuchte/Temperatur und Wüsten-Biomgewichte des LivingPlanet-Terrains,
ockerfarbene Staubinstanzen im bestehenden Wetterpool, radial projizierter Wind,
Sichtweite an den bestehenden Atmosphärenleser und `Player.receive_damage`.
Asche/Feuer bräuchten noch belastbare Hitze-/Glut-/Atemanschlüsse; Blizzard eine
abgenommene Kälte-/Ausrüstungswirkung. Deshalb genau eine Familie.

Ein Klima-Label allein genügt nicht: nur Atmosphäre, reale trockene unversperrte
Landfläche, Feuchte <0,25, Temperatur >0,30 und Wüstengewicht >=0,10 (oder reales
Wüstenbiom) erlauben Sand. Feuchte Wälder werden durch die Wetter-Klimaskalierung
nicht zu Wüsten. Heimat und historische Schutzreferenzen, fehlende/falsche oder
zukünftige Klimareferenzen, Vakuum, andere Basisprofile und die reservierten
`*_extreme`-Profile bleiben gesperrt. Die reservierten Profile werden nicht
umdefiniert oder allgemein freigeschaltet.

Körper-ID + Seed + vorhandene `campaign.elapsed_seconds` planen deterministisch:
30–36 min Ruhe, 180 s echte Vorwarnung, 45 s Eintritt, 90 s Höhepunkt, 60 s
Abklingen. Körperfeste kompakte Regionen folgen dem vorhandenen 6,4-km-Feld mit
1,6-km-Kern und 2,8-km-Rand. Trockenheit/Wüstenanteil formen die örtliche Stärke.
Forecast +60/+120/+180 verwendet dieselbe Ableitung, dieselbe Ereignis-ID und
Phase. Sand/Sichtverlust tritt weich ein; der periodische Windversatz bleibt auch
nach langen Spielzeiten begrenzt. Zwei MultiMeshes / 384 Niederschlags- bzw.
Staubinstanzen / 96 Wolken bleiben unverändert.

## Reale Exposition und begrenzte Folgen

Der Reisende wird am tatsächlichen Actor-Ort und anhand aktuellen Terrains
abgefragt. Physischer Schutz: tatsächliches Unterwasser oder Dach plus
Windschutz an der Actor-Position (22-m-Aufwärtsstrahl, 6-m-Strahl gegen den
horizontalen Wind, bestehende Masken 1|2|4, eigener Collider ausgeschlossen).
Eine offene Überdachung blockiert horizontalen Sand nicht. Kamera-/Anzeige-
Schutzflags und sichtbare Ausrüstung verleihen keinen Schutzbonus.

Nur aktive normale Sandstärke >=0,25 führt über den bestehenden Gesundheitsport
zu einer Wirkung: 0,15 % Maximalgesundheit je Kampagnensekunde mal Intensität,
höchstens 15 % je Ereignis und kein Sandabzug unter 25 % Restgesundheit.
Bestehende Schadensminderung gilt weiterhin. Das Ereignisbudget zählt den
angeforderten Rohbetrag konservativ, der tatsächliche Verlust kann kleiner sein.
Pause, Lade-/Terrainwartephase, Erholungsschutz, Tod, Stammeskontrolle und
Diagnosevorschau verursachen keinen Schaden. Pro Auswertung maximal zwei
Schutzstrahlen; die native Aufnahme liefert keine Ziel-PC-FPS-Abnahme.

Die optionale körpergebundene `weather_exposure`-Quittung besteht genau aus
Schema, Körper-ID, Reisenden-ID, Kampagnen-Cursor, Ereignis-ID und verbrauchtem
Budget. Sie ist keine Wetterplanung oder zweite Uhr. Derselbe Cursor zahlt nie
zweimal. Ein neuer Szenenbesitzer setzt den Cursor bei Ankunft auf die aktuelle
Kampagnenzeit und behält das Budget desselben Ereignisses. Körperwechsel,
Neustart und Reise verbuchen damit keine Abwesenheits-/Offlinefolgen. Lange
Einzelticks sind auf eine Kampagnensekunde begrenzt; keine Schadensschuld wird
nachgeholt. Der neue Ereigniszyklus erhält sein eigenes Budget.

Für aktive nahe Dorfbewohner liest der Besitzerpatch die echte örtliche Stärke
und denselben Kollisionsschutz vor `Work.prepare`, Dispatch oder Transporttick.
Exponierte Außenarbeit wird reversibel angehalten, ohne Auftrag, Arbeitsfortschritt,
Fracht, Bauescrow oder Lieferung umzuschreiben; `move`/`wait` bleiben möglich.
Geschützte Arbeit und Arbeit nach Abklingen laufen über den vorhandenen Besitzer
weiter. Keine neue automatische Deckungssuche oder Tiergesundheits-Simulation.
Ferne Dorfbesitzer, Gebäude-, Tier- und Ausrüstungsschaden bleiben Folgearbeit;
es gibt keinen zweiten fernen Schadens-/Produktionswriter.

## Enge Besitzerpatches an R33-01

Der Fachbranch verändert keine gemeinsamen Produktblätter. In Reihenfolge:

1. `owner-patches/01-save-work.patch`: vier SaveParticipant-Anschlüsse für
   Registrierung, Bindungsprüfung und Zukunftsschutz; fünfzeiliger reversibler
   Arbeits-Hold im bestehenden nahen Dorfcontroller.
2. `owner-patches/02-registry.patch`: genau eine Registrierung des neuen
   `r33_07_extreme_weather_test` im Wettervertrag. Der Test ruft seinen
   unterstützenden Arbeits-Fixture-Prozess selbst auf; keine doppelte Registrierung.
3. `owner-patches/03-localization.patch`: drei DE/EN-Statuskeys; danach
   `python3 tools/localization/catalog.py generate` durch den Besitzer.
4. `owner-patches/04-native-workflow.patch`: opt-in, isolierter Diagnoseworkflow;
   keine Änderung oder Lockerung vorhandener Abnahmeworkflows.
5. `owner-patches/05-weather-plan.patch`: Wetterplan-Abgleich.

Der Savepatch ist eine notwendige Integrationsabhängigkeit: die vorhandene
zentrale Persistenz weist unbekannte Körpersektionen absichtlich zurück.
Deshalb ist der reine Fachbranch kein alleinstehend freigegebener Spielbuild.
Der getrennte Diagnose-Draft #279 enthält die angewandten Besitzerpatches und
führt dieselben Fachbytes aus; er ist kein Produktmerge.

## Prüfnachweise

`r33_07_extreme_weather_test` prüft Planung, Warnvorlauf, Ein-/Austritt,
Forecast-Gleichheit, reale Actor-Kollisionen, vorhandenen Gesundheitsport,
Grenzfälle/Cap/Health-Floor, Tempo 0/1/2/4, Regionsausstieg, A–B–A,
reale SaveService-Speicherung, eigenen frischen Prozess und Zukunftsschutz vor
Backup-Rückfall/Überschreiben. Der unterstützende Prozess verwendet die vorhandene
physische Dorf-Testszene, öffentlichen Stammes-Eintritt und Holzauftrag: real
produzierte Fracht bleibt beim Hold/Save/Load erhalten und wird nach Ende geliefert.
Sein normaler Wettereingang ist ein kontrollierter Modell-Fixture; der Dorfcontroller
und die Schutzkollisionen sind die echten Besitzer, keine nachgebaute Arbeitslogik.

`tools/review_r33_07.py` prüft exklusiv beide lokalen Heavy-Locks und tatsächliche
Godot/Xvfb-Prozesse. Native Runs nutzen 300-s-Prozess-/90-s-Public-Load-Grenzen,
isolierte Nutzerdaten und SourceRun vor/nach jedem Lauf. Der opt-in GitHub-Runner
führt GL dann tatsächlich `forward_plus` auf demselben Host mit identischer
Referenzsave, Auflösung 960×540, Tagesphase, Blick und 27 Zeitfenstern aus.
Der Körper und die trockene Landestelle werden regulär generiert, Klima/Schutz
werden nicht umgeschrieben. Zusätzliche Bilder zeigen DE/EN-Warnung, echten
Gesundheitsabzug, Schutz durch die vorhandene Hütten-Geometrie, Pause, Diagnose
und Reload. Ein frischer Prozess liest den während des Ereignisses gespeicherten
Gesundheits-/Budgetstand. Videos sind ausdrücklich zeitverdichtete native Frames
(15 Kampagnensekunden pro Bild), keine FPS-Messung.

Erster Original-Prüflauf: [37609773093](https://github.com/MajorDragonfly/voxelverse/actions/runs/37609773093),
negativ; Test-Player-Eigenschaft, Zyklusgrenzen-Fixture und JSON-Zahlenvergleich
wurden korrigiert. Die fünf vorhandenen Wettertests waren darin erfolgreich.
Weitere Ergebnisse und Quell-Head/Tree werden nach Abschluss der echten Runs
im Nachweismanifest ergänzt. Keine Erfolgsaussage aus bloßer Testplanung.

Offen bleiben weitere Sturmfamilien, Wetteraudio, Ausrüstungs-/Gebäude-/Tierfolgen,
ferne Dorf-Folgen, Balancing- und Ziel-PC-/Windows-Abnahme sowie die vier
Integrationsgates am seriell zusammengesetzten R33-Tree bei R33-01.

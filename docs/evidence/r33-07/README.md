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
   `python3 tools/localization/catalog.py` durch den Besitzer.
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

## Finaler Lauf und vergleichbare native Belege

[Finaler GitHub-Lauf 37621406004](https://github.com/MajorDragonfly/voxelverse/actions/runs/37621406004),
Godot `4.6.3.stable.official.7d41c59c4`, tatsächlich ausgeführter QA-Head
`32d5ba3479831dd7ca11a9bf1a532445c2e4c447`, Tree
`d82fad3e3ed94b10b16ab8f9813ec05e632b79e9`.
Sieben Fachtests einschließlich 241 neuer Prüfungen bestehen; Source-Contracts,
Import, Art-Sources und Source-Integrität ebenfalls. Dieser QA-Tree enthält die
engen Besitzerpatches; die Fachbytes sind über 17 Hashbindungen mit diesem
Produktbranch identisch. Die vollständige Suite und die Integrationsgates bleiben
Aufgabe des zusammengesetzten R33-Trees.

| Tatsächlicher Messwert | Native GL | Native Forward+ |
| --- | ---: | ---: |
| Laufzeit des nativen Prüfablaufs | 151,81 s | 292,78 s |
| Gesundheitsverlust bei Tempo 1 | 0,14793135 | 0,14793135 |
| Gesundheitsverlust bei Tempo 4 | 2,81069559 | 2,81069559 |
| Gesamter offener Verlust | 2,95862694 | 2,95862694 |
| Verlust unter physischer Deckung | 0 | 0 |
| Gespeicherte / frisch geladene Gesundheit | 98,29137025 | 98,29137025 |
| Verbrauchtes Ereignisbudget / Maximalgesundheit | 0,02922101 | 0,02922101 |
| Original-PNGs / vergleichbare Messpunkte | 36 / 35 | 36 / 35 |

Das sichtbar gezeichnete Gesundheitslabel lautet in beiden `exposed-after.png`
**98/101**. Die reale Maximalgesundheit beträgt 101,24999719. Die vorhandene
Hütte schützt ohne Ausrüstungswert; Schutz wird nach der öffentlichen
Szenenladung wieder physisch abgefragt. Pause friert die bestehende Kampagnenzeit
ein. Diagnose erzeugt weder normale Warnung noch Extremfolge. Ein frischer
OS-Prozess und anschließender öffentlicher Szenenreload erhalten Gesundheit,
Cursor und Budget ohne Offline-Nachbelastung oder zweiten Schaden am selben
Cursor. Der echte Dorf-Fixture-Prozess behält Holzfracht, Auftrag und vollständigen
Member-Zustand während Hold/Save/Load; nach Fortsetzung liefert derselbe
Holzauftrag +1 Holz in den vorher leeren Vorrat.

Die gemeinsam geladene Referenz hat SHA256
`7e46b8b5ff1b04f45b7f6f97b81037eba4ea7ccbb68f0bc19b1d8107b0457b41`.
Regulär erzeugter Körper `body_b08a5382f1b97901ccf4cad16304b5a2`, Seed 15838,
Klima `arid`, `home_protected=false`; Face 0, u=0,3125, v=-0,75.
Rohterrain: Land, unversperrt, Biom `desert`, Feuchte 0,10886077,
Temperatur 0,50863289 und Wüstengewicht 0,79113786. Damit stammen Auswahl
und Stärke aus den vorhandenen Klima-/Terrainanschlüssen.

Der [maschinenlesbare Paarvergleich](native-pair-results.json) besteht für alle
35 Messpunkte: Wetter, Kampagnenzeit, Kamera, Auflösung, Gesundheit,
Ereignisquittung und Terrain. Numerische Vergleiche verwenden 1e-6 absolute / 1e-10
relative Toleranz. Körper/Face/u/v stimmen überein; die physische Actor-Höhe
setzt sich rendererabhängig um 1,91 cm, nach Reload maximal 6,81 cm verschieden
(deklarierte Grenze 10 cm). Diese Abweichungen sind einzeln protokolliert.
Kameraposition und Blick werden unabhängig davon gleich fixiert. Das ist keine
Behauptung bitidentischer Physik oder eine Ziel-PC-/FPS-Abnahme: beide Renderer
liefen seriell auf demselben isolierten Software-Mesa/LLVM-GitHub-Runner im
abgestimmten Messslot, mit Prozessinventar und beiden exklusiven Heavy-Locks.
Die bestehenden 300-s-Native-/90-s-Load-Grenzen wurden nicht erweitert.

| Ablaufbeleg | GL | Forward+ |
| --- | --- | --- |
| 180-s-Vorwarnung (DE / EN) | [DE](gl/warning-de.png) / [EN](gl/warning-en.png) | [DE](forward/warning-de.png) / [EN](forward/warning-en.png) |
| Sichtbarer Eintritt | [Bild](gl/frame-0014.png) | [Bild](forward/frame-0014.png) |
| Tatsächliche Exposition vorher / nachher | [vorher](gl/exposed-before.png) / [98/101](gl/exposed-after.png) | [vorher](forward/exposed-before.png) / [98/101](forward/exposed-after.png) |
| Tatsächliche physische Deckung | [Bild](gl/physical-shelter.png) | [Bild](forward/physical-shelter.png) |
| Abgeklungen / Reload | [Ende](gl/frame-0026.png) / [Reload](gl/reloaded.png) | [Ende](forward/frame-0026.png) / [Reload](forward/reloaded.png) |
| Zeitverdichteter nativer Ablauf | [MP4](gl/sandstorm.mp4) | [MP4](forward/sandstorm.mp4) |

Die 27 Sequenzbilder enthalten 2 Ruhe-, 12 Warn-, 3 Eintritts-, 6 Höhepunkt-
und 4 Abklingbilder; 6 Bilder/s ergeben 4,5 s Video. Diese gezielt gewählten
Zeitfenster zeigen den normalen Planverlauf. Der getrennte Expositionsfall läuft
20 Kampagnensekunden über den vorhandenen Clock-Port; übersprungene Sequenzzeit
wird nicht als kontinuierlich simulierte Gesundheitswirkung ausgegeben.

[Das vollständige originale ZIP in drei verlustfreien Teilen](originals/final-native-original.parts.json) enthält
alle PNGs, beide MP4s, Folgen-/Save-Daten, Kindprozess- und Testlogs sowie
vollständige Start-/End-SourceRun-Manifeste; SHA256
`17aafc71b28258b4ff20c5995eff8f068b79cbb3ad8e47f3108cc84c4ca887ef`,
24.504.713 Bytes. Die drei Byte-Teile umgehen nur die 16-MiB-Uploadgrenze;
ihre Verkettung erzeugt unverändert das originale ZIP. Quellen bleiben vor/nach den Läufen sauber und unverändert.
[`evidence-index.json`](evidence-index.json) enthält die Größen und SHA256 aller
lieferbaren Nachweise. Reproduktion des abgeschlossenen Paarchecks:

```bash
cat docs/evidence/r33-07/originals/final-native-original.zip.part-001 \
    docs/evidence/r33-07/originals/final-native-original.zip.part-002 \
    docs/evidence/r33-07/originals/final-native-original.zip.part-003 > final-native-original.zip
unzip final-native-original.zip -d native-original
python3 docs/evidence/r33-07/verify_native_pair.py native-original --output pair.json
```

Die Original-Laufhistorie steht in [`run-history.json`](run-history.json).
Drei frühe Fehlerläufe sind vollständig unter `originals/initial-originals.tar.gz`
erhalten: ein null-sicherer Actor-Guard, zwei fehlerhafte Testgrenzen und die
anfänglich falsche Player/Körper-Bindung im nativen Aufnahme-Fixture wurden
korrigiert. Der erste vollständige native Erfolg ist Lauf
[37611582207](https://github.com/MajorDragonfly/voxelverse/actions/runs/37611582207):
sieben Fachtests, 241 neue Prüfungen und beide wirklichen Renderer mit jeweils
36 PNGs/35 Messpunkten; realer offener Gesundheitsverlust 0,151874995783032,
geschützt 0. Alle nicht-PNG-Originale einschließlich Videos und vollständiger
SourceRun-Manifeste bleiben als Archiv erhalten.

Zwei spätere Gesundheitsbelege erreichten die unveränderte 300-s-Grenze nach
32 PNGs. Beide vollständigen Original-ZIPs bleiben erhalten. Der zweite Lauf
zeigt bereits rund 3,04 Punkte tatsächlichen Abzug und null Verlust unter Deckung,
aber eine leere, gepufferte Eingabedatei für den Kindprozess. Die Ausgaben des
Aufnahmehelfers werden deshalb vor dem frischen Leser ausdrücklich geflusht und
geschlossen; ein ungültiger Kindprozesseingang beendet sich mit Fehlercode.
Der Helfer verwendet für 20 Kampagnensekunden Exposition kompakte 0,25-s-Schritte
über den vorhandenen `GameState._process`-Port bei Tempo 1 und 4. Normale Planung,
reale Kollisionen, Gesundheitsport, Wirkung und Fristen bleiben dieselben. Die
Kamera und Spielerbewegung sind für vergleichbare Beobachtungen fixiert; dies ist
eine kontrollierte native Ablaufaufnahme.
Der Gesundheitsfall setzt ausschließlich vorhandene Fixture-Stats:
`defense_rating = 0` und Hunger-/Durstverlustraten = 0 isolieren den Sandabzug.
Die Aufnahme prüft zusätzlich tatsächlichen Verlust gegen den neu verbuchten
Rohbetrag. Das ist kein Ausrüstungsbonus und keine allgemeine Balancingaussage.
Die vorhandene Hütten-Geometrie wird als echter Collider eingesetzt; sie ist
kein gespeichertes Schutzflag und gehört nicht zur dauerhaften Kampagnenbebauung
dieses Aufnahme-Fixtures. Nach dem Reload wird Schutz erneut am echten Zustand
ermittelt. Der HUD-Leser wird wegen der eingefrorenen Spielerbewegung explizit
aufgerufen und sein Wert gegen die vorhandenen Gesundheitsdaten geprüft.

[`owned-source-binding.json`](owned-source-binding.json) bindet alle 17 eigenen
Code-/UID-Dateien an den Prüf-Tree mit angewandten Besitzerpatches. Der spätere
Fach-Head ergänzt nur diese unveränderten Fachbytes und Nachweisdokumente/-medien;
er wird nicht als vollständig geprüfter zusammengesetzter R33-Tree ausgegeben.
Der finale PR nennt seinen eigenen Head/Tree getrennt vom tatsächlich ausgeführten
QA-Head/Tree. `verify_native_pair.py` prüft die Originale nach dem Entpacken,
Start-/End-Manifeste, Bild- und Loghashes, reale Gesundheits-/Save-Werte und die
35 Paarungen von Wetter, Kampagnenzeit, Kamera, Actor-Ort und Auflösung.

Offen bleiben weitere Sturmfamilien, Wetteraudio, Ausrüstungs-/Gebäude-/Tierfolgen,
ferne Dorf-Folgen, Balancing- und Ziel-PC-/Windows-Abnahme sowie die vier
Integrationsgates am seriell zusammengesetzten R33-Tree bei R33-01.

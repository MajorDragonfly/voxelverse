# Körpervertrag B2: geometrische Passprüfung

Ergänzt [B1](CREATURE_BODY_CONTRACT.md). API: `creatures/runtime/creature_body_fit.gd`, `inspect(preview)`. Schema **1**, Prüfprofil **`workshop_reference_v1`**. D1 entscheidet weiterhin allein über Eignung. Dieser Bericht enthält ausschließlich Geometrienachweise.

## Messgegenstand

Die sichtbare Passprobe und die Prüfung verwenden dieselben Boxen aus `creature_body_fit_shapes.gd`: Sattel, Becken, Oberkörper, Kopf, zwei Reiterbeine sowie je Geschirrseite Polster und gerade Zugleine. Die Größen skalieren mit `body_scale`. Die feste Referenzfigur repräsentiert keinen beliebigen Bewohner. Ankerwürfel und Richtungspfeil sind Orientierungshilfen und werden nicht auf Kollision geprüft.

Geprüft werden diese Boxen gegen die tatsächlichen belegten Voxel von Rumpf und anatomischen Anbauteilen einschließlich Endstücken. Eine räumliche Vorprüfung begrenzt die Suche; der anschließende Separating-Axis-Test unterscheidet belegte Würfel von leeren Ecken einer Boundingbox. Lokale Drehung, Spiegelung und nicht einheitliche Skalierung gehen vollständig ein. Die Welttransformation der Vorschau beeinflusst den Befund nicht. Reines Berühren wird toleriert; die numerische Überlappungstoleranz beträgt `0.00001` in unskalierten Prüfprofil-Einheiten.

Pro Form und Teil-UID/Seite wird höchstens ein Treffer ausgegeben. Ein Trefferpunkt markiert die betreffende Umgebung, keine exakte Kontaktdurchdringung oder Kontaktkraft. Es gibt keine Prüfung von Ausrüstung gegen andere Ausrüstung, keine durchgehende Bewegungsprüfung zwischen zwei Posen und keine Bewertung von Sattelauflage, Anatomielast oder Tragfähigkeit.

## Bericht

Alle Werte von `inspect` sind JSON-kompatibel. Beispiel und Messergebnisse: [creature-body-fit.json](../validation/creature-body-fit.json).

| Feld | Bedeutung |
|---|---|
| `schema`, `profile` | Berichtsversion 1 und feste Größen der Passprobe. |
| `frame` | `preview_local`; Positionen relativ zur Vorschau einschließlich der lokalen Körper-/Teilbewegung. Nicht mit den körperlokalen Anschlussposen aus B1 verwechseln. |
| `pose` | `rest` im Bearbeitungsmodus; sonst `single_motion_sample`. Ein freier Zeitpunkt bestätigt keinen freien Gangzyklus. |
| `complete` | Aktive Anschlüsse konnten mit bekannter Geometrie innerhalb des Suchbudgets geprüft werden. Kein Eignungs- oder Freigängigkeitssiegel. |
| `checked_sockets` | Tatsächlich geprüfte IDs. Eine leere Liste bestätigt keinen nutzbaren Anschluss. Deaktivierte Anschlüsse fehlen absichtlich. |
| `collisions` | `socket_id`, `shape_id`, `part_uid`, `category`, `side`, `position: [x,y,z]`. Rumpfkennung `body`; Anbauteile behalten ihre B1-UID. |
| `errors` | Fehler der B1-Anschlussauflösung; fehlende Sculpt-Haut meldet `sculpted_skin_missing`. |
| `cells_tested` | Sucharbeit: maximal 40.000 Zellen je Mesh/Form und 200.000 je Bericht. |
| `stretched_legs` | Teil-UID, Seite, `stretch` und Position des Beinansatzes für auffällige Ruhelängen. |
| `rest_stretch_notice` | 1,2: Werkstatthinweis ab mehr als 20 % Verlängerung gegenüber entworfenen Segmentlängen. D1 übernimmt diese Grenze nicht automatisch. |
| `suitability_owner` | `D1`. |

Unbekannte Geometrie im Prüfbereich, unauflösbare Anschlüsse oder ausgeschöpftes Budget ergeben `complete=false`. Bekannte Treffer bleiben erhalten. Ungültige oder zukünftige Anschlussversionen werden weder ersetzt noch durch Vorschläge repariert. Ein leerer Trefferbericht ist nur bei passendem Profil, `complete=true` und vorhandenen erforderlichen Kennungen aussagekräftig.

`Contract.inspect_rest(preview)` aus B1 liefert zusätzlich je Fuß `rest_stretch`; vorhandene Felder und Schema bleiben kompatibel. Während Animationen bleiben gespeicherte Ruhelängen messbar; Fußkontaktwerte aus `inspect_rest` sind ausschließlich in Ruhe auszuwerten.

## Werkstatt und Korrekturen

**F2 → Körper → Sattel & Geschirr prüfen.** Rot zeigt betroffene Formen und Kollisionsstellen; goldene Punkte zeigen überstreckte Beinansätze. Befundschaltflächen öffnen das zugehörige Anbauteil beziehungsweise Gelenk. Bei Rumpftreffern wird der betroffene Anschluss ausgewählt.

Die Freiraumsuche prüft zuerst sechs nahe Rückenlagen, dann höchstens zehn Schritte nach oben beziehungsweise seitlich nach außen. Ein Vorschlag wird nur nach vollständiger kollisionsfreier Prüfung des gewählten Anschlusses angeboten. Seine genaue Lage und sein Versatz stehen vor dem Übernehmen im Statusfeld. Ein erhöhter Sattel benötigt weiterhin eine visuelle Prüfung seiner Auflage. Ein bereits freier Anschluss wird in der Werkstatt nicht verschoben. Ein erfolgloser begrenzter Suchlauf bedeutet nicht, dass eine manuelle Lösung unmöglich ist.

Die Beinlängenübernahme bearbeitet ausschließlich die beiden Segmentparameter der gewählten Teil-UID einschließlich ihres gespiegelten Partners. Sie prüft zunächst eine eigene Vorschaukopie: gleiche Fußanzahl, Bodenabweichung höchstens 0,002, gewähltes Paar höchstens 1,2-fach gestreckt und keine neue oder verschärfte starke Streckung anderer Füße. Die bestehenden Parametergrenzen 0,4–2,2 bleiben erhalten. Bei unzureichendem Ergebnis bleibt der Entwurf unverändert; Gelenk, Größe und Beinansatz bleiben manuell bearbeitbar.

Beide Korrekturen sind ausdrückliche Bedienaktionen mit Undo/Redo. Geprüfte Anschlussvorschläge werden bei verändertem Entwurf verworfen. Gespeichert werden nur vorhandene B1-Anschlussfelder beziehungsweise Gelenkparameter; weder Befunde noch Bewegungspose landen im Bauplan. Keine Migration und kein neues Speicherschema.

Im Testlauf friert **Anhalten & jetzt prüfen** die aktuelle Pose ein. Beim Weiterlaufen verschwinden alte Befunde und Markierungen. Die Prüfung läuft nur auf Anforderung in der Werkstatt beziehungsweise bei bewusstem API-Aufruf, nicht pro Tier und Frame. Voxelprimitiven halten dafür zusätzlich eine kompakte Belegung von einem Byte pro Rasterzelle; die sichtbare Geometrie bleibt unverändert.

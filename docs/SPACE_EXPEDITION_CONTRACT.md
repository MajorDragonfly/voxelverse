# ARCH-30 — Reise- und Schiffsvertrag, Datenentwurf v1

Dieser Entwurf bereitet **M9-EXPEDITION / M9.1–M9.6** vor. Er beschreibt Besitz,
Orte und gemeinsame Übergaben und enthält einen ausführbaren Vertragsnachweis.
Er registriert keinen Save-Teilnehmer, erzeugt keine Schiffe in einer Kampagne
und gibt keine Epoche frei. Das Referenzmodell liegt ausschließlich unter
`tests/fixtures/`; es ist kein neuer Laufzeitdienst.

Basis ist `ea900f2e09946660694a9e59399b4680a5655a85`. ARCH-04 ist darin enthalten;
die vorhandenen radialen Ortsanschlüsse aus ARCH-06 werden verwendet. Der
Bauplananschluss ist mit dem Entwurf aus [ARCH-23 / PR #50](https://github.com/MajorDragonfly/voxelverse/pull/50)
abgeglichen, aber noch nicht integriert. Die verbindlichen Abhängigkeiten in
[ARCHITECTURE_BACKLOG.md](ARCHITECTURE_BACKLOG.md#arch-30--reise-schiffsvertrag-vor-m91m96)
bleiben bestehen: Laufzeitintegration erst nach M8 und ARCH-16/18/27/28 sowie
den integrierten Orts- und Bauplanverträgen. Das Raumfahrtziel stammt aus
der [bestehenden M9-Planungsquelle](https://github.com/MajorDragonfly/voxelverse/blob/61ccebb2c6eec5d6f5826867cc91205265dd7667/docs/SPACE_EXPEDITION_PLAN.md).

## Identitäten und Datenbesitzer

| Begriff | Vertrag und Besitzer |
|---|---|
| Kampagne, Fraktion, Spezies | Vorhandene stabile IDs aus der Kampagne. Eigentum und aktuell gesteuertes Objekt sind verschiedene Beziehungen. Der Nachweis behandelt eine eigene Expedition einer Fraktion. |
| Bauplan | Vorhandener modularer Entwurf: `design_id`, positive `revision`, unterstütztes `payload_schema`. Ein individuelles Schiff pinnt diese Referenz. Kein neuer Bauplaneditor und keine Kopie von Weltbesitz im portablen Entwurf. |
| Individuelles Schiff | Eigene stabile `ship_id`; Rolle `expedition` oder `lander`, genau ein `place`, Energie und abgeleitete Fähigkeiten. Zwei Instanzen desselben Entwurfs bleiben unterschiedliche Schiffe. IDs kommen später aus `CampaignIds`, niemals aus Listenindizes oder Seeds. |
| Fähigkeiten | Geprüfte Ableitung aus installierten Modulen und gepinnter Design-/Katalogrevision: Rumpfmaße, nutzbare Frachtkapazität, Sitze, Energiespeicher und Bays. Die Zahlen der Fixture sind synthetisch; echte Modulableitung, Preise und Balancing fehlen noch. |
| Fracht/Probe | Ein Transportverweis auf `(owner_module, record_id)`, genau ein Schiff, belegter Frachtraum. Inhalt, Menge und Einmaligkeitsbelege bleiben beim vorhandenen bzw. späteren Fachbesitzer. Ein zweiter Verweis auf denselben Datensatz ist ungültig, auch mit neuer Transport-ID. |
| Personen | Bestehende individuelle IDs und genau ein Ort: an Bord eines Schiffes oder auf einer Körperoberfläche. Sitzbelegung wird daraus abgeleitet. Die Fixture projiziert Personen in `people`; die Laufzeit darf deshalb kein zweites Bevölkerungsregister anlegen. |
| Steuerung | Eine Spielerperson und ein Ziel: ihr aktuelles Schiff oder sie selbst an der Oberfläche. Brücke/Hangar/Cockpit sind Ansichten dieses Zustands. Kamerawechsel ändern weder Spezies noch Phase. |
| Hangarbelegung | Wird ausschließlich aus `place.kind == dock` abgeleitet. Kein zweites autoritatives `occupied_by`-Feld. Pro `(host_ship_id, bay_id)` höchstens ein Beiboot. |

Der zukünftige gemeinsame Save-Snapshot verbindet diese Fachbesitzer. Eine
Lesekopie für UI/Simulation und die Nodes der sichtbaren Szene sind keine
weiteren Eigentümer. Die Fixture `assets` enthält **keinen Ressourcenbestand**
und keine Forschungsbelohnung. Mengen, Portionierung, Aufteilen/Zusammenführen
von Ladungen und einmalige Probenanalyse benötigen die Fachbelege aus
ARCH-20/27 bzw. M9.3; eine Ortsübergabe darf diese Inhalte nicht neu erzeugen.
Entfernte eigene Schiffe/Orte müssen außerdem genau einen Simulationsbesitzer
haben. Reise und Produktion verwenden später ausschließlich Kampagnenzeit;
Pause und ausgeschaltetes Spiel erzeugen keinen Fortschritt.

## Drei Ortsformen

Alle Varianten besitzen genau die aufgeführten Schlüssel. Mischformen,
unbekannte Varianten, lokale `Vector3`-Objekte und nicht endliche Zahlen werden
abgewiesen. Quaternionen werden als vier normierte Skalare gespeichert.

| `kind` | Weitere Felder | Bedeutung |
|---|---|---|
| `surface` | `system_id`, `address`, `orientation` | `address` verwendet unverändert `CubeSphere.MODE`, `body_id`, `face`, `u`, `v`, `height`. Körper und System müssen im bestehenden Register zusammengehören; Höhe wird durch `SurfaceContext.location` geprüft. Ausrichtung im lokalen Oberflächenrahmen. |
| `system` | `system_id`, `position`, `orientation` | Drei skalare Double-Koordinaten relativ zum Ursprung des bezeichneten Systems, Ausrichtung im Systemrahmen. Ein Sektorwechsel braucht später einen expliziten Systemanschluss; es gibt keinen galaxisweiten `Vector3`. |
| `dock` | `host_ship_id`, `bay_id`, `offset`, `orientation` | Position und Ausrichtung relativ zum Bay-Rahmen des Hosts. Der System-/Körperkontext ergibt sich über die Host-Kette. Zusätzliche eigene Weltkoordinaten sind ungültig. |

Ein Dock braucht einen existierenden Host und Bay. Selbstbelegung, Zyklen,
Doppelbelegung und fehlende Referenzen scheitern. Der geometrische Nachweis
prüft die gedrehte Rumpfbox einschließlich Versatz gegen die Bay-Box; die
spätere reale Flugkollision und Einflugöffnung bleiben eine eigene Abnahme.
Verschachtelte Hosts sind eindeutig auflösbar; der erste Spielumfang braucht
nur Expeditionsschiff und ein Landungsschiff.

Die Proben prüfen alle sechs Würfelflächen einschließlich Kanten und einen
Körper/System-Widerspruch. Das bestätigt das **Adressformat**. Bodenkollision,
erreichbarer Landeplatz, Anflug, Geschwindigkeit und eine begehbare Körperklasse
müssen die späteren Oberflächen-/Flugadapter bestätigen. Ein formal gültiger
Ort ist keine Ankunftsberechtigung.

### Offenes Präzisionstor vor Speicherintegration

Der reale gemeinsame `AtomicJson.write` verwendet auf dieser Basis
`JSON.stringify` ohne `full_precision`. Die Probe mit
`1000000000010.125` verliert beim Speichern Nachkommastellen. Der Test gibt
deshalb separat `system_coordinate_save_precision: ready=false` aus.
**Die aktuelle Speicherung ist damit für diese Systemadressen noch nicht
abgenommen.** Vollständige Double-Präzision lässt sich mit
`JSON.stringify(data, "", true, true)` verlustfrei darstellen.

Vor dem M9-Save-Anschluss muss der zuständige gemeinsame Speicherbesitzer
verlustfreie Serialisierung einschließlich Wiederladen und Backup beweisen.
Das ist eine koordinierte Änderung am bestehenden Writer; hier wird kein
zweiter Writer eingeführt. Der isolierte Atomizitätsnachweis verwendet exakt
erhaltene Testkoordinaten und weist dieses separate Präzisionstor ausdrücklich
aus. Die grünen Vertragsprüfungen schließen dieses Tor nicht.

## Gemeinsame Übergabe

`stage(before, after, context, energy_spent)` ist eine reine **Entwurfsprobe**
für einen bereits fachlich vorbereiteten lokalen Vorgang. Sie ist keine
öffentliche Flug-, Teleport-, Bau- oder Handelsfunktion. Sie verlangt:

1. Beide vollständigen Zustände sind gültig und gehören derselben Kampagne,
   Fraktion und Spezies. Die Revision steigt um genau eins.
2. Schiffs-, Personen- und Transportidentitäten bleiben erhalten. Bauplan,
   Fähigkeiten, referenzierte Fracht-/Probendatensätze und belegter Frachtraum
   bleiben unverändert. Aufrüsten ist ein späterer eigener Fachbefehl.
3. Orte, Steuerungsziel derselben Spielerperson, Frachtzuordnung und Energie
   ändern sich gemeinsam. Kapazitäten und Bay-Belegung gelten für das ganze
   Ergebnis. Die Gesamtenergie sinkt um exakt den vorgegebenen Verbrauch;
   Energieübertragung zwischen Speichern erzeugt keine Energie.
4. Die lokale Übergabe wechselt kein System. Erlaubnis, erreichte Ankunft,
   Energiepreis, Ladezugang und Reservierungsbelege kommen später vom
   zuständigen Flug-/Transportadapter und müssen **vor** dieser Probe stimmen.

`admit(current, staged, context)` prüft die Vorlage erneut und vergleicht den
vollständigen Ausgangszustand, zusätzlich zur Revision. Eine abweichende
Vorlage ist veraltet. Ist das exakte Ergebnis bereits aktuell, wird dieselbe
Übergabe wirkungslos als Wiederholung bestätigt. Nach einer weiteren Revision
scheitert die alte Vorlage. Alle Resultate sind tiefe Kopien; Prüfen und
Vorbereiten verändern weder den Eingang noch eine Datei.

Der spätere vorhandene Save-Besitzer muss die Folge **Vorbereiten → gegen den
aktuellen Zustand prüfen → vollständigen gemeinsamen Snapshot dauerhaft
schreiben → Speicherzustand veröffentlichen → Szene/Kamera umschalten** ohne
konkurrierende Fachmutation ausführen. Ein Schreibfehler veröffentlicht nichts.
Ein Abbruch vor dem Commit lässt den bisherigen Ort und die alte Ladung
gelten; ein Abbruch danach lädt das ganze Ergebnis. Scene-Recovery baut die
Ansicht aus diesem Ergebnis auf und verbucht keine Fracht ein zweites Mal.

Das Testmodell hält je Auftrag genau Ausgang und Ergebnis; es erzeugt kein
wachsendes Receipt-Archiv. Seine `.request.json` ist nur eine Neustart-Fixture.
Der echte Auftrag samt Reservierung und Belegen gehört später in den
gemeinsamen, begrenzten Transport-/Save-Anschluss aus ARCH-27/18. Eine zweite
autoritative Expeditionsdatei ist ausdrücklich kein Integrationsvorschlag.

## Versionen, Altstände und optionale Vorlagen

`schema: 1` bezeichnet ausschließlich diesen lokalen Vertragsentwurf, keine
neue SaveGame-Version. Ein bestehender Save ohne Raumfahrtteil bleibt
unverändert und erhält durch Lesen keine Schiffe. Unbekannte Pflichtversionen
werden abgewiesen; beim späteren Save-Anschluss müssen sie wie andere
Zukunftsverträge sowohl Schreiben als auch Backup-Rückfall blockieren.

Die Fixture akzeptiert den bisherigen modularen `payload_schema: 1` und eine
synthetische Fähigkeiten-Katalogrevision 1. Sie lädt keine Bauplan-Dateien.
Der tatsächliche Anschluss muss ARCH-23s validierte Entwürfe und Module
verwenden; Angaben aus Downloads dürfen keine Kapazitäten oder Freischaltungen
behaupten. Kompatible eigene, mitgelieferte und lokal gespeicherte
Community-Vorlagen sind gleichwertige Ausgangspunkte. Editorarbeit bleibt
freiwillig, verwendete Vorlagen bleiben offline verfügbar.

Ein neues Design ersetzt kein bestehendes Schiff automatisch. M9.4 muss den
Umbau ausdrücklich bestätigen und dabei Schiff-ID, Fracht, Personen und
Bordschiffe erhalten. Ein nicht mehr passendes Beiboot oder überfüllter
Frachtraum blockiert den Umbau, bis der Konflikt aufgelöst ist. Fehlender Host,
Stranden oder zerstörte Schiffe brauchen später einen expliziten Recovery-
Vorgang; der Loader darf keine Referenz erfinden oder Ladung still löschen.

## Abnahme und nächste Anschlüsse

Die vollständige [Fixture](../tests/fixtures/expedition_contract_draft.json)
zeigt eine Expeditionsbasis und ein separates Landungsschiff. Der
[Vertragstest](../tests/expedition_contract_test.gd) weist Doppelbelegung,
kopierte Probenreferenzen, Besitzkonflikte, Kapazitäten, Control-Zuordnung,
gedrehte Bay-Passung, Energieerhalt, gepinnte Baupläne, veraltete Aufträge,
Schreibfehler und zwei echte Prozessneustarts nach. Die bloßen Ortswechsel
des Tests sind keine geflogene Expedition.

Die Fixture begrenzt Arbeit auf 64 Schiffe/Bays, 4096 Personen/Transportverweise,
16 Verschachtelungen und 100000 JSON-Werte. Zähler sind ganze Zahlen von 0
bis 10^9; positive Größen haben eine Untergrenze. Das sind Prüfgrenzen dieses
Entwurfs, keine zugesagten Spielbudgets oder Balancing-Werte. Skalierung und
echte Kapazitäten müssen nach ARCH-02 gemessen werden.

| Bestehende Etappe | Noch zu liefernde Abnahme |
|---|---|
| M9.1 | Gepinnte Schiffdaten aus echten Modulen, optionale Vorlagen/Editor, validierte Fähigkeiten, integrierte Speicherteilnahme samt Präzisionstor. |
| M9.2 | Eigene Basis vorbereiten, Beiboot wählen/abdocken, beide lokalen Flugabschnitte steuern, landen, aussteigen, erkunden, zurückfliegen und andocken; Neustart und sichere Recovery. Eine kurze Oberfläche/Orbit-Sequenz ist erlaubt. Brücke/Hangar-Umschaltung genügt als erste Innenraumlösung. |
| M9.3 | Physische Proben von digitalen Entdeckungen unterscheiden, im Labor genau einmal verbrauchen/anrechnen und Forschungswirkung nach Neustart behalten. |
| M9.4 | Wirksamer Rumpf-/Kapazitätsausbau unter Erhalt aller vorhandenen Individuen und Inhalte. |
| M9.5 | Zusätzliche Bordschiffe und Bewaffnung; Kampfsysteme werden hier abgenommen. |
| M9.6 | System-/Sektorreise und Kolonien; friedliche Reise benötigt kein Kampftor aus M9.5. |

ARCH-30s Datenentwurf kann separat geprüft werden. ARCH-30 als Laufzeitvertrag
und die gesamte M9-Spielschleife bleiben bis zu diesen Anschlüssen offen.

# ARCH-27 – regionaler Wege- und Transportvertrag 1

Status: ausführbarer, geprüfter Modellanschluss für den laufenden Siedlungsausbau ARCH-26. Noch kein produktiver Kampagnen-/Vorratsanschluss. Grundlage ist `main` `bb2f83b56267964baa7037720c4daca26fe3d007`. [Arbeitsauftrag](ARCHITECTURE_BACKLOG.md), [Besitzer](MODULE_CONTRACTS.md), [Übergabe](WORK_ARCH27_REGIONAL_TRANSPORT.md).

Die gemeinsame lokale Navigation, `VillageWork`, `VillageEconomy`, `VillageSimulation` und SaveGameService bleiben bestehen. Zwei neue reine Modelle unter `world/tribe/transport/` verbinden später deren geprüfte lokale Wege. Sie besitzen keine eigene Vorrats-, Tier-, Save- oder Echtzeitsimulation. Ein neuer Test ist im vorhandenen Vertragsregister eingetragen.

## Regionale Verbindungen

`regional_routes.gd` prüft ein gerichtetes Netz und plant nach Reisezeit eine deterministische Route. Gleiche Daten ergeben unabhängig von der Dictionary-Reihenfolge dieselbe Auswahl. Aktuelle Grenzen pro eingelesenem Routenkorridor: 128 Übergangspunkte, 256 gerichtete Verbindungen, 64 Verbindungen pro Route. Das ist kein planetenweites Feinraster und erhöht keine Bewohner-/Aktivobjektgrenze. Eine Suche, deren gewählter kürzester Weg mehr als 64 Verbindungen benötigt, meldet `routes.leg_budget`; Korridoraufteilung bleibt ein späterer Anschluss.

| Datensatz | Felder und Bedeutung |
|---|---|
| Netz, Schema 1 | `id`, `body_id`, `nodes`, `edges` |
| Übergangspunkt | `id`, `region_id`, `settlement_id`, `faction_id`, `place`; Zwischenpunkte dürfen eine leere Siedlungs-ID haben. `region_id` ist eine Referenz des bestehenden Regionsbesitzers, keine neue Seed-ID. |
| Ort | Bestehende Cube-Sphere-Adresse mit `mode`, `body_id`, `face`, `u`, `v`, `height`, `radius`. Keine dauerhaften lokalen XYZ-Koordinaten. |
| Verbindung | `id`, `from`, `to`, `mode`, `seconds`, `capacity`, `revision`, `blocked`; Rückrichtung wird ausdrücklich separat zertifiziert. |
| Route, Schema 1 | `graph_id`, `body_id`, kopierte geordnete `nodes` und `legs`; unabhängig von einem später geleerten Regionscache lesbar. |

Zunächst ist nur `foot` zulässig. `seconds` bezeichnet die vom lokalen Navigationsbesitzer zertifizierte Dauer, maximal 86.400 Sekunden pro Verbindung. `capacity` begrenzt die Menge derselben Ressourceneinheit; es ist keine neu erfundene Kilogramm-/Traglastphysik. Ressourcenrevision und Einheiten kommen aus `resource_catalog.gd`. Die tatsächliche Fähigkeit des Trägers muss der spätere Host zusätzlich prüfen.

Das Modell berechnet weder Geländewege noch Reisezeiten aus Luftliniendistanzen. Es akzeptiert Zertifikate des bestehenden Navigationsbesitzers. Dieser muss bei Hindernissen, Geometrie-, Endpunkt- oder Dauerkorrekturen die Verbindung sperren bzw. ihre Revision ändern. Eine laufende Route prüft vor jedem Fortschritt das aktuelle Netz und die vollständige gespeicherte Verbindung samt beiden Endpunkten. Fehlendes Netz, entfernte Verbindung, Sperre, geänderte Revision oder verschobenes Ziel halten den Auftrag an. Eine unverändert wieder verfügbare Verbindung kann fortgesetzt werden. Ein geändertes Zertifikat erfordert einen späteren ausdrücklichen Neuplanungsanschluss; der Vertrag übernimmt keine veränderte Geometrie mitten auf dem Weg.

Eine Route ohne Verbindung, aber mit genau einem Übergangspunkt, ist erlaubt, damit bereits aufgenommene Ware am unverändert erreichten Quelllager wieder ausgeladen werden kann. Ein neuer Transport braucht trotzdem zwei verschiedene Lager und Siedlungen.

## Transport und Besitzer

`regional_transport.gd` verwendet Schema 1. Ein Auftrag speichert unveränderliche Transport-, Träger-, Fraktions- und Reservierungs-ID, `resource_id/resource_revision/amount`, vollständigen Quell-/Zielbezug und die Route. Beweglicher Zustand: `leg`, `elapsed`, `cursor`, `owner`, `epoch`, `status`, `returning`, `blocked`, `at_gateway`.

`create()` plant eine Reservierung, `depart()` die Abholung. `advance_far()` verbraucht höchstens 0,25 Sekunden und höchstens die verbleibende Dauer einer Verbindung pro Aufruf. Überschüssige geschuldete Kampagnenzeit bleibt am Cursor erkennbar; der vorhandene Scheduler muss seine Aufrufzahl begrenzen. Der Vertrag verwendet keine Systemzeit. Gleicher Kampagnenzeitpunkt erzeugt keinen zusätzlichen Weg. Gesperrte oder nicht geladene Abschnitte verbrauchen keine Reisezeit und sammeln keinen nachträglichen Reisevorsprung.

`observe_near()` lässt Zeit allein nicht als Ankunft gelten. Der autoritative physische Trägerhost muss einen aktuellen körperfesten Ort liefern. Erst innerhalb eines Meters vom nächsten geprüften Übergangspunkt wird die Etappe abgeschlossen. Der Vertrag prüft die Orts-/Körperbindung, ersetzt aber keine Kollision, Bewegung oder Trägerauthentifizierung.

`handoff()` wechselt den einzigen Besitzer zwischen `near` und `far` und erhöht `epoch`. Alte Worker werden zurückgewiesen. Für diese erste Stufe ist eine Übergabe nur an einem bestätigten Übergangspunkt und nach vollständiger Bearbeitung der bis dahin geschuldeten Kampagnenzeit zulässig. `at_gateway` wird durch die Nahbeobachtung bzw. erreichte Ferndauer aktualisiert. Ein Wechsel mitten auf einer Verbindung ist ausdrücklich gesperrt: keine erfundene Zwischenposition und kein Teleport. Dort bleibt beim späteren Host der bisherige Besitzer aktiv, bis ein geeigneter Übergangspunkt erreicht ist.

Nach der letzten Verbindung ist der Auftrag `arrived`; das schreibt noch keinen Vorrat gut. `finish(..., "deliver")` erzeugt den Abschlussvorschlag. Volles Ziel, fehlender Zugang oder Schreibfehler müssen den angekommenen Auftrag samt Ladung erhalten. Nicht beladene Aufträge lassen sich stornieren. Beladene Aufträge benötigen `return_to_source()` mit einer passenden Rückroute vom tatsächlichen Übergangspunkt; erst nach Rückankunft erfolgt Rückgabe. Verlust ist ein eigener terminaler Abschluss ohne Lagergutschrift. Schema 1 erlaubt nur Quell- und Ziellager derselben eigenen Fraktion; fremde Lager werden abgewiesen, bis ein ausdrücklich geprüfter Handels-/Hilfsvertrag existiert.

## Ein gemeinsamer Abschluss statt zusätzlicher Warenbuchhaltung

Jeder Befehl liefert `{ok, code, data, effects, expected}` als Kopie. Bestehende Daten werden nicht verändert; Fehler liefern keine Kandidaten oder Effekte. `admit(current, proposal)` vergleicht den vollständigen erwarteten Vorzustand und lehnt überholte Vorschläge ab. Seine Eingabe ist ein vertrauenswürdiges lokales Modellergebnis, kein Import-/Netzwerkformat.

Effekte sind **Buchungsabsichten**, keine bereits ausgeführten Buchungen. Die eindeutige Effekt-ID wird aus Transport-ID und Aktion abgeleitet. Der spätere einzige Siedlungs-/Transportbesitzer muss Transportkandidat, Effektbeleg, Trägerladung, Reservierung und betroffene Bestände synchron prüfen und zusammen über den vorhandenen SaveGameService veröffentlichen. Nach gescheitertem Save bleibt die vorherige vollständige Kopie maßgeblich. `admit()` allein macht externe Vorratsänderungen nicht atomar.

| Effekt | Erforderliche Wirkung beim vorhandenen Besitzer |
|---|---|
| `reserve` | Verfügbaren Quellbestand und Zielannahme prüfen; Quellmenge für genau diese `reservation_id` binden. Keine Zielgutschrift. |
| `pickup` | Dieselbe Reservierung einlösen, Quelle vermindern, dieselbe Ladung dem zugewiesenen Träger/Transport zuordnen. Keine zweite Ladung im Bewohnerregister anlegen. |
| `cancelled` | Noch nicht aufgenommene Quellreservierung genau einmal freigeben; keine neue Ware erzeugen. |
| `delivered` | Angekommene Ladung entfernen, Zielbestand und Transferbeleg zusammen ergänzen. |
| `returned` | Angekommene Rückfracht entfernen und Quellbestand wieder ergänzen. |
| `lost` | Ladung entfernen und Verlustbeleg ergänzen; trotz enthaltenem Quellbezug keine Lagergutschrift. |

Siedlungsübergreifender Transfer ist keine Produktion: besonders bei Milch darf er weder einen neuen D3-Produktionszyklus noch neue Produktionsbelohnungen erzeugen. Die heutigen lokalen Milchbilanzprüfungen müssen beim produktiven Anschluss zusammen mit vorhandenen Transfer-/Verbrauchsbelegen erweitert werden. Dieses Paket verändert sie nicht.

## Verbindlicher Folgeanschluss nach ARCH-26

1. Stabile Siedlungs-/Arbeitsplatz- und Regionsreferenzen auflösen; Netz-/Auftragsregister genau einem Kampagnenbesitzer zuordnen. Dieses Paket führt kein neues Top-Level-Savefeld ein.
2. Lokale Wege zwischen Gateway-Orten mit dem vorhandenen Navigator zertifizieren. Bei Änderungen Verbindungen invalidieren; Quelle/Ziel und Carrier-Kapazität vor Auftrag/Abholung erneut prüfen.
3. Registryweit eindeutige Transport-, Träger- und Reservierungsbindungen prüfen. Alle Befehle synchron zulassen, gemeinsam verbuchen und sichern; terminale IDs/Einmaligkeitsbelege nicht still verwerfen.
4. Nahakteur und Fernscheduler an denselben Datensatz anschließen. Kampagnenzeit, Phase, Pause, Regionen und Besitzerwechsel bleiben bei den vorhandenen Diensten. Noch keine Geschwindigkeits-/Trägerzahlerhöhung.
5. Über ARCH-07/13 versionierte Validierung, Import/Export, Zukunftsschutz und gemeinsame Segment-/Manifestreferenzen integrieren. Alte Kampagnen bleiben ohne diesen optionalen Anschluss unverändert.
6. Echte A→B-Lieferung mit zwei spielbaren Siedlungen, Bestandsbilanz einschließlich Milch, vollem/gesperrtem Ziel, Unterbrechung, Regionswechsel und Neustart abnehmen. Physische Zwischenpositionen und Neuplanung geänderter Routen sind dabei eigene konkrete Anschlüsse.

Damit ist der erste Vertrag lieferbar. Die Gesamt-ARCH-27-Abnahme mit spielbaren Siedlungen bleibt offen.

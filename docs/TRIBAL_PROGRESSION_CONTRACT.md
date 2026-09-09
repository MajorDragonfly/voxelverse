# Stammesfortschritt und Epochenvertrag – Version 2

Auftrag 6, gemeinsame Basis `3a3e0272375e556f3ff65b7370582af79a9d48b5`.
Version 2 verbindet den abgeschlossenen M6-Stand
`9d30a0c31bc5da066580a2b58db6be782f899f41` mit dem Stammesfortschritt.
Implementierung: `core/progression/tribal_progression.gd` und
`core/progression/civilization_contract.gd`. Diese Regeln sind kein neuer
Artenkatalog und keine zweite Zähmungs- oder Dorfsimulation.

## Produktiver Anschluss für Auftrag 5

`TribeController._work(member, delta)` umfasst genau **einen tatsächlich am
Arbeitsplatz angekommenen Bewohner**. Der Wrapper sichert den vorherigen
Dorfzustand, führt `_perform_work` aus und ruft synchron auf:

```gdscript
ProgressionService.record_tribal_work(before, member_id, self)
```

Der Service akzeptiert ausschließlich den aktuellen aktiven Dorfcontroller in
Phase 1. Das Modell prüft Vorher/Nachher gegen den vorhandenen `TribeState`-Vertrag
und eigene Kampagne, Spezies, Fraktion und Bewohner-ID. Es beobachtet:

- Lieferung: Fracht verschwindet beim Träger, derselbe Lagervorrat wächst um eins
  und `delivered` wächst um eins. Abholung allein zählt nicht.
- Bau: Fortschritt desselben Projekts wächst, während der Bewohner diesen Auftrag
  ausführt. Erst der abgeschlossene Werkzeug-/Hütten-/Gartenstand zählt als Erfolg.
- Versorgung: Das Lager verliert eine Nahrung, `meals` wächst um eins und der
  betreffende Bewohner wird tatsächlich gesättigt.

Der Beobachter konsumiert keine Rohstoffe und simuliert keine Arbeit. Er reagiert
nicht auf `order_resolved` oder bloße Befehle. `_work_rate` liest jetzt direkt
`get_behavior_effect("group_cooperation", 1)`; bestehendes Kreaturenvermächtnis und
neue Stammesboni werden einmal addiert und innerhalb der bisherigen Grenzen
gehalten. Körperwerte werden nicht verändert.

**Integration mit Auftrag 5:** Die eigentliche `_work`-Logik heißt hier
`_perform_work`. Dessen Dorfänderungen und diesen kleinen Wrapper bewusst
zusammenführen. Beide Vorher/Nachher-Zustände müssen weiterhin vom gemeinsam
integrierten `TribeState` akzeptiert werden. Der geprüfte M6-Vertrag liefert nun
Wasser, Berufe und einen Milchtransportadapter. Milch zählt nach wirklicher
Lieferung und Verbrauch als Nahrung; der Adapter erzeugt selbst keine Tiere oder
Milch. Milch-/Fütterungs-/Pflugklicks erhalten keine eigenen Punktquellen.

`tribal_economy_progress.gd` beobachtet außerdem den vollständigen Berufszyklus:
Bei Abholung sinkt die erneuerbare Quelle um eins und derselbe Bewohner nimmt
Fracht auf; später steigt durch seine Lieferung der Lagerbestand um eins. Der
Beruf bei der Abholung bleibt auch über Unterbrechung, Berufswechsel und Laden
erhalten. Ohne beobachtete Abholung zählt alte Fracht nicht als Berufszyklus.
Versorger (Nahrung/Wasser), Holzarbeiter, Steinmetz und Fasersammler sind hierfür
unterstützt. Bau- und Milchberufe bleiben über ihre tatsächlichen Bau-/Liefer-
und Versorgungsbeiträge an den übrigen Gemeinschaftszielen beteiligt.

Nach jedem aktiven Physikschritt ruft der Controller einmal
`record_tribal_tick(simulation_delta, self)` auf. Garten und Brunnen müssen schon
wirklich produziert haben, Nahrung und Wasser im Lager sein und alle Bewohner
einen Sättigungs- und Flüssigkeitswert von jeweils mindestens 20 haben. Ein Ausfall setzt das
laufende 180-Sekunden-Fenster und seine Ess-/Trinknachweise zurück. Innerhalb des
Fensters muss jeder Bewohner tatsächlich gegessen und getrunken haben; für den
Abschluss sind mindestens 12 Nahrung (einschließlich Milch) und 6 Wasser nötig.
Pause und Offlinezeit zählen nicht. Der Timer verschiebt keine laufenden
Autosaves; reguläre Snapshots speichern ihn zusammen mit der Dorfwirtschaft.

## Einmalige Gemeinschaftsverdienste

| ID | Tatsächlicher Abschluss | Soziale Stammespunkte |
|---|---|---:|
| `shared_stock` | Acht ausgelieferte Einheiten, mindestens zwei verschiedene Träger | 3 |
| `shared_tool` | Ein fertig gebautes Steinwerkzeug mit mindestens zwei tatsächlich mitarbeitenden Bewohnern | 3 |
| `shared_hut` | Eine fertige Hütte mit mindestens zwei tatsächlich mitarbeitenden Bewohnern | 4 |
| `shared_garden` | Ein fertiger Garten mit mindestens zwei tatsächlich mitarbeitenden Bewohnern | 4 |
| `shared_meals` | Mindestens drei Nahrung von mindestens zwei Trägern; danach essen alle drei ursprünglichen Bewohner aus dem Lager | 4 |
| `sustained_supply` | Das oben definierte ununterbrochene Versorgungsfenster ist erfüllt | 3 |
| `working_professions` | Zwei verschiedene unterstützte Berufe mit jeweils drei vollständigen erneuerbaren Arbeits-/Lieferzyklen; mindestens zwei tatsächlich beteiligte Bewohner | 3 |

Jeder Meilenstein wird genau einmal **pro Kampagne** vergeben, auch bei mehreren
Dörfern/Planeten. Höchstverdienst derzeit 24 soziale Stammespunkte. Ein späterer
Versorgungsausfall widerruft keinen früheren Verdienst, setzt aber die aktuelle
Versorgungsvoraussetzung im Entwicklungspfad zurück. Aggressive
Stammespunkte bleiben null, bis eine wirkliche Gruppenkampf-Spielschleife ihren
Abschluss nachweisen kann. Weder friedlicher noch aggressiver Spielstil wird über
Punkte zur Voraussetzung eines Epochenwechsels.

Stammeskäufe: `tribe.social.teamwork` kostet 3 Punkte und verbessert Arbeitsraten
um 10 %. `tribe.social.practice` kostet weitere 5 Punkte, benötigt den ersten
Knoten und verbessert um weitere 10 %. Die Wirkung gilt für die Stammesphase;
ein Vermächtnis in nicht implementierte Epochen wird damit nicht zugesagt.
Kreaturenpunkte und deren sechs vorhandene Käufe bleiben unverändert erhalten.

## Speicherung und Wiederaufnahme

Das äußere Speicherformat bleibt 6, `progression.schema` steigt von 4 auf **5**.
`progression.tribal.schema` ist **2**, das neue `villages[id].economy.schema`
ist **1**. Verhaltensformat/-regeln bleiben beide 1, Dorfzustand ist durch M6
**3** mit `economy.schema = 1`, Epochen-IDs bleiben 0–5.

`tribal` enthält Kampagnen-/Spezies-/Fraktionsidentität, pro Dorf begrenzte
Bewohnernachweise, monotone Arbeitszähler, Träger, versorgte Bewohner und das
laufende Projekt mit seinen Mitwirkenden. `awards` enthält die einmal bezahlten
Meilenstein-IDs, `purchases` die Käufe. Der Kontostand wird daraus berechnet;
separate, voneinander abweichende Kontostandzähler werden nicht gespeichert.

- Vorhandene Progressionsformate 1–4 erhalten einen leeren Stammesnachweis. Alte
  Lieferungen oder fertige Gebäude erzeugen beim Öffnen/Laden keine rückwirkenden
  Punkte. Bei einer teilweise fertigen alten Baustelle zählen nur neue Beiträge.
- Der erste neue Arbeitsnachweis beginnt bei den tatsächlichen aktuellen
  Arbeitszählern. Alte Starts, Menüaufrufe und Neuinitialisierung zahlen nicht aus.
- Stammesformat 1 wird verlustfrei auf 2 angehoben. Seine Erfolge, Käufe und
  laufenden Baubeiträge bleiben erhalten; neue Wirtschaftsbeweise beginnen leer.
  Der begrenzte Nachweis speichert Liefer-/Ess-/Trinkzähler, Frachtzuordnung,
  abgeschlossene Berufszyklen mit Beteiligten sowie Zeit und Verbrauch im
  laufenden Versorgungsfenster. Auch eine neuere verschachtelte Version wird vor
  Überschreiben geschützt.
- Dorf und Nachweis werden in **demselben atomaren Kampagnensnapshot** gespeichert.
  Ein Absturz vor dem nächsten Autosave stellt beide auf denselben alten Stand.
  Erwerb eines Knotens speichert sofort; bei Schreibfehler werden Kauf und
  Kontostand zurückgesetzt, der Bonus wird nicht aktiviert.
- Spielstandkopien behalten bezahlte Meilensteine und Bewohner-/Tieridentitäten;
  nur die Bindung an die neue Kampagnen-ID wird angepasst.
- Ein neueres Progressions- oder Stammesnachweisformat wird abgelehnt und über
  die vorhandene Zukunftsstand-Sperre vor Überschreiben geschützt.
- Welt-Y, Spawns, Tierarten, D1/D2-Zustände und Offline-Produktion werden nicht
  eingeführt oder verändert.

## Fraktionen der eigenen Spezies

`neighbor_plan(campaign, body_id, slot)` liefert für Slot 0–15 eine deterministische
**Planung**, ohne sie in die Kampagne zu schreiben oder Bewohner zu erzeugen:
`id` (Fraktion), `species_id`, `body_id`, `phase`, eigener `technology`-Stand,
`relation`, `status: planned`, `contract: 2`.

Nachbar und Spieler haben dieselbe `player_species_id`, aber unterschiedliche
Fraktions-IDs. `validate_faction` lehnt eine fremde Art ab. Spätere Übergänge
ändern nur die jeweilige Fraktion, niemals automatisch jede Art oder Fraktion
des Planeten. Geplante neutrale Nachbarn können eigene Versorgung, Aufträge,
Abkommen und abgegrenzte Konflikte erhalten. Das ist noch keine aktive
Nachbarstammes-KI. Gezüchtete/gezähmte Wildtiere behalten Tier-ID, eigene Art,
Besitzerfraktion und Bindung; sie gehören nicht zur Bürgerliste.

## Spielbare Epochenvoraussetzungen

Alle Werte sind die konkret definierte erste Abnahmefassung; spätere
Balancingänderungen benötigen eine Vertragsrevision. Zeit meint ausschließlich
laufende Simulation, ohne Pause oder Offlinezeit.

Für **Antike/Mittelalter (ID 2)**:

1. Zwei fertige Hütten, ein hergestelltes Steinwerkzeug und ein angelegter Garten,
   aus dem bereits Nahrung nachgewachsen ist. Diese Teilziele sind heute lesbar.
2. Alle Bewohner 180 Spielsekunden mit erneuerbarer Nahrung/Wasser versorgen;
   jeder hat im laufenden Fenster gegessen und getrunken; am Ende 12 Nahrung und
   6 Wasser im gemeinsamen Lager. Dieser Teil ist jetzt spielbar und nachgewiesen.
3. Mindestens zwei Bewohner beteiligen sich an zwei Berufen mit jeweils drei
   vollständigen Arbeits-/Lieferzyklen an erneuerbaren Arbeitsplätzen. Der
   Entwicklungspfad zeigt die tatsächlich beobachteten Zähler je Beruf.
4. Eine Hilfs-/Handelslieferung an einen Nachbarstamm derselben Spezies abschließen
   **oder** das eigene Dorf in einem abgegrenzten Gruppenkonflikt verteidigen.
5. Ein spielbarer Zielmodus mit Siedlungsverwaltung, Handwerk, Wegen, Handel und
   geprüfter Zustandsübernahme existiert tatsächlich.

Für **Neuzeit/Weltmacht (ID 3)**:

1. Zwei eigene Siedlungen mit Wohnraum und 180 Spielsekunden gesicherter Versorgung.
2. Eine begehbare Verbindung bringt insgesamt 30 Waren ins jeweilige Ziellager.
3. Eine Rohstoffkette verarbeitet 12 Erz zu 6 Metall und daraus 3 nutzbare Werkzeuge.
4. Eine bilanzierte Energiequelle betreibt einen Arbeitsplatz 30 Spielsekunden.
5. Ein regionales Abkommen erfüllen **oder** ein begrenztes Verteidigungsziel mit
   versorgten eigenen Truppen abschließen.
6. Eine spielbare Neuzeit mit Industrie, Energie, globalen Orten,
   Fraktionsverwaltung und getesteter Übernahme existiert.

Das Modell nimmt keine `ready`-/`implemented`-Flags aus Spielständen, Menüs oder
Punktekonten als Freigabe an. Noch fehlende Nachweise werden ausdrücklich als
„Spielsystem folgt“ angezeigt. Die produktiven Gate-Funktionen und der
Speicherservice lassen Phase 2/3 weiterhin nicht zu. Die UI zeigt deaktivierte
Aktionen „Jetzt ins Mittelalter fortschreiten“ / „Jetzt in die Neuzeit
fortschreiten“ statt eines nur durch Punkte aktivierten Knopfs.

## Verbindliche spätere Übergabe

Erst wenn der Zielmodus implementiert und geprüft ist:

1. Sämtliche Voraussetzungen aus echten Simulationsnachweisen neu prüfen.
2. Auswirkungen und erhaltenen Bestand anzeigen; an Kampagne, Fraktion, Epoche und
   vollständigen Bestand gebundene einmalige Bestätigung erstellen.
3. **Ausdrücklicher Klick** auf die entsprechende Wechselaktion. Menüöffnung,
   Punktestand, Manipulation eines Anzeigestatus oder doppelter Klick sind kein
   Auftrag. Alte Bestätigung bei verändertem Bestand verwerfen.
4. `validate_retention(before, after)` vor dem gemeinsamen atomaren Speichercommit
   anwenden. Bestehende Identitäten und sämtliche vorhandenen Bestandsfelder,
   einschließlich noch unbekannter Tiererweiterungen, bleiben erhalten. Neue
   Felder sind erlaubt; beabsichtigte spätere Migrationen benötigen einen eigenen
   geprüften Vertrag statt gelöschter oder still ersetzter Bestände.
5. Erst nach erfolgreichem Commit Kamera/Steuerung und Fraktionsepoche wechseln.
   Fehler lassen den Ausgangsstand aktiv; Neustart erkennt den abgeschlossenen
   Übergang ohne zweite Vergabe von Vermächtnis.

Dieser Auftrag definiert und prüft die Erhaltungsregel an Einwohnern und
Tierdaten, implementiert aber ausdrücklich noch keinen produktiven
Mittelalter-/Neuzeit-Übergang. Der vorhandene bestätigte Wechsel 0 → 1 bleibt
aktiv und wird in den Regressionstests erneut durchlaufen.

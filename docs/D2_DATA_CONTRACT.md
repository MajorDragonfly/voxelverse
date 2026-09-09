# D2 – Individuelle Tiere, Vertrag 1

Status: Kampagnenadapter für die spielbare Stammesphase, zusätzlich eine
isolierte Prüfszene. Globales SaveGameService-Schema **7**; Tierregister und
D2-Kampagnenhülle jeweils **1**. Der Integrationschat übernimmt die gemeinsamen
Anschlüsse aus diesem Fachbranch, ohne ROADMAP.md hier zu ändern.

## Zuständigkeit und Voraussetzung

D1 besitzt Art-Eignung, eingefrorene Artkörper und Vorkommen. Zusätzlich zum
Vertrag `bb43b61482ab129b72a66b5299a6bfec80a1e128` ist seine abgeschlossene
Generator-/Spawnlieferung übernommen: lokaler Code `08fde2a4d496de2d4538508be5b77016fa7cd1c0`,
veröffentlichter Code `96c61f49213b9906b45b07e7ff3f5d3bb6d1d682`.
D2 konsumiert Vertrag 1 unverändert und führt keinen konkurrierenden Katalog.

`world/domestication/d1_taming_policy.gd` nimmt einen lesenden Resolver:
`species_id -> bestehendes species.domestication`. Er verwendet ausschließlich
`D1.validate()`, `tameable`, `diet` und `trainability` aus Vertrag 1.
Fehlende Arten, fehlender Resolver, ungültige Anatomie und unbekannte Versionen
geben keine Zähmung frei. Die Zuordnung tatsächlicher Inventarressourcen zu
D1-Nahrungsklassen liefert der Host, z. B. Wurzeln → plant.

Futterkosten und Vertrauensgewinn sind D2-Balance, keine neuen D1-Felder:
eine reale Inventareinheit pro abgeschlossener Gabe; zwei aktive Sekunden
Kontakt; Vertrauensgewinn `25 * clamp(trainability / 0.9, 0.1, 1)`.
Das D1-Beispiel für Begleiter benötigt vier Gaben bis 100 Vertrauen.

## Individueller Zustand

`animal_state.gd` validiert ein Register mit `schema = 1`, `campaign_id`,
`body_id` und `animals[object_id]`. Es führt keine Speziesdatenbank.

| Feld | Bedeutung |
|---|---|
| object_id, species_id, body_id | Stabile Objekt-, Art- und Körperidentität; Zähmung ändert sie nicht |
| design_ref.id / revision | Erhaltener Körperbezug; Revision 0 bezeichnet D1s eingefrorenen, nicht im Spielerregister versionierten Artkörper |
| surface_mode | In dieser Lieferung ausdrücklich legacy_plane_v9 |
| position, home, wait_position | Gespeicherte Positionen in Metern im benannten Adapter |
| status | wild / taming / tamed / dead |
| owner_faction_id | Besitzer erst nach vollständiger Zähmung; bleibt bei Tod als Historie erhalten |
| claim_faction_id | Reservierter Bestandsplatz während begonnener Zähmung |
| trust | 0–100; unabhängig vom Freundschaftsvertrauen |
| health | 0–100; 0 genau dann, wenn status = dead |
| hunger, thirst | 0–100; für D3 reserviert, keine Versorgungssimulation gehaltener Tiere |
| order | follow / wait / home |
| handler_id | Konkreter Betreuer für follow; kein bewegungsloser Gruppen-Cursor |
| pending | Aktiver Futterversuch mit Betreuer, Fraktion, Nahrung und aktiven Sekunden |
| equipment, cargo | Leere, reservierte Felder; nichtleere D3/D4-Daten werden in Schema 1 abgewiesen |

Gezähmte Tiere werden weder in `tribe.members` noch in `home_group.members`
aufgenommen. Es entstehen keine Bürger, keine neue Spielerart und keine
Sozial-/Stammespunkte. Der Kampagnenadapter übernimmt die tatsächliche Gesundheit. Er spiegelt spätere
Gesundheit/Tod über `ProgressionService.store_fauna_health()` zurück, damit D1s
Todes-/Ersatzregeln dieselbe ID erkennen. Beziehung, Freundschaftsvertrauen,
Belohnungen und Fähigkeiten werden dabei nicht verändert. Das Labor besitzt
einen separaten Befreunden-Prüfschalter.

## Controller und Transaktionen

`configure(registry, persist, checked_d1_adapter)` validiert und kopiert Daten.
Ohne D1-Adapter bleibt Lesen möglich, neue Zähmung wird abgewiesen.
`record(object_id)` und `owned_animals(faction_id, include_dead=false)`
liefern Kopien. Ein Buch oder eine Oberfläche darf diese lesend verwenden.

Der Host liefert pro Aktion vertrauenswürdigen Laufzeitkontext: aktuelle Phase,
Kampagne/Körper, eigene Spezies, Besitzerfraktion, lebenden Betreuer, Position,
Heimat, Bestand/Kapazität, Sicht und Bedrohung. Die UI darf diese Ergebnisse
nicht selbst behaupten. Sicht und Bewegung werden in Labor und Kampagne an realen Kollisionen geprüft.
Während einer Gabe muss der echte Betreuer ohne Ladung warten.

- Zähmung und Befehle verlangen Phase 1–5 und eine fremde Art auf demselben
  Körper. Produktiv sind nur tatsächlich spielbare Phasen zu aktivieren.
- Füttern verlangt höchstens 4,5 m Reichweite, Sicht, ein ruhiges lebendes Tier,
  passende Nahrung und Bestand. Diese Bedingungen werden während der Gabe
  und beim Abschluss erneut geprüft.
- Eine laufende Gabe kann nicht doppelt gestartet werden. Unterbrechung,
  Flucht, Wechsel des Betreuers oder Verlust von Reichweite/Sicht berechnen
  für die unfertige Gabe keine Kosten. Bereits bezahltes Vertrauen bleibt.
- Der erste unbezahlte Versuch gibt bei Abbruch den Bestandsplatz frei.
  Teilweise gezähmte Tiere reservieren weiter einen Platz. `abandon_claim()`
  gibt ihn frei, setzt das Zähmvertrauen zurück und erstattet kein Futter.
- `damage()` beendet die laufende Gabe. Tod bleibt als Datensatz erhalten,
  gibt den lebenden Bestandsplatz frei und verhindert weitere Befehle.
- Warten speichert den aktuellen Ort; Heimkehr verwendet den gespeicherten
  Heimatplatz (Kampagne: 1,5-m-Ankunftsbereich); Folgen referenziert den konkreten Betreuer.

Der Persistenz-Callback erhält `(proposed_registry, food_cost)`. Er muss
Tierregister UND echte Vorräte in derselben Transaktion prüfen und schreiben.
Nur nach erfolgreichem Callback ersetzt D2 seinen Stand und sendet
`animal_changed(object_id, code)`. Dieses Signal dient bestätigter UI-/Klang-
Rückmeldung, nicht der automatischen Vergabe von Entwicklungspunkten.
Ein fehlgeschlagener Save meldet keinen Erfolg und verbraucht kein Futter.

Bewegung und noch nicht abgeschlossene Sekunden werden im Speicher fortgeführt
und mit `checkpoint()` gemeinsam gesichert. Das Labor sichert zusätzlich alle
drei Sekunden sowie beim Schließen. Bei einem harten Abbruch können diese
letzten ungesicherten Sekunden/Bewegungen fehlen; abgeschlossene Futtergaben,
Besitz und Befehle sind bereits synchron gesichert. Es gibt keine Offline-Zeit.

## Begrenzte Prüfszene

`world/domestication/lab/domestication_lab.tscn` verwendet einen synthetischen,
sichtbaren Vierbeiner mit fester Test-ID und D1s Begleiter-Beispieleignung.
Sein einfacher Boxkörper ist kein Ersatz für den Kreatureneditor.
Ein echter CharacterBody3D läuft auf einer begrenzten Ebene um einen Collider
zu Betreuer/Heimat; ein AStarGrid2D beschreibt nur diese bekannte Prüffläche.
Der Adapter wartet bei nicht erreichbaren Zielen, ohne Teleportation.

Der Prüfstand `user://d2_lab/snapshot.json` enthält Tierregister, Futter und
Laboreinstellungen. Schreiben nutzt geprüfte temporäre Dateien und Ersetzung,
mit vorherigem gültigem Stand als .bak. Beschädigte Daten werden aus .bak
wiederhergestellt; unbekannte neuere Versionen sperren Laden/Überschreiben.
Kampagnen-Autosave und der SaveGameService-Schließhandler sind für diese Szene
gesperrt. Ein Sentinel-Test prüft, dass die Kampagnendatei unverändert bleibt.

## Kampagnenanschluss

`campaign_domestication.gd` hängt als Kind `Domestication` am vorhandenen
`Nest/Tribe` und verwendet dessen Mitglieder, Auswahl, Dorfnahrung und
Navigation. Der Tab „Tierhaltung“ teilt sich das bestehende HUD mit der
Dorfarbeit. Kein zweiter Pausenbesitzer, kein zweites Buch. Nahrung `food`
(Wurzeln) entspricht der D1-Klasse `plant`; weitere Inventare bleiben bei M6/D3.
Sechs lebende Tiere einschließlich begonnener Zähmungen sind erlaubt.

Der Body erhält optional:

```text
body.domesticated_animals = {
  schema: 1,
  registry: { schema: 1, campaign_id, body_id, animals: { object_id: record } },
  sources: { object_id: frozen_source }
}
```

`campaign_animal_state.gd` prüft die Hülle, gemeinsame Identitäten,
Stammesbesitzer/-betreuer und gespeicherte D1-Körper. `frozen_source` enthält
die unveränderte Herkunftsidentität einschließlich ursprünglicher `design_ref`,
den mit D1.encode gespeicherten Blueprint, Maßstab, Körperoffset, Blickrichtung,
Art-/Individuumsseed, Anzeigename, ökologische Rolle, Geschwindigkeit,
Maximalgesundheit und Ende der Fluchtzeit. Die Tierinstanz wird beim Laden
aus diesem Körper gebaut, ohne den Generator erneut aufzurufen.

Der erfolgreiche Start einer Futtergabe reserviert das Objekt im gemeinsamen Save,
entfernt die wilde Instanz und ersetzt sie durch `campaign_animal.gd` unter
derselben `object_id`. Wildtier-KI und Sozialkomponente besitzen diese Instanz
anschließend nicht mehr. Sie gehört ausschließlich zu D2. Der Spawner prüft
bereits den geladenen Body auf diese ID, auch bevor der Stamm aufgebaut ist;
das gilt für beanspruchte, gehaltene, aufgegebene und tote Datensätze.
D1 darf nach dem gespeicherten Tod später einen **neuen** Habitatvertreter
mit neuer ID erzeugen; der alte Tierdatensatz bleibt tot.

`_persist(registry, food_cost)` schreibt Tiere, eingefrorene Körper und den
wirklichen `tribe.stock` durch **einen** SaveGameService-Aufruf. Bei einem
Schreibfehler werden Stock, Hülle und Gesundheitsspiegel zurückgenommen;
der Controller bestätigt weder Besitz noch Vertrauen noch Auftrag.
`save_started` übernimmt aktuelle Positionen und unvollständige Futtersekunden
in den normalen Kampagnensnapshot. Es entsteht keine zweite Kampagnendatei.
Alte Saves ohne Hülle bleiben ohne Tiere. Schema 7 schützt neue Tierstände vor
alten Builds, die gehaltene IDs beim Spawnen noch nicht kennen. Unbekannte
neuere Hüllen/Register werden vor Backup-Rückfall und Überschreiben gesperrt.

Wilde KI, Pflanzen-/Wassersuche und Pflanzenstreaming laufen gezielt auch in
Phase 1. Phase-0-Spielerangriffe und Sozialinteraktionen bleiben dort gesperrt;
Schadensspeicherung erhält einen eigenen Gesundheitspfad ohne Sozialpunkte.
Gezähmte Tiere verwenden Bodenprüfung, lokale Kollisionslenkung und das
vorhandene Dorfwegenetz. D2 erweitert dessen geprüfte Fläche auf 20 Meter
um den Dorfplatz; Annäherungsziele bleiben höchstens 20 Meter entfernt
und damit im vorhandenen 22-Meter-Speichervertrag für Bürger. Normale
Bewegungsbefehle behalten ihre 18-Meter-Grenze. Unbekannter Boden oder blockierte Wege führen zum
Warten. Die Kugeloberfläche benötigt einen separaten Adapter.

## Lesende Anschlüsse und weitere Pakete

- Laufzeitgruppe `domestication_runtime`; `controller.record(id)` und
  `controller.owned_animals(faction_id)` geben Kopien für Buch/Oberfläche zurück.
- Ohne geladene Szene: validierte Body-Hülle über `campaign_animal_state.FIELD`;
  `lookup(state, object_id)` dient dem Spawner, sein Ergebnis nicht verändern.
- `controller.animal_changed(id, code)` bestätigt abgeschlossene Transaktionen.
- D3 besitzt Versorgung, Milchproduktion und Transport; D4 Reiten/Pflügen.
  D2 vergibt keine Produktionsgüter und behauptet keine nutzbaren Reitanschlüsse.
- Aktuell ist nur die spielbare Phase 1 aktiv. Spätere Epochen müssen ihren
  eigenen Gruppen-/Bewegungsadapter anschließen; gespeicherte Tiere bleiben
  dabei Teil des Body-Snapshots.

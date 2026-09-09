# D2 – Individuelle Tiere, Vertrag 1

Status: überprüfbare, eigenständige Prüfszene plus D1-Adapter. Noch keine
Freigabe für die produktive Kampagne. Die endgültigen Einbaupunkte bleiben
beim Integrationschat; es gibt keine Änderung am globalen Speicherschema.

## Zuständigkeit und Voraussetzung

D1 besitzt die Art-Eignung. Übernommen wurde ausschließlich der abgeschlossene
Vertrags-Commit `bb43b61482ab129b72a66b5299a6bfec80a1e128` aus Auftrag 3.
Sein unveränderter Vertragstest wurde hier erneut ausgeführt. Generator,
Vorkommen, Kampagnenmigration und Spawner des laufenden D1-Arbeitszweigs sind
nicht Bestandteil dieser Lieferung.

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
| design_ref.id / revision | Referenz auf den erhaltenen konkreten Körperentwurf |
| surface_mode | In dieser Lieferung ausdrücklich legacy_plane_v9 |
| position, home, wait_position | Gespeicherte Positionen in Metern im benannten Adapter |
| status | wild / taming / tamed / dead |
| owner_faction_id | Besitzer erst nach vollständiger Zähmung; bleibt bei Tod als Historie erhalten |
| claim_faction_id | Reservierter Bestandsplatz während begonnener Zähmung |
| trust | 0–100; unabhängig vom Freundschaftsvertrauen |
| health | 0–100; 0 genau dann, wenn status = dead |
| hunger, thirst | 0–100; im D2-Labor reserviert, keine Versorgungssimulation |
| order | follow / wait / home |
| handler_id | Konkreter Betreuer für follow; kein bewegungsloser Gruppen-Cursor |
| pending | Aktiver Futterversuch mit Betreuer, Fraktion, Nahrung und aktiven Sekunden |
| equipment, cargo | Leere, reservierte Felder; nichtleere D3/D4-Daten werden in Schema 1 abgewiesen |

Gezähmte Tiere werden weder in `tribe.members` noch in `home_group.members`
aufgenommen. Es entstehen keine Bürger, keine neue Spielerart und keine
Sozial-/Stammespunkte. D2 liest oder verändert den Begegnungs-/Freundschaftsstand
nicht. Das Labor besitzt lediglich einen separaten Befreunden-Prüfschalter.

## Controller und Transaktionen

`configure(registry, persist, checked_d1_adapter)` validiert und kopiert Daten.
Ohne D1-Adapter bleibt Lesen möglich, neue Zähmung wird abgewiesen.
`record(object_id)` und `owned_animals(faction_id, include_dead=false)`
liefern Kopien. Ein Buch oder eine Oberfläche darf diese lesend verwenden.

Der Host liefert pro Aktion vertrauenswürdigen Laufzeitkontext: aktuelle Phase,
Kampagne/Körper, eigene Spezies, Besitzerfraktion, lebenden Betreuer, Position,
Heimat, Bestand/Kapazität, Sicht und Bedrohung. Die UI darf diese Ergebnisse
nicht selbst behaupten. Im Labor stammt Sicht aus einem echten Physik-Ray.

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
  Heimatplatz; Folgen referenziert den konkreten Betreuer.

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

Produktiv muss der vorhandene SaveGameService das optionale Tierregister im
gemeinsamen Kampagnensnapshot validieren. Die Labordatei ist dafür ausdrücklich
kein Anschluss und darf nicht als zweiter Kampagnenspeicher übernommen werden.

## Noch erforderliche Integration

1. Abgeschlossene D1-Katalog-/Spawnlieferung prüfen: Auflösen bestehender Art-
   und Körperentwürfe, erreichbare Vorkommen, Wiederbesuch und Ersatzregeln.
2. Aktive Phase-1-Fauna freigeben: `creatures/ai/wildlife_brain.gd`,
   `foraging_brain.gd` und `drinking_brain.gd` besitzen Phase-0-Grenzen.
   `creature_social_component.gd` begrenzt außerdem Interaktionen und
   Schadensspeicherung. Diese Grenzen dürfen nicht pauschal entfernt werden.
3. Wildes Individuum unter derselben object_id an D2 übergeben, Encounter-
   Gesundheit übernehmen, wilde KI abschalten und genau einen Zustandsbesitzer
   festlegen. `fauna_streamer_v7.gd` muss beanspruchte, gezähmte und tote
   D2-IDs berücksichtigen, damit nach Despawn/Neustart keine Doppeltiere entstehen.
4. Konkreten lebenden Stammesbewohner als Betreuer auswählen. Die bestehende
   Phase-0-Spielerangriffslogik darf nicht auf den Gruppen-Cursor wirken.
5. `tribe.stock` und Tierregister gemeinsam über SaveGameService schreiben,
   Altstände ohne Register unverändert als leer behandeln, fremde neuere
   Schemata schützen. Globale Schemaänderung beim Integrationschat koordinieren.
6. Buch/Klang lesen das Register bzw. bestätigte Ereignisse. D3 implementiert
   Versorgung/Produktion; D4 prüft tatsächliche Sattel-/Geschirranschlüsse.

Die vollständige D2-Kampagnenabnahme bleibt bis zu diesen Anschlüssen offen.

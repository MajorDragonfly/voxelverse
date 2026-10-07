# R33-06 — persönlicher Bewohnerbesitz (#206)

Feste Fachbasis: `94de70cacd250337976b8f63031fff4afc72e2bb`, Tree
`58506a6feba11be547197223fa319e7265cf4d99`. Fachbranch:
`agent/r33-06-resident-equipment`; Draft #275 gegen R33-Integration.
AGENTS.md, R33-Zuordnung #137 und integrierte Bewohnerdetail-Lieferung #258
sind die Grundlage. Technische Fachlieferung; Ziel-PC/Spielkomfort bleibt offen.

## Besitz und Herstellung

Ein fertig hergestellter Gegenstand hat eine stabile Dorf-/Sequenz-ID,
Herstellungsrevision und genau einen Besitzerort. `owner_id=""` bedeutet freier
Dorfbestand; eine Bewohner-ID bedeutet dessen persönlichen Werkzeug- oder
Kleidungsplatz. Der Platz folgt dem Gegenstandstyp, maximal ein Gegenstand je
Bewohner und Platz. Es gibt keine zweite Bestandstabelle im Bewohner oder UI.
Auswahl reserviert nichts. Ausstattung prüft die aktuelle freie ID erneut;
Wechsel gibt die bisherige ID frei, Rückgabe behält ID/Revision/Gegenstand.
Rückgabe erzeugt keine Rohstoffe. Maximal 48 fertige Gegenstände pro Dorf.

Das bisherige Dorf-`tools` bleibt sein gespeicherter Technologie-/Arbeitsport.
Es wird niemals als persönlicher Besitz angezeigt, kopiert oder migriert.
Die erste Handwerksaktion ist unmittelbar am Dorfplatz, mit leerer Fracht und
ohne Bau-/Pflege-/Siedlungstransportbindung. Voraussetzung: bereits tatsächlich
hergestellte gemeinsame Werkzeuge. Material kommt ausschließlich aus aktuellem
spendbarem `stock`; bestehende Bau-/Transportreservierungen, Fracht und
Kapazitätsreservierungen werden nicht als freies Material ausgegeben.

| Herstellungsrezept, Revision 1 | Materialverbrauch | Fertiger Gegenstand |
|---|---|---|
| `equipment.stone_tool` | 3 Holz, 2 Stein | 1 Steinwerkzeug im freien Dorfbestand |
| `equipment.wooden_tool` | 2 Holz, 1 Faser | 1 Holzwerkzeug im freien Dorfbestand |
| `equipment.fiber_tunic` | 4 Fasern | 1 Fasertunika im freien Dorfbestand |

Rezepte ergänzen den vorhandenen Produktionskatalog. Holz/Stein stammen aus
vorhandener Arbeit; Fasern aus dem bestehenden kostenpflichtigen Faserbeet.
Die neue Tunika hat damit einen echten Material- und Besitzpfad. Es gibt keine
neue Bonusverwaltung: bestehende gemeinsame Werkzeug-/Arbeits-/Kooperationseffekte
bleiben an ihren bisherigen Stellen. Kleidung erzeugt weder erfundene Gesundheit
noch Wettereffekte. R33-07/R33-01 besitzen diese Anschlüsse.

## Save, Schema und Lebenszyklus

Optionaler Dorf-Untervertrag `resident_equipment`, Schema 1:

```json
{"schema":1,"next_sequence":1,"items":{}}
```

Jeder Eintrag hat genau `id`, `sequence`, `kind`, `recipe_id`, `recipe_revision`,
`owner_id`. Kein unabhängiger Tribe-/Economy-Schemabump. Altstände ergänzen nur den
leeren Untervertrag; bestehende Bewohner, Werte, Ressourcen und Fremdfelder bleiben
unverändert. Herstellung/Ausstattung/Wechsel/Rückgabe benutzen den vorhandenen
SaveService-Transaktionsport; Schreibfehler stellen den gesamten kanonischen
Vorstand wieder her, einschließlich Material, Sequenz und beider Besitzplätze.
UI/Runtime behalten keine lebenden Dorf-/Bewohner-/Actor-Dictionaries über Loads.

Validierung prüft Mengenlimit, lückenlose Herstellungssequenz, stabile ID,
unterstützte Rezeptrevision, eindeutige Bewohnerbindung und einen Gegenstand pro
Platz. Bezahlte Gegenstände bleiben in der Rohstoffbilanz enthalten:
`remaining + stock/cargo + equipment_spent <= original + produced + freight.net`.
Nach R33-05 kommt rechts dessen **kanonisches** `LocalSources.initial` hinzu;
`Economy.remaining` enthält links bereits deren restliche Einheiten. Kein zweiter
Quellenzähler, keine Wiederauffüllung. Siehe seriellen Patch unten.

Neuere Unterverträge und unbekannte/neue Rezeptrevisionen werden vor Backupfallback
und Schreibversuch geschützt, auch in einer nicht ausgewählten Siedlungsinstanz.
Körper-/Nah-/Fern-/Actorwechsel ändern keinen Besitz. Gegenstände sind zunächst
lagerlokal: ein ausgerüsteter Siedlungsgründer muss am alten Lager zurückgeben,
bevor er das Dorf verlässt. So gibt es weder impliziten Gegenstandstransport noch
verwaiste Besitzer. Abbau/Zerstörung und Gegenstandstransport zwischen Dörfern sind
nicht Bestandteil dieses ersten Pfads.

## Serielle Besitzeranschlüsse für R33-01

Produktionsdateien außerhalb der exklusiven Blätter sind im Fachbranch unangetastet.
`patches/owners.patch` verbindet TribeState, Produktionskatalog, Save-Futureguard,
Settlement-Futureguard/Gründer, Controller, TribePanel-Callables und das bestehende
begrenzte Long-Test-Budget. `localization-append.json` ergänzt 30 DE/EN-Nachrichten;
`test-registry-append.json` registriert genau die drei eigenen Fachtests einmal im
Vertrag `village`. Der Helfer `tools/review_r33_06_overlay.py` wendet diese ausschließlich
in einem separaten QA-Checkout an und lehnt seinen eigenen Fachcheckout ab.

Mit R33-05 abgeglichen in #137, Kommentar 6036443175: erst dessen Quellen-/Economy-
Ports, dann die 06-Ports, dann `patches/after-r33-05.patch` für den einzigen
Bilanzleseanschluss. Die eigenen Lifecycle-Prüfungen führen dann zusätzlich echte
örtliche Entnahme/Fracht/Lieferung, bezahltes Werkzeug und JSON-Restore aus; ohne
05 wird dieser Fall ausdrücklich als noch nicht angewendeter kombinierter Umfang
ausgegeben. Gemeinsame Schema-/Wirtschaftsquellen bleiben bei R33-01/05.

Opt-in `.github/workflows/r33-06-equipment-review.yml` ist nur als Patchvorlage hier
und tatsächlich ausschließlich im Diagnose-Draft #278. Dieser Branch enthält keine
Produktimplementierung und darf nicht als Featuremerge verwendet werden. Er baut
an einer festen Quell-SHA den isolierten QA-Tree und bewahrt Originalartefakte.

## Prüfung und Grenzen

Die eigenen Fachtests prüfen zwei Bewohner/letzte freie ID, bezahlte Materialien,
Wechsel/Rückgabe, Bau-/Frachtreservierung, fremde/mehrdeutige Besitzer, Migration,
Futureguard, den vorhandenen radialen Siedlungs-/Körperadapter und Nah/Fern.
`r33_06_equipment_ui_test` verwendet tatsächliche Maus-/Popup-Tastaturereignisse,
physische Sammel-/Bauwege, echte Save-Schreibfehler samt Bytes/komplettem Rollback,
Actorrekonstruktion und einen frischen Godot-Prozess. Die Layoutmatrix umfasst
DE/EN × 800×600/1280×720/1920×1080 × 100/125/150 %, 36 Originalcaptures.
Die gesonderte `review_r33_06_sphere.gd` nutzt Titel/Playtest/Kugelkampagne, echte
Materiallieferung, gemeinsame Werkzeugproduktion, persönliche Herstellung/
Ausstattung und Titel/Load; keine gratis vorbereiteten Gegenstände oder Vorräte.

Ergebnis-/Quell-/Tree-/Lognachweise werden nach dem abgeschlossenen Lauf ergänzt.
Negative Originale werden erhalten. Vollsuite, gemeinsamer Merge-Tree, Reise-/Export-
kette und native Exporte gehören zur R33-01-Integration. Software-GL-Bilder sind
kein Ziel-PC-/FPS-/Spielkomfortnachweis. #206 wird durch diesen Draft nicht geschlossen.

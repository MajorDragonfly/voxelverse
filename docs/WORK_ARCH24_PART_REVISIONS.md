# ARCH-24-PART-REVISIONS

Basis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8`, Integrationskandidat
`agent/integration-vegetation-nest-20260915` / PR #110. Fachbranch:
`agent/arch24-part-revisions-20260915`.

## Ergebnis und Vertrag

Gespeicherte Kreaturen referenzieren ihre vorhandenen Modelle ausdrücklich.
Mund-/Kopfmodelle, Füße, Hände und deren Gelenke lösen die gespeicherte
Teilrevision über denselben Kataloganschluss auf. Diese Lieferung verändert
keine Modellgeometrie, Spielwerte, Freischaltungen oder Artenkennungen.

| Bezug | Gespeicherte Felder | Aktuell unterstützt |
|---|---|---|
| Körper, Hautauswahl, platziertes Teil | `part_revision`, `catalog_revision` | 1 |
| Hand/Fuß am Arm/Bein, auch implizites Standardendstück | `end_part_revision`, `end_catalog_revision` | 1 |
| Ganzer Entwurf | bestehende `design_id`, `assembly.revision` | unverändert |

Fehlende Revisionsfelder bedeuten immer den eingefrorenen Modellstand 1,
niemals einen künftig aktuellen Katalogstand. Die Serializer ergänzen die
Felder auf einer Kopie. Alte unveränderte Wildartengeneratoren und ihre
eingefrorenen Hashes behalten deshalb ihren bisherigen Inhalt. Bereits
explizite Referenzen bleiben auch durch den Basis-/V5-Adapter erhalten.
JSON-Zahlen für Referenzen werden als ganze Zahlen kanonisiert.

Der bestehende `BlueprintContract.version_error()` erkennt unbekannte sowie
ungültige Revisionswerte vor Normalisierung. Das erreicht die vorhandenen
DesignStore-/SaveService-Sperren: keine Ersatzkopie über ein neueres Original,
kein Rückfall auf ein älteres Kampagnenbackup. Vorschau und Körperanschlüsse
interpretieren unbekannte Revisionen nicht. Der Editor prüft vor der
Fortschrittssynchronisation und vor jeglicher Speichernormalisierung.

Portable Pakete/Bibliotheken übernehmen die Referenzen. Die zusätzlichen
Felder sind optional, damit bisherige Pakete lesbar bleiben. Eine alte
Referenz ohne Feld und die explizite 1 sind für den Duplikatvergleich gleich;
die alte Datei bleibt dabei unverändert. Andere Inhaltsunterschiede bleiben
Revisionskonflikte. Die bereits integrierte Kategorie `head` ist auch im
portablen Schema zugelassen.

## Erweiterungsregel

Vor Modellrevision 2 zuerst einen expliziten Resolver für beide Revisionen
und ihre jeweiligen Geometrierezepturen liefern. Katalogannahmen in
`creature_part_revisions.gd` und im portablen Schema nur zusammen erweitern.
Neue Auswahl muss die gewünschte Revision ausdrücklich setzen; historische
Referenzen und die Bedeutung fehlender Felder bleiben bei Revision 1.
Ein höherer globaler Katalogzähler allein ist keine Migrationsstrategie.

Die bisherige Behandlung fehlender Teil-IDs mit erhaltenem `missing_part_id`
bleibt bestehen. Dieses Paket ersetzt sie nicht durch einen neuen Katalog
oder einen automatischen Modell-Upgradepfad. Gebäude-/Schiffsrevisionen
bleiben bei ihren bisherigen Verträgen.

## Prüfung und Übergabe

Ein neuer registrierter Test prüft ungültige/future Referenzen an allen
Speicherstellen, konstante Meshdaten, Editor mit Undo/Redo, Bibliotheksduplikate,
Schreibfehler, Original-/Backupschutz und einen neuen Godot-Prozess.
Bestehende Modell-/Katalognachweise bleiben erhalten. Die Neustartvergleiche
verwenden nun den vollständigen Speichervertrag mit den Revisionsfeldern;
der alte ARCH-23-Test für beliebige opaque Kreaturenrevision 3 verwendet
jetzt unterstützte Revision 1, während der neue Test Revision 3 und andere
unbekannte Werte ausdrücklich sperrt. Gebäuderevisionen bleiben unverändert.

Gezielte Fachprüfung mit Godot 4.6.3, Linux Headless und isolierten synthetischen
Nutzerdaten. Exakte Quellrevision, Befehle, Ergebnisse und ursprüngliche
Entwicklungsbefunde werden unter `docs/evidence/arch24-part-revisions/` ergänzt.
Der automatische Diffplan verlangt wegen der gemeinsamen Testregistry eine
Gesamtprüfung; hier wird gemäß Fachworkflow eine explizite Auswahl direkter
Verbraucher geprüft. Gemeinsame CI-/Merge-, native Export-, Grafik- und
Ziel-PC-Abnahme gehören weiterhin zur Integration.

Schreibbereiche: Kreaturen-Speicheradapter, gemeinsamer Blueprint-Vertrag,
Geometrie-/Vorschaugrenzen, Editor-Speichergrenzen, portables Schema und
Bibliotheksvergleich. Keine zentralen Status-/Roadmap-Häkchen geändert.

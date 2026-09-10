# Bauplanvertrag und Versionsschutz (ARCH-23)

Stand: 10. September 2026. Basis: `main` `ea900f2e09946660694a9e59399b4680a5655a85`.
Dieses Paket ändert weder Kampagnen- noch Bauplanschemata. Es sichert die bestehenden
Leser, Migrationen und Schreibwege. Onlineaustausch bleibt BP-COMMUNITY.

## Besitzer und Schnittstellen

| Inhalt | Autoritativer Besitzer / Anschluss |
|---|---|
| Kreaturentwurf | `creature_assembly_blueprint_v7.gd`; `version=7`, `assembly.schema=7`, `design_id`, `assembly.revision` |
| Generischer Bauplan / Gebäude | `modular_assembly.gd`; `schema=1`, `design_id`, `revision`; Gebäude zusätzlich `building.schema=1` |
| Körperanschlüsse / Reiterprofil | Bestehender B1/B3-Vertrag unter `assembly.body_attachments`, jeweils Schema 1 |
| Originaldatei / gemeinsamer Slot | `DesignStore` liest den aktiven Slot, andernfalls die lose Datei. `SaveGameService` besitzt den atomaren Kampagnenabschluss. Kein zweiter Speicherbesitzer. |
| Prüfung | `blueprint_contract.gd`: `version_error`, `inspect`, `inspect_text`; reine Prüfung, `{ok, code}`, keine Mutation und keine Normalisierung |
| Migration | Kreatur: `migrate_snapshot(data, legacy_key)`; modular: `deserialize(data)`; Gebäudeleser sichert zuvor die alte Design-ID über den bestehenden Pfadvertrag |
| Darstellung / Instanz | Gebäudevorschau hält eine tiefe Kopie. Der vorhandene Registry-Anschluss referenziert `design_id` + `revision`; Objekt-/Besitz-ID bleibt bei der Kampagne. |

## Lesen, Migrieren, Normalisieren

1. Vor Interpretation oder Normalisierung die Version prüfen. Fehlende Versionsfelder
   sind unterstützte Altdaten; bekannte positive ganzzahlige Kreaturversionen bis 7
   nutzen den vorhandenen Migrationsweg. Generisches/Gebäudeformat bleibt 1.
2. Unbekannte neuere oder ungültige Versionen einschließlich verschachteltem
   Gebäude-, Assembly-, Anschluss- und Reiterformat werden abgewiesen. Normalisieren
   darf solche Daten nicht auf heute bekannte Versionsnummern zurücksetzen.
3. Struktur und Aufwand prüfen, dann ausschließlich eine Kopie migrieren. Vorhandene
   IDs/Revisionszahlen bleiben erhalten. Fehlende alte Teil-UIDs werden deterministisch
   aus Design-ID bzw. stabiler Quellkennung und Teilindex ergänzt. Dateien werden beim
   Lesen nicht neu geschrieben. Für ID-lose Legacy-Kreaturen einen stabilen `legacy_key`
   übergeben; ein neuer Entwurf darf weiterhin eine neue ID erhalten.
4. Normalisierung bleibt eine interne Operation für unterstützte Entwürfe. Sie ersetzt
   weder Validierung noch einen Fremddatenimport. Der bestehende Ersatz unbekannter
   Teile erhält `missing_part_id`, Lage und Erweiterungsdaten; das Original bleibt
   bis zu einer ausdrücklich erfolgreichen Speicherung unverändert.

`serialize_snapshot` ist rein. Erfolgreiches explizites Speichern übernimmt wie bisher
die normalisierten Werte in den offenen Entwurf; bei Schreibfehler bleiben Inhalt und
Revision unverändert. Gebäude `save_design` erhöht die Revision erst mit erfolgreichem
Commit. Nach Undo nimmt das nächste Speichern mindestens die gespeicherte Revision
desselben Designs als Ausgangspunkt. Der bestehende Kreatureneditor hält seine bereits
geprüfte Revisionsobergrenze und Undo-Historie weiter selbst.

## Schutz von Originalen

`DesignStore.write` prüft den neuen Entwurf und vor jedem Schreibversuch sowohl den
aktuellen Slotinhalt als auch eine vorhandene lose Zieldatei. Unlesbare, übergroße oder
neuere Originale sperren das Überschreiben, bevor `AtomicJson` temporäre Dateien oder
Backups anlegt. `write_status(path)` liefert die stabile Fehlerkennung. Der V5-Schreibweg
verwendet ebenfalls den bestehenden atomaren Store.

Der Kampagnenleser erkennt nun auch neuere Gebäudeschemata und verschachtelte
Kreaturenverträge: kein stiller Rückfall auf ein älteres Backup, keine nachträgliche
ID-Vergabe in einem geschützten Original. Ein beschädigter/neuerer ausgewählter
Kreaturentwurf erhält nur eine gekennzeichnete temporäre Vorschau. Sie ist nicht
speicherbar; der reguläre Kugelstart meldet den Ladefehler vor jedem Entwurfs-Commit.

## Erweiterungen und Aufwand

- Bestehende Spielregeln bleiben erhalten, insbesondere 100 Formpunkte im
  Kreatureneditor. Die technischen Einlesegrenzen schaffen keine neue Baukapazität.
- Ein lokaler Bauplan darf höchstens 2 MiB JSON, 2.048 Teile, 24 Verschachtelungsstufen
  und 100.000 Werte enthalten. Nichtendliche Zahlen, doppelte vorhandene Teil-UIDs,
  fehlerhafte Transformdaten und nicht unterstützte Laufzeitobjekte werden abgewiesen.
- Für additive deklarative Daten dient `extensions` an Entwurf, Körper, Farbe und Teil.
  Erweiterungen enthalten ausschließlich endliche JSON-Werte; Namensräume wie
  `org.voxelverse.example` vermeiden Kollisionen. Sie werden beim V7-/Gebäude-Rundlauf
  erhalten, aber nicht als Skript, Assetpfad oder Spielregel interpretiert.
- Optionale `part_revision` und `catalog_revision` bleiben erhalten. Ihre Speicherung
  ist noch kein historischer Geometrieanbieter: neue Teilrevisionen benötigen im
  Fachkatalog später eine explizite kompatible Auflösung und Fähigkeitenprüfung.
- Eine Downloadrevision darf eine vorhandene Instanz nicht automatisch umbauen.
  Bestehende Vorschauen/Instanzen verwenden eigene Kopien; künftige gespeicherte
  Objektinstanzen müssen ihren konkreten Bauplan und seine Revision referenzieren.
- `CreatureAssemblyAdapter` bleibt eine gerichtete Darstellungshilfe. Er behält
  Design-ID/Revision, lehnt Zukunftsdaten ab und markiert `adapter_only=true`.
  Ein vollständiger Rückimport von Kreaturen ist damit **nicht** implementiert.

## Anschluss für BP-COMMUNITY.1 (noch kein Importdienst)

Der spätere portable Umschlag braucht eine eigene Formatversion und mindestens
`blueprint_id`, `revision`, `kind`, `payload_schema`, deklarativen `payload`,
Quell-/Katalogrevisionen und optionale geprüfte Vorschau. Bauplanidentität ist keine
Tier-, Bürger-, Besitzer-, Fraktions- oder Weltobjektidentität.

Der Import muss eine explizite Feld-Positivliste verwenden. Der lokale V7-Speicher
enthält auch `progression` und Editorzustände und darf deshalb nicht unverändert als
Community-Datei verschickt werden. Skripte, Szenenpfade, ausführbare Ressourcen,
Fortschritt, Weltorte, Besitz und Spielstanddaten gehören nicht in den portablen
Vertrag. Vorschauen werden separat in Format und Größe begrenzt; die obigen lokalen
Grenzen sind Obergrenzen für den künftigen Payload. Teile/Fähigkeiten, Formpunkte und
Kosten müssen gegen die lokal installierten Kataloge und die aktuelle Spielphase
geprüft werden. Quelle und heruntergeladene Revision bleiben offline erhalten.

Erst ein nachgewiesener vollständiger Kreaturenexport **und** Rückimport erfüllt
BP-COMMUNITY.1. Galerie, Upload, Download und Gebäude-/Schiffeditoren bleiben deren
eigene Arbeitspakete. ARCH-23 stellt dafür die Versions- und Originalschutzgrenze.

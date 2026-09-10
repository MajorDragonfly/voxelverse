# Portabler Kreaturenbauplan (BP-COMMUNITY.1)

Stand: 10. September 2026. Dieses Paket implementiert den dateibasierten Austauschvertrag
auf dem V7-Vertrag aus ARCH-23. Die Fachplanung liegt in
[COMMUNITY_DESIGNS_PLAN.md auf dem Planungsbranch](https://github.com/MajorDragonfly/voxelverse/blob/agent/roadmap-eggs-animal-parts-2026-09-09/docs/COMMUNITY_DESIGNS_PLAN.md).
Der Planungsbranch wird dadurch nicht integriert.

## Schnittstelle und Besitzer

`assembly/exchange/creature_blueprint_package.gd` stellt reine Vorbereitung und
portable JSON-Dateien bereit. `creature_package_schema.gd` beschreibt die geschlossene
Feldliste und Einlesegrenzen. V7 bleibt der einzige Kreaturen-Codec; Vorschau und
Spiel verwenden weiterhin `CreatureRuntimePreview` und den bestehenden Teilekatalog.

| Aufruf | Ergebnis / Wirkung |
|---|---|
| `export_blueprint(committed_blueprint, metadata)` | `{ok, package}` oder Fehler. Exportiert eine Kopie des gespeicherten Entwurfs; Metadaten erlauben nur Titel, Beschreibung, Autor und Tags. |
| `inspect(package)` | Prüft Schema, Katalog, Geometriewerte und Verbindungen; liefert eine native V7-`preview`, lokal berechnete `stats` und `required_parts`. Ändert keinen Spielstand. |
| `decode(text)` / `read_file(path)` | Begrenztes JSON lesen und vollständig prüfen; nur bei Erfolg `{ok, package}`. Dateigröße vor dem Einlesen prüfen. |
| `write_file(path, package)` | Geprüfte Kopie atomar schreiben. Eine vorhandene identische Datei ist ein erfolgreicher Leerlauf. Andere/neue Revisionen benötigen einen anderen Dateinamen. |
| `prepare_import(package, current, phase, unlocked_parts)` | Neue native `blueprint`-Kopie oder Fehler; lokale Phase/Freischaltungen stammen vom vertrauenswürdigen Aufrufer. |
| `prepare_for_active_editor(package, current)` | Liest lokale Phase und Freischaltungen aus den bestehenden Autoloads; lehnt fehlende aktive Kampagnen und laufende Epochenübergaben ab. |

Fehler enthalten `ok=false`, eine stabile `code`-Kennung und gegebenenfalls `field`,
`item` oder `missing_parts`. Sie erzeugen keinen Ersatzentwurf. Unbekannte Teile
werden hier abgewiesen; der verlustbehaftete lokale Legacy-Ersatz wird nicht zur
Interpretation heruntergeladener Vorlagen verwendet.

## Umschlag und vollständige Formdaten

| Feld | Bedeutung |
|---|---|
| `schema=1`, `kind="creature"` | Austauschformat und einziger unterstützter Objekttyp |
| `design_id`, `revision` | Quellentwurf und konkrete gespeicherte Revision; unabhängig von Kampagnen-/Speziesidentität |
| `catalog_revision=1` | Unterstützte Ausgangsgeneration des eingebauten Kreaturenkatalogs |
| `title`, `description`, `author`, `tags` | Explizite öffentliche Metadaten; Autor ist eine Angabe, keine geprüfte Accountidentität |
| `required_parts` | Sortierte, eindeutige Liste sämtlicher tatsächlich verwendeter Körper-, Farb-, Anbau- und Endteile |
| `provenance` | Bis zu acht Quellen mit Design-ID, Revision und Autor; kein beliebiger Erweiterungspayload |
| `blueprint` | Geschlossene Teilmenge des nativen V7-JSON; `version=7`, `assembly.schema=7` |

Übertragen werden Körper-ID, Form und Skalierung, alle sieben Wirbelsäulenpunkte,
Körperlänge, Farbmuster und Intensität, fünf optionale Farben, Hauttyp/-stärke/-maßstab,
sämtliche Teil-UIDs und Teil-IDs, Positionen/Rotationen/Skalierungen, Spiegelung,
Zentrumsbindung, Gliedmaßen- und Endteilform, Gelenkprofil, Oberflächenanker samt
manuellen Offsets, Sockettyp und Paarverweise. Die drei Körperanschlüsse und das
optionale Reiterprofil bleiben in ihrem vorhandenen B1/B3-Schema erhalten.

`progression`, Weltorte, Inventare, Tiere, Besitzer, Kampagnen-, Spezies-, Fraktions-
und Objekt-IDs werden nicht übernommen. Editorwahl, Cursor/Zähler und beliebige
lokale `extensions` werden nicht exportiert. Die einzige erlaubte Herkunftserweiterung
ist `extensions["org.voxelverse.community_blueprint"]` mit Schema 1 und `sources`;
ihre geprüfte Quellenliste wird beim erneuten Export weitergegeben.

Die Kataloggeneration 1 bedeutet keine universelle Auflösung historischer Teilmodelle.
Unbekannte IDs sowie ausdrücklich andere lokale `part_revision`/`catalog_revision`
werden abgewiesen. Bei inkompatiblen Änderungen bestehender Teilgeometrie muss der
Kataloganschluss eine neue Generation beziehungsweise einen expliziten historischen
Resolver einführen. Der laufende ARCH-24-Umbau wird hier nicht vorweggenommen.

## Prüfung und Übernahme

Die Feldliste gilt rekursiv: keine Skripte, Ressourcen-/Szenenpfade, hochgeladenen
Statistiken oder unbekannten Zusatzfelder. Körper- und Teilkategorien müssen zum
installierten Katalog passen; Füße passen nur an Beine, Hände nur an Arme. Teil-UIDs
sind eindeutig. Explizite Paarverweise sind vorhanden, gegenseitig und von derselben
Kategorie. Wirbelsäulenpunkte müssen geordnet sein; Transform-, Farb-, Gelenk-,
Anschluss- und Reiterwerte werden vor der Migration auf erlaubte Typen und Bereiche
geprüft. Neuere oder beschädigte Pakete bleiben unverändert erhalten.

Technische Grenzen: 2 MiB JSON, 256 Anbauteile, 96 Zeichen je ID, 120 UTF-8-Bytes je
Titel/Autor, 2.000 für die Beschreibung, zwölf Tags mit jeweils 40 Bytes und acht
Herkunftseinträge. Die feste rekursive Struktur begrenzt zusätzlich Tiefe und Wertezahl.
Diese Grenzen erhöhen das unveränderte Spielbudget von 100 Formpunkten nicht.
Eine Vorschau darf ein formal gültiges Design über diesem Spielbudget beschreiben;
`prepare_import` lehnt seine Übernahme ab. Auch Endteile brauchen lokale Freischaltung.

Die aktuelle Fachregel erlaubt eigene Formänderungen nur in der Kreaturenphase
(`phase=0`). Das Paket erweitert keine spätere Epochenregel. Die Vorbereitung kopiert
die Form in den Empfängerentwurf; dessen Name, Design-ID, Fortschritt, lokale
Erweiterungen und Editorpräferenzen bleiben erhalten. Die vorbereitete Revision bleibt
unverändert. Erst der vorhandene Editor-Speicherbefehl erhöht sie und veröffentlicht
sie über V7/DesignStore/SaveGameService. Weitere Teil-UIDs werden oberhalb aller
übertragenen `part_N`-Kennungen vergeben. Herkunft ist reine Metadateninformation;
sie erzeugt keine Tiere oder sonstigen Weltobjekte.

Für die folgende UI-Integration:

1. Gespeicherten V7-Entwurf mit `export_blueprint` exportieren und über `write_file`
   in eine vom Benutzer gewählte neue Datei schreiben.
2. Datei mit `read_file` prüfen; `inspect(...).preview` mit dem vorhandenen Renderer
   anzeigen. Keine Dateipfade aus dem Payload auflösen.
3. Bei ausdrücklicher Übernahme `prepare_for_active_editor(package, current)` erneut
   gegen den aktuellen Zustand prüfen. Fehler und fehlende Teile anzeigen.
4. Die zurückgegebene Kopie als eine normale Editoränderung in die vorhandene
   Undo-Historie übernehmen. Speichern, Revisionsobergrenze und Fehlerbehandlung bleiben
   im bestehenden Editor. Reines Lesen/Prüfen/Vorschauen speichert niemals automatisch.

Eine vorhandene Exportdatei wird auch bei geändertem Titel oder neuer Revision nicht
überschrieben. Eine lokale Bibliothek muss zusätzlich Konflikte gleicher ID/Revision
über verschiedene Dateien erkennen; der spätere Dienst muss veröffentlichte Revisionen
global unveränderlich halten. Bestehende gespeicherte Kreaturen hängen nach Übernahme
weder von der Austauschdatei noch von einer Internetverbindung ab.

## Abnahme und Folgepaket

`tests/community_blueprint_package_test.gd` prüft echte Dateiübertragung zwischen
getrennten Benutzerverzeichnissen, Quell-/Empfänger-Spielständen und einem frischen
Empfängerprozess. Die Austauschdatei wird vor dessen Neustart entfernt. Eigene
Identitäten, Fortschritt, Form, Anschlüsse und Herkunft müssen erhalten bleiben.
Zwei tatsächliche Vorschauen vergleichen Meshdaten, Farben, Transformationen und
Socketlagen vor und nach JSON-Übertragung. Hinzu kommen manipulierte/fremde Felder,
Zukunftsversionen, unbekannte Teile, gesperrte Endteile, Formbudget, Schreibfehler,
Dateikonflikte, geschützte Originale und Weiterbearbeitung ohne doppelte Teil-UIDs.

BP-COMMUNITY.1 liefert diesen nutzbaren Code-/Dateivertrag. Eine neue sichtbare
Import-Schaltfläche, lokale Vorlagenbibliothek und Startauswahl gehören zu
**BP-COMMUNITY.2**. Online-Dienst, Upload, Galerie und weitere Objekttypen folgen in
.3–.5. Kein bestehender SaveGameService-, Teilekatalog-, Streaming- oder UI-Code
wird durch dieses Paket umgebaut.

# Arbeit über mehrere Chats

Ziel: Einmal gemeinsame Entscheidungen treffen, danach kleine vollständige
Teilaufträge bearbeiten. Einstieg und verbindliche Kurzregeln stehen in
[AGENTS.md](../AGENTS.md); der aktuelle Lieferstand in [PROJECT_STATUS](PROJECT_STATUS.md).

## Runde vorbereiten

Jeder Checkout braucht eigenständige Git-Objekte. Keine dauerhafte Abhängigkeit
von Objektverzeichnissen fremder temporärer Checkouts: Wird deren Verzeichnis
entfernt, können sonst Historie und Merge-Basis fehlen, obwohl Arbeitsdateien
noch vorhanden sind. Nach lokalem Klonen diese Unabhängigkeit sicherstellen.

Ein Integrationschat legt den Basiscommit und zunächst drei Fachaufträge fest.
Er prüft aktuelle Lieferungen/Belegungen einmal und führt genau eine Rundenliste:

| Teilauftrag | Besitzer/Chat | Branch | Basis-SHA | Schreibbereiche | Status/PR |
|---|---|---|---|---|---|
| Eindeutige ID | Eine Zuordnung | Eigener Branch | Fester Commit | Aus Paketbrief, ggf. ergänzt | Zugewiesen → geliefert → integriert |

Die Liste lebt im Integrationschat oder einem bereits verwendeten gemeinsamen
Ticket. Ein Fachchat braucht nur seine Zuweisung. Das ist eine organisatorische
Vergabe durch einen Besitzer; der lokale Katalog ist **kein verteilter Lock**.
Keine mehreren unabhängigen „Reservierungsdateien“ auf Fachbranches anlegen.
Neue externe Tickets/Nachrichten nur im Rahmen des autorisierten Auftrags erzeugen.

```sh
python3 tools/work_packet.py list
python3 tools/work_packet.py conflicts ARCH-17-PUBLISH-TAIL ARCH-13-RETENTION-LIFECYCLE ARCH-24-PART-REVISIONS
python3 tools/work_packet.py show ARCH-17-PUBLISH-TAIL
```

Der Konfliktprüfer vergleicht deklarierte Schreibbereiche und gleiche
Einstiegsdateien. Er meldet beispielsweise ARCH-13/26/27 sowie ARCH-24/25 als
Kollision. Neue Dateien, indirekte Verbraucher und nicht deklarierte Änderungen
muss der Integrationsbesitzer zusätzlich zuordnen. Parallel gelesene Dateien
sind keine Schreibkonflikte. Die Paketbriefe sind begrenzte Vorschläge aus den
offenen ARCH-Aufgaben und werden nach ihrer Lieferung ersetzt oder entfernt.

## Fachauftrag ausführen

Ein geeigneter Startauftrag ist:

> Übernimm ARCH-17-PUBLISH-TAIL auf Basis des zugewiesenen Commits in einem eigenen
> Branch. Lies AGENTS.md, PROJECT_STATUS.md und den Paketbrief. Bearbeite nur
> diesen Umfang, prüfe die betroffenen Verträge und übergib einen PR mit kurzer
> Testevidenz. Zentrale Planung und Gesamtintegration übernimmt der Integrationschat.

Die konkret zugewiesene Basis-SHA und der Besitzer gehören in den tatsächlichen
Auftrag. Fehlt die Zuweisung, liefert der Chat zunächst den Vorschlag, statt
eigenmächtig dasselbe Paket wie ein anderer Chat zu beginnen. Ein ausdrücklicher
Nutzerauftrag für dieses Paket zählt bereits als Zuweisung, sofern kein konkreter
Konflikt bekannt ist. Routineentscheidungen brauchen keine neue Bestätigung.

Nach dem einmaligen Fetch/Checkout: betroffene Dateien lesen, implementieren,
Diff prüfen, relevante Tests ausführen. Bei „weiter“ den vorhandenen Stand
fortsetzen. Neu abgleichen nur bei neuer Integration, Abhängigkeit, Konflikt,
unerklärlichem Fehler oder geänderter Aufgabe. Keine vollständige PR-Inventur
für jeden Text- oder UI-Schritt.

## Testumfang und Wiederverwendung

| Änderung | Fachprüfung | Gemeinsame Abnahme |
|---|---|---|
| Dokumentation | Diff, Verweise und konsistenter Status | Kein neuer Spieltest allein wegen Text |
| Tooling/Workflow | Betroffene Python-Fälle, CLI-Fehlerpfade, Workflowstruktur | Bestehende CI-Gates bleiben erhalten |
| Fachfunktion | Ablauf plus betroffene direkte Verbraucher | Gemeinsamer Merge-Stand |
| Save, Identität, Körperreise, Nah/Fern | Alt-/Neustand, Fehler, Neustart und Übergabe | Vollständige relevante Produktions-/Reisekette |
| Darstellung/Leistung | Passende reale Szene und Vorher/Nachher-Messung | Nativer Build auf benannter Zielhardware |

`python3 tools/validate_godot.py --contracts surface --list-tests` zeigt die
Auswahl ohne Engine. `--list-tests` entfernen führt sie aus. Vertragstests stammen
weiterhin ausschließlich aus `tools/validation/contracts.json`; der neue
Paketkatalog speichert keine zweite Testliste. Mehrere Verträge werden dedupliziert.
Ein Vertrag ist eine Startauswahl, keine automatische vollständige Wirkungsanalyse.

Ein Ergebnis darf wiederverwendet werden, wenn Quell-Tree, Testauswahl/Befehl,
Engine, Ausführungsart, Umgebung und erforderliche Fixtures übereinstimmen.
Native Pakete benötigen zusätzlich ihre Build-ID/Prüfsumme. Ein anderer Commit
mit identischem Tree kann dieselbe Quelle enthalten; ein neuer Merge-Tree kann
es nicht. Bei reinem Dokumentationsdelta darf die Integration einen vorhandenen
Spielcodebeleg ausdrücklich referenzieren, muss das Delta aber prüfen. Sie darf
ihn nicht als neu ausgeführten Test ausgeben. Laufende Logs nicht vollständig in
jeden Chat kopieren: Kurzresultat und Link reichen, bei Fehlern den relevanten Ausschnitt.

## CI und Abschluss

Die fünf projektweiten Workflows (Godot, Desktopexport, Rendering, Baugruppen,
Planetendiversität) laufen für Facharbeit über PR-Ereignisse. Frühe Arbeit kann
einen Draft-PR verwenden; ohne PR ist ein manueller Workflowstart möglich.
`main` bleibt als Push-Ereignis geprüft. Dadurch entfällt bei neuen Fachbranches
der zusätzliche vollständige Push-Lauf neben dem PR-Lauf. Jobinhalte, vier
Godot-Shards, Neustarts, Exporte und die bestehenden PR-Gates bleiben erhalten.
Ältere Spezialworkflows mit konkreten historischen Branchnamen bleiben unverändert.

Kleine lokale Commits bündeln und einen fachlich prüfbaren Stand pushen.
Der Integrationschat übernimmt abgegrenzte Lieferungen, löst gemeinsame
Anschlüsse, lässt den tatsächlichen Kandidaten prüfen und aktualisiert den
Status einmal. Ein Merge in `main` bleibt von der jeweiligen Nutzerfreigabe
abhängig; dieser Arbeitsablauf erteilt keine pauschale Merge-Freigabe.

Kurze Übergabe im PR genügt:

```text
Paket / Basis-SHA / Liefer-SHA / Tree / sauberer oder identifizierter Arbeitsstand
Ergebnis: sichtbares Verhalten und geänderte Verträge
Gemeinsame Dateien / direkte Verbraucher / erforderlicher Anschluss
Prüfung: Engine, Befehl, Umgebung, bestanden/fehlgeschlagen, Log- oder CI-Link
Offen: konkrete Grenze; nächster Teilauftrag nur falls erforderlich
```

Rohmessungen oder komplexe Migrationen bekommen weiterhin einen eigenen
Fachbericht. Für jede Kleinigkeit gleichzeitig ROADMAP, NEXT_PARALLEL_WORK,
Architektur-Audit, Statusdatei und mehrere neue Abschlussberichte zu ändern
ist nicht erforderlich.

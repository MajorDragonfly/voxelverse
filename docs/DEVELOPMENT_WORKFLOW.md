# VoxelVerse: kurze Entwicklungszyklen und verlässliche Integration

Freigegeben durch Lars am 16.09.2026. Der konkrete Arbeitsrahmen steht in
[AGENTS.md](../AGENTS.md), die einzige laufende Vergabe in [Issue #137](https://github.com/MajorDragonfly/voxelverse/issues/137).

## Prüfungen passend zum Arbeitsstand

| Stand | Quelltests | Runtime | Grafik / native Exporte |
|---|---|---|---|
| Entwurfs-PR | Vorhandene Vertragsauswahl anhand des tatsächlichen Merge-Trees | Bei gemeinsamem/unbekanntem Pfad vollständig | Bei Fertigmeldung |
| Fertiger Code-PR | Vollständig, bis zu vier disjunkte Shards | Vollständig | Beide Renderer / Linux und Windows |
| Reiner Dokumentations-PR | Struktur, Hygiene, Werkzeugfälle, Dashboard | Explizit nicht nötig | Explizit nicht nötig |
| main / manueller Lauf | Vollständig | Vollständig | Vollständig |

`tools/ci_plan.py` nutzt `validation_plan.py` und dieselbe Registry. Unbekannte
Dateien, Workflowänderungen und gemeinsam genutzte Infrastruktur erweitern die
Quellprüfung. Fehlende Git-Historie oder ein nicht integrierter Basiscommit
brechen die Planung ab. Der Wechsel von Entwurf zu „Ready for review“ startet
automatisch die vollständige Abnahme. Pläne liegen als kleine CI-Artefakte vor.
Keine `[skip ci]`-Marker; die Abschlussjobs laufen mit `always()` und akzeptieren
übersprungene Jobs nur, wenn der erfolgreiche Plan sie ausdrücklich ausgenommen hat.
Entwürfe verwenden eigene Check-Namen. Ihre grünen Rückmeldungen können daher
nicht schon beim Fertigmelden die vier für einen Merge erforderlichen Gates erfüllen.

Render-Jobs verwenden den bestehenden Editor-Cache ohne Desktop-Exportvorlagen.
Die vollständigen Vorlagen bleiben für tatsächliche Exporte vorhanden.

## GitHub einmalig einrichten

Vier stabile Pflichtprüfungen:

- `Godot validation gate`
- `Desktop export gate`
- `Environment render gate`
- `Project dashboard gate`

Die importierbare Konfiguration liegt in
[`tools/workflow/main-ruleset.json`](../tools/workflow/main-ruleset.json).
Sie gilt nur für main: PR erforderlich, aktueller Branch, erfüllte Prüfungen
aus GitHub Actions, aufgelöste Review-Threads, keine Löschung/Force-Push und keine
Bypass-Ausnahmen. Es wird kein zusätzlicher manueller Reviewer vorgeschrieben.
Andere bestehende Rulesets bleiben erhalten.

Erst nach Integration und dem ersten Lauf der neuen Gates anwenden:

```sh
python3 tools/configure_github.py
python3 tools/configure_github.py --apply
```

Der erste Befehl ist eine reine Vorschau. `--apply` verwendet eine bereits
angemeldete GitHub CLI mit Administrationsrechten, prüft die Gate-Namen auf main,
installiert den Ruleset und aktiviert danach `allow_auto_merge` und
`allow_update_branch`. Abschließend werden die tatsächlichen Einstellungen erneut
gelesen. Ein bereits vorhandener abweichender gleichnamiger Ruleset wird nicht
überschrieben. Zugangsdaten gehören nicht ins Repository oder in einen Chat.

Alternativ in den Repository-Einstellungen den JSON-Ruleset unter Rules → Rulesets
importieren und unter General → Pull Requests Auto-Merge sowie das Aktualisieren
von PR-Branches erlauben. Das Einchecken dieses JSON aktiviert selbst keine Regel.
Der verbundene GitHub-Connector bietet derzeit keine Schreiboperation für diese
Repository-Administration; damit kann die Einrichtung allein über diesen Connector
nicht abgeschlossen werden.

Anschließend pro abgeschlossener, zugewiesener Lieferung Auto-Merge aktivieren.
Abhängige/fremde Entwürfe bleiben bis zur tatsächlichen Fertigstellung offen.
Keine Automation merged ungeprüfte PRs allein anhand ihres Titels oder Labels.

## Eine Vergabe, automatisch beobachteter Status

`Project live status` aktualisiert genau einen Bot-Kommentar in #137 nach
PR-Änderungen und nach Abschluss der drei großen Prüfworkflows. Angezeigt werden
aktueller main-Stand, offene PRs, gestapelte Branches sowie laufende/fehlgeschlagene
Prüfungen am konkreten PR-Kopf. API-Fehler werden als Fehler sichtbar.

Dieser Workflow führt ausschließlich Code vom Standardbranch aus. Er lädt keine
Artefakte oder Programme aus dem auslösenden PR und verändert keine Vergabe,
Quellen oder Prozentwerte. `project.json` bleibt die Quelle für bewerteten
Fortschritt und Paketabhängigkeiten. Lokaler Abruf:

```sh
python3 tools/project_dashboard.py live --checks --output /tmp/voxelverse-live
python3 tools/work_packet.py list
python3 tools/work_packet.py start PERF-COLD-START --owner MEIN-CHAT
```

`start` verwendet den dokumentierten main-Stand und weist Pakete mit noch nicht
integrierten Voraussetzungen zurück. Die sechs vorbereiteten Briefe sind Vorschläge;
die laufenden M4-/ARCH-/Audio-Zuweisungen in #137 bleiben maßgeblich.

## Skill und kompakter Paketstart

Der persönliche Skill **Voxelverse** führt die vorhandenen Helfer zusammen.
„Setze das nächste Arbeitspaket um“ und konkrete Änderungswünsche bleiben die
Arbeitsaufträge. Der Skill nutzt die aktuellen Repository-Regeln und kopiert
weder den Paketkatalog noch Testlisten oder den Projektstatus. Bereits installierte
Fachrollen und ihre Zuständigkeiten können denselben Einstieg verwenden.

```sh
python3 tools/work_context.py next --live --limit 3 --save-snapshot ../voxelverse-start.json --context-id paketstart-1
python3 tools/work_context.py show PERF-COLD-START --snapshot ../voxelverse-start.json --context-id paketstart-1
```

Der erste Befehl liest aktuellen main, das Koordinationsticket und die paginierte
Liste offener PRs. Er zeigt tatsächlichen lokalen HEAD/Branch, den **datierten**
Dashboard-Stand und höchstens drei Planungskandidaten in Katalogreihenfolge.
Die Priorität und Auswahl folgen weiterhin dem konkreten Nutzerauftrag und der
zentralen Runde. Aktive, gelieferte, integrierte, unbekannte oder von nicht
integrierten Voraussetzungen abhängige Katalogeinträge werden nicht vorgeschlagen.
Exakte Paketverweise in offenen PRs oder im Koordinationsticket schließen weitere
Kandidaten vorsorglich zur manuellen Einordnung aus; daraus wird kein konkreter
Bearbeitungsstatus abgeleitet. Abweichend benannte PRs und Zuweisungen brauchen
den gezielten Abgleich. Bei einem Umsetzungsauftrag einen tatsächlich bearbeitbaren
Kandidaten wählen; eine nur auf Lars' Referenz-PC mögliche Abnahme hält unabhängige
Entwicklungsarbeit nicht auf.

Den vollständigen Tickettext einmal aus `observation.issue.body` im Snapshot
lesen. Dadurch benötigt der zweite Befehl keinen weiteren Abruf. Der Snapshot
liegt außerhalb des Checkouts, ist maximal 30 Minuten für denselben Paketstart
gültig und an Repository, HEAD und die zugrunde liegenden Planungsdateien gebunden.
Er ist eine datierte Beobachtung, keine Sperre und keine zweite Statusquelle.
Einen eigenen Dateinamen und eine eigene Kontext-ID je Paketstart verwenden.

Ohne `--live` oder `--snapshot` bleibt der Helfer vollständig offline und
kennzeichnet die fehlende Live-Prüfung. `--busy ID ...` berücksichtigt bekannte
belegte Katalogpakete und ihre deklarierten Datei-/Bereichskonflikte;
`--exclude ID ...` entfernt explizit ausgeschlossene Vorschläge. Beide Optionen
reservieren nichts. Unbekannte Zuweisungen gelten niemals als frei. Mit `--json`
stehen dieselben Angaben maschinenlesbar zur Verfügung. API-Fehler und veraltete
Snapshots brechen sichtbar ab. Fehlt direkter API-Zugang, dieselben begrenzten
Quellen über den verfügbaren GitHub-Connector lesen; keinen Offline-Bericht als
aktuellen Live-Stand ausgeben.

Für die Testplanung gibt es eine kurze Ansicht des unveränderten Auswahlplans:

```sh
python3 tools/validate_godot.py --changed-since BASIS_SHA --plan --summary
```

`BASIS_SHA` ist der volle vereinbarte Basiscommit. Die Ausgabe enthält Quellstand,
Umfang, Testanzahl, Verträge und Gründe für eine Erweiterung zur Vollsuite.
`--summary` weglassen zeigt den vollständigen JSON-Plan; beide Plan-Optionen
weglassen führt die Prüfungen aus. Es werden weder Tests noch Import-/Merge-Gates
abgeschwächt. Das bestehende `work_packet.py handoff` erzeugt anschließend die
Übergabe. Plan, Testnachweis, Integration und Ziel-PC-Abnahme bleiben unterscheidbar.

## Grafikfehler aus PR #142

Der Forward+-Kugelfluss scheiterte einmal am bisherigen 50-Sekunden-Ladelimit.
Der gezielte Wiederholungslauf bestand bei identischem Quellstand
(`5d8e14070b484064ef70b6f3d3d20c18f3f0713c`); alle 27 aktuellen Checks waren
erfolgreich. [CI-Nachweis](https://github.com/MajorDragonfly/voxelverse/actions/runs/35101332072).
Das belegt einen sporadischen Fehler, keinen nachgewiesenen Fehler der entfernten Assets.

Grafische Aufnahmen warten nun bis zur bestehenden Weltaufbau-Frist von SessionFlow
zuzüglich zehn Sekunden für die Fehlermeldung. Headless bleibt bei 50 Sekunden;
Produktionsgrenzen und sämtliche Spielbehauptungen bleiben unverändert. Ladezeit,
Szene und Fehler werden protokolliert; auch ein äußerer Prozess-Timeout erhält
sein Log. Es gibt keine automatischen Wiederholungen oder unterdrückten Fehler.

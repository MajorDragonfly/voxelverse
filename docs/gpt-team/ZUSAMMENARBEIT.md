# Voxelverse: Übergaben zwischen den Rollen

Stand: 17.09.2026. Ergänzt [AGENTS.md](../../AGENTS.md) und [PROJECT_TRACKING](../PROJECT_TRACKING.md). Es entsteht keine zweite Aufgaben- oder Statusverwaltung.

## Eine Quelle je Zweck

| Information | Verbindliche Quelle | Pflege |
|---|---|---|
| Konkrete Beobachtung, Idee, Diskussion, Abnahme | GitHub-Issue mit verlinktem Beleg | Aufnahme-/Ideenrolle, danach zuständige Fachrolle |
| Aktive Paketvergabe, Besitzer, Basis, geteilte Dateien | Beschreibung von [#137](https://github.com/MajorDragonfly/voxelverse/issues/137) | Ein Koordinator je Runde |
| Implementierung und technische Übergabe | Eigener Branch und PR | Zugewiesene Fachrolle |
| Ausführbare vorbereitete Paketbriefe | `tools/workflow/packets.json` | Koordination, mit Fachbeiträgen |
| Verbindlicher Zielumfang | `ROADMAP.md`, begründete Entscheidungen im Issue/PR | Ideenrolle schlägt vor; Koordination integriert |
| Bewerteter Fortschritt und Abhängigkeiten | `tools/workflow/project.json` | Koordination |
| Testzuordnung | `tools/validation/contracts.json` | Fachrolle bei echten neuen Tests |

Rollen arbeiten erst nach einem Auftrag. Ein Issue ist eine dokumentierte Übergabe, kein Aufruf eines anderen GPTs. Für gleichzeitige Codex-Arbeit können unabhängige Teilaufträge delegiert werden; jeder braucht einen abgegrenzten Schreibbereich. Mehrere GPTs im selben Fachgebiet besitzen keinen gemeinsamen Chatverlauf.

## Eingang → Bearbeitung → Abnahme

1. **Spieletest:** Beobachtungen in `BUG` oder `VERBESSERUNG` aufteilen, Duplikate suchen, vorhandene Einträge ergänzen oder neue anlegen. Bei mehreren Problemen ein `SPIELTEST`-Sammelissue mit Links zu den einzelnen Befunden nutzen. Kein Sammelissue für einen einzelnen Befund nötig.
2. **Ideen:** als `IDEE` aufnehmen, Spielnutzen, passende Epoche, Abhängigkeiten und kleinste sinnvolle Umsetzung beschreiben. Bestehende Roadmap und Issues abgleichen. Eine Idee ist zunächst ein Vorschlag. Eine ausdrückliche Umsetzungsentscheidung von Lars gilt bereits als Entscheidung; nicht erneut abfragen.
3. **Koordination:** Umfang und Abhängigkeiten klären, vorhandene Besitzer respektieren. Paket-ID (z. B. `ISSUE-162-AI-RECOVERY`), Besitzerkennung (Rolle + Chatdatum/Kurzkennung), Basis, Branch und Schreibbereiche in #137 dokumentieren. Nur der Koordinator editiert die Rundenbeschreibung. Fachrollen können eine Zuweisung anfragen oder eine direkte Nutzerzuweisung dort zur Übernahme melden. Das ist keine atomare Sperre; bei widersprüchlichen Ansprüchen nicht gleichzeitig in geteilten Dateien schreiben.
4. **Fachrolle:** Paket gezielt umsetzen, passend prüfen und im PR übergeben. Benötigt sie eine andere Disziplin, beschreibt sie den gewünschten Anschluss im bestehenden Ticket oder legt bei eigenständigem Umfang einen verlinkten Teilauftrag an. Keine laufende Arbeit des anderen Besitzers überschreiben.
5. **Qualitätssicherung:** Reproduktion bzw. Abnahmekriterien am konkreten Build/Commit prüfen, Grenzen dokumentieren. Koordination integriert nach den bestehenden Gates. Ziel-PC-Nachtest bleibt getrennt sichtbar.

## Ticketfelder und Suche

Titel: `[BUG][03-KI] Gefährte verliert nach Hindernis das Folgeziel` oder `[IDEE][02-GAMEPLAY] ...`. IDs 01–11 entsprechen den Rollen im [Index](README.md). Die Präfixe und Felder sind Konventionen; sie benötigen keine neuen Labels oder GitHub-Projects-Rechte. Vorhandene passende Labels dürfen nach tatsächlicher Abfrage zusätzlich genutzt werden. Keine nicht vorhandenen Labels oder Assignees voraussetzen.

Suche beispielhaft mit `repo:MajorDragonfly/voxelverse is:issue Gefährte`, danach verwandten Begriffen und `is:pr`. Offene **und geschlossene** Einträge prüfen; bei größeren Ergebnissen paginieren. Ein geschlossener Fehler kann in einem anderen Build wieder aufgetreten sein. Bei einer Regression mit eigener Ursache ein verlinktes neues Issue erstellen, sonst den vorhandenen Befund ergänzen. Nach einem unklaren POST-Ergebnis Titel/Erfassungskennung suchen statt blind erneut anzulegen. Die Suche kann verzögert sein; bei Unsicherheit zusätzlich die jüngsten Issues/Kommentare lesen.

Pflichtangaben im Inhalt (fehlende Fakten ausdrücklich `unbekannt`):

- Typ, vorgeschlagene Hauptrolle und beteiligte Rollen; kein GitHub-Assignee durch Rollenname.
- Erfassungskennung, z. B. `PT-20260917-<kurze-Sitzungskennung>-01`; gleiches Ereignis behält seine Kennung bei Wiederholung.
- Quelle/Datum, tatsächliche Build-ID oder Commit, Epoche, Seed/Planet/Spielstand soweit relevant.
- Beobachtung/Spielnutzen; erwartetes Verhalten; Schritte und Häufigkeit.
- Beleg mit Bild-/Log-/Videoverweis; Ursachenvermutung ausdrücklich getrennt.
- Auswirkung, Prioritätsvorschlag, Abhängigkeiten, überprüfbare Abnahme und nächste Zuständigkeit.

**Medien:** Nur tatsächlich sichtbare Bildinhalte/Zeitmarken beschreiben. Kann ein Video nicht gelesen werden, gezielte Einzelbilder oder ein Transkript anfordern und vorhandene Notizen schon erfassen. Ein Chat-Anhang ist für einen anderen GPT nicht automatisch erreichbar. Die Action lädt keine binären Anhänge hoch. Fehlt ein beständiger GitHub-Anhang/erreichbarer Link, das im Issue markieren und eine textliche Beschreibung ergänzen; keinen lokalen `sandbox:`-Link als allgemein zugänglichen Beleg ausgeben. Das öffentliche Repository erhält nur projektbezogene, von Lars zur Dokumentation bestimmte Inhalte; private Desktopdetails weglassen.

## Priorität und Status ohne zweite Datenbank

| Priorität | Bedeutung |
|---|---|
| P0 | Datenverlust, nicht startbarer regulärer Spielweg oder vergleichbarer Blocker |
| P1 | Kernspiel deutlich beeinträchtigt, häufiger Absturz oder schwerer Spielfehler |
| P2 | Relevante Bedienungs-, Darstellungs- oder Gameplayverbesserung |
| P3 | Feinschliff oder spätere Option |

Priorität ist begründet und zunächst vorgeschlagen; eine unsichere Ursache senkt nicht automatisch die Auswirkung. Ideen werden zusätzlich nach Nutzen, Aufwand (klein/mittel/groß, keine erfundenen Stunden) und Abhängigkeiten bewertet.

Der erste Tickettext enthält **Aufnahmestatus: erfasst**. Spätere Fortschritte stehen in datierten `Statusmeldung`-Kommentaren: `geklärt`, `bereit`, `in Arbeit`, `zur Prüfung`, `integriert`, `Nachtest offen`, `bestätigt` oder `blockiert`. Ein Statuskommentar nennt Beleg und nächsten Schritt. Die aktuelle Vergabe bleibt ausschließlich #137; technische GitHub-Zustände (Issue offen/geschlossen, PR draft/merged) werden mitgelesen. Keine selbstgebauten Labels als Freigaben verwenden.

Ein Bug-Issue bleibt offen, solange seine vereinbarten Abnahmekriterien fehlen. Falls Lars' Nachtest dazugehört, im PR `Refs #...` statt eines vorzeitigen `Closes #...` verwenden. `Closes` ist erst passend, wenn die vollständigen Ticketkriterien erfüllt sind. Beheben, Mergen und Spieltest-Bestätigung sind unterschiedliche Nachweise. Einen lediglich vorgeschlagenen Umfang nicht als implementiert zählen.

## Roadmap-Änderungen

Die Ideenrolle dokumentiert Entscheidung `Vorschlag`, `angenommen`, `zurückgestellt` oder `abgelehnt` mit Quelle und Datum. Ein eigenes GPT-Urteil ist keine Nutzerentscheidung. Akzeptierte Ideen erhalten einen gezielten Änderungsvorschlag für ROADMAP und bei Bedarf kleine Folgepakete. Mit Codewerkzeugen kann die Rolle diesen Vorschlag in einem eigenen Dokumentations-PR umsetzen; mit der Intake-Action liefert sie ihn im Issue an Koordination. Größere v1-Erweiterungen verlangen die in PROJECT_TRACKING beschriebene `scope_version`-/Gewichtsbewertung durch Koordination. Keine Prozentwerte aus der Zahl neuer Ideen ableiten.

## Kurzformat für Fachübergaben

```text
Statusmeldung – Datum – Besitzerkennung
Ticket / Paket-ID / empfangende Rolle:
Ergebnis und gewünschter nächster Schritt:
Basis / Branch / PR / tatsächlicher Commit und Tree:
Abhängigkeiten / geteilte Dateien und Zuständigkeiten:
Prüfung: Quelle, Umgebung, Befehl, Ergebnis, Beleg:
Nicht geprüft / Nachtest / weitere Grenzen:
```

Zentrale Fortschrittsdateien werden einmal pro Integrationsrunde aktualisiert und mit `python3 tools/project_dashboard.py render` erzeugt. Es gibt keine automatische GPT-Kommunikation, Issue-Zuweisung, Bewertung oder Zusammenführung allein durch diese Dokumente.

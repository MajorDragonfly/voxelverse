# Fortschritt und gemeinsame Chat-Arbeit

Die [Projektübersicht](PROJECT_DASHBOARD.md) wird aus
`tools/workflow/project.json` erzeugt. Das ist die einzige Quelle für Gewichte,
Schätzintervalle, feste Statusreferenzen und die ausgewiesenen Folgepakete.
Der vorhandene Paketkatalog bleibt die Quelle für ausführbare Auftragsbriefe;
`tools/validation/contracts.json` bleibt die einzige Godot-Testzuordnung.

## Was der Prozentwert bedeutet

Zielumfang v1 ist die vollständige Singleplayer-Vision bis zur Weltraumphase,
einschließlich Community-Vorlagen und Veröffentlichung. Die am 16.09.2026
besprochene Gewichtung summiert sich auf 100. Jeder Bereich hat ein manuell
begründetes Schätzintervall; die Anzeige summiert Gewicht × Schätzung / 100.
Der Mittelpunkt beträgt anfangs rund 35 %, die Grenzen rechnerisch 30–39,5 %.
Das ist eine Planungsschätzung, keine Messung oder Restzeitprognose.

Ein neuer Schwanztyp ist Teil des Kreaturenumfangs, kein weiterer Meilenstein
neben der Kreaturenphase. Eine komplette neue Epoche hat eigenes Gewicht.
ARCH- und D-Pakete konkretisieren die bestehenden Bereiche. Neue Wünsche zuerst
im Zielumfang einordnen; bei echter Umfangsänderung `scope_version` erhöhen,
Gewichte neu begründen und die Änderung im PR erklären. Der Git-Verlauf bewahrt
die alten Bewertungen. Die angezeigte Quote darf bei größerem Zielumfang sinken.

Tests, Zeilen, Commits, geschlossene Issues und PRs verändern den Prozentwert
nicht automatisch. `delivered` belegt eine veröffentlichte Fachlieferung mit
festem Commit und Evidenz. `integrated` verlangt zusätzlich den Integrationscommit;
`accepted` zusätzlich Abnahmebeleg, Abnehmer und Build-ID. Eine abgeschlossene
Teilprüfung darf nicht stellvertretend zur Gesamtfreigabe aufsteigen.

## Einmal je Integrationsrunde

1. Den aktuellen Stand von main und gemeinsamem Kandidaten abfragen; die festen
   SHAs in `project.json` aktualisieren, sobald der neue gemeinsame Stand belegt ist.
2. Abgegrenzte Lieferungen mit ihren tatsächlichen Köpfen übernehmen. `included`
   führt genau diese PR/Kopf-Paare. Bei späteren Commits im selben PR meldet der
   Live-Bericht einen nötigen Nachlieferungsabgleich.
3. Folgepakete unter `deliveries` pflegen. Ein Paket steht entweder in der
   kompakten Eingangsliste oder als detaillierte Lieferung; dieselbe PR-Nummer
   wird nicht doppelt aufgenommen. Fachliche `depends_on`-IDs müssen existieren
   und dürfen keinen Kreis bilden. Beim Entfernen einer Lieferung ihre Verweise
   ebenfalls abgleichen; historische Details bleiben in den datierten Berichten.
4. Erreichte Funktionen, offene Grenzen, drei Prioritäten und Bewertungsdatum
   aktualisieren. Eine reine neue PR ohne belegten Umfang erhöht keine Schätzung.
5. `python3 tools/project_dashboard.py render` ausführen und Diff prüfen.
   Der Befehl erzeugt README-Abschnitt, Detailübersicht, PROJECT_STATUS,
   NEXT_PARALLEL_WORK und SVG ohne Engine oder
   Netzwerk. `python3 tools/project_dashboard.py check` prüft anschließend
   Datenschema, Gewichte, Quellenfelder, Abhängigkeiten und erzeugte Ansichten.

Schema-/Linkfelder werden strukturell geprüft; der Generator überprüft weder
den Inhalt externer Nachweise noch den tatsächlichen Spielspaß. Die Bewertung
verantwortet der Integrationsbesitzer. Ziel-PC-Freigaben benötigen reale Belege.

## Zentrale Vergabe und Start

Die verbindliche Rundenliste ist [GitHub-Issue #137](https://github.com/MajorDragonfly/voxelverse/issues/137).
Genau ein Integrationsbesitzer pflegt dort die aktuellen Zuweisungen und deren
gemeinsame Schreibbereiche. Frühere Nutzerzuweisungen gelten weiterhin. Die
Rundenliste erfasst die bekannten Fachlieferungen und weiterlaufenden Zuständigkeiten
der Integration vom 16. September. Fehlende oder ungenaue Einträge bedeuten nicht frei.

```sh
python3 tools/project_dashboard.py round
python3 tools/work_packet.py list
python3 tools/work_packet.py start ARCH-19-TARGET-PC --owner Ziel-PC-Chat
```

`round` liest die aktuelle Ticketbeschreibung von GitHub, `start` liest nur den
lokalen Paketkatalog und den datierten Status. Die Ausgabe ist ein Startauftrag,
keine verteilte Sperre. Eine neuere konkrete Zuweisung hat Vorrang vor dem
Basisvorschlag. Bei fehlender Verbindung keine Aussage über freie Pakete erfinden.
Der Integrationschat kann neue eindeutige IDs wie M4-…, UI-… oder WEATHER-… mit
denselben Pflichtfeldern in `packets.json` ergänzen. `work_packet.py check` prüft
Datei- und Vertragsverweise; `conflicts ID ID ...` prüft gemeinsame Schreibgruppen
und identische Einstiegsdateien. Indirekte Abhängigkeiten bleiben eine Fachentscheidung.

## Lieferung statt neuer Dokumentationsrunde

```sh
python3 tools/validate_godot.py --changed-since VOLLE_BASIS_SHA --plan
python3 tools/work_packet.py handoff PAKET-ID --base VOLLE_BASIS_SHA
```

Der erste Befehl nutzt die vorhandene Prüfauswahl. Bei Tooling-/Workflowänderungen
bleibt die manuell begründete Python-/CLI-Prüfung aus PARALLEL_WORKFLOW maßgeblich;
die konservative Diff-Auswahl darf dafür weiterhin die Vollsuite vorschlagen.
Der zweite Befehl läuft erst auf einem sauberen Fachbranch mit der Basis als
Vorfahre. Er gibt Commit, Tree und tatsächlichen Dateiumfang aus; Testresultate
und fachliche Grenzen ergänzt der Besitzer anhand seiner Nachweise. Kein
Test wird erneut gestartet. Neue Paket-IDs müssen für eine Übergabe nicht in
einer veralteten Katalogkopie stehen. PR-Vorlage und Issue-Formular unterstützen
denselben Ablauf. Kleine Fachpakete benötigen keine zusätzliche Abschlussdatei.

## Live-Abgleich und GitHub Actions

```sh
python3 tools/project_dashboard.py live --output /tmp/voxelverse-project-dashboard
```

Der read-only Aufruf liest offene PRs seitenweise sowie main und den Kandidaten,
zeigt Draft-Status, bekannte identische Eingänge einschließlich detaillierter integrierter Lieferungen und gestapelte Branches. Zusätzliche reine Status-/Nachweiscommits werden nur nach einem vollständigen vorwärts führenden GitHub-Dateivergleich erkannt; Spielcodeänderungen bleiben abgleichpflichtig. Er
folgt keinen PR-Titeln als Anweisung und schreibt keine GitHub-Daten. Mit
`GH_TOKEN` oder `GITHUB_TOKEN` werden vorhandene Leserechte verwendet; ohne Token
gelten die öffentlichen GitHub-Limits. API-Fehler werden als Fehler gemeldet,
nicht als leere Aufgabenliste. Der Aufruf verändert keine Bewertung oder Datei
im Repository; der Ausgabeordner enthält einen datierten JSON-/Markdown-Bericht.

Der neue Workflow **Project dashboard** prüft die erzeugten Ansichten und
liefert Bericht und Live-Abgleich in Job Summary und Artefakt. Er läuft auf
PR-Ereignissen und main-Updates; ein manueller Start wird nach Übernahme des
Workflows in den Standardbranch verfügbar. Er hat ausschließlich Leserechte.
README und Fortschrittsgrafik ändern sich erst mit einer geprüften Aktualisierung
der zentralen Daten und erneuter Generierung. Es gibt keine stillen Bot-Commits,
keine automatischen Merges und keine aus PR-Ereignissen erfundene Abnahme.

Die bestehenden Spiel-, Export- und Render-Gates bleiben erhalten. Reine
Statuspflege startet lokal keine Engine; CI wird nicht durch Skip-Marker umgangen.
Bei Fortsetzung desselben Auftrags keine erneute globale Inventur: eigener
Paketkontext plus aktuelle konkrete Änderung reichen.

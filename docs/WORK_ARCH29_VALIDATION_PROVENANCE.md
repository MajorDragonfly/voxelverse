# ARCH-29-VALIDATION-PROVENANCE

Basis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8` aus dem gemeinsamen
Integrationsbranch `agent/integration-vegetation-nest-20260915` (#110).
Eigenständiger Fachbranch: `agent/arch29-validation-provenance-20260915`.
Der Stammes-Testeinstieg aus #116 ist keine Abhängigkeit dieses Pakets.

## Problem und Ergebnis

Der Testläufer erfasste seine Revision bisher erst beim Schreiben von
`results.json`. Ein Commit oder eine Änderung während des Laufs konnte dadurch
dem gesamten Ergebnis fälschlich den letzten Stand zuordnen. Neue, noch nicht
committete Dateien fehlten außerdem in der Kennzeichnung des Arbeitsstands.

Der Läufer erfasst jetzt vor der Auswahl und an jeder Befehlsgrenze:

- HEAD-Commit und Git-Tree, Indexfingerabdruck und Zustand der versionierten Dateien;
- relative Pfade, Status und SHA-256 für geänderte und neue, nicht ignorierte Dateien;
- bei symbolischen Links den Linktext statt fremder Zieldateien;
- Zeitpunkt, Prüfschritt und zugehörigen Snapshot. Unveränderte Snapshots werden
  im Bericht einmal gespeichert und über Nummern referenziert.

`source-start.json` liegt vor dem ersten Prüfprozess vor und bleibt auch bei
abruptem Prozessabbruch erhalten. `results.json.source` bezeichnet jetzt den
**Startstand**. Der vollständige Verlauf steht in `source_provenance`; jeder
Prüfeintrag enthält Befehl, Zeitgrenze und Referenzen auf seine Vorher-/Nachherstände.

Wird eine unerwartete Änderung beobachtet, stoppt der Läufer vor weiteren Prüfungen
und liefert Exitcode 1. Bereits abgeschlossene Einzelresultate werden nicht
umgeschrieben. `checks_passed` zeigt ihre vollständige technische Ausführung;
`passed` verlangt zusätzlich einen gültigen Quellnachweis. Nicht ausgeführte
Befehle stehen ausdrücklich unter `unexecuted_checks`. Ein zwischen Prüfungen
beobachteter Wechsel bleibt vermerkt, auch wenn am Ende wieder der Anfangsstand gilt.

## Einordnung des Quellnachweises

| Status | Bedeutung | Erfolgreicher Gesamtlauf möglich? |
|---|---|---|
| `unchanged` | Gleicher beobachteter Stand an allen Grenzen | Ja |
| `generated_outputs_only` | Ausschließlich erwartete neue UID-Dateien nach Import | Ja |
| `changed` | Änderungen an Quellen, Index oder Revision beobachtet | Nein |
| `unavailable` | Kein eindeutiger Git-Stand, Konflikt oder fehlgeschlagene Aufnahme | Nein |

Ein bereits vor Beginn geänderter Arbeitsstand ist zulässig: Seine geänderten und
neuen Eingaben sind ausdrücklich gehasht. Der Runner behauptet keinen sauberen
Commit für diesen Stand. Git-Worktrees werden anhand ihrer eigenen Wurzel erfasst.
Die Aufnahme erzeugt weder Commits noch Trees und schreibt nicht in den Git-Index.

Ein erfolgreicher Godot-Import darf neue `.gd.uid`/`.gdshader.uid`-Dateien für
bereits zu Laufbeginn erfasste Skripte erzeugen, auch für dort gehashte neue Dateien.
Nur neue, nicht symbolisch verlinkte Dateien
mit gültigem `uid://…`-Inhalt werden unmittelbar nach diesem Import als erzeugte
Ausgabe eingeordnet. Pfade und Hashes bleiben im Bericht. Änderungen an vorhandenen
UID-Dateien, beliebige neue Quelldateien und spätere UID-Änderungen lösen weiterhin
eine Änderung aus. Der `.godot`-Cache ist wie zuvor durch Git ignoriert.

**Grenze:** Das sind Beobachtungen an Befehlsgrenzen, keine Sperre des Dateisystems.
Eine vollständig innerhalb eines Befehls vorgenommene und zurückgenommene Änderung
kann unbemerkt bleiben. Ignorierte Dateien, Importcache-Inhalte und externe Ziele
symbolischer Links werden nicht zertifiziert. Weiterhin in eigenem Checkout arbeiten.

## Verwendung und Integration

Die vorhandenen Selektoren bleiben erhalten. `--plan` und `--list-tests` starten
keine Prüfung und erzeugen keinen Quellnachweis. Ausgabeordner müssen jetzt auch
bei manueller Testauswahl **außerhalb des Projekts** liegen und leer/neuwertig sein:

```sh
python3 tools/validate_godot.py --godot <Godot-4.6.3> \
  --tests performance_measurement_test --skip-main --output ../pruefung-neu
```

So überschreiben neue Prüfungen keine älteren Berichte und ihre Ausgabe erscheint
nicht als neue Quelle im nächsten Snapshot. Die bestehenden CI-Ausgabeziele liegen
bereits außerhalb des Projekts. CI-Python-Discovery findet den neuen Werkzeugtest
automatisch; die Godot-Testregistrierung wird nicht dupliziert.

Prüfumfang: gezielte Python-Werkzeugtests mit echten Git-Repositories/Worktrees,
Subprozessänderung, Abbruch der weiteren Ausführung, neuen/binären/gelöschten/
umbenannten Dateien, Staging/Commit, Import-UIDs, Konflikten und erhaltenen Berichten;
zusätzlich ein bestehender kurzer Godot-Test durch den echten Runner. Ergebnisse
und exakter Prüfcommit gehören zur PR-Übergabe. Kein neuer Gesamtspiel-, Export-,
Windows-, Grafik- oder Ziel-PC-Nachweis. Zentrale Statuslisten bleiben bei der Integration.

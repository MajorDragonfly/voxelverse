# ARCH-29-RUN-PROVENANCE: Quellen eines Prüflaufs nachweisen

Basis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8`.
Branch: `agent/arch29-run-provenance-20260915`.
Abgegrenzter Folgeauftrag zu ARCH-29-CHECK-PLAN aus NEXT_PARALLEL_WORK.

## Verhalten

Der Godot-Runner erfasst den tatsächlichen Checkout vor der Testauswahl,
nach der Auswahl, nach jedem gestarteten Prüfprozess und abschließend mit
erneutem vollständigem Lesen der Dateien. Die Beobachtungen enthalten HEAD,
HEAD-Tree, Index-Fingerprint, Arbeitsstand und SHA-256 der tatsächlichen
Dateiinhalte. Vorgemerkte, ungesicherte, neue und fehlende Dateien werden
berücksichtigt. Der abschließende Commit ersetzt den ursprünglichen nicht.

`results.json` enthält Start-/Endzustand, Änderungen je Prozessgrenze, exakte
Befehle, Log-Hashes, Plattform, Python- und Godot-Version. Die beiden
`source-files-*.jsonl` inventarisieren Pfade, Dateityp, Ausführbarkeit, Größe,
Inhaltshash und Git-Zugehörigkeit. Ihre Hashes stehen im Ergebnis. Die
Quellidentität ist unabhängig vom absoluten Checkout-Pfad und den Zeitstempeln.
Zeitstempel/Inode werden zusätzlich beobachtet, sodass auch normalerweise
erkennbare Änderungen mit anschließender Wiederherstellung den Lauf entwerten.

Eine Quellenänderung stoppt weitere Prüfprozesse und setzt den Gesamtlauf auf
fehlgeschlagen. Bereits gestartete Prozesse behalten ihr tatsächliches
`process_passed`; dieses allein ist keine Freigabe des Laufs. Index-/Commitwechsel,
Konflikte und nicht erfassbare Quellen verhindern einen Quellen-Pass. Derselbe
ruhende, auch anfangs schmutzige Checkout kann dagegen gültig geprüft werden:
seine tatsächlichen Bytes sind über das Manifest identifiziert.

Während **nur des Imports** gelten zwei eng begrenzte Vorbereitungen:

- Neue, nicht versionierte `.gd.uid`/`.gdshader.uid` mit gültigem UID-Inhalt für
  eine schon vorher vorhandene und unveränderte Quelldatei.
- Identische Neuschreibungen vorhandener `.import`-Dateien für unveränderte
  vorhandene Quelldateien. Geänderte Bytes sind niemals ausgenommen.

Auch diese Vorgänge bleiben im Delta sichtbar (`import_preparation`, gesamter
Status `prepared`). Sobald weitere Änderungen auftreten, gilt die Ausnahme
nicht. Laufzeit-Tests beginnen anschließend auf dem dokumentierten vorbereiteten
Stand. Start-/Endmanifeste bleiben getrennt; hinzugekommene UIDs werden nicht als
Bestandteil des ursprünglichen Git-Trees ausgegeben.

## Aufruf und Berichte

```sh
python3 tools/validate_godot.py --godot /pfad/zu/godot \
  --tests performance_measurement_test --skip-main --output ../mein-neuer-lauf
```

Alle ausgeführten Aufrufe verlangen einen neuen/leeren Ausgabeordner außerhalb
des Projekts; ohne `--output` entsteht ein eindeutiger temporärer Ordner. Ein
exklusiver Besitzmarker schützt gegen gleichzeitig gestartete Runner im selben
Ordner. Vorherige Nachweise werden nicht überschrieben. Der Startdatensatz wird
vor den Prüfprozessen geschrieben. Erst eine atomar veröffentlichte `results.json`
belegt einen abgeschlossenen Lauf; ein Startdatensatz allein genügt nicht.
Timeouts und während eines Prüfprozesses abgefangene Unterbrechungen hinterlassen
ein fehlgeschlagenes Ergebnis mit Quellenbeobachtung. Ein hart beendeter Runner
kann lediglich Start-/Teilnachweise hinterlassen.

`--plan` und `--list-tests` bleiben ohne Engine-/Prüfstart und ohne neue Berichte.
Ausgeführte `--changed-since`-Pläne enthalten dieselbe Quellenbeobachtung, auch
beim reinen Quellgate. Registry, Testauswahl und Tests gehören weiterhin den
vorhandenen Fachverträgen. Die volle Integrationssuite bleibt unverändert.

## Grenzen und Aufwand

`provenance.reusable` verlangt erfolgreiche Prüfungen und vollständige, stabile
Beobachtungen im beschriebenen Umfang. Es ist keine automatische Wiederverwendung
alter Ergebnisse und keine Aussage über ungestartete Tests. Ein anderer
Merge-Tree oder eine andere Umgebung braucht die dafür vorgesehenen Prüfungen.
Ignorierte Import-Caches und externe Eingaben werden nicht erfasst. Symlinks
werden als Linktext erfasst, Submodule als Gitlink; bei beiden ist die Abdeckung
unvollständig und `reusable` falsch. Der Runner verlangt das Git-Projektwurzel-
verzeichnis. Die Beobachtung sperrt das Dateisystem nicht und ist kein Nachweis
gegen absichtliche Manipulation zwischen Beobachtungsgrenzen.

Inhalts-Hashes werden nur bei unverändertem Inode, Modus, Größe, mtime und ctime
zwischengespeichert. Der Endzustand wird unabhängig davon vollständig gehasht.
Dateianzahl und Lesemengen sind begrenzt; ein überschrittenes Budget erzeugt
einen Fehler statt einer still unvollständigen Freigabe. Git-Aufrufe sind
lesend und deaktivieren optionale Indexschreibvorgänge.

## Übergabe

Schreibbereich: Runner, eigenes Quellenmodul, Python-Runner-Fachtests und dieses
Arbeitsdokument. Keine Änderungen an Spielcode oder zentralen Statusdateien.
Die bestehenden CI-Jobs entdecken die Python-Tests automatisch und archivieren
die kompletten Runner-Ausgabeordner einschließlich der neuen Manifeste.
Die konkrete Prüfevidenz wird im Paketnachweis und im Draft-PR verlinkt.

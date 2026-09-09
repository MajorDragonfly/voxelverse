# Exportzuverlässigkeit – 9. September 2026

## Integration

Eigener Branch `agent/export-reliability-2026-09-09`, aufbauend auf PR #36,
Commit `5ef5028128407ad3db25f2ad2dda89d7e0b91bd0`. Integrationsfolge:
Bereinigung #34 → Leistungsdiagnose #36 → dieses Paket. Kein automatischer Merge.
Commit und lokal/remote identischer Git-Quellbaum stehen im PR-Text.

Die veröffentlichten Fachbranches wurden vor der Änderung geprüft; keine
Dateiüberschneidung mit den fünf bearbeiteten Bestandsdateien. Genaue Stände in
`validation/export-reliability/branch-checks.json`. Beim Abschlussabgleich kam
eine D2-Änderung an `core/runtime_shutdown.gd` hinzu, siehe unten. Nicht veröffentlichte Arbeit
anderer Chats ist nicht sichtbar. Planeten-, Menü-, Kreaturen- und Speicherschemata
werden hier nicht umgebaut. `ROADMAP.md` bleibt beim Integrationschat.

## Zwei reproduzierte Ursachen

### Spieler-Verweis zwischen Aushängen und Freigeben

Der Linux-Export meldete beim Eintritt ins Planetenlabor Zugriffe auf globale
Transformationen außerhalb des Szenenbaums. `world_audio.gd` behielt einen gültigen
Node-Verweis auf den alten Spieler. Beim Szenenwechsel ist ein Objekt bereits
ausgehängt, bevor seine spätere Freigabe den Verweis ungültig macht. Ein weiterer
Audio-Physikschritt konnte in diesem Zwischenraum Positionen abfragen.

Der neue Test entfernt einen echten, bereits gebundenen Spieler aus dem Baum,
führt den Audio-Schritt aus, hängt ihn wieder ein und prüft anschließend auch
`queue_free()`. Vor der Korrektur entstehen die Transformation-Fehler mit
GDScript-Stack in `world_audio.gd`; danach werden ausgehängte und zum Löschen
vorgemerkte Spieler verworfen und wieder eingehängte Spieler korrekt gebunden.

### Musik beim Beenden

Der Windows-Menütest absolvierte seine Eingabeprüfung erfolgreich, hinterließ
beim Beenden jedoch eine Ogg-Musikwiedergabe. Derselbe Fehler wurde lokal mit dem
Linux-Release reproduziert: `menu.ogg`, `AudioStreamPlaybackOggVorbis` und dessen
Paketreferenzen blieben zurück.

Die Audio-Abspielknoten erhalten beim Austritt aus dem Baum ihre Pause-Mitteilung,
bevor `_exit_tree()` des übergeordneten AudioManagers ausgeführt wird. Bisher
stoppte der Manager die Musik erst dann. `runtime_shutdown.gd` ruft jetzt
`AudioManager.prepare_shutdown()` auf, solange die Abspielknoten noch im Baum
sind. Musik, Scanner-, Umgebungs-, Welt- und UI-Töne werden beendet, ausstehende
Audioeinstellungen gespeichert und anschließend der Manager freigegeben.
`_exit_tree()` verwendet dieselbe Aufräumfunktion als Rückfallebene.

Der erste lokale Release bestand nach dieser Korrektur alle 29 Prüfungen; der
anschließende CI-Lauf deckte einen weiteren Zeitfehler auf. Der bisherige
`SceneTreeTimer` konnte nach einem langsamen Frame mit dessen bereits verstrichener
Zeit verrechnet werden und praktisch sofort auslösen. Eine neue Probe mit einem
absichtlich blockierenden 350-ms-Frame maß nur **2.371 Mikrosekunden** Wartezeit
nach dem Austritt des AudioManagers. Die Wartezeit wird jetzt mit der realen Uhr
begrenzt; dieselbe Probe maß danach **159.586 Mikrosekunden**.

Die Zeitkorrektur entspricht der inzwischen von D2 veröffentlichten Änderung
in Commit `38d6177a27a228fdf0ea8418062f710ab90b558e`. Hier ist ausschließlich
diese gemeinsame Beenden-Stelle berücksichtigt; der D2-Fachbranch wurde nicht
zusammengeführt. Unsere zusätzliche frühe Audiofreigabe bleibt erhalten. Eine
Drei-Wege-Vorschau für die gemeinsame Datei ist textuell konfliktfrei.

Der neue Shutdown-Test startet echte Ogg-Wiedergabe und prüft mit schwachen
Referenzen, dass sie nach dem Aufräumen freigegeben ist: im laufenden und im
pausierten Spiel. Der vorhandene Menütest ist mit der Korrektur ebenfalls sauber.

Die Reihenfolge der Engine-Mitteilungen ist im unveränderten
[Godot-4.6.3-Quellcode](https://github.com/godotengine/godot/blob/4.6.3-stable/scene/audio/audio_stream_player_internal.cpp)
nachvollziehbar. Es wird keine neue Engineversion vorausgesetzt.

## Export-Cache und Diagnose

`export-validate.yml` speichert nur `*.zip` und `*.tpz` aus dem Toolchain-Ordner.
Der neue Cache-Schlüssel enthält Betriebssystem und Installer-Hash. Alte vollständige
Toolchain-Caches werden dadurch nicht versehentlich wiederhergestellt. Entpackte
Editor-/Vorlagendateien und portable Benutzerdaten gelangen nicht mehr in den Cache.

Der bestehende Installer prüft weiterhin SHA-256 bei jedem Aufruf und installiert
die bisherigen vier Desktop-Vorlagen. Seine Standardfunktion wurde nicht verändert.
Auch Trigger, Windows-/Linux-Matrix, Akzeptanzprüfungen und Fehlerfilter bleiben
erhalten. Die drei nativen Szenen-/Menüprüfungen liefern jetzt zusätzlich ausführliche
Godot-Logs, damit verbliebene Ressourcen bei einem Fehler eindeutig benannt werden.

Lokal umfassen die zwei geprüften Linux-Downloadarchive 1.327.725.010 Bytes.
Zusätzlich entpackte Dateien von 490.841.100 Bytes werden aus dem Cache ausgeschlossen.
Der bisherige komprimierte CI-Cache hatte 1.518.418.665 Bytes. Die tatsächliche
komprimierte Größe des neuen Caches steht im zugehörigen CI-Lauf; Rohdateigrößen
sind kein exakter Nachweis der Übertragungsersparnis.

## Prüfung und Wiederholung

Vollständiger lokaler Linux-Release erfolgreich: **29 Prüfungen** einschließlich
Startmenü, Planetenlabor, echter Eingaben, Spielständen, Stammeswelt/Neustart und
drei Planeten-Seeds. ZIP und SHA-256 wurden erst nach erfolgreicher Abnahme erzeugt.

Sechs Audioprüfungen erfolgreich:

- `audio_scene_lifecycle_test`: Aushängen, Wiedereinbinden und vorgemerktes Löschen.
- `audio_shutdown_test`: Freigabe echter Musikwiedergabe, laufend und pausiert.
- `runtime_shutdown_test`: Mindestens 140 ms tatsächlich verstrichene Mixerzeit
  nach einem absichtlich langsamen Frame; Sollwartezeit 150 ms.
- Bestehende `audio_runtime_test`, `music_runtime_test`, `audio_expansion_test`.

Die neuen Tests werden von der bestehenden rekursiven Testsuche automatisch
ausgeführt. Vorher-/Nachher-Nachweise und Exportergebnisse stehen in
`validation/export-reliability/`. Actionlint und `git diff --check` sind fehlerfrei.
Die native Windows-Abnahme wird auf dem GitHub-Windows-Runner ausgeführt; genaue
Ergebnisse und der geprüfte Commit stehen im PR. Keine lokale Windows-Ausführung
und keine neue Grafik-/FPS-Abnahme.

Im ersten Windows-CI-Lauf auf `821fcd470c380ddbb8e69b5aedcfa907baeec4eb`
bestanden die nativen Menü-, Eingabe- und Planetenprüfungen. Später scheiterte
`packaged_tribal_age_world_test`: Bei Seed 15838 fand die Prüfung unter Windows
keinen geeigneten Heimat-/Dorfplatz (`sites=13`, Rückmeldung: fester, möglichst
ebener Boden erforderlich). Derselbe Test besteht lokal unter Linux. Die Ursache
dieses zusätzlichen Plattformbefunds ist noch offen. Der Dorfchat bearbeitet
`tests/tribal_age_world_test.gd` bereits in `agent/m6-village-growth`; hier werden
weder seine Platzierungsregeln geändert noch die Prüfung abgeschwächt.
Der weitere Windows-Status nach der Zeitkorrektur ist im PR dokumentiert.

Aus dem Projektverzeichnis:

```powershell
python tools/install_godot.py --directory ../godot-toolchain
python tools/validate_export.py --godot ../godot-toolchain/editor/Godot_v4.6.3-stable_win64_console.exe --platform windows --output ../export-pruefung/windows-01
```

Unter Linux dieselben Werkzeuge mit `--platform linux` und dem Engine-Namen
`Godot_v4.6.3-stable_linux.x86_64` verwenden. Ausgabeordner außerhalb des Projekts
wählen. Die Akzeptanz läuft mit isolierten Spielständen und startet die exportierte
Anwendung außerhalb des Quellverzeichnisses.

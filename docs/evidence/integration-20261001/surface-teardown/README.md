# Surface-Teardown-Diagnose, 01.10.2026

**Offen: Die konkrete native Leckinstanz ist noch keinem Besitzer zugeordnet. Keine Runtime-Korrektur freigegeben oder vorgenommen.**

Der Surface-Vergleich [36824683113](https://github.com/MajorDragonfly/voxelverse/actions/runs/36824683113) prüfte Kandidat `74bbcbcf9854cd35eb0c816f95a65ad17d2e2dfe` gegen Baseline `0e0a1cda0d645f872cecd42881b3f6e53b3ba34e` mit derselben Messdatei (SHA256 `33fbf6b3b97b3ce19980b0b8695bdf13cba19b0a07a0e5db2ac1d2bd5f74a132`). Die eingefrorene Messdatei wurde ausschließlich in die Baseline kopiert; Produktquellen blieben dort unverändert.

## Native Belege

| Renderer | Ergebnis | Originalartefakt |
|---|---|---|
| GL Compatibility | Baseline: acht PNGs, `passed=true`, keine Messfehler. Danach `RefCounted:9223372224776375246 - Reference count: 0`; strikter Logfilter verwirft den Lauf. Kandidat startet deshalb nicht. | Job `110247615956`, Artefakt `11144398722` |
| Forward Plus | Vollständiger Vergleich bestanden: Collision-Digest gleich, Normalfehler 0.202186495065689 → 0.0. Beide Quellen unverändert und Messdatei identisch. | Job `110247615698`, Artefakt `11145058860` |

`diagnosis.json` enthält genaue Commit-/Tree-, ZIP- und Dateidigests. Originale GL-Import-/Render-/Joblogs und Capture-JSON sind hier erhalten; gzip-Dateien enthalten unveränderte Originalbytes. Die acht PNGs verbleiben im bezeichneten Originalartefakt. Der Forward-Bericht bleibt ein Nachweis seines eigenen Renderers, keine GL-Abnahme. Dies ist kein Performance-Schwellenfehler.

## Enge Quellen- und Laufzeitprüfung

Die Baseline ruft im Campaign-Exit `scenery.close()`, `flora.close()` und `adapter.close()` auf. Diese Wege joinen die Worker, nullen Jobs, leeren Staging-/Renderreferenzen und trennen Adapter-/Consumer-Signale. Auch der Terrain-Exit wartet seine Tasks ab. Der Messbericht wird erst nach allen Aufnahmen geschrieben; danach werden Scene/Camera freigegeben, vier Prozessframes abgewartet und der normale Runtime-Shutdown ausgeführt. Daraus ergibt sich kein belegter defekter Besitzer.

Eine separate headless Diagnose auf genau Baseline0e durchlief dieselben sechs Routen mit den zusätzlichen Side-/Low-Sun-Punkten und dem unveränderten Cleanup. Sie endete in 112.284 s innerhalb einer eigenen 120-s-Diagnosegrenze mit Exit0; der unveränderte strikte Fehlerfilter findet weder Scriptfehler noch ObjectDB-Leak. Pixel- und Timing-Messung wurden in dieser diagnostischen Kopie durch 18 Prozessframes ersetzt. Owner-/Signal-IDs werden nur als Zahlen/Strings gespeichert. Dies reproduziert den GL-Leak nicht und ist keine native Renderer-Abnahme. Script, Log, Bericht und Provenienz sind beigefügt. Ein erster Instrumentierungsfehler bei einer bereits freigegebenen Node-Referenz ist mit Originalbeleg ebenfalls erhalten.

Die exakten Godot-Quellen `4.6.3-stable` sind in `engine-source-identities.json` mit Blob-SHA dokumentiert. [ObjectDB cleanup](https://github.com/godotengine/godot/blob/4.6.3-stable/core/object/object.cpp#L2689) druckt die native Klasse. [GDScriptFunctionState](https://github.com/godotengine/godot/blob/4.6.3-stable/modules/gdscript/gdscript_function.h#L614) hat eine eigene Klasse; die Diagnose zeigt Await-IDs auch tatsächlich als `GDScriptFunctionState`. Der anonyme native `RefCounted`-Eintrag belegt somit keinen solchen Await-Zustand.

Ein konkret reproduzierbarer Mechanismus für **dieselbe Logform** steckt in [ResourceLoader cleanup](https://github.com/godotengine/godot/blob/4.6.3-stable/core/io/resource_loader.cpp#L1384): Unbeanspruchte User-LoadTokens werden dort unreferenziert, bei Null aber nicht gelöscht. `LoadToken` trägt keine eigene GDCLASS. Der beigefügte minimale Zweifall-Probe beweist mit derselben Engine: Threaded-Request auf leere Szene ohne Get → genau ein `RefCounted`, Referenzzahl0 (0.263 s); mit `load_threaded_get()` → sauberer Exit (0.258 s). **Das identifiziert den Mechanismus, nicht die Instanz aus dem Surface-Lauf.** SessionFlow beansprucht seine Kampagnenanfrage normalerweise durch Get; die vollständige headless Kampagne blieb sauber.

## Sinnvoller nächster Schritt

Eine einzige gezielte native Diagnose soll nach dem letzten PNG, vor Scene-Free, den Threaded-Status von `Context.SCENE` protokollieren. Die Baseline hat nur die eine öffentliche Threaded-Anfrage aus SessionFlow. Nach normaler vollständiger Beanspruchung muss deren Status `THREAD_LOAD_INVALID_RESOURCE` sein. Ein weiterhin geladener Token belegt eine Request/Get-Unwucht und erlaubt eine gezielte Besitzerprüfung. Für die konkrete ID-Zuordnung sind zudem direkt erreichbare Owner-IDs bzw. gegebenenfalls eine reine Engine-Diagnose der LoadToken-ID und ihres Ressourcenpfads nötig; IDs aus verschiedenen Läufen dürfen nicht gleichgesetzt werden. Signed GDScript-IDs beim Abgleich als uint64 normalisieren.

Erst ein Besitzerbeleg rechtfertigt einen engen Teardown-Fix. Kein spekulatives Get/Drain, keine zusätzlichen Wartezeiten, keine Leak-Ausnahme und kein unveränderter Blind-Retry. Produktquellen, eingefrorene Messdatei, Helper, paired Digest-/Source-Prüfungen, Messframes, Collision-Assertions, Fehlerfilter und native 900-s-Fristen bleiben in diesem Commit unverändert.

## Vorbereitete Beobachtung, noch nicht nativ ausgeführt

`observe-threaded-status.patch` fügt ausschließlich diese Statusausgabe nach allen Aufnahmen ein. Die Variante wurde mit Godot4.6.3 gegen Kandidat74bb und Baseline0e erfolgreich kompiliert. Die Produkt-Messdatei dieses Nachweiscommits bleibt unverändert. Zur späteren autorisierten Diagnose auf einem Runner mit Xvfb:

```bash
git worktree add -b agent/int30-surface-owner-observation /tmp/voxelverse-surface-owner 74bbcbcf9854cd35eb0c816f95a65ad17d2e2dfe
cd /tmp/voxelverse-surface-owner
git apply --unidiff-zero /absolute/path/to/observe-threaded-status.patch
git add tools/capture_surface_transitions.gd
git commit -m "Observe pending surface load request after paired captures"
xvfb-run -a python3 tools/review_surface_transitions.py --godot "$SURFACE_DIAGNOSTIC_EDITOR" --renderer gl_compatibility --output /tmp/voxelverse-surface-owner-result --baseline-ref 0e0a1cda0d645f872cecd42881b3f6e53b3ba34e
```

`SURFACE_DIAGNOSTIC_EDITOR` muss auf den unveränderten Godot4.6.3-Editor zeigen. Der Outputpfad muss neu sein. Diese Befehle wurden hier nicht nativ gestartet und veröffentlichen nichts. Der unveränderte Helper kopiert die identische Diagnosefassung auf beide Seiten und prüft ihren neuen SHA256 `2c871a08f3ee071d4c308f5ff677c223b3fc76311b67c58ca642cea0b96017b9` sowie die erlaubte Baseline-Injektion; alle Filter und 900-s-Fristen gelten weiter. Kein grüner Diagnosebericht ersetzt die Owner-Zuordnung oder die endgültige reguläre Abnahme. Bei Status0 ohne konkreten ID-Treffer bleibt der Besitzer offen; dann ist eine gezielte LoadToken-ID-/Pfad-Beobachtung im exakten Engine-Lifecycle sinnvoller als eine weitere unveränderte Aufnahme.

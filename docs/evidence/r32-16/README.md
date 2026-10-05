# R32-16 · #181 · Audioeinstellungen

Draft [#250](https://github.com/MajorDragonfly/voxelverse/pull/250), eigener Branch
`agent/r32-16-audio` ab `2a738a4891a8de11d682c469833ade4dc9b01dfb`
(Basis-Tree `f2bda4f815df1c73b9d740ca5282917523faf618`).

## Belegter Fix

Bei aktivierter Hintergrundstummschaltung wurde der VV-Masterbus beim Fokusverlust
korrekt stumm, die laufende Hörprobe behauptete auf der Audioseite aber weiterhin
„wird abgespielt“. Die Seite aktualisiert ihren Status jetzt auch an den beiden
Window-Fokussignalen. Der Produktionseingriff umfasst drei Zeilen in
`audio/ui/audio_settings.gd`; im bereits einmal registrierten
`tests/audio/audio_settings_test.gd` steht die negative/positive Regression.
Freigabe/Entfernung der Seite verwendet weiterhin Godots bestehende Signal-Lifecycle.

AudioManager, Menühost, Musikproduktion, Unterwasserfilter, Saves und gemeinsame
Registry wurden nicht verändert. Für einen weiteren Bus- oder Gameplayfehler
liegt hier kein Beleg vor. Die neuen Helfer dienen ausschließlich der Review.

## Ergebnisse und tatsächliche Quellen

| Nachweis | Ergebnis | Quelle/Original |
| --- | --- | --- |
| Unveränderte Basis | 285 Kontrollen positiv | `baseline-audio.zip` |
| Neue Fokusregression ohne Fix | 289 Kontrollen, genau ein Statusfehler | `focus-negative.zip` |
| Dieselbe Regression mit Fix | 289 Kontrollen positiv | `focus-positive.zip` |
| Native Audioseite, Linux GL/Software, Dummy-Audio | 313 Kontrollen, 12 PNG positiv | [Run 36971977245](https://github.com/MajorDragonfly/voxelverse/actions/runs/36971977245), `native-page-original.zip` |
| Aktuelle native Audioseite am finalen Codehead | 313 Kontrollen, 12 PNG positiv | [Run 36976483518](https://github.com/MajorDragonfly/voxelverse/actions/runs/36976483518), `native-page-final-original.zip` |
| Vollständige erste Kugelkampagnenprobe | 30 PCM und 8 PNG positiv; durch isolierte Kategorienprobe ergänzt | [Run 36974179964](https://github.com/MajorDragonfly/voxelverse/actions/runs/36974179964) |
| Isolierte Kategorien vor der zusätzlichen Quellenquittung | 315 Kontrollen, 46 PCM/8 PNG positiv | [Run 36975235923](https://github.com/MajorDragonfly/voxelverse/actions/runs/36975235923), `campaign-before-receipts-original.zip` |
| Finale Kategorien und Quellenquittung | 318 Kontrollen, 46 PCM/8 PNG positiv; 20 stumme WAVs exakt Null; zwei Quellenquittungen; [Run 36976484013](https://github.com/MajorDragonfly/voxelverse/actions/runs/36976484013) | `campaign-audio-original.zip`, `pcm-verification.json` |
| Bestehende Audio-Fach-CI | AudioRuntime, CreatureAudio, MusicRuntime, AudioExpansion, InterfaceAudio positiv | [Run 36976483493](https://github.com/MajorDragonfly/voxelverse/actions/runs/36976483493), `audio-domain-original.zip` |
| Bestehende Foley-Assetprüfung | 29 Assets positiv | `foley-signals.json` |

Alle Godotläufe verwenden **4.6.3.stable.official.7d41c59c4**. Die Originale
enthalten Befehle, Umgebung, Ergebnisse und Logs. Lokale Gegenproben tragen den
Basiscommit, sind ausdrücklich dirty und über vollständige Start-/Endmanifeste
identifiziert: ohne Fix `source_sha256=13f542ba0e9159b45ccf1fc625f0393557f584cdf7b885f84916d07792fdaf69`,
mit Fix `5e94250aa4e405372094dfe357c7ab702ee40065efd626948bb06c9452f30742`.
Der damalige Produktionseingriff und Test sind als `focus-fix.patch` beigelegt.
Die positive Probe hat dieselben Produktions-/Testbytes wie die Lieferung;
UI-SHA256 `7d1f211e8861598e38fd6ac6425c30c294d12ca24b6511b3463f734ce46ac277`,
Test-SHA256 `1b34097fd56599e9a79c316244b75c2e9898624769cf4a8ff4316c1d38db857c`. Sie
ist kein sauberer finaler Gesamt-Tree-Test.

Die aktuelle native Audioseiten-CI prüfte clean/unchanged den PR-Mergecommit
`8fcc3ccd93ed689a83b89d49c167b09271f44dd9`, Tree
`b4d948c0aa6210291fa116bc7b31b34722a51b7e`, aus der Integrationsbasis und
Fachhead `1ee299a438cd6b0822ae7df32f1208d834f79b6e`.

Die erste native Audioseiten-CI prüfte den echten PR-Mergecommit
`86fc3c7c770b044b7f048832cdff27a30b9695bc`, Tree
`f5950638fe927fb8cc97f989ed63f7434624c0bb`, aus Integrationsbasis und erstem
Fachhead `3b6c5499d6269f1bb67d4919968c972b4224ed59`.
Die ursprünglichen Seitenreports deklarieren clean/unchanged, enthält aber noch nicht die
vollständigen Manifeste des neuen Kampagnenhelfers. Diese Reichweite wird nicht
nachträglich erweitert. Der synthetische Produktion-Voice-Signaltest misst bei
halber Lautstärke RMS-Verhältnisse 0,499764–0,500350; Kategorien-/Mastermute
ergibt exakt RMS 0. Musik/Umgebung/Effekte/UI laufen durch die vorhandenen Busse.

Die finale native Kampagnenquelle ist separat und unverändert beobachtet:
Commit `8e24227b73323d49684610f999d4a149343634a8`, Tree `ca20c22ff9f6b55270a1d441d20ea5b73efd8310`, clean; Start/Ende `source_sha256=ce4eef846a7796e5a98dff945067d63d4168d5c5ac326fa355d765d29461be91`, stable/reusable. Ihr Diagnose-Tree enthält zusätzlich genau den optionalen
CI-Workflow. Die Fachquellen entsprechen Commit
`1ee299a438cd6b0822ae7df32f1208d834f79b6e`, Tree
`cd6a137144697638743092608952d4bfec9f89c3`. Die anschließend ergänzten
Nachweisdateien sind keine erneut geprüften Produktionsänderungen. Endgültiger
Liefercommit/Tree stehen im PR und in der zentralen Übergabe; das vermeidet einen
selbstreferenziellen Commit in dieser Datei.

## Was die Kampagnenprobe tatsächlich tut

Der öffentliche Titel-Einstieg startet die vorhandene Kugelkampagne mit dem
regulären Tribal-Playtest. Die gewöhnliche Phasenbestätigung wird zuerst
abgebrochen, nach der Kreaturenprüfung erneut geöffnet und bestätigt. Es gibt
keine ersetzte Szene, erfundenen Audioquellen oder umpositionierten Bewohner.

In **Kreaturen- und Stammesphase**, jeweils DE und EN bei 1280×720 und
**zur Laufzeit gesetzten 150 %**, werden Esc → Einstellungen → Audio, Mausmute,
Keyboard-Hörprobe, Slider links, 100/0 %, gemerkter Wert beim Entstummen, Reset,
Rücknavigation und wiederhergestellter Kategorienfokus geprüft. Die Kampagnenzeit
bleibt im Audiomenü stehen, Back beendet die Hörprobe. Ein wirklich neu gestarteter
Godot-Prozess liest Master 71 %, Musik 0 %, Umgebung 29 %, Effekte 43 %, UI 57 %,
Nachtmodus und Hintergrundstummschaltung aus denselben isolierten Nutzerdaten.
Die Stammesprobe erhält außerdem taktische Pause und Space-Eigentümerschaft.

Die **46 unveränderten Stereo-PCM16-Aufnahmen** kommen hinter dem tatsächlichen
Mastermixer aus `AudioEffectCapture`, ohne Testton in dieser Kampagnenprobe:

- Zwei normale automatische Weltmixe mit bestehender Musik-/Umgebungsproduktion.
- Je Phase eine vorhandene Bewohnerreaktion und ein vorhandener Aktionssound.
  Beide Bewohnerreaktionen werden ausdrücklich über `play_creature` ausgelöst;
  zusätzlich muss `creature_sound_played` genau eine Quittung mit der Quellen-ID
  des ausgewählten Bewohners liefern (ID, Ereignis, Pitch und Familie im Original).
  Das Essen verwendet `play_action` am realen Player. Das sind **geskriptete Audioports**, keine bewiesenen gewöhnlichen
  Begegnungen oder Mahlzeiten. An deren Spielverdrahtung wurde nichts verändert.
- Je Phase/Sprache fünf echte Kategorie-Hörproben. Musik, Wind, Essen und
  Menübestätigung werden auf ihrer jeweiligen Kategorie isoliert; der Masterfall
  lässt die übrigen Kategorien offen. Danach wird dieselbe echte Hörprobe auf der
  stummen Kategorie erneut gestartet und als Nullsignal aufgenommen.

`cases.json` im Original dokumentiert Pegel, Rezepte, Mixerfrequenz, Kontext und
Pausenzustand. Die stummen Aufnahmen beginnen nach ausdrücklich protokollierten
180 ms Mixer-Einschwingzeit, wie im vorhandenen Routingtest. Der unmittelbare
Stummübergang ist im zusätzlichen Originalnegativ erhalten, siehe unten.
`pcm-verification.json` prüft unabhängig die gespeicherten WAV-Bytes,
Hashes, Dauer, Kanäle, Spitzen und RMS. Kein Normalisieren, Schneiden oder neuer Mix.
`listening-pack.zip` enthält dieselben WAVs und PNGs plus einen lokalen Player
(`index.html`, entpacken und öffnen); die Originalarchive enthalten zusätzlich
die Rohlogs und vollständigen Quellmanifeste.

Die Window-Fokussignale werden in der Regression **explizit injiziert**. Das
belegt UI-/Busreaktion auf das Signal, keinen Betriebssystemwechsel des Fokus.
Die zwölf separaten Audioseitenbilder decken 800×600, 720p und 1080p, DE/EN,
jeweils oben/unten ab. Die acht Kampagnenbilder zeigen beide Phasen/Sprachen und
den korrigierten Hintergrundstatus. Die begrenzte Sichtprüfung ist in
`visual-review.txt` festgehalten.

## Erhaltene Negative

Zwei Fehler des neuen Prüfhelfers und eine zusätzliche Signalgegenprobe bleiben
als originale Negative erhalten:

1. [Run 36972542623](https://github.com/MajorDragonfly/voxelverse/actions/runs/36972542623):
   fehlende explizite String-Typisierung, Parserfehler vor Kampagnenstart,
   keine Aufnahmen/Bilder, durch 360-s-Prozessgrenze beendet.
   `campaign-parser-negative-original.zip`.
2. [Run 36973334253](https://github.com/MajorDragonfly/voxelverse/actions/runs/36973334253):
   Zugriff auf die nach dem Phasenwechsel leere HomeGroup-Liste. 16 WAV/4 PNG,
   strenger Runner insgesamt negativ trotz damaligem irreführendem PASS-Marker
   des GDScript-Helfers. `campaign-fixture-negative-original.zip`.
3. [Run 36974403100](https://github.com/MajorDragonfly/voxelverse/actions/runs/36974403100):
   Alle 46 WAV/8 PNG und 315 Kontrollen vollständig, vier unmittelbare
   Umgebung-Mute-Aufnahmen negativ. Unveränderte WAV-Auswertung ergibt jeweils
   nur die ersten 28 Frames mit Signal (letzter bei 0,612 ms), ab 10 ms exakt Null.
   Das ist mit einem kurzen Rest im vorhandenen World-Tiefpass vereinbar; ein
   kontinuierliches Muteleck wurde nicht nachgewiesen. Die finale Steady-State-Probe
   verwendet die bereits im Routingtest eingesetzten 180 ms; die unmittelbare
   Gegenprobe wird nicht zu einem Erfolg umgeschrieben. Original:
   `category-transition-negative-original.zip`, Analyse:
   `category-transition-analysis.json`. Filter-/Unterwasserproduktion unangetastet.

Der Helfer nimmt jetzt tatsächliche Bewohner aus dem jeweiligen Besitzer,
verlangt zwei vollständig beendete Phasen, taktischen Lifecycle und alle 46
Aufnahmen. Der Pythonrunner verlangt zusätzlich alle Bilder, positiven Marker,
saubere unveränderte Quelle und keinen ERROR-/Leak-/Scriptfehler. Die separate
CI macht vor dem Kampagnenstart eine echte `--check-only`-Parserprüfung.

## Anschluss und offene Abnahme

R32-01 erhält `ci-owner.patch` als **optionalen additiven Workflowanschluss**.
Er wurde nicht auf dem Fachbranch unter `.github/workflows` angewandt; bestehende
Workflows und Testregistry sind unverändert, der Regressionstest ist bereits
registriert. Für die finale Integration den Workflow auf den gewünschten Branch
anpassen und die kombinierte Probe auf dem tatsächlichen Integrations-Tree
ausführen. R32-15 behält Menühost, reguläre 125/150-%-Einstellung und deren
Persistenz. Das Laufzeit-150-%-Override hier ist kein Nachweis dafür.

**#181 bleibt offen.** Diese Linux-Quellläufe mit Dummy-Ausgabe belegen Signal,
Bedienung und Lifecycle. Sie ersetzen weder Windows-/Exportprüfung noch die vom
Auftrag verlangte gemeinsame Hörprüfung auf Lars’ Ziel-PC. Dort beide Phasen
über den normalen Esc-Weg öffnen; reale Musik, Wetter/Umgebung, Tiere, Aktionen
und Menüs hören; Master und jede Kategorie senken, auf 0 setzen, stummschalten
und wiederherstellen; Hörproben und Reset vergleichen; alle Rückschritte sowie
gespeicherte Werte nach Spielneustart prüfen. Native Fokuswechsel ebenfalls dort
prüfen. Lautheit, Balance und Verständlichkeit brauchen diese Hörentscheidung.

Lokaler Shared-Host wurde für die native Kampagnenprobe nicht weiter belastet;
die Captureläufe verwendeten unabhängige GitHub-Hosts. Die konservative Auswahl
plant FULL 267/Main wegen der neuen Toolpfade, führt damit nichts aus. Volle Suite,
gemeinsame Produktionskette, Pflichtgates, Exporte und Merge bleiben bei R32-01.

## Reproduktion

```bash
python3 tools/validate_godot.py --godot /path/to/godot --tests audio/audio_settings_test --skip-main --output /tmp/r32-16-audio-unit
python3 tools/audio/check_foley.py --output /tmp/r32-16-foley.json
godot --headless --path . --import
godot --headless --path . --script res://tools/review_r32_16_audio_campaign.gd --check-only
xvfb-run -a -s '-screen 0 1920x1080x24' python3 tools/review_r32_16_audio.py --godot /path/to/godot --mode campaign --output /tmp/r32-16-campaign-audio
```

Keine vorhandenen Ausgabeverzeichnisse überschreiben. Native Läufe nur im
zugeordneten Hostslot oder auf einem unabhängigen Host ausführen. Dateihashes und
CI-/Quellzuordnung stehen zusätzlich maschinenlesbar in `evidence-index.json`.

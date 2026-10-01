# INT30-21 Unterwasser-Audio

Feste Fachbasis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`, Tree `5f815f478ceeabefcfc50a6388e3e4b0daa2ac45`. Eigener Branch: `agent/int30-21-underwater-audio`. Produktionsbereich durch Nutzer zugewiesen und in #137 gemeldet; Umwelt-/Wasser-Foley in aktueller INT30-Tabelle bestätigt. Benötigte zusätzliche Assetdateien sind `water_dive.wav`, `water_surface.wav` und die sechs betroffenen Manifest-Einträge. AudioManager, Einstellungen, Musik, Wasserabfrage, Übersetzungen und zentrale Registry im Fachbranch unverändert.

## Befund und Ergebnis

Der tatsächliche aktuelle Loop enthält vorwiegend tiefe Rauschenergie: 20,83 % unter 60 Hz, insgesamt 79,98 % unter 150 Hz. Hochfrequentes Hiss und ein auffälliger Schleifensprung sind auf dieser Basis **nicht** belegt. Die gemeldete subjektive Störung wird deshalb nicht vollständig auf ein bestimmtes Frequenzband zurückgeführt. Das konstante Bett wird zurückhaltender gestaltet; vorhandene Originalassets werden deterministisch gefiltert und abgesenkt, ohne Normalisierung oder fremde Samples.

Zwei konkrete Runtimefehler reproduziert der echte Mixerfall auf unveränderter Produktbasis: zwei gleichzeitig laufende Ein-/Auftauchstimmen bei Wechseln alle 0,67 s; weiterhin laufender Unterwasserloop 0,55 s nach dem Auftauchen. Ursache der Überlappung: Sperre 0,65 s gegenüber 0,75/0,82 s langen Clips. Zusätzlich kann Physik-Catch-up gegenüber dem Mixer vorlaufen; eine reine verlängerte Simulationssperre reicht dann nicht aus.

Die Sperre ist jetzt 0,85 s. Die vorhandenen 16 Managerstimmen werden begrenzt lesend geprüft. Ein noch beobachteter Gegenwechsel wartet auf das echte Ende des vorherigen Clips; es gibt genau einen vorgemerkten Zustand und keine Ereigniswarteschlange. Zurückkehren auf die bereits präsentierte Seite verwirft den vorgemerkten Wechsel. Spawn, Stall und Trackingreset initialisieren still. Der vorhandene einzelne Unterwasserloop blendet in 0,65 s ein und in 0,35 s aus, ohne Neustart bei bloßer Richtungsumkehr. Wasserabfrage, Hysterese und Mixerroute bleiben erhalten.

## Signalwerte

| Asset | RMS vorher (dBFS) | RMS nachher (dBFS) | Änderung |
|---|---:|---:|---:|
| Unterwasserbett | -35,54 | -44,87 | -9,34 dB |
| Eintauchen | -31,65 | -36,14 | -4,49 dB |
| Auftauchen | -31,41 | -37,81 | -6,40 dB |
| Blasen 0 | -40,17 | -43,81 | -3,64 dB |
| Blasen 1 | -38,89 | -42,54 | -3,65 dB |
| Blasen 2 | -38,24 | -42,01 | -3,76 dB |

Der Anteil unter 60 Hz im Bett sinkt auf 2,08 %. Schleifennaht: 0,000641 → 0,000275 linear; gewöhnlicher 99-%-Sampleschritt nachher 0,000610. Beide Schleifen sind acht Sekunden, stereo und ohne auffälligen Nahtsprung. Alle Einmalklänge behalten ihre bisherigen Längen/Kanäle und stille geglättete Endpunkte. Alle 29 vorhandenen Foley-Assets bestehen die bestehenden Datei-/Pegel-/Manifestprüfungen. Die sechs neuen PCM-Dateien sind bytegenau reproduziert; andere Assetbytes bleiben erhalten. Vollständige Messung: [pcm-measurements.json](pcm-measurements.json), [Reproduktion](reproduction.json).

## Hörproben

[Vorher anhören](before.ogg) · [Nachher anhören](after.ogg)

Tatsächliche Master-Mixer-Ausgabe aus Godot 4.6.3 mit dem bestehenden Director, radialer Diagnose-Wasserquelle und echten importierten Assets. Alle Kategorie-Fader stehen für den Vergleich auf 1, Nachtmodus aus; keine individuelle Lautheitsnormalisierung. Musik/automatische Tiere sind in der Fixture abgeschaltet. Vorbis-Kodierung mit FFmpeg, Qualität 6, ohne weiteren Filter. Es sind Diagnoseszenen-Hörproben, kein Windows-/Ziel-PC-Mitschnitt und kein subjektiver Hörbefund des Agenten.

Ablauf: Eintauchen; achtsekündige Schleifennaht; Pause/Fortsetzung; Umgebung und Master stumm; Auftauchen; zehn Oberflächenwechsel mit 0,67-s-Abstand; Bewegung und echte Blasen. Die nachher Aufnahme verwendet denselben finalen Produktionscode wie der erweiterte Lifecyclefall. Letzterer ergänzt nach diesen Aufnahmen zusätzlich Effektestumm und echten Szenenwechsel während Pause. Die früheren Capture-Fixtures besitzen entsprechend weniger Zusatzassertions. Headless-Dummy-Mixer und Wallclock liefern nicht identische Zeitachsen; PCM-Dauer, SHA256 und unveränderte Vorbispegel sind in [mixer-provenance.json](mixer-provenance.json) dokumentiert. Zeitabläufe und Ergebnisse: [vorher](before-lifecycle.json), [nachher](after-lifecycle.json).

## Prüfung und Besitzeranschlüsse

Engine: `4.6.3.stable.official.7d41c59c4`, Linux, headless/Dummy, isolierte XDG-Nutzerdaten. Alle Messungen bleiben getrennt von Gesamtintegration, nativen Exporten und Lars’ Hörtest.

- Auf sauberer unveränderter Fachbasis bestehen `spherical_water_audio_test`, `foley_runtime_test`, `audio_scene_lifecycle_test` einschließlich Erstimport und Quellintegrität: [Basisbericht](baseline-godot-results.json).
- Regressionsaufnahme auf unveränderter Produktbasis scheitert genau an Nachklingen und zwei Übergangsstimmen: [Log](before-lifecycle.log).
- Finaler eigener Verbraucherfall besteht mit 58 Kontrollen und sieben weiteren Kontrollen im frischen Prozess: [Log](final-lifecycle.log), [Prüfbericht](patched-focused-godot-results.json). Er prüft tatsächliche Ausgabe bei Pause/Umgebung-/Effekt-/Masterstumm (RMS jeweils 0), gehaltene/verworfene Übergänge, Mixer-Catch-up, Oberflächenwechsel, idle/Bewegungsblasen, unveränderten Node-/Stimmenpool, maximal vier bestehende Wasserabfragen pro Tick, Entfernen/Restaurieren der Quelle, tatsächlichen Szenenwechsel während Pause, gespeichertes Stumm und Unterwasser-Neustart ohne erfundenen Eintauchklang.
- Der bestehende Foley-Test ist auf unverändertem Testquellstand zunächst rot: seine manuell beschleunigte Simulation erwartet den zweiten Eintauchklang schon nach drei process_frame-Ticks, obwohl der vorige reale Clip noch läuft. Der enge [Foley-Zeitpatch](foley-mixer-timing.patch) wartet begrenzt auf dasselbe reale Ereignis. Erwartung `water_dive == 2`, Bewegung, Pausenaktion und globaler Timeout bleiben erhalten. Mit diesem Patch besteht die unveränderte Zahl von 24 Assertions: [Log](patched-foley.log). Erster Fehler und unveränderte Quellberichte bleiben daneben erhalten.
- Gemeinsame Bestands-Testdatei und Registry sind im Fachbranch **nicht angewendet**. Die Prüfkopie enthält genau den [Registry-Anschluss](registry.patch) (ein Eintrag im vorhandenen Vertrag `audio`) und den Foley-Zeitpatch, ausdrücklich durch Quell-SHA256 im Prüfbericht identifiziert. Chat 1 übernimmt diese Anschlüsse nacheinander. Kein notwendiger AudioManager-Produktionspatch.

Die konservative Planung verlangt nach Registry-Integration die vollständige Suite/Runtimeprüfung; der vorhandene Audio-Dateipfad wählt außerdem Wildtier- und Kugelspiel-Verbraucher. Diese Integrationsprüfungen dürfen durch die Fachbelege nicht ersetzt werden. Der komplette lokale Audiovertrag wurde gegen exakt dieselbe Prüfkopie ausgeführt: 13/14 Tests bestanden im ersten Lauf; `animal_action_feedback_test` erreichte im Laboraufbau unter Speicherlast den unveränderten 120-s-Timeout. Genau dieser Test wurde einmal mit identischer Quelle, Engine, Assertions und Timeout wiederholt und bestand in 12,620 s. Damit liegen für alle 14 Audiotests gültige Einzelbelege vor; der erste Komplettlauf bleibt als fehlgeschlagener Bericht erhalten. [Zusammengeführter unveränderter Quellnachweis](audio-contract-combined.json), [erster Lauf](audio-contract-godot-results.json), [gezielte Gegenprobe](animal-feedback-recheck-results.json). Ein eigener Fach-PR mit noch nicht angewendetem Registry-/Testanschluss ist zunächst Review/Draft; keine main-/Auto-Merge-Freigabe.

Die gemeinsam ausgelastete 8-GiB-Umgebung verursachte außerdem einen Start-Timeout und einen Timeout im zusätzlichen frischen Prozess; diese Fehlversuche gelten nicht als Prüferfolg. Der Instrumentierungsversuch mit AudioEffectRecord löste einen Engine-Crash aus und wurde durch bestehendes AudioEffectCapture ersetzt. Nachweise werden mit dieser endgültigen Capture-Methode erhoben; keine fremden Prozesse beendet, keine Produktbudgets angehoben.

## Reproduzieren

```sh
python3 audio/tools/refine_underwater.py
python3 tools/audio/check_foley.py --baseline-ref 2b1ac023db4074c2ce6b7db8fbab09ab929a8435 --output /tmp/underwater-foley.json
python3 audio/tools/measure_underwater.py --output /tmp/underwater-pcm.json
# In einer getrennten Prüfkopie; gemeinsame Dateien nur durch deren Besitzer übernehmen:
git apply docs/evidence/int30-underwater-audio/registry.patch
git apply docs/evidence/int30-underwater-audio/foley-mixer-timing.patch
python3 tools/validate_godot.py --godot /path/to/godot-4.6.3 --contracts audio --skip-main --output /tmp/underwater-audio-checks
# Hörprobe mit isolierten Nutzerdaten und zuvor importierter Quelle:
godot --headless --path . --script res://tests/audio/int30_underwater_audio_test.gd -- --capture-dir /tmp/underwater-audition
```

Der Capture-Ordner muss existieren. Der Test speichert PCM und JSON mit Dateihashes sowie Mixer- und Wallclock-Zeitpunkten. Keine Hörqualität-/Ziel-PC-/FPS-Abnahme wird aus Signalzahlen, Linux-Dummy-Ausgabe oder grünem Einzeltest abgeleitet.

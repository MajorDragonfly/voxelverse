# Voxelverse Audio-Grundlage

Eigenständiges Paket auf main `c9be789b9d1b1effa9e3b30a653c739feb392b25`.
Keine Übernahme unfertiger Arbeiten anderer Chats. Einzige geänderte Bestandsdatei:
`project.godot` registriert den neuen AudioManager-Autoload.

## Ausprobieren

- Hauptszene starten: Schritte, Springen, Landen und Umgebungsgeräusche sind angeschlossen.
- F7 öffnet die Audioeinstellungen; F7/Escape schließt sie. Änderungen werden gespeichert.
- `audio/audio_playground.tscn` im Editor öffnen und F6 drücken: alle Klänge anhören,
  Richtung/Entfernung vergleichen, Umgebungsloops und Unterwasserfilter testen.
- Die 29 eigenen, synthetisierten Dateien sind spielbare Prototyp-Klänge.
  Ihr Klangcharakter braucht noch einen Hörtest auf dem Zielgerät.

## Verhalten

Getrennte Kanäle für Gesamtlautstärke, Musik, Umgebung, Spieleffekte und Menü.
0 % schaltet den jeweiligen Kanal stumm. Einstellungen liegen ausschließlich in
`user://audio_settings.cfg`; Spielstände werden nicht verändert.
16 räumliche Effektstimmen und vier Menüstimmen begrenzen die Ressourcen.
Ein Limiter schützt den Ausgang vor Übersteuerung. Weltgeräusche pausieren mit
dem Spiel; Menügeräusche bleiben bedienbar. Unter Wasser werden Spieleffekte und
Umgebung gedämpft, Musik und Menü bleiben klar.

Schritte folgen der tatsächlichen Bewegung, nicht den gedrückten Tasten. Gras,
Sand, Stein, Schnee, Holz und Wasser haben je drei wechselnde Varianten.
Collider-Metadatum `audio_surface` überschreibt die sonst verwendete Biomeinordnung.
Stillstand, Spawn, Teleport und blockierte Bewegung erzeugen keine Schrittserie.
Sprung und Landung verwenden Bodenkontaktwechsel.

Waten und tiefere Wasserbewegung haben unterschiedliche Klänge. Schwimmphysik
wird hier nicht hinzugefügt. Die Kameraposition bestimmt unabhängig von den Füßen,
ob der Unterwasserfilter aktiv ist. Wind, Blätter und Unterwassergeräusche blenden
weich um. Wasserambiente ist räumlich an einer nahen Wasserprobe verankert.
Ein Fluss-Biom allein löst keine Wassergeräusche aus. Die Ufersuche ist eine lokale
Näherung; Schallverdeckung durch Hindernisse ist noch nicht umgesetzt.

## Anschlüsse für die anderen Chats

Menü: `AudioManager.open_settings()` öffnet das mitgelieferte Panel.
Eigene Regler können `set_volume(channel, value)` und `get_volume(channel)` mit
Werten von 0.0 bis 1.0 verwenden. `settings_changed(channel, value)` meldet Änderungen.
Kanalnamen: `master`, `music`, `ambience`, `effects`, `ui`.
`fallback_shortcut_enabled = false` deaktiviert F7, sobald das Hauptmenü übernimmt.
Das Panel stellt beim Schließen den vorherigen Pause- und Mauszustand wieder her.

Spielereignisse:

```gdscript
AudioManager.play_ui(&"discovery")
AudioManager.play_world(&"step_stone", global_position, -3.0, 1.0, get_instance_id())
AudioManager.register_sound(&"creature_contact", [my_imported_audio_stream])
```

Die Parameter für `play_world` sind Ereignis, Position, Pegel in dB, Tonhöhe,
Quell-ID. Unbekannte Ereignisse, Pause, volle Stimmenbelegung oder Wiederholung
innerhalb von 80 ms je Quelle/Ereignis ergeben false. Die Zuordnung lässt sich
über `register_sound` austauschen, ohne Spielcode zu verändern.

Ereignisse: `step_grass`, `step_sand`, `step_stone`, `step_snow`, `step_wood`,
`step_water`, `jump`, `land`, `splash`, `swim`, `ui_confirm`, `ui_back`, `discovery`,
`wind_loop`, `foliage_loop`, `water_loop`, `underwater_loop`.

Entdeckungstöne sind vorhanden; der Fortschritts-Chat muss sie an erfolgreiche
Entdeckungen anschließen. Individuelle Kreaturenstimmen und ein Soundtrack sind
noch nicht Teil dieses ersten Pakets. Der Musikkanal ist dafür vorbereitet.

## Welt und spätere Planeten

Der Standardadapter liest die Gruppe `player` und WorldGenerator-Methoden
`get_terrain_height`, `get_sea_level`, `get_biome`, `get_biome_name`.
Wasser liegt derzeit auf der gerenderten Ebene `sea_level + 0.03` und wird nur bei
darunterliegendem Gelände angenommen. Der visuelle Orbit-/Weltraummodus blendet
Außenambiente aus. Profilwechsel und Spielerwechsel setzen die Verfolgung zurück.

Für spätere Seen/Flüsse lässt sich
`AudioManager.director.sample_provider = my_sample_function` setzen.
Die Funktion nimmt eine Vector3-Position entgegen und liefert ein Dictionary mit
`water_present` (bool), `water_height` (float), `ground_height` (float),
`biome_name` (String). Der Adapter erwartet aktuell die bestehende lokale Y-Achse
als oben. Für Kugelgravitation müssen Tiefenprüfung und Uferabtastung zusammen mit
der Koordinatenanbindung angepasst werden; Audio-API und Busse bleiben nutzbar.

## Prüfung

Godot 4.6.3: sauberer Erstimport, Hauptszenenstart, Hörtest-Szenenstart und gezielte
Physik-/Audiotests erfolgreich. Das exportierte PCK wurde aus einem separaten
Verzeichnis mit demselben Laufzeittest geprüft: erfolgreich. Alle WAV-Dateien
wurden auf vorhandenen Signalpegel, Clipping, Endpunkte und Loopübergänge geprüft.
Eine grafische Abnahme und ein Hörtest unter Windows stehen aus.

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/audio/audio_runtime_test.gd
```

Tests bitte mit eigenem Benutzerverzeichnis ausführen: Sie prüfen bewusst das
Speichern und Zurücksetzen der Audioeinstellungen. Die neue Audio-CI setzt dafür
XDG_DATA_HOME. Die anderen Arbeitszweige und main werden nicht zusammengeführt.

# Voxelverse Audiopaket

Eigenständiges Paket auf main `c9be789b9d1b1effa9e3b30a653c739feb392b25`.
Keine Übernahme unfertiger Arbeiten anderer Chats. Einzige geänderte Bestandsdatei:
`project.godot` registriert den neuen AudioManager-Autoload.

## Ausprobieren

- Hauptszene starten: Erkundungsmusik, Schritte, Springen, Landen und Umgebungsgeräusche sind angeschlossen.
- F7 öffnet die Audioeinstellungen; F7/Escape schließt sie. Änderungen werden gespeichert.
- `audio/audio_playground.tscn` im Editor öffnen und F6 drücken: alle Klänge anhören,
  Richtung/Entfernung vergleichen, Umgebungsloops und Unterwasserfilter testen.
  Oben lassen sich alle drei Musikstücke, ein achtsekündiger Gefahrwechsel und
  „Musik + Umgebung“ auswählen; darunter Schritte und Kreaturen dazuschalten.
  Die Seite ist scrollbar. F7 regelt den gesamten Mix.
- Die 65 eigenen Effekte/Umgebungs-/Kreaturenklänge und drei Musikstücke sind spielbare Prototypen.
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
Quell-ID. Unbekannte Ereignisse, Pause, ein voller Pool ohne verdrängbare Stimme oder Wiederholung
innerhalb von 80 ms je Quelle/Ereignis ergeben false. Die Zuordnung lässt sich
über `register_sound` austauschen, ohne Spielcode zu verändern.

Ereignisse: `step_grass`, `step_sand`, `step_stone`, `step_snow`, `step_wood`,
`step_water`, `jump`, `land`, `splash`, `swim`, `ui_confirm`, `ui_back`, `discovery`,
`wind_loop`, `foliage_loop`, `water_loop`, `underwater_loop`.

Kreaturenstimmen und optionale Erfolgsereignisse sind im zweiten Paket enthalten
(siehe unten). Das dritte Paket ergänzt einen spielbaren Soundtrack (siehe unten).

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


## Ausbau: Kreaturenstimmen und Ereignisse

36 zusätzliche, eigene nichtsprachliche Laute: heller Ruf, Kehllaut und raues
Knurren, jeweils Kontakt/Warnung/Angriff/Verletzung/Tod/freundliche Antwort mit
zwei Varianten. Ein stabiles Artenprofil und die aktuelle Körpergröße bestimmen
die Tonhöhe. Der Profilgenerator verwendet einen eigenen Zufallsgenerator und
verändert die Zufallsfolge von Welt oder Verhalten nicht.

Der AudioManager ergänzt vorhandene Knoten der Gruppen `wildlife`, `grazer` und
`player` um ein Kind `_VoxelverseAudio`. Es werden weder Lebenspunkte noch KI,
Beziehungen, Bewegung oder gespeicherte Blueprints verändert. Automatische
Wildtierrufe sind zeitlich versetzt und leise. Maximal 64 Kreaturen werden verfolgt;
48 m Entfernung und die Weltraumansicht unterdrücken unhörbare Stimmen. Entfernte
Knoten werden aus der Verfolgung entfernt, ihre Stimmen beendet.

Lebensverlust wird über vorhandene `health_changed(current, maximum)`-Signale
oder einen lesenden Vergleich der Gesundheit erkannt. Heilung und Änderungen der
maximalen Gesundheit gelten nicht als Treffer. `creature_defeated(creature)` und
`died()` werden zusammen mit dem Gesundheitszustand gegen doppelte Todeslaute
gesichert. `respawned()` setzt das Stimmleben zurück. Ein vorhandenes Signal
`creature_attacked(target, damage)` löst einen Angriffslaut aus.

Warnung und freundliche Reaktion entstehen nur durch ein echtes externes
Ereignis; die Audioanbindung errät weder Aggression noch Freundschaft aus Nähe.
Der Verhaltens-/Sozial-Chat kann nach einem erfolgreichen Ereignis aufrufen:

```gdscript
AudioManager.play_creature(&"warn", creature)
AudioManager.play_creature(&"friend", creature)
AudioManager.play_creature(&"attack", creature)
```

Alternativ kann die Kreatur `signal audio_event(event: StringName)` anbieten und
`audio_event.emit(&"warn")` auslösen. Ereignisse: `contact`, `warn`, `attack`,
`hurt`, `death`, `friend`. `audio_disabled = true` als Knotenmetadatum deaktiviert
die Stimme. `audio_body_size` überschreibt die aus Blueprint/Skalierung gelesene
Größe. Die Spielerfigur ruft nicht automatisch in regelmäßigen Abständen.

Die Stimmen verwenden denselben begrenzten Pool. Wichtige Reaktionen können
niedriger priorisierte Rufe verdrängen; Schritte können beiläufige Rufe verdrängen.
`play_world` hat dafür einen optionalen letzten Parameter `priority` (0–2,
Standard 1). Kreaturenruf=0, Bewegung=1, Reaktion=2. Wiederholte Warnungen und
freundliche Antworten sind zusätzlich gedrosselt.

Falls `ProgressionService` vorhanden ist, werden die bereits geprüften
Signalverträge `species_discovered(key, display_name)` und
`behavior_node_purchased(node_id)` automatisch angeschlossen. Der Service wird
nicht mitgeliefert oder aus einem anderen Arbeitszweig übernommen. Das Basisspiel
hat diese Anschlüsse möglicherweise noch nicht; die Anbindung bleibt dann still.
Ein vorhandenes Angriffs-/Gesundheitssignal wird genutzt, keine private KI-Variable.

Die Hörtest-Szene enthält jetzt Art-/Größenauswahl und sechs Reaktionsschaltflächen.
Die Klänge sind weiterhin Prototypen; die finale Klangqualität benötigt einen
Hörtest. Kein eigener Warn-/Sozialzustand wird durch das Audiopaket eingeführt.

Zusätzlicher Test:

```sh
godot --headless --path . --script res://tests/audio/creature_audio_test.gd
```

Er prüft deterministische Artenstimmen, Größenunterschiede, automatische Rufe,
echte Signale, Verletzung/Heilung/Statänderung, Todesduplikate, Wiederbelebung,
Distanz, Pause, Stimmenpriorität, Bereinigung und optionale Entdeckungsanbindung.


## Ausbau: Musikpaket

Drei eigene instrumentale Kompositionen mit warmen Flächen, hellen Synth-Keys,
einem gemeinsamen Motiv und zurückhaltendem Elektro-Groove. Alle verwenden
96 BPM, 4/4 und D-Dorisch mit demselben achttaktigen Harmoniezyklus. Die Arrangements
ändern innerhalb des Stücks Dichte, Bass und Schlagzeug. Gesang ist nicht enthalten.

| Kontext | Stück | Länge | Charakter |
| --- | --- | --- | --- |
| `menu` | Kleine Umlaufbahn | 40 s / 16 Takte | Helle Keys und lockerer Rhythmus |
| `exploration` | Unter fremden Blättern | 60 s / 24 Takte | Ruhige Flächen, luftiges Motiv, sparsame Percussion |
| `danger` | Etwas im Unterholz | 40 s / 16 Takte | Bewegter Bass und dichterer Rhythmus |

Die Stücke liegen als Stereo-Ogg mit 32 kHz vor, zusammen etwa 1 MB. Der Generator
legt Notenausklänge und Delay-Echos über die Schleifengrenze. Die Dateien werden
im Spiel gestreamt und endlos abgespielt. Kein Python oder FFmpeg ist zum Spielen
nötig. Partitur und Herkunft: `audio/assets/music/score.json` und
`audio/assets/PROVENANCE.md`; Generator: `tools/audio/generate_music.py`.

Zwei Musikstimmen reichen für weiche Übergänge: normal drei Sekunden, hinein in
Gefahr 1,2 Sekunden. Der neue Titel übernimmt die musikalische Position des alten.
Schnelle Wechsel merken sich den zuletzt gewünschten Kontext und führen zunächst
die laufende Blende zu Ende; es entstehen keine zusätzlichen Player. „Musik aus“
ist eine Ausblendung. Der Lautstärkeregler auf 0 % schaltet sofort stumm.
In Pause laufen Musik und Übergänge weiter, Weltmusik wird auf halben Pegel
abgesenkt. Die Gefahruhr pausiert. Beim Fortsetzen steigt der Pegel wieder an.
Menümusik wird in Pause nicht abgesenkt. Der Unterwasserfilter betrifft Musik nicht.

Automatische Auswahl: eine vorhandene Node3D der Gruppe `player` ergibt Erkundung;
die bekannte Frontend-Szene `res://ui/frontend/main_menu.tscn` ergibt Menü.
Unbekannte Szenen ohne Spieler bleiben still. Die Menüszene wird hier weder
mitgeliefert noch aus einem anderen Branch übernommen. Wenn sich ihr Pfad später
ändert, kann der Menü-Chat die explizite API oder Szenen-Metadaten verwenden.

Erfolgreich abgespielte Warnungs- oder Angriffsereignisse höchstens 24 m vom
Spieler entfernt aktivieren Gefahr für zehn Sekunden. Weitere solche Ereignisse
verlängern die Zeit. Nähe allein, harmlose Kontaktrufe oder Lebensverlust ohne
Angriff lösen keinen Gefahrkontext aus. Nach Ablauf kehrt Erkundung zurück.
Auf dem unveränderten main gibt es noch nicht für jede KI solche Signale; im
Hörtest ist der Gefahrwechsel deshalb zusätzlich jederzeit direkt auswählbar.
Die API erlaubt später auch Ereignisse unabhängig von einer Kreaturenstimme:

```gdscript
AudioManager.set_music_context(&"menu")         # Bis Automatik oder Szenenwechsel.
AudioManager.set_music_context(&"exploration")
AudioManager.set_music_context(&"danger")       # Bewusst festhalten, z.B. Hörtest.
AudioManager.set_music_context(&"silent")
AudioManager.resume_music_automation()
AudioManager.notify_music_danger(10.0)          # Temporär, nur bei Erkundungsbasis.
```

Eine explizite Kontextwahl hat Vorrang vor der Automatik inklusive temporärer
Gefahr. `resume_music_automation()` hebt diese Wahl auf. Szenenwechsel löschen
manuelle Wahl und alte Gefahrzeiten. Ein Szenenwurzel-Metadatum
`audio_music_context` (`menu`, `exploration`, `danger` oder `silent`) überschreibt
die automatische Szenenerkennung. Signal für Anzeige/HUD:
`AudioManager.music.context_changed(context, title)`.

Zusätzlicher Laufzeit-/Exporttest:

```sh
godot --headless --path . --script res://tests/audio/music_runtime_test.gd
```

Er prüft die importierten und tatsächlich abgespielten Ogg-Schleifen, Menü- und
Spielererkennung, echte Überblendung, schnelle Kontextwechsel, zeitweilige Gefahr
über ein Kreaturensignal, Distanz, Pause, Lautstärke, Szenenwechsel und Freigabe.
Die Audiodateien wurden zusätzlich dekodiert und auf Länge, Signalpegel, Clipping
und Sprünge an der Schleifengrenze geprüft. Die musikalische Wirkung und der Mix
brauchen weiterhin deinen gemeinsamen Hörtest auf dem Zielgerät.

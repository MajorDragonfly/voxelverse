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
- Die 87 eigenen Effekte/Umgebungs-/Kreaturen-/Aktions-/Interfaceklänge und drei Musikstücke sind spielbare Prototypen.
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
Näherung. Die räumlichen Stimmen erhalten nun Schallverdeckung anhand vorhandener
Kollisionen; siehe Ausbau unten.

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
im Spiel gestreamt. Menü, Gefahr und direkte Hörtest-Auswahl laufen als Schleife;
automatische Erkundung erhält jetzt zusätzlich Ruhephasen (siehe unten). Kein Python oder FFmpeg ist zum Spielen
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


## Ausbau: Hindernisse, Ruhephasen und Aktionen

### Schallverdeckung

Alle 16 räumlichen Effektstimmen und die vorhandene Uferquelle prüfen die Linie
zwischen aktueller Kamera und Klangposition. Ein Hindernis senkt nur diese Quelle
um bis zu 9 dB und filtert Höhen bis 1.600 Hz. Die Wirkung steigt schnell an und
löst sich weich auf; andere Quellen, Musik und Menü werden nicht mitgefiltert.
Jede der höchstens 17 Quellen hat einen eigenen Filterbus, der weiterhin über
Effekte bzw. Umgebung läuft. Die bestehenden Lautstärken und der Unterwasserfilter
bleiben damit wirksam. Neue Wiedergabe auf einem wiederverwendeten Player beginnt
mit zurückgesetzter Verdeckung. Unbenutzte Filter werden abgeschaltet.

Die Abfrage läuft ausschließlich im Physiktakt und verbraucht global höchstens
vier Strahlabfragen pro Schritt. Abfragen wechseln zwischen den aktiven Quellen,
üblicherweise alle 120 ms je Stimme. Folgeabfragen für transparente Körper zählen
zum selben Budget; unvollständige Abfragen behalten ihren vorherigen Zustand und
werden erneut versucht. Daraus folgt eine kurze Reaktionszeit, keine exakte
akustische Simulation. Beugung um Kanten, Hall und Materialstärken sind nicht
enthalten. Rein sichtbare Objekte/Fernmeshes ohne Kollision verdecken keinen Klang.

Quellkörper und Spielerkörper werden ausgeschlossen, Trigger-Areas ignoriert.
Ein Treffer direkt am Quellendpunkt gilt nicht als Wand (z.B. ein Schritt auf dem
Boden). Das Metadatum `audio_transparent = true` am Kollisionskörper oder einem
übergeordneten Knoten nimmt ihn aus der Verdeckung. Eine Wand hinter diesem Objekt
kann weiter erkannt werden. Es werden keine Kollisionslayer oder Spielknoten verändert.
Die Standardmaske berücksichtigt alle Körper-Layer; sie kann beim Zusammenschluss
mit der Weltanbindung eingeschränkt werden:

```gdscript
AudioManager.occlusion.collision_mask = 1
AudioManager.occlusion.enabled = false # Optional, stellt den klaren Mix wieder her.
```

### Ruhephasen der Erkundungsmusik

Die automatische Erkundung spielt ungefähr 60 Sekunden Musik, blendet aus und
lässt danach 12–22 Sekunden nur Umgebung und Effekte hören. Anschließend beginnt
das Erkundungsstück erneut mit Einblendung. Ein eigener Zufallsgenerator variiert
die Ruhedauer, ohne die Welt-Zufallsfolge zu beeinflussen. Die stille Zeit zählt
erst, wenn die vorherige Musik vollständig ausgeblendet ist. Pausieren hält die
Zeitplanung an; die bereits bekannte leise Pausenmusik und laufende Blenden bleiben
bestehen. Szenenwechsel und Gefahr setzen den Ruhezyklus zurück.

Gefahr kann auch die laufende Ausblendung in die Ruhephase sofort unterbrechen;
dabei bleibt es bei zwei Musikstimmen. Nach Gefahr beginnt ein neuer Erkundungszyklus.
Menü, direkte Kontextwahl und die drei einzelnen Musikschaltflächen haben keine
Ruhephasen, damit sich Stücke weiterhin gezielt vergleichen lassen.

```gdscript
AudioManager.music.configure_rest_cycle(60.0, 12.0, 22.0)
AudioManager.music.rest_cycles_enabled = true
AudioManager.resume_music_automation()
# Signal: AudioManager.music.rest_changed(resting)
# Abfrage: AudioManager.music.is_resting()
```

Der Hörtest bietet „Musik mit Ruhephasen“ und den kurzen „Pausentest · 6 s / 5 s“.
Die genannten Zeiten enthalten nicht die zusätzliche Ausblendung. „Gefahr für
8 Sekunden“ kann den Pausentest unterbrechen. Beim Verlassen der Szene werden
die vorherigen Rhythmuseinstellungen wiederhergestellt; der Test verändert keine
Spielstände oder dauerhaften Audioeinstellungen.

### Aktionsgeräusche

Zwölf neue eigene WAV-Dateien: jeweils drei Varianten für Essen, Trinken, Sammeln
und Evolution. Knuspern, Flüssigkeitsblasen, kurzer Sammelimpuls und aufsteigende
Evolutionsbestätigung werden synthetisiert. Insgesamt enthält das Paket damit
77 WAV-Klänge und drei Ogg-Musikstücke. Der Hörtest kann jede Aktion unmittelbar
vorspielen. Essen/Trinken/Sammeln sind räumliche Spieleffekte; Evolution ist eine
Bestätigung über den UI-Kanal und funktioniert auch im pausierten Editor.

Es werden bewusst nur bestätigte Aktionen angeschlossen. Das heutige Basisspiel
hat dafür noch keine einheitlichen Erfolgssignale. Der Audioadapter leitet deshalb
keine Aktion aus Eingabetasten, UI-Text, steigenden Hunger-/Durstwerten, Laden,
Wiederbelebung oder einer bloßen Phasenänderung ab. Die anderen Chats können nach
erfolgreicher Spielzustandsänderung aufrufen:

```gdscript
AudioManager.play_action(&"eat", creature, "optional-action-receipt-123")
AudioManager.play_action(&"drink", creature)
AudioManager.play_action(&"gather", creature)
AudioManager.play_action(&"evolve")
```

Alternativ kann ein von der Kreaturen-Audioanbindung verfolgter Knoten das neue
optionale Signal `signal audio_action(action: StringName)` anbieten und z.B.
`audio_action.emit(&"eat")` auslösen. Die Anbindung wird einmalig beim Anhängen des
Audio-Kindknotens hergestellt. Ein Aufruf allein fügt keine Nahrung, Ressourcen,
Fähigkeiten oder Evolution hinzu. `AudioManager.actions.action_played(action,
source_id)` meldet eine tatsächlich angenommene Wiedergabe.

Wiederholungen je Aktion/Quelle sind gedrosselt (Essen/Trinken 650 ms, Sammeln
250 ms, Evolution 1.500 ms). Optionale Beleg-IDs verhindern auch spätere doppelte
Auslösung innerhalb derselben Szene, solange der Beleg im begrenzten Verlauf liegt
(maximal 256 Belege und 128 zeitliche Einträge). Bei abgelehnter Wiedergabe, etwa
einem vollen Pool, wird kein Beleg verbraucht. Direkter Aufruf plus Signal im selben
Moment erzeugt keinen Doppelton. Unbekannte Aktionen, fehlende/freigegebene Quellen,
Audio-Sperre und tote Quellen werden abgewiesen. Weltaktionen sind in Pause gesperrt.

### Gemeinsamer Test

In `audio/audio_playground.tscn`:

1. „Rufschleife starten“, dann „Fels an/aus“: die mittlere Quelle wird durch einen
   echten Test-Kollisionskörper verdeckt. „Rufschleife stoppen“ beendet sie.
2. „Pausentest · 6 s / 5 s“ starten; während der Ruhephase „Gefahr für 8 Sekunden“ wählen.
3. Essen, Trinken, Sammeln und Evolution zu Musik, Umgebung und Kreaturen dazuschalten.

Zusätzliche automatische Prüfung mit echten Physikkörpern und laufender Audioausgabe:

```sh
godot --headless --path . --script res://tests/audio/audio_expansion_test.gd
```

Geprüft werden Quell-/Spielerkörper, blockierter und freier Weg, transparenter
Körper, Filter-/Pegeltrennung, Pausenverhalten, Stimmenwiederverwendung, Abfragebudget,
Aktionssignale, Duplikate, abgewiesene Belege, unveränderte Spielwerte sowie natürliche
Musikruhe, Wiederaufnahme und Gefahr während der Ausblendung. Subjektiver Klang,
Grafik und Windows-Ausgabe bleiben dem gemeinsamen Hörtest vorbehalten.


## Ausbau: Scanner, Gruppenbefehle und Audio-Komfort

Zehn neue eigene WAV-Dateien ergänzen drei Scannerklänge (Erfassen, Abbruch und
Fortschrittsschleife) sowie sieben kurze, unterscheidbare Befehlsrückmeldungen.
Der vorhandene Entdeckungston bestätigt weiterhin einen erfolgreichen Scan.
Gesamtumfang: **87 WAV-Klänge und drei Ogg-Musikstücke**.

### Scannen

Ein neuer, unbekannter Zielkörper startet einen leisen Erfassungston und genau
eine Fortschrittsschleife. Die Tonhöhe folgt weich dem gemeldeten Scanfortschritt.
Verliert der Spieler ein bereits begonnenes Ziel, ertönt ein kurzer Abbruch.
Bei Pause, Fokusverlust oder deaktiviertem Scanmodus endet die Schleife still.
Bereits bekannte Arten starten weder einen Scanloop noch eine Erfolgsfanfare.
Ein Fortschrittswert von 1 allein löst keinen Erfolgston aus: erst das bestätigte
Abschlussereignis spielt den vorhandenen Entdeckungston. Wiederholte Abschlüsse
mit demselben Artenschlüssel werden im begrenzten Verlauf unterdrückt (128 Schlüssel).

Die Audioanbindung erkennt optional einen bereiten Scanner mit dem Scriptpfad
`res://creatures/player/creature_scanner.gd` unter einem Spieler der Gruppe `player`.
Sie liest dessen öffentliche Schnittstelle `active()`, `ratio()`, `target`, `known`
und verbindet `scan_completed(species_key: String)`. Die Suche ist auf 64 Knoten
begrenzt und findet nur statt, solange kein Scanner gebunden ist. Die eigentliche
Scanmechanik, Zielerfassung, Dauer und Eintragung ins Artenbuch stammen vollständig
aus dem Scanner-Chat. Dessen Code wird durch diesen Audio-Branch nicht übernommen.
Die geprüfte Schnittstelle ist bereits in jenem Scanner vorhanden; ein Integrationstest
mit einer passenden Laufzeitfixture sichert den Vertrag ab.

Ein scanfähiger `ProgressionService` mit `has_species_scan(...)` darf bereits beim
ersten Sichten `species_discovered` melden. In diesem Fall wird der frühere allgemeine
Entdeckungston unterdrückt: der Scanner übernimmt die Bestätigung beim Abschluss.
Ältere Services ohne Scanvertrag behalten ihren bisherigen Entdeckungston.
Die Audioanbindung vergibt keine Punkte, speichert keine Scans und verändert kein Ziel.

Alternativ stehen explizite Anschlüsse bereit:

```gdscript
AudioManager.update_scan_audio(target.get_instance_id(), progress, already_known)
AudioManager.cancel_scan_audio()                     # Ziel verloren.
AudioManager.complete_scan_audio(species_key)        # Erst nach bestätigtem Erfolg.
AudioManager.scans.bind_scanner(my_scanner)           # Abweichender Scriptpfad.
```

`update_scan_audio` erwartet während eines Scans regelmäßige Updates. Ohne neue
Updates endet die Schleife nach 0,4 Sekunden, damit ein entfernter Produzent keinen
Dauerton hinterlässt. Signal für Diagnose/Hörtest:
`AudioManager.scans.feedback_played(event)`. Die zwei Scannerplayer laufen über
`VV UI`; die Schleife beansprucht damit keine räumliche Kreaturenstimme. Alle
Scanner-Wiedergaben werden bei Pause oder Fokusverlust gestoppt.

Szenenwechsel, vorhandene `GameState.world_seed_changed(seed)`- und
`SaveGameService.game_loaded(path)`-Signale setzen Scanner- und Befehlsverläufe
zurück. Ein neues Spiel mit erneut verwendeten Artenschlüsseln wird dadurch nicht
von alten Audio-Belegen unterdrückt. Optional später bereitgestellte Services werden
angeschlossen; entfernte Services werden ohne verwaiste Verbindungen bereinigt.

### Gruppenbefehle

Die Bestätigung gehört zum ganzen Auftrag. Alle Meldungen zu diesem Auftrag
verwenden dieselbe eindeutige `command_id`, unabhängig von der Zahl der Mitglieder.
Die Audioanbindung nimmt höchstens eine Bestätigung pro ID an; der Verlauf hält
maximal 256 IDs. Zusätzlich bremst eine globale Pause von 180 ms hektische Wiederholungen.
Die Töne verwenden den vorhandenen begrenzten UI-Stimmenpool.

```gdscript
# Einmal nach tatsächlicher Prüfung bzw. erfolgreicher Speicherung des Auftrags:
AudioManager.play_group_order(&"move", command_id, true)
# Ein ausdrücklich abgewiesener Spielerauftrag:
AudioManager.play_group_order(&"move", command_id, false)
```

| Auftrag | Klang |
| --- | --- |
| `move` | Bewegung bestätigen |
| `gather`, `wood`, `stone`, `food` | Sammeln bestätigen |
| `attack` | Angriff bestätigen |
| `build`, `tool`, `hut` | Bau-/Herstellungsauftrag bestätigen |
| `wait` | Warten bestätigen |
| `feed` | Versorgung bestätigen |
| Gültiger Auftrag mit `accepted = false` | Eigener Ablehnungston |

Unbekannte Auftragsarten, leere/zu lange IDs und Aufträge während Pause werden
ignoriert. Ein fehlgeschlagener Wiedergabeversuch verbraucht keine ID.
`AudioManager.orders.feedback_played(order, command_id, accepted)` meldet eine
angenommene Wiedergabe. IDs sollten über das Spiel/den Gruppenauftrag eindeutig
sein, z.B. Kampagnen-ID plus fortlaufende Auftragsnummer; keine ID pro Bewohner.

Ein Controller kann alternativ anbieten:

```gdscript
signal order_resolved(order: StringName, command_id: String, accepted: bool)
```

Controller der Gruppe `tribe_controller` mit diesem Signal werden automatisch
angeschlossen; alternativ `AudioManager.orders.bind_source(controller)`.
Der derzeit eingesehene Stammescontroller stellt `issue_order(...) -> bool` bereit,
aber noch kein solches Ergebnissignal. **Die Befehlsgeräusche sind daher anschlussfertig;
die einzelne Meldung nach dem Auftrag muss beim Zusammenführen im Gruppen-Chat
ergänzt werden.** Speichern, Auswahl, Navigation, Ablehnungsgründe und Kampfmechanik
werden von Audio weder geändert noch aus Texten oder laufenden Bewohnerzuständen erraten.
Insbesondere wird eine vorbereitete Angriffsbestätigung hier nicht als neue
Angriffsfunktion ausgegeben.

### Nachtmodus und Hintergrund

F7 enthält zwei neue, zunächst ausgeschaltete Schalter:

- **Nachtmodus:** Eine sanfte Mischung aus Originalsignal und komprimiertem Signal
  reduziert große Lautstärkeunterschiede. Der Kompressor liegt vor dem bestehenden
  Limiter im VV-Masterbus. Er verstärkt keine leisen Signale und verändert keine Reglerwerte.
- **Stumm im Hintergrund:** Fokusverlust des Spielfensters schaltet VV Master stumm.
  Beim Zurückkehren gilt wieder die gewählte Lautstärke; 0 % bleibt immer stumm.
  Bei ausgeschalteter Option kann Audio im Hintergrund weiterlaufen.

Die Optionen werden zusammen mit den Lautstärken in `user://audio_settings.cfg`
gespeichert. Ältere Dateien funktionieren weiterhin; fehlende oder falsch typisierte
Bool-Werte werden als ausgeschaltet geladen. Fokuszustände werden nicht gespeichert.
„Standardwerte“ im Panel setzt sowohl Lautstärken als auch Komfortoptionen zurück.

```gdscript
AudioManager.set_preference(&"night_mode", true)
AudioManager.set_preference(&"mute_in_background", true)
AudioManager.get_preference(&"night_mode")
# Signal: preference_changed(preference, enabled)
AudioManager.reset_settings()  # Alle Audioeinstellungen; reset_volumes nur Regler.
```

Technische Abstimmung: Kompressorschwelle −16 dB, Verhältnis 2:1, Attack 2 ms,
Release 150 ms, 60 % Effektsignal, kein zusätzlicher Ausgangs-Gain. Eigenschaften:
[Godot 4.6 AudioEffectCompressor](https://docs.godotengine.org/en/4.6/classes/class_audioeffectcompressor.html).
Die Wirkung wird zusätzlich im Laufzeittest über `AudioEffectCapture` im echten
Audiographen gemessen: Bei einem gleichbleibenden Sinus bleibt die leise Stufe fast
unverändert, die laute Stufe wird reduziert, bleibt aber deutlich lauter als die leise.
Diese technische Messung ersetzt nicht die Hörabstimmung des gesamten Spielmixes.

### Testen

Der Hörtest beginnt jetzt mit einem simulierten 2,5-Sekunden-Scan, Zielverlust,
bekannter Art und acht Befehls-Schaltflächen. „12 Mitglieder · ein Ton“ sendet zwölf
Meldungen mit derselben ID und demonstriert die einzelne Gruppenbestätigung.
Die Simulation erzeugt keine echten Entdeckungen oder Gruppenaufträge. F7 erlaubt
das Vergleichen des Nachtmodus im laufenden Mix; die Hintergrundoption lässt sich
mit Wechsel zu einem anderen Fenster prüfen.

```sh
godot --headless --path . --script res://tests/audio/interface_audio_test.gd
```

Die neue Fixture prüft Scanfortschritt und echte Signale, Erfolg erst beim Abschluss,
Deduplizierung mit dem Progression-Service, bekannte Arten, Zielverlust, Pause,
fehlende Updates, Gruppen-IDs, Ablehnung, entfernte Controller/Services, Ladeereignisse,
strenge Einstellungswerte, Speichern/Laden, F7-Abgleich, Fenster-Fokussignale und
aufgezeichnete Kompressorwirkung. Die native Windows-Fokusausgabe und der subjektive
Hörtest bleiben für das Zielgerät offen.

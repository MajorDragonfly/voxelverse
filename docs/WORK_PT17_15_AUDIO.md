# PT17-15 – Audioeinstellungen

Paket #181 aus dem Spieltest-Backlog #166. Feste Basis:
`0e0a1cda0d645f872cecd42881b3f6e53b3ba34e` (main beim Start).
Branch: `agent/pt17-15-audio-settings-20260920`.
Die aktuelle Belegung bleibt ausschließlich in #137.

## Befund und Änderung

Die vorhandene Audioseite war unter „Ton und Musik …“ auf der Anzeigeseite
versteckt, fest auf mindestens 600 Pixel ausgelegt und nur deutsch beschriftet.
Die fünf Busse und die bestehende Datei `user://audio_settings.cfg` waren bereits
funktionsfähig. Der Esc-/Einstellungsmenü-Host wird separat durch PT17-14 verändert.

Diese Lieferung ersetzt die Audioseite durch eine Seite im gemeinsamen Menüstil:
fünf live wirksame Regler mit Prozentwert, Stumm und Hörprobe je Kategorie,
Nachtmodus, Hintergrund-Stumm, Standardwerte und Zurück. Die Seite scrollt bei
kleinen Fenstern; Titel, Hilfetext und Fußaktionen bleiben sichtbar. Tastaturfokus
scrollt mit. DE/EN wechseln ohne Verlust der Werte oder des Fokus.

Stumm verwendet denselben Lautstärkewert 0 wie der Regler; es gibt keine zweite
Konfigurationsquelle. Erneutes Einschalten stellt den letzten positiven Wert der
offenen Seite wieder her, nach einem Neustart bei gespeichertem 0 den Kanalstandard.
Eine einzige zusätzliche Vorschau-Stimme nutzt die tatsächlichen Kategorie-Busse,
spielt vorhandene Klangressourcen höchstens drei Sekunden und stoppt beim
Zurückgehen, Szenenwechsel und Shutdown. Musikdirektor, Musikproduktion und
Weltstimmen werden dabei nicht umgeschaltet. Die globale Lautstärke und
Hintergrund-Stummschaltung gelten auch für Vorschauen.

`AudioManager.open_settings()` und `close_settings()` behalten ihre API und die
vorherige Pause-/Mauszuständigkeit. Zurück stellt zusätzlich den Fokus des
aufrufenden Bedienelements wieder her. PT17-14 besitzt weiterhin
`core/display_settings.gd` und `autoload/session_flow.gd`; diese Dateien werden
hier nicht verändert. Die Audioseite bleibt auf der gemeinsamen Basis bereits
über den vorhandenen Einstellungen-Knopf erreichbar.

## Nachweise

Godot `4.6.3.stable.official.7d41c59c4`, Linux, isolierte Nutzerdaten.
[Maschinenlesbarer Nachweis](evidence/pt17-15/headless.json) enthält Quellhash,
Dateihashes, Befehle, Laufzeiten und Log-Prüfsummen.

- `audio/audio_settings_test`: 282 Kontrollen bestanden. Echte Maus-/Tastatur-
  Eingaben, Kategorien/Vorschau-Lebenszyklus, Sprachwechsel, drei Fenstergrößen
  (800×600, 1280×720, 1920×1080) bei 150 %, Pause/Fokus/Zurück und echter
  zweiter Prozess zur Prüfung aller gespeicherten Lautstärken/Optionen.
- Der Test speist einen deterministischen Ton durch die **vorhandenen** Musik-,
  Umgebungs-, Welt-/Effekt- und Menüstimmen und misst hinter sämtlichen VV-Bussen.
  50 % ergibt etwa die halbe Signalamplitude; Stummschalten einer fremden Kategorie
  ändert das Signal nicht. Kategorie 0 % und Master 0 % ergeben jeweils RMS 0.
- Bestehende `audio_runtime_test`, `interface_audio_test`, `music_runtime_test`
  und `audio_shutdown_test`: alle bestanden. Damit sind reale Bewegungs-/Wasser-
  und UI-Ereignisse, Nachtkompressor, Hintergrund-Stumm, Musikautomation und
  laufender/pausierter Shutdown zusätzlich geprüft.
- Registry und generierte DE/EN-Kataloge konsistent; Änderungsauswahl fordert
  konservativ 237 Tests und volle Integrationsgates. Diese Vollprüfung gehört
  zur PR-CI und wird nicht als lokal ausgeführt behauptet.

Gezielte Reproduktion:

```sh
python3 tools/validate_godot.py --godot /pfad/zu/godot --skip-main --tests audio/audio_settings_test audio/audio_runtime_test audio/interface_audio_test audio/music_runtime_test audio/audio_shutdown_test
```

Native Aufnahmen mit echtem GUI-Eingabepfad und denselben Bus-/Neustartprüfungen:

```sh
xvfb-run -a -s '-screen 0 1920x1080x24' python3 tools/review_audio_settings.py --godot /pfad/zu/godot --output /tmp/audio-settings-review
```

Der Workflow `Audio settings review` liefert zwölf Aufnahmen (DE/EN, drei Größen,
oben/unten) plus Log und Quellcommit/Tree. Seine konkreten Ergebnisse und die
Sichtprüfung werden im PR nachgetragen; dieser Bericht behauptet keinen vorweg
bestandenen Grafiklauf.

Der erste native Lauf 35528323534 war formal grün, produzierte aber bei allen
Größen 1600×900: Unter Xvfb aktualisierten die DisplayServer-Aufrufe die
Window-/Renderzielgröße nicht. Diese Bilder zählen nicht als Nachweis der drei
Größen. Die Aufnahmeprüfung setzt deshalb zusätzlich die tatsächliche
`Window.size` und prüft sowohl das Renderziel als auch die PNG-Header gegen die
angeforderte Größe. Erneuter Fachtest: 285 Kontrollen bestanden;
[Nachweis](evidence/pt17-15/capture-size-fix.json). Der Produktionscode blieb
bytegleich; der korrigierte native Lauf wird im PR separat verlinkt.

## Übergabegrenzen

Die gemeinsame Endabnahme **Esc → Einstellungen → Audio** in Kreatur- und
Stammesphase folgt zusammen mit PT17-14 auf einem gemeinsamen geprüften Tree.
Der neue Menühost wird weder vorweggenommen noch parallel editiert.
Eine Ziel-PC-Hör-/Sichtabnahme und Windows-Abnahme sind separat. #181 bleibt bis
zur gemeinsamen Erfüllung seiner Kriterien offen. Kein Merge dieser Lieferung,
solange PT17-14 und die erforderlichen gemeinsamen Prüfungen ausstehen.

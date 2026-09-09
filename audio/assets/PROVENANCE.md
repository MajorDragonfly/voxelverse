# Herkunft der Klänge

Die ersten 29 WAV-Dateien wurden für Voxelverse mit `tools/audio/generate_sounds.py`
synthetisiert. Es wurden keine fremden Aufnahmen, Samples, Stimmen oder Musik aus
anderen Spielen verwendet. Grundlage sind deterministisches gefiltertes Rauschen,
Sinusschwingungen und Hüllkurven.

Format: 16-Bit-PCM, 22.050 Hz. Die sechs Schrittmaterialien enthalten je drei
Varianten. Vier achtsekündige Ambientes nutzen periodisches Rauschen; kurze
Effekte besitzen ausgeblendete, nullwertige Endpunkte. Spitzenpegel maximal 0,65.

Es handelt sich um spielbare Prototypen zur späteren klanglichen Verfeinerung.
Python mit NumPy wird nur zur Neugenerierung gebraucht; das Spiel verwendet die
mitgelieferten WAV-Dateien. Zuordnung: `audio/runtime/sound_library.gd`.


Die 36 zusätzlichen Dateien in `creatures/` werden unabhängig davon durch
`tools/audio/generate_creature_sounds.py` erzeugt: harmonische Schwingungen,
Formantgewichtung, Rauschen und nichtsprachliche Tonhöhenkonturen, ohne Aufnahmen
oder Stimmenmodelle. Sie sind mono, 16-Bit-PCM mit 22.050 Hz, Spitzenpegel maximal
0,52, mit ausgeblendeten Endpunkten. Es sind nun insgesamt 65 eigene WAV-Dateien.


Die drei Musikstücke in `music/` wurden eigens mit
`tools/audio/generate_music.py` komponiert und synthetisiert. Die enthaltene
Partitur ordnet selbst formulierte Melodiephrasen, Akkorde, Bass und synthetische
Percussion an. Keine fremden Lieder, Aufnahmen, Samples oder Stimmenmodelle wurden
verwendet. Synthese: Sinusharmonische, sanfte FM-Keys, Rausch-Percussion und
Hüllkurven; Stereo-Delay mit umlaufenden Ausklängen. D-Dorisch, 96 BPM, 4/4.

Format: Stereo-Ogg/Vorbis, 32.000 Hz, Qualitätsstufe 4. Menü und Gefahr dauern
jeweils 40 Sekunden, Erkundung 60 Sekunden. Der Generator benötigt Python, NumPy
und FFmpeg mit libvorbis, das Spiel nur die mitgelieferten Ogg-Dateien. Die
Komposition und PCM-Erzeugung sind deterministisch; Containerdaten können sich
zwischen FFmpeg-Versionen unterscheiden. `music/score.json` enthält Titel,
Taktdauer und Messwerte nach dem Dekodieren. Insgesamt: 65 WAV-Klänge plus drei
Ogg-Musikstücke. Auch die Musik ist ein erster spielbarer Entwurf zur Hörabnahme.


Das vierte Paket ergänzt zwölf Aktionsklänge in `actions/`, erzeugt mit
`tools/audio/generate_action_sounds.py`: drei Varianten für Essen, Trinken,
Sammeln und Evolution. Eigene kurze Impulse, gefiltertes Rauschen, Sinustöne und
Hüllkurven, ohne fremde Aufnahmen, Musik oder Stimmen. 16-Bit-PCM, mono,
22.050 Hz; Spitzenpegel höchstens 0,5, Anfang und Ende exakt null. Deterministische
NumPy-Erzeugung; NumPy wird zum Spielen nicht benötigt. Neuer Gesamtumfang:
77 WAV-Dateien und drei Ogg-Musikstücke.


Das fünfte Paket ergänzt zehn Interfaceklänge in `interface/`, generiert mit
`tools/audio/generate_interface_sounds.py`: Scanner-Erfassen, -Abbruch und ein
periodischer Scannerloop sowie sieben klar unterscheidbare Gruppenrückmeldungen.
Grundlage sind selbst angeordnete Sinustöne mit Obertonanteilen und Hüllkurven.
Keine Aufnahmen, Stimmenmodelle oder fremden Samples. 22.050 Hz, mono, 16-Bit-PCM;
kurze Signale mit nullwertigen Endpunkten, Spitzenpegel höchstens 0,42. Der einsekündige
periodische Loop hat Spitzenpegel 0,22; seine Schleifengrenze wird geprüft. Der
Scan-Abschluss verwendet die vorhandene Entdeckungsdatei. Gesamtumfang nach diesem
Paket: 87 WAV-Dateien und drei Ogg-Musikstücke.

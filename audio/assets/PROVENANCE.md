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

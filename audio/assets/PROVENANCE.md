# Herkunft der Klänge

Alle 29 WAV-Dateien wurden für Voxelverse mit `tools/audio/generate_sounds.py`
synthetisiert. Es wurden keine fremden Aufnahmen, Samples, Stimmen oder Musik aus
anderen Spielen verwendet. Grundlage sind deterministisches gefiltertes Rauschen,
Sinusschwingungen und Hüllkurven.

Format: 16-Bit-PCM, 22.050 Hz. Die sechs Schrittmaterialien enthalten je drei
Varianten. Vier achtsekündige Ambientes nutzen periodisches Rauschen; kurze
Effekte besitzen ausgeblendete, nullwertige Endpunkte. Spitzenpegel maximal 0,65.

Es handelt sich um spielbare Prototypen zur späteren klanglichen Verfeinerung.
Python mit NumPy wird nur zur Neugenerierung gebraucht; das Spiel verwendet die
mitgelieferten WAV-Dateien. Zuordnung: `audio/runtime/sound_library.gd`.

# M10-FOLEY: Nachweise und Hörprobe

Quellcommit: `95d66322c97d9820bd890011e2be23a615519583`; Tree: `4d49c07e4aed489c041d6f9e28f049b3ec52e9b6`.

- [Ergebnisse, Quellhashes und Befehle](results.json)
- [Signalvergleich zur Basis](signals.json)
- [Rohlogs einschließlich des korrigierten Lebenszyklusfehlers](raw-logs.tar.gz)
- [38-Sekunden-Hörprobe](foley-preview.ogg) und [Zeitmarken](foley-preview.json)

6/6 gezielte Godot-Prüfungen, Quell-/Sprachgate und alle 29 Signalprüfungen
bestanden. Gleiche PCM-Dateien vorher erfolgreich importiert; finaler Lauf auf
sauberem Quellcommit mit `--skip-import`. Alle 29 Dateien in einem frischen
Verzeichnis bytegleich regeneriert. Godot 4.6.3, Linux/headless, isolierte Daten.

Der neue Test prüft die Bewegung und Wasserübergänge an einer lokalen Fläche mit
X-Normale. Bestehende Tests prüfen zusätzlich den echten radialen Adapter, Wasser-
hysterese, Bewegung/Settings, Schallverdeckung und Mixer-Shutdown. Weiterhin
16 räumliche Stimmen, höchstens vier bestehende Umweltabfragen pro Schritt.

Die Hörprobe spielt je Material zuerst drei alte, dann drei neue Schritte bei
gleichem Pegel: Gras (0 s), Sand (4,2 s), Stein (8,4 s), Schnee (12,6 s), Holz
(16,8 s), Waten (21 s). Ab 25,5 s Wasseroberfläche; ab 30 s Unterwasserklänge.
Sie ist zusammengesetzt und keine Aufnahme aus dem Spiel. Die neue Gestaltung
reduziert die Lautstärke und den starken Anfangsimpuls bewusst. Eine subjektive
Hörabnahme und die Lautstärkeabstimmung auf dem Zielgerät bleiben offen.

Die GitHub-Übertragung kann andere Commit-IDs erzeugen; der PR ordnet beide über
den identischen Tree zu. Originalnachweise behalten ihre lokalen Prüfreferenzen.

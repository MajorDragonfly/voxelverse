# ARCH-17-AUDIO: Nachweise

Quellcommit: `195e029b513ddbc101cf28be49c491c56ac4d77a`; Tree: `ad915307b79932d2a2c80a346dcdd0068577e74f`.

[Ergebnisse und Grenzen](results.json), [identische A–B–A-Messroute](comparison.json),
[vollständige Rohlogs einschließlich der korrigierten Entwicklungsläufe](raw-logs.tar.gz).
Das Archiv enthält ausschließlich synthetische Prüflogs/Manifeste, keine Spielstände.

11/11 Audiofachtests und das Quell-/Sprachgate bestanden auf dem sauberen
Quellcommit. Godot 4.6.3, Linux/headless, isolierte Nutzerdaten. Ressourcen wurden
im selben Checkout zuvor erfolgreich importiert; der Abschlusslauf verwendet
`--skip-import`. Originalprotokolle und alle Befehle stehen im Ergebnismanifest.

| Identische synthetische Route | Basis | Änderung |
|---|---:|---:|
| Automatische Anhänge-Spitze pro Frame | 64 | 2 |
| Aktive Beobachter, Spitze | 64 | 64 |
| Ausgewähltes nahes Tier in A/B/A registriert | nein/nein/nein | ja/ja/ja |
| Größter gemessener CPU-Schritt | 1,198 ms | 1,300 ms |
| CPU-Schritt p95 | 0,267 ms | 0,364 ms |
| CPU-Zeit über 1.080 Schritte | 126,981 ms | 240,797 ms |

402 Tiere, 2.048 weitere Szenenobjekte; einzelne Messläufe auf geteilter
AMD-EPYC-9V74-Maschine. Die Änderung benötigt in dieser Route mehr CPU-Zeit;
sie liefert begrenzte Einzelarbeit und funktionierende Näheauswahl. Keine
FPS-Verbesserung oder Aussage über Lars’ Rechner daraus ableiten. Automatische
Ersterkennung benötigt hier 114/197/43 Frames; direkte Reaktionen können sofort
innerhalb des reservierten Budgets anhängen. Hohe Baumtiefe (>128) bleibt eine
ausgewiesene Grenze. Ganze Szenen werden bis zur festen Registergrenze von 64
Beobachtern sofort abgebaut; reguläre Wechsel bleiben bei zwei je Frame.

Die Übertragung über die GitHub-Anbindung kann neue Commit-IDs erzeugen.
PR-Beschreibung ordnet lokale/öffentliche Quellcommits über den identischen Tree
zu. Diese Originalnachweise behalten ihre tatsächlich geprüften Referenzen.

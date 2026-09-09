# Kreaturen-Werkstatt M3A

Stand: 8. September 2026. Eigener Branch `agent/creature-editor-spore`, Draft PR #12 auf PR #10. Die Implementierung übernimmt Lars’ neue Priorität: Kreaturen und Editor sollen sich beim Gestalten deutlich stärker an Spore orientieren. Voxelverse behält eigene Formen, Teile und Oberfläche. Am 9. September wurde die Darstellung auf Lars’ Wunsch wieder konsequent auf kleine Voxel abgestimmt; die direkte Formung bleibt bestehen. [Voxel-Überarbeitung](CREATURE_VOXEL_STYLE.md).

## Was sich ändert

- Vier Arbeitsbereiche: **Formen, Teile, Farbe, Testen**. Die Kreatur steht groß auf einer drehbaren Arbeitsfläche; Fähigkeiten, Kosten und angebaute Teile bleiben sichtbar.
- Sieben Körperpunkte lassen sich in der Körperkurve verschieben. Innere Punkte ändern auch ihren Abstand; die Endpunkte strecken den Körper. Monotone kubische Interpolation hält die zugrunde liegende Körperkurve zwischen den Punkten gleichmäßig, ohne negative Radien oder überschießende Kurven; die sichtbare Oberfläche bleibt aus klaren Würfelflächen aufgebaut. Punktabstand und Werte bleiben begrenzt.
- Das Mausrad verändert den Radius; getrennte Breiten-/Höhenregler erlauben weitere Formen. Aufrecht, Langhals, Kriecher und Kugelbauch ändern nur den Körper und erhalten Anbauteile und Identitäten.
- Native Teilekarten werden aus dem vorhandenen Katalog gezeichnet. Entdeckte Teile lassen sich auf den Körper ziehen oder per Klick anbauen. Ein abgebrochener Drag oder ein Drop außerhalb des Körpers erzeugt kein Teil. Bestehende Freischaltungen und Komplexitätskosten bleiben wirksam.
- Symmetrie, Andocken, Skalieren, Drehen, Duplizieren und Löschen bleiben verfügbar. Oberflächenanker werden beim Formen mitgeführt; die bisherige doppelte Verformung bereits gebundener Teile entfällt.
- Haut- und Musterfarbe werden im V7-Entwurf gespeichert. Vorhandene Muster bleiben an ihre Freischaltung gebunden.
- Stehen/Atmen, Gehen und Laufen können direkt getestet werden. Die Vorschau verändert keine Entwurfsdaten. Zwei-, vier- und sechsbeinige Testkörper verwenden dieselbe Kniekonstruktion wie die adaptive Spielanimation.
- Eine geschlossene Voxeloberfläche und aus kleinen Würfeln aufgebaute Augen, Mäuler, Gliedmaßen und Schmuckteile werden von Editor, Spieler und erzeugten Wildtieren gemeinsam verwendet. Der Spieler behält die adaptive Geländeanimation und die vorhandene Angriffsanimation. Wildtiere erhalten sichtbare Schrittbewegung; tote Tiere stoppen diese.

![Kreaturen-Werkstatt mit feinerem Langhals und Teileauswahl](../art/review/creature_fine_voxels/grazer_parts.png)

## Bedienung

| Aktion | Eingabe |
|---|---|
| Werkstatt aus dem Spiel öffnen | F2 |
| Körper formen | Formen → Körperpunkt ziehen |
| Stelle dicker/dünner machen | Punkt wählen → Mausrad |
| Nur die Breite ändern | Umschalt + Mausrad oder Breitenregler |
| Körperlänge ändern | Strg + Mausrad oder Längenregler |
| Teil anbauen | Teile → Karte auf den Körper ziehen; alternativ anklicken |
| Teil verschieben | Angebaute Komponente ziehen; bei deaktiviertem Andocken innerhalb der sicheren Befestigungsgrenzen frei bewegen |
| Teil drehen | Alt + Ziehen oder Drehknöpfe |
| Teil skalieren | Mausrad oder −/+ |
| Ansicht drehen | Rechts/Mitte ziehen; auch links auf freier Fläche |
| Ansicht einpassen | F |
| Rückgängig / Wiederholen | Strg+Z / Strg+Y oder Strg+Umschalt+Z |
| Kopieren / Entfernen | Strg+D / Entf |
| Speichern | Strg+S oder Speichern |
| Bearbeiten und spielen | In die Welt; nur nach erfolgreichem Speichern |

## Speicherung und Integration

Das Entwurfsformat bleibt V7. Neue optionale Felder sind `body.spine[].t`, `appearance.base_color`, `appearance.accent_color` und `assembly.sculpt_surface_bindings`. Alte Entwürfe erhalten gleichmäßig verteilte Körperpunkte. Design- und Teile-IDs bleiben erhalten. Aufruf des Editors allein überschreibt den Entwurf nicht. Erst ein bewusster Formeingriff bindet alte freie Offsets an die neue Oberfläche; dieser Eingriff ist rückgängig machbar.

Ein Ziehvorgang bildet einen Rückgängig-Schritt. Speichern löscht die Historie nicht. Die Revision steigt erst mit einem erfolgreich geschriebenen V7-Entwurf; auch Speichern nach Rückgängig verwendet keine bereits geschriebene Revision erneut. Wenn die anschließende Kampagnensicherung scheitert, bleibt die Werkstatt geöffnet und zeigt den Fehler. Farben und Punktpositionen werden über die bestehende gemeinsame Entwurfssicherung übernommen.

Die neue Darstellung nutzt den bestehenden `CreatureRuntimePreview`. Sein optionaler alter Voxelpfad bleibt für Vergleich und Regression verfügbar. Die ursprüngliche Prüfung identischer Voxel/Materialien mit und ohne Batching bleibt erhalten; ein zusätzlicher gerenderter Kreaturenfall prüft die neue Oberfläche gegen ein Budget von 120 Mesh-Nodes für die Referenzarten. Der Standardkörper benötigt 21 Geometrie-Nodes.

PR #12 wird nach PR #10 integriert. PR #11 kann separat übernommen werden; bei `tools/capture_environment.gd` sind beide Ergänzungen zu behalten: der Kreaturenvergleich hier und die Planeten-/Menünachweise aus PR #11. Keine automatische Zusammenführung nach `main`; PR #9 bleibt ungemergt.

Eine reine Git-Integrationsprobe gegen PR #11 (`0ad98d9`) führt die Codedateien einschließlich der Render-Prüfung automatisch zusammen. In `ROADMAP.md` bleibt der benachbarte M1/M2-Statusblock manuell zusammenzuführen: den geprüften M1-Ausbau aus PR #11, den M2A-Status aus PR #10 und das M3A-Teilpaket aus PR #12 beibehalten. Das ist kein getesteter gemeinsamer Spiel-Build und ersetzt nicht den abschließenden Integrationslauf.

## Prüfung

Historische Prüfung der ersten Werkstatt vor der Voxel-Überarbeitung, Code `09ee6d4`: **51/51 Projektprüfungen**, **6/6 gezielte Werkstattprüfungen** und **12/12 Exportprüfungen je Windows/Linux** bestanden. Die vollständige Umgebungsrenderprüfung ist in **Forward+ und Compatibility** erfolgreich. Die Werkstatt wurde in 1600×900 gerendert und visuell geprüft. Der Standardkörper benötigt 21 Geometrie-Nodes; die zwei Wildtier-Referenzen 40 und 33. CPU-Software-Rendering ist kein Leistungsnachweis für Lars’ Ziel-PC. [Maschinenlesbare Nachweise](../validation/creature-studio.json).

`tests/creature_studio_test.gd` prüft echte GUI-Klicks durch den skalierten Viewport, gültige/ungültige Drops, Symmetrie, Punktabstände, Speichern/Laden, Farben, Identitäten, anatomische Positionen, zwei-/vier-/sechsbeinige Bewegungsproben und Undo/Redo einschließlich Speichern. Bestehende Kreaturen-, Kampagnen-, Wildtier-, Speicher- und Exportprüfungen bleiben Teil der Projektprüfung.

Die Bilder werden mit `tools/review_creature_studio.py` aus der aktiven Godot-Szene aufgenommen. Der Wrapper isoliert die Spielstände, prüft Prozessstatus und Laufzeitfehler und erzeugt `review.json` mit Dateinamen, Auflösungen und Prüfsummen. Die bestehende Umgebungsprüfung nimmt zusätzlich die Kreaturen in Forward+ und Compatibility auf. Nachweise und geprüfter Code-Commit werden in `validation/creature-studio.json` festgehalten.

```bash
python tools/validate_godot.py --godot /path/to/Godot_v4.6.3-stable_linux.x86_64 --output /tmp/creature-checks
xvfb-run -a -s '-screen 0 1600x900x24' python tools/review_creature_studio.py --godot /path/to/Godot_v4.6.3-stable_linux.x86_64 --output /tmp/creature-review
```

## Verbleibender Umfang

M3A ist die überarbeitete Kreaturen-Werkstatt mit gemeinsamer Darstellung. Eine vollständige Spore-Nachbildung, zusätzliche Gliedmaßen mit frei aufgebauten Gelenkketten, prozedurales Schwimmen/Fliegen und ein vollständiger Fähigkeitensatz sind damit nicht abgeschlossen. Die Terrain-Kollision des Spielers bleibt dessen bestehende Bewegungskapsel; sie wird noch nicht aus jeder frei gestalteten Silhouette neu berechnet. Extreme Körperformen benötigen weiterhin die manuelle Gelände- und Wasserabnahme auf Lars’ Rechner.

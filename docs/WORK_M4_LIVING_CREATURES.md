# M4-LIVING-CREATURES — Kreaturenphase

Direkter Nutzerauftrag vom 17.09.2026: zusammenhängende Gegner-KI, bewohnte fremde Nester und aktive, unterscheidbare Gefährten.
Basis: `176d088d34324de14952bc7506fe9763a22cf4b0` (`main`). Branch: `agent/m4-living-creatures-20260917`. Koordination: #137.

## Verhalten

- Normale Wildtiere erhalten dauerhaft zugeordnete Nester mit angestrebten drei bis vier Bewohnern derselben eingefrorenen Art. Nur trockene, geeignete Plätze werden besetzt; schwieriges Gelände kann die Zahl reduzieren. Alte Originaltiere, Positionen, Verletzungen und Beziehungen bleiben erhalten. Bewohner, die die Region wechseln, werden über ihren bestehenden Index gefunden und nicht erneut erzeugt. Pflichtarten der Tierhaltung bleiben unverändert.
- Die bestehenden Bedürfnisse und das vorhandene Sozialspiel finden dadurch tatsächlich Artgenossen. Ein akzeptierter Angriff kann nahe Nestmitglieder über Sichtkontakt warnen; Grasfresser fliehen, Raubtiere reagieren auf die letzte bekannte Bedrohung. Kein Wissen über verdeckte spätere Zielbewegungen.
- Nahkämpfe bleiben bei echtem Kontakt bestehen. Sichtverlust, Verfolgungsbudget, Reviergrenzen und niedrige Gesundheit führen weiterhin zu Suche beziehungsweise Rückzug. Bisse haben eine abbrechbare Vorbereitung von 0,32 Sekunden und prüfen Sicht und Reichweite beim Treffer erneut.
- Die beiden eigenen Gefährten behalten ihre Art und IDs, unterscheiden sich aber in Größe, Farbabstufung und Verhalten. Der wachsame Gefährte ist im Kampf stärker; der neugierige zeigt bei Hunger erreichbare Nahrungsquellen. Beide verteidigen die Gruppe, unterstützen einen angenommenen Spielerangriff, begrüßen sich, spielen und erkunden ihren Nestplatz. Ausdrucksanimationen und Stimmen nutzen bestehende Systeme.
- Folgen bleibt in Spielernähe. Warten stoppt selbstständige Bewegung und Heimkehren startet keine Jagd. Verletzte Gefährten ziehen sich zurück; bei null Gesundheit sind sie kampfunfähig und erholen sich erst ohne akute Bedrohung. Gesundheit wird im bestehenden Mitgliedsdatensatz gespeichert und geprüft. Keine zusätzliche Speicherdatei, keine Offline-Simulation und keine kostenlosen Nahrungspunkte.

## Grenzen und Integration

Die physische Population bleibt bei maximal zwölf Wildtieren; höchstens sechs dekorative Wildnester werden gleichzeitig gehalten. Es gibt weiterhin zwei ursprüngliche Gefährten. Nester dienen nicht als Spieler-Respawn. Die Nachbarsuche und tatsächliche Fortbewegung bleiben lokal; globale Wegplanung, Lebenszyklen/Fortpflanzung und das Rekrutieren weiterer Arten sind kein Bestandteil dieser Lieferung.

Die laufenden Pakete M4-WILDLIFE-NAVIGATION und M4-GROUP-NAVIGATION werden nicht übernommen. `wildlife_brain.gd` und `wildlife_steering.gd` bleiben unverändert. Neuer KI-Aufsatz über der vorhandenen Kette. Gemeinsame Anschlüsse: `campaign_population.gd` (Kolonie-/Darstellungsanschluss, keine Navigationsänderung) und ein kleines Ziel-/Tempo-/Status-Interface in `home_companion.gd`; bei späterer Navigationsintegration dieses Interface zusammen mit deren Bewegungslogik erhalten. Lokalisierung/Testregistry nur additiv. Zentrale Dashboard-Daten bleiben beim Integrationsbesitzer.

## Prüfung

Godot 4.6.3, Linux/Headless, isolierte Nutzerdaten je Prüfung. Fachtests und echte Kugelkampagne; kein nativer Grafik-/Windows-/Ziel-PC-Nachweis. Die vier Integrationsgates und deren aktueller Merge-Tree sind getrennte Abnahmen.

Frühe Läufe wurden nicht als Erfolg gewertet: Ein Gefährten-Spiel brach beim zu schnellen Umkreisen mit `regroup` ab; behoben durch eigenes Spieltempo und Orientierung am gemeinsamen Aufenthaltsbereich. Der bestehende KI-Test wartete noch auf den früher sofortigen Biss und nutzte bereits vor Nahkampfkontakt verstrichene Verfolgungszeit; seine beiden Zeitfenster bilden nun Bissvorbereitung und das volle Suchbudget nach Kontaktverlust ab, bei unveränderten Schaden-/Sicht-/Abbrucherwartungen. Ein Weltprüfungs-Helfer fehlte anfangs im neuen Diagnose-Einstieg und wurde ergänzt. Ein einzelner früher Engine-Start endete ohne Fachtestergebnis; der Lauf wurde nicht wiederverwendet.


Geprüfter Code-Commit: `5e58e7ff2fcf069639a77295b7901062660f5412`; Tree: `f631caef16ba7fb9dc893ea91fa0033726007662`.
Geprüfter Quellfingerabdruck: `54bf7598674384892f0dde1e6d24b4b94bd92ac1ac81c614b661a6d02d038c69`.
Die Prüfung lief auf dem vor dem Commit unveränderten Arbeitsstand; der Runner bestätigt `source_integrity: stable`. Danach wurden ausschließlich Übergabe/Nachweise ergänzt.

**13/13 Fachtests bestanden:**

- `living_creature_ai_test`
- `living_companion_test`
- `wildlife_colony_test`
- `living_creatures_world_test`
- `wildlife_ai_test`
- `home_group_test`
- `wildlife_social_play_test`
- `wildlife_hunting_test`
- `wildlife_foraging_test`
- `wildlife_drinking_test`
- `creature_behavior_gameplay_test`
- `surface_population_budget_test`
- `home_group_localization_test`

[Maschinenlesbarer Bericht](evidence/m4-living-creatures/results.json) · [Ungekürzte Logs einschließlich Vorläufen](evidence/m4-living-creatures/logs.tar.gz).

Befehl (Godot-Pfad an die Umgebung anpassen):

```sh
python3 tools/validate_godot.py --godot /path/to/Godot_v4.6.3-stable_linux.x86_64 --tests living_creature_ai_test living_companion_test wildlife_colony_test living_creatures_world_test wildlife_ai_test home_group_test wildlife_social_play_test wildlife_hunting_test wildlife_foraging_test wildlife_drinking_test creature_behavior_gameplay_test surface_population_budget_test home_group_localization_test --skip-import --skip-main --output /tmp/living-creatures-checks
```

Ein erfolgreicher Import des identischen Ressourcenstands ging voraus. Isolierte Nutzerdaten werden durch den bestehenden Runner bereitgestellt.

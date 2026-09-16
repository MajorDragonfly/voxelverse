# ARCH-26-WORKPLACE-INSTANCES

Basis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8`, gemeinsamer Kandidat von PR #110.
Branch: `agent/arch26-workplace-instances-20260915`.

## Spielen

Unter **Arbeitsplätze & Berufe** lassen sich je zwei Brunnen, Forstplätze,
Steinbrüche und Faserbeete bauen. Der zweite Platz benötigt einen eigenen,
geladenen und erreichbaren Standort. Bestehende Plätze und Quellen behalten
ihre Identität. Insgesamt bleiben es höchstens acht Arbeitsplätze je Ort,
zwei Orte und sechs Bewohner je Körper.

Für einen bestimmten Arbeitsplatz Bewohner auswählen und dessen Zeile anklicken,
oder einen Rechtsklick auf den Platz ausführen. Die Zeile zeigt Nummer, abholbare
Menge und Anzahl zugeordneter Bewohner. Die Bewohnerkarte nennt den zugeordneten
Platz. Allgemeine Sammelbefehle verwenden weiterhin die ursprüngliche Quelle.
Eine neue Berufszuweisung hebt die konkrete Platzzuordnung auf. Stop/Fortsetzen
behält sie. Eine bereits getragene Einheit wird vor dem neuen Auftrag abgeliefert.

Neue Arbeitsplatzbauten verwenden denselben Baumaterialvertrag wie Unterkünfte:
Kosten werden einmal aus dem Lager reserviert, Bewohner tragen sie zur Baustelle,
Fortschritt beginnt erst nach vollständiger Anlieferung. Es bleibt bei **einer
laufenden Baustelle je Ort**. Alte bereits bezahlte Baustellen werden ohne erneute
Kosten oder Materialtransporte fortgesetzt.

## Daten und bestehende Anschlüsse

| Zustand | Vertrag |
|---|---|
| Wirtschaft | Schema **3**; Versionen 1 und 2 bleiben lesbar und werden verlustfrei angehoben. |
| Erster Arbeitsplatz | Schlüssel `well`, `forester`, `quarry`, `fiberbed`; vorhandene Arbeitsplatz-ID, `deposits` und `economy.clocks` bleiben erhalten. |
| Zweiter Arbeitsplatz | Schlüssel `kind:2`, eigene ortsgebundene ID und Position; `remaining` und `clock` gehören ausschließlich diesem Datensatz. |
| Produktionsbeleg | `economy.produced[resource]` zählt beide Quellen. Kapazität je erneuerbarer Quelle weiterhin acht; Lager und bereits getragene Ware teilen die bisherige Lagergrenze. |
| Auswahl und Fracht | Optionale `member.workplace_id` und `member.cargo_source_id`; Zugehörigkeit zur Siedlung und Ressource werden validiert. Herkunft bereits getragener Ware bleibt bei einer Neuzuweisung erhalten. |
| Baustelle | `project.station_key`, Arbeitsplatz-ID, Position/Eingang, reservierte und angelieferte Materialien sowie bestehende `construction_id` am Träger. |
| Nah/Fern | Beide Pfade verwenden `VillageWork`/`VillageEconomy`. Der bestehende Abreiseanschluss zertifiziert jeden zusätzlichen Quellort. Fehlende Wege erzeugen keine Ankunft. |

Keine zweite Produktions-, Speicher- oder Auftragsarchitektur. Der gemeinsame
SaveGameService besitzt weiterhin Commit und Rücksetzung. Zukunftsversionsschutz
verhindert Rückfall auf ein älteres Backup und Überschreiben unbekannter Versionen.
Die Summenprüfungen für Baumaterial und Tierwasser berücksichtigen beide Quellen.
Berufsfortschritt beobachtet die tatsächlich abgeholte Quelle. Fernansichten
werden bei Mengen-/Geometrieänderungen erneuert, nicht für jeden Taktbruchteil.

Der reale Wiederladefall deckte zusätzlich einen bestehenden Lebenszyklusfehler
auf: entfernte `SocialBehavior`-Nodes empfingen noch das laufende `game_loaded`-
Signal. Ihr benannter Anschluss wird jetzt beim Verlassen des Szenenbaums gelöst;
die Rückrufprüfung schützt vor Entfernung während derselben Signalauslösung.

## Prüfungen und Grenzen

`workplace_instances_test` verwendet synthetische radiale Orte und echte
SaveGameService-Dateien. Er prüft alle vier Arbeitsplatztypen, getrennte Takte,
Kapazitäten, Berufsbelege, Frachtwechsel, Materialreservierungen, Ortsgrenzen,
fehlerhafte Datensätze, fehlgeschlagene Dateischreibvorgänge, abwesende/pausierte
Arbeiter und einen neuen Godot-Prozess mit laufender Baustelle und gehaltener Fracht.

`workplace_runtime_test` beginnt in der regulären Kugelkampagne mit bestätigtem
Stammesübergang. Ein begrenzter entwickelter Testbestand stellt Werkzeug und
Material bereit; Bauorte, Ankunft, Baukosten, Transporte, Arbeitsplatzzuweisung,
fehlerhafter Commit, Nah/Fern-Wege und Live-Save/Load laufen durch die echten Hosts.
Die Layoutmatrix prüft stabile und erreichbare Zeilen in DE/EN bei 800×600,
1280×720 und 1920×1080, jeweils 100/150 Prozent Schriftgröße.

Rohlogs, genaue Befehle, Quellstände und Ergebnisse stehen unter
`docs/evidence/arch26-workplaces/`. Die anfänglichen fehlgeschlagenen Prüfungen
sind dort ausdrücklich als Diagnoseläufe gekennzeichnet, einschließlich der
korrigierten JSON-Testfixture und des behobenen Ladesignalfehlers.

Headless-Prüfungen sind keine gerenderte Grafik-, Windows-Export- oder Ziel-PC-
Abnahme. Der Laufzeitprobe kann `--capture-dir VERZEICHNIS` für zwölf native
Aufnahmen übergeben werden. In dieser Umgebung steht kein virtueller Bildschirm
zur Verfügung. Vollsuite, Transport zwischen Orten (ARCH-27), größere Budgets und
Zusammenführung bleiben gesonderte Integrationsarbeit. ARCH-13, ARCH-17 und ARCH-24
werden nicht bearbeitet. PROJECT_STATUS, NEXT_PARALLEL_WORK und zentrale Backlog-
Häkchen aktualisiert die Integration einmal für ihren gemeinsamen Stand.

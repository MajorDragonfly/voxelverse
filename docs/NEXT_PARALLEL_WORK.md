# Nächste parallele Arbeitsrunde

Stand: 9. September 2026. Gemeinsame Ausgangsbasis ist die zusammengeführte Version gemäß [Integrationsbericht](INTEGRATION_2026-09-09.md). Vor jedem Start `main` aktualisieren und den Start-Commit im eigenen Bericht festhalten. Keine alten Fachbranches weiterverwenden, ohne sie zuerst bewusst auf die gemeinsame Basis zu bringen.

**Veröffentlichung freigegeben:** Lars hat den öffentlichen Upload und die Übernahme nach `main` ausdrücklich bestätigt. Gemeinsamer Integrationsbranch: `agent/integration-2026-09-09`. Neue Fachbranches vom aktualisierten `main` erstellen, sobald der Integrations-PR dort zusammengeführt ist.

## Gemeinsame Regeln

- Jeder Chat erstellt einen eigenen Branch und arbeitet nur an seinem abgegrenzten Paket. Kein Zusammenführen anderer unfertiger Stände und kein automatischer Merge nach main.
- Vor Änderungen aktuelle Dateien und Eigentümer prüfen. Gemeinsame Kerndateien (`autoload/`, `project.godot`, `ui/progression_hud.gd`, Spieler-/Wildtierbasis, Speicherschemata) werden pro Integrationsrunde koordiniert. Erweiterungen sollen eigene Module und klar benannte Anschlüsse verwenden.
- Neue Ideen und ihre Roadmap-Einordnung werden gemäß Lars' Auftrag im Roadmap-Chat gepflegt; konkrete To-dos stehen in [FEATURE_BACKLOG.md](FEATURE_BACKLOG.md). Integrations- und Teststatus werden weiterhin nur anhand der Fach-/Integrationsnachweise aktualisiert. Jeder Fachchat dokumentiert Ergebnis, genaue Commit-ID, Prüfungen, geänderte Dateien, Schemaänderungen und Grenzen in `docs/WORK_<Paket>.md`.
- Fertig bedeutet ein überprüfbarer Ablauf mit Save/Load und gegebenenfalls Migration. Neue Eigenschaften dürfen nicht bloß im Menü behauptet werden.
- Aufstieg betrifft nur die eigene Spezies. Zähmbare Tiere behalten ihre eigene Art und werden keine Bürger. Kein Tierrollen- oder Zähmungsprototyp darf vorhandene Arten/Spielstände still neu generieren.
- Teilpakete können nacheinander geliefert werden. Datenvertrag D1 muss geprüft vorliegen, bevor andere Chats seine produktiven Daten anschließen. Bis dahin dürfen sie eigene kleine Prüfszenen vorbereiten; keine zweite konkurrierende Speziesdatenbank bauen.

## Sieben konkrete Aufträge

| Chat | Auftrag | Eigene Dateien/Module | Erster überprüfbarer Abschluss | Abhängigkeit |
|---|---|---|---|---|
| 1 – Planeten | M1d: vorhandene Weltobjekte an die Kugeloberfläche anbinden | `world/planet_lab/`, `world/surface/`, neue Adapter; V9-Kernänderung gesondert melden | Spieler, ein Baum und eine Kreatur auf radialer Oberfläche, Körper-/Ortsrückkehr; messbares Streaming | Gemeinsame Basis; keine stille Kampagnenmigration |
| 2 – Kreaturen | Funktionale Anatomie und Anschlüsse für Reiter/Geschirr vorbereiten | `creatures/editor/`, `creatures/runtime/`, `assembly/`; eigener Körpervertrag | Zwei-/Vierbeiner und mehrere Beinpaare mit Fußkontakt; dokumentierter Sattel-/Geschirr-Anschluss in Vorschau und Laufzeit | Abstimmung mit D1; keine eigene Haltungslogik |
| 3 – Artenkatalog | D1: deterministische Tierrollen pro Planet | Neue Module `world/fauna/domestication/`; gezielter Anschluss an Artenfabrik/Spawner | Drei unterschiedliche Pflichtarten mit Milch-, Zug-/Reit-, Begleiterfähigkeiten und erreichbarem Habitat; Mehr-Seed-/Neustartprüfung | Erster Datenvertrag für Chat 4/7; besitzt Spezies-Eignungsmodell |
| 4 – Zähmung | D2: ein fremdes Tier in der Stammesphase zähmen | Neue Module `world/domestication/`; eigener Haltungszustand/Controller | Phase/Eignung/Futter/Kosten prüfen, Vertrauen, Folgen/Warten/Heimkehr; Individuum/Besitz/Auftrag nach Laden erhalten | D1-Vertrag und freigegebene Fauna in Phase 1; keine automatische Bürgerrekrutierung |
| 5 – Dorfwirtschaft | M6: Wasser, weitere Rohstoffe, Berufe und anschließbar Milchproduktion | `world/tribe/`, `ui/tribe/`; Ressourcen-/Auftragsanschlüsse | Langfristig versorgtes Dorf ohne erschöpfte Startvorräte; weiterer Arbeitsplatz, zuverlässige Transporte; D3 nach D2 | Keine eigene Tierarten-/Zähmungsdatenbank; Chat 4 liefert konkrete Tiere |
| 6 – Entwicklung | Stammesfortschritt der eigenen Spezies und Mittelaltervoraussetzungen | `core/progression/`, `ui/development_path_panel.gd`, `ui/behavior_skill_tree.gd`; Phasenvertrag | Echte Gemeinschaftserfolge verdienen eigene Stammespunkte; Nachbarfraktionen bleiben eigene Spezies; spätere Phase bleibt bis Spielschleife gesperrt | Gemeinschaftsereignisse von Chat 5; globale Speicheränderungen koordiniert |
| 7 – Bedienung und Klang | Tierregister im Buch, Gruppenrückmeldung, UI-/Audio-Abnahme | `ui/discovery/`, `ui/frontend/`, `audio/`; vorhandene Ereignis-APIs | Gescannte Eignung versus eigenes gezähmtes Tier klar anzeigen; keine erfundenen Werte; klare Befehls-/Fehlerklänge; kleine Auflösungen | D1/D2 nur lesend; kein zweites Buch und keine zweite Pauseverwaltung |

## Kopierbare Einstiege für neue Chats

### 1 – Planeten

„Arbeite auf dem zusammengeführten Voxelverse-main an M1d gemäß ROADMAP.md und docs/NEXT_PARALLEL_WORK.md, Auftrag 1. Beginne mit einem begrenzten Oberflächenadapter für Spieler, einen Baum und eine Kreatur auf einem real großen Kugelplaneten. Erhalte die bestehende Kampagne und liefere messbare Bewegung, Kollision und Wiederbesuch. Eigener Branch und Übergabebericht; keine fremden unfertigen Änderungen zusammenführen.“

### 2 – Kreaturen

„Arbeite auf dem zusammengeführten Voxelverse-main an Auftrag 2. Prüfe die vorhandene Werkstatt einschließlich mehrerer Beinpaare und Fußkontakt. Ergänze stabile, gespeicherte Körperanschlüsse, mit denen später Reiter und Geschirr korrekt am Tier sitzen. Zähmung/Wirtschaft gehören anderen Chats. Eigener Branch und überprüfbarer Körpervertrag für den Artenkatalog.“

### 3 – Arten und Tierrollen

„Setze D1 aus ROADMAP.md auf der gemeinsamen Voxelverse-Basis um. Jeder belebte Spielplanet braucht deterministisch eine Milchtierart, eine Zug-/Reittierart und eine hundeartige Begleiterart mit geeigneten Körper-/Verhaltensmerkmalen und erreichbaren Vorkommen. Behalte bestehende Art-IDs/Spielstände. Liefere zuerst den versionierten Datenvertrag, dann Generator-/Spawnanschluss und Neustartprüfung. Keine Zähmungsoberfläche parallel erfinden.“

### 4 – Zähmung

„Setze D2 gemäß Roadmap um: Ab Stammesphase ein geeignetes fremdes Tier zähmen und als individuelles Tier mit Besitzer, Vertrauen und Folgen/Warten/Heimkehr speichern. Befreunden ist keine Zähmung und das Tier wird kein Bürger. Nutze den geprüften D1-Vertrag; solange dieser fehlt, bereite eine klar abgegrenzte Prüfszene vor. Berücksichtige, dass die bisherige Fauna teilweise auf Phase 0 begrenzt ist.“

### 5 – Dorf

„Baue das gemeinsame Voxelverse-Stammesdorf gemäß Auftrag 5 aus. Beginne mit dauerhafter Wasser-/Rohstoffversorgung und wiederaufnehmbaren Aufträgen. Danach Berufe, weitere frei erreichbare Arbeitsplätze und Anschluss für Milchlieferung aus D3. Verwende gemeinsame Vorräte, tatsächliche Transporte und Save/Load. Keine eigene Arten- oder Zähmungslogik.“

### 6 – Entwicklung

„Baue den Stammesfortschritt der eigenen Spezies gemäß Auftrag 6 aus. Echte Gemeinschaftserfolge sollen getrennte Stammespunkte verdienen. Plane Nachbarstämme als Fraktionen derselben eigenen Spezies; fremde Wildarten steigen nicht auf. Definiere spielbare Voraussetzungen für Mittelalter und später Neuzeit, mit ausdrücklicher Bestätigung und erhaltenen Bewohnern/Tieren. Schalte noch fehlende Spielphasen nicht durch Punktestände allein frei.“

### 7 – Oberfläche und Audio

„Übernimm Auftrag 7 auf dem integrierten Voxelverse-main. Erweitere das vorhandene gemeinsame Entdeckungsbuch um echte Tierrollen-/Eignungsdaten aus D1 und später ein lesbares Register eigener Tiere aus D2. Verbessere die Gruppenrückmeldung, Tonanschlüsse und kleine Auflösungen. Nutze bestehende Services, Erfolgsereignisse und Pausezustände; keine Doppelimplementierung von Buch, Zähmung oder Speicherung.“

## Integrationsreihenfolge dieser Runde

1. D1-Datenvertrag und Editoranschlüsse prüfen; gemeinsame Einbaupunkte festlegen.
2. Unabhängige Planeten-, UI-/Klang- und Dorfverbesserungen als abgeschlossene Pakete übernehmen.
3. D2 mit aktiver Stammesfauna und eigenen Tier-IDs integrieren.
4. D3/Milch und D4/Reiten/Pflügen jeweils als eigene spätere Lieferungen integrieren; D4 ist noch kein Auftrag, gleichzeitig einen kompletten Fahrzeugeditor zu bauen.
5. Gesamtspieltest: neue Kampagne → Scan → eigene Nestgruppe → bestätigter Stamm → zähmen → versorgen → speichern/neustarten. Anschließend Roadmap und Folgeaufträge aktualisieren.

## Planungsergänzung: Eier und Tierkörperteile (9. September 2026)

Die obenstehenden Einstiege beschreiben den Umfang der laufenden Grundlieferungen. Der neue Nutzerwunsch erweitert das Ziel über diese erste Runde hinaus; die konkreten To-dos und Abnahmen stehen in [FEATURE_BACKLOG.md](FEATURE_BACKLOG.md).

| Zuständigkeit | Geplante Ergänzung | Anschluss / Reihenfolge |
|---|---|---|
| 2 – Kreaturen | M3-TEILE: alle vorhandenen Teile prüfen/überarbeiten oder kompatibel ersetzen; frei kombinierbare Einzeloptionen nach echten Tieren, zuerst Mund/Kopf, Hände/Greifer und Füße | M2B-Anschlüsse und stabile IDs zuerst; vorhandene Reiter-/Geschirrverträge erhalten |
| 3 – Artenkatalog | D1-EIER: Eierlieferfähigkeit und eine vierte geeignete, erreichbare Art je belebtem Spielplaneten | Geprüften Drei-Arten-Grundvertrag versioniert erweitern; keine stille Neugenerierung |
| 4 – Zähmung | Die neue Eier-Eignung über den gemeinsamen D1-Vertrag verwenden | Vorhandene Zähmung/Individuen wiederverwenden; kein zweites Tierregister |
| 5 – Dorfwirtschaft | D3-EIER: Versorgung, Legestelle, Sammel-/Transportauftrag und Eier als Nahrung | Nach D1-EIER, D2 und D3-Haltungsbasis; gemeinsame Vorräte, reale Transporte, Save/Load |
| 7 – Bedienung und Klang | Eierrolle und neue Teile aus echten Daten anzeigen; Vorschauen/Silhouetten und gemeinsame Symbole verwenden | Nach den jeweiligen Fachverträgen; Übersetzungsanschluss mit Sprachverwaltung abstimmen |

Der vollständige Modellpass ist keine Voraussetzung für die erste Eierkette. Ein vorhandener Milchproduktionsnachweis oder Drei-Arten-Test gilt nicht automatisch als Abnahme der Erweiterung. Diese Dokumentation startet keine zusätzliche parallele Implementierung und ändert keine bestehenden Abschlussmeldungen.

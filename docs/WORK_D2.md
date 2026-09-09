# Auftrag 4 – D2 Zähmung

Stand: 9. September 2026. **D2 ist im Fachbranch an die spielbare Kampagne
angeschlossen und geprüft.** Die ursprüngliche isolierte Prüfszene bleibt
für Grenzfälle erhalten. D1s inzwischen abgeschlossene Generator-/Spawnlieferung
ist gezielt übernommen; fremde unfertige Wirtschaft-/UI-Arbeit ist nicht enthalten.

## Stand und Integration

- Gemeinsame Ausgangsbasis: `3a3e0272375e556f3ff65b7370582af79a9d48b5`.
- Fachbranch: `agent/d2-domestication`, [PR 30](https://github.com/MajorDragonfly/voxelverse/pull/30).
- Veröffentlichter Code-Commit: `bd259aabde2553f7d952e912197d6f4cee6d2cea`.
- Geprüfter Dateibaum: `73bedbdb26ef76334c8029ef9d1ef93e63a38144`
  (lokaler Code-Commit `af697d353c1f88f823d6176f40698ba16e74bc80`).
  Der nachfolgende Dokumentationscommit ergänzt nur Übergabe und Nachweise.
- D1-Vertrag: `bb43b61482ab129b72a66b5299a6bfec80a1e128`.
- Fertiger D1-Code: lokal `08fde2a4d496de2d4538508be5b77016fa7cd1c0`,
  veröffentlicht `96c61f49213b9906b45b07e7ff3f5d3bb6d1d682`; zugehöriger
  abgeschlossener Übergabebericht übernommen. Seine ursprünglichen Hashes
  unter `validation/d1/` beschreiben D1s eigene Lieferung.
- Kein automatischer Merge nach main. ROADMAP.md bleibt beim Integrationschat.
  Die gemeinsamen Anschlüsse und Schema 7 müssen bei M6/UI-Integration
  zusammengeführt werden; identische D1-Dateien nur einmal übernehmen.

## Spielbarer Ablauf

1. Eine Kampagne starten/laden, einen geeigneten Heimatplatz mit Nestgruppe
   anlegen und den Wechsel ins Stammeszeitalter ausdrücklich bestätigen.
2. Nahrung im Dorf einlagern. Genau einen lebenden Bewohner ohne Ladung
   auswählen; nach abgeschlossener Lieferung anhalten.
3. Im bestehenden Stammes-HUD „Tierhaltung“ öffnen, ein geeignetes fremdes
   Tier auswählen und „Zum Tier“ ausführen. Der Betreuer braucht einen
   begehbaren Weg in der geladenen Dorfumgebung.
4. „Füttern / Zähmen“: zwei aktive Sekunden innerhalb 4,5 m mit freier Sicht.
   Jede abgeschlossene Gabe kostet genau eine eingelagerte Nahrungseinheit.
   D1-Lernfähigkeit bestimmt den Gewinn; ein Begleiter benötigt vier Gaben.
5. Erst bei 100 Vertrauen gehört dieses Individuum dem Stamm. „Folgen“,
   „Warten“ und „Heimkehr“ schreiben den konkreten Auftrag sofort gemeinsam
   mit dem Tier. Befreunden allein erzeugt keinen Besitzer und keinen Bürger.
6. Speichern und neu starten: gleiches Tier mit ursprünglicher ID, fremder
   Art, eingefrorenem Körper, Besitzer, Vertrauen, Position und Auftrag.
   Tod bleibt gespeichert; das Tier wird nicht als Wildtier verdoppelt.

Sechs lebende Tiere einschließlich begonnener Zähmungen sind möglich.
Unbezahlte abgebrochene Gaben verbrauchen keine Nahrung. Bereits erworbenes
Vertrauen bleibt bei einer Unterbrechung bestehen; „Zähmung aufgeben“ gibt den
reservierten Platz ohne Futtererstattung frei. Speicherversagen bestätigt weder
Auftrag noch Vertrauen/Besitz und zieht keine Nahrung ab.

## Dateien und gemeinsame Anschlüsse

Der Daten- und API-Vertrag steht in [D2_DATA_CONTRACT.md](D2_DATA_CONTRACT.md).

| Bereich | Änderung |
|---|---|
| `world/domestication/animal_state.gd`, `domestication_controller.gd`, `d1_taming_policy.gd` | Individueller Zustand, geprüfte D1-Eignung, atomare Zähmung/Befehle; originale D1-Körperrevision 0 zulässig |
| `campaign_animal_state.gd` | Optionale Body-Hülle mit validiertem Register und eingefrorenen Körpern/Herkunftsidentitäten |
| `campaign_domestication.gd` | Anschluss an echten Stamm, Betreuer, Sicht/Kollision, Vorräte, SaveGameService und Lebenszyklus |
| `campaign_animal.gd` | Ursprünglicher D1-Körper, eigener Zustandsbesitzer, tatsächliche Bewegung und Tod |
| `domestication_controls.gd`, `ui/tribe/tribe_panel.gd` | Umschaltbarer Arbeitsbereich im vorhandenen HUD, gemeinsame Auswahl/Pause |
| `world/tribe/tribe_controller.gd`, `village_navigation.gd` | D2-Kind und begrenzter Annäherungsanschluss; geprüfter Wegbereich 20 m, D2-Ziele höchstens 20 m, normale Ziele weiterhin 18 m; vorhandene 22-m-Speichervalidierung bleibt erhalten |
| `autoload/save_game_service.gd` | **Globales Schema 6 → 7**, D1- und D2-Body-Prüfungen, Schutz neuerer Daten; keine neue Kampagnendatei |
| `autoload/progression_service.gd`, Sozialkomponente | Getrennte Gesundheit-/Tod-Spiegelung in Phase 1 ohne Beziehung, Belohnungen oder Sozialpunkte |
| Wildtierbasis, KI, Nahrung/Trinken und Pflanzenstreamer | Gezielte Phase-1-Aktivität; alte Einzelspielerangriffe bleiben gesperrt |
| `world/fauna/fauna_streamer_v7.gd` | Gespeicherte D2-IDs vor dem Spawnen reservieren, einschließlich toter Tiere |
| `creatures/ai/wildlife_steering.gd` | Optional begrenzte Vorausprüfung bis zum nächsten Tier-Wegpunkt, vorhandene Wildtier-Aufrufe unverändert |
| `core/runtime_shutdown.gd` | Tatsächlich 150 ms Mixer-Freigabezeit auch bei beschleunigten Testframes; verhindert nachgewiesene Audio-Restressourcen |
| Tests und D2-Workflow | Gemeinsamer Save, Bedienung, Neustart, generiertes Gelände und bestehende Stammes-/Faunaschleifen |

`body.domesticated_animals` verwendet Hüllenschema 1 und Registerschema 1.
Schema 7 verhindert, dass ein alter Build denselben Tierstand ohne D2-Reservierung
weiterspeichert. Altstände ohne Hülle erzeugen weder Tiere noch neue Bürger.
Vorhandene Körper/Arten werden nicht erneut generiert. Bei Integration nach D1
beide optionalen Body-Validatoren im SaveGameService erhalten.

## Nachweise

Godot `4.6.3.stable.official.7d41c59c4`, headless. Alle 17 abschließenden Gates (15 Tests plus Import und Assetquellen) bestehen.
Der maschinenlesbare Bericht enthält die abschließenden Ergebnisse und Messungen; fehlgeschlagene
Entwicklungszwischenstände werden nicht als bestandene Abnahme gezählt.

- D1-Vertrag, D1-Adapter (17), D2-Zustand (73 plus separater Prozess) und
  isolierte D2-Physikszene (21) bestanden.
- D1-Katalog mit 78 Seeds / 234 Arten sowie echte D1-Laufzeitprüfung bestanden.
- Kampagnenprüfung: 41 Prüfungen plus echter neuer Godot-Prozess. Vorhandene
  Freundschaft bleibt unabhängig; ursprünglicher Körper und dessen Revision
  bleiben gleich. Teilgabe setzt nach Laden fort; vier Gaben kosten vier
  reale Dorfnahrung. Echte HUD-Klicks, Bürgeridentitäten, Folgen/Warten/Heimkehr,
  Schreibfehler, neuere Schemata, Tod und Wiederherstellung sind geprüft.
- Hauptszene auf generiertem Gelände, Seed 23757: ursprüngliche D1-Spawninstanz,
  tatsächlicher Dorfplatz und Stammeswechsel, Nahrung sammeln/transportieren,
  lebenden Betreuer zum erreichbaren Tier führen, zähmen und heimkehren;
  nach Laden genau eine Instanz derselben ID. Phase-1-Nahrungs-/Wasseruhren
  laufen. HUD-Grenzen bei 1280 × 800 und 1280 × 720 geprüft.
- Bestehende Stammesbedienung und Versorgung, Wildtier-KI, Nahrung/Trinken,
  Speicherplätze und Kampagnenmigration bestanden.

Die Weltprüfung maß 22,435 m tatsächliche Heimkehr und 1,423 m Restabstand
zum Dorfplatz; das Milchtier kostete genau sechs eingelagerte Nahrungseinheiten.
[Weltprotokoll](../validation/d2/domestication_world_test.log),
[Kampagnenprotokoll](../validation/d2/domestication_campaign_test.log) und
[Quell-Hashes](../validation/d2/source-sha256.json) sind abgelegt.

Die Weltprüfung hält die ursprüngliche D1-Spawninstanz während Dorfplatzsuche,
Nahrungsvorbereitung und Annäherung des Betreuers still, um einen wandernden
Testaufbau zu vermeiden. Vor der Futtergabe läuft ihre echte Phase-1-KI wieder;
andere Tiere laufen bereits während der Nahrungssammlung. Weder die Art,
der Tierkörper, dessen Platzierung noch Dorfnahrung werden dort erfunden.
Die Kampagnenprüfung auf der Ebene ergänzt gezielte Fehlerfälle und Neustart.

Reproduktion der neuen Kampagnenabnahme:

```sh
python tools/validate_godot.py --godot <Godot-4.6.3> --skip-main --tests domestication_contract_test domestication_d1_adapter_test domestication_state_test domestication_lab_test domestication_campaign_test domestication_world_test tribal_age_test save_slots_test campaign_foundation_test --output <Pruefordner>
```

Die isolierte Szene bleibt über
`godot --path . res://world/domestication/lab/domestication_lab.tscn`
startbar und schreibt ausschließlich `user://d2_lab/snapshot.json`.

## Grenzen

- Zielbereich ist die geladene Dorfumgebung auf `legacy_plane_v9`. Unbekannter
  Boden und blockierte Wege führen zum Warten; keine Teleportation. Ein fernes
  oder wegwanderndes Tier muss erneut erreichbar werden. Kein Nachweis für
  beliebige Gelände-/Dorfkombinationen oder die Kugeloberfläche.
- Aktuell spielbare Stammesphase 1; spätere Epochen brauchen eigene Adapter.
- M6s noch nicht integrierte Wirtschaftslieferung ist nicht vorausgesetzt.
  D3 besitzt laufende Versorgung, Wasser, Milch und Transport; D4 Reiten/Pflügen.
  Hunger/Durst gehaltener Tiere bleiben dafür reserviert.
- Die grafische manuelle Windows-Abnahme bleibt offen. Kein neuer Windows-
  Spielbuild oder bereits zusammengeführtes main wird behauptet.

# Aktueller Projektstand

Stand: 15. September 2026, zweite Integrationsrunde. Kurzer Einstieg für neue Fachchats.

## Gemeinsame Basis

- `main` beim Abruf: `d378ca0ecd7f03429a5150df6358e0646ec06689`, Merge von #92.
- Neuer gemeinsamer Kandidat: `agent/integration-vegetation-nest-20260915`.
  Enthält die veröffentlichten PRs **#93–108** und die Ressourcen-/Anschlusskorrekturen.
  Exakte Eingangsköpfe: [Integrationsbericht](INTEGRATION_2026-09-15_RESOURCES.md).
- Der Kandidat ist eine eigene Branchlieferung. `main` wird dadurch nicht umbenannt
  oder stillschweigend als bereits geprüft erklärt. Für neue Pakete den festen
  Quellcommit aus der aktuellen PR-Übergabe verwenden.
- Godot **4.6.3**, Forward+, Jolt; regulärer Start ausschließlich über
  `ui/frontend/main_menu.tscn` → `main/spherical_campaign.tscn`.

## Enthalten und offen

| Bereich | Gemeinsamer Kandidat | Nächste Grenze |
|---|---|---|
| Kugelkampagne | Heimat, Dorf, vier Nutztierspezies, Milch/Eier und Körperreise | Zusammenhängende Ziel-PC-Abnahme |
| Vegetation/Heimat | Sechs individuell erzeugte Beerenformen, Planeten-/Biompalette, modernes Zweignest; stabile Form beim Wiederbesuch | Optische Abnahme im nativen Build |
| Speicher | Globaler Aufbewahrungsbericht, archivierte Begegnungen und Labortierhistorie; beide Blobverzeichnisse | Laufende Schreiber und sichere spätere Bereinigung |
| Leistung | Schrittweise Terrain-/Kollisionspublikation, begrenzte Tier-Audiobeobachter; Ernte ohne Mesh-/Colliderneubau | Restliche Einzelaufrufe und Ziel-PC-Messung |
| Kreaturen | Separater Rüssel, aktive Kiefer/Scheren, Katze/Bär/Schwein; Werkstatt DE/EN | Gespeicherte Teilrevisionen und weitere Katalogwünsche |
| UI/Audio | Vitalwerte unter der Minimap, Scanner, Dorfaufträge/Berufe DE/EN; weichere Schritte und Wasserklänge | Restliche Tierhaltungs-/Epochenkopie und Hörabnahme |
| Siedlungen | Zwei produktive eigene Orte, getrennte Vorräte/Aufträge und Nah-/Fernarbeit | Gleichartige Arbeitsplätze im selben Ort, Transporte zwischen Lagern |
| Raumfahrt | Modularer Schiffseditor mit Vorlagen, Vorschau, Symmetrie, Bibliothek und Undo | Instanz-/Kampagnenanschluss und spätere spielbare Flugschleife |
| Entwicklungsablauf | Fachtestplan aus lokalem Git-Diff; aktualisierte Folgepakete | Neue Pakete immer von diesem gemeinsamen Stand ableiten |

**Enthaltener Code ist nicht automatisch vollständig abgenommen.** Die genaue
lokale und CI-Prüfung steht in der [aktuellen Übergabe](INTEGRATION_2026-09-15_RESOURCES.md).
Keine Ableitung von Ziel-PC-FPS aus Headless-/CPU-Ansichten.

## Referenzhardware

| Komponente | Ausstattung |
|---|---|
| CPU | AMD Ryzen 7 9800X3D |
| GPU | NVIDIA GeForce RTX 4070 Ti |
| RAM | 32 GB, 5200 MT/s |

Vorläufiges Ziel: 1920 × 1080 bei 60 FPS. Preset und Treiber beim Lauf erfassen;
das ist keine Mindesthardwarefestlegung.

## Nächste Arbeitsrunde

`python3 tools/work_packet.py list` enthält ausschließlich neue abgegrenzte
Folgevorschläge und die offene Ziel-PC-Abnahme. Alte Pakete für Rüssel, Editor,
Manifest, Begegnungen, Zweitort und erste Terrainpublikation nicht nochmals starten.
Der Katalog reserviert keine Arbeit; die Belegung führt der Integrationschat.

[Folgearbeiten](NEXT_PARALLEL_WORK.md) · [Arbeitsablauf](PARALLEL_WORKFLOW.md) ·
[Technische Richtung](GODOT_TECHNICAL_DIRECTION.md) · [Roadmap](../ROADMAP.md).

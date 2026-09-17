# Stammesphase: Spieltestbefunde und Folgepakete

Auftrag von Lars, 16.09.2026: aktuelle Stammesansicht prüfen und Verbesserungen
an Lagerdarstellung, Tutorial, Oberfläche, Kamera, Planetendarstellung und
Wartezeiten bei Zuweisungen in die Roadmap aufnehmen.

**Status: geprüft und geplant; keine Laufzeitänderung in dieser Lieferung.**
Geprüfte Codebasis: `176d088d34324de14952bc7506fe9763a22cf4b0` (`main`).
Im vorherigen Chat bereitgestellter Windows-Testbuild:
[`c2e8188`, Lauf 35106489226](https://github.com/MajorDragonfly/voxelverse/actions/runs/35106489226).
Der Nutzer hat die tatsächlich gestartete Build-ID nicht erneut bestätigt.
Die hier untersuchten Spielpfade sind zwischen diesen beiden Ständen unverändert.
Quelle der Sichtprüfung: beigefügter Screenshot `e43ec829-bc2d-4e33-9cf0-dc472cff1773.png`
(2048 × 1152); keine neue Performance- oder Ziel-PC-Messung durchgeführt.

## Was die Prüfung belegt

| Beobachtung | Befund im aktuellen Code | Einordnung |
|---|---|---|
| Menü verdeckt einen Großteil des Spiels | Im Screenshot beginnt das Panel ungefähr bei y=475 und reicht bis unten. `TribePanel._layout()` begrenzt nur den inneren Scrollbereich auf 44 % der Fensterhöhe; Kopf und Rückmeldungen kommen hinzu. Bewohner belegen zwei bzw. drei breite Spalten. | Bestätigtes Layoutproblem. Ein bloß kleinerer Schriftgrad löst die Informationshierarchie nicht. |
| Ressourcenzahlen ohne wachsenden Lagerhaufen | `TribePanel.refresh()` liest `village.stock`. `VillageVisuals.rebuild()` zeichnet hingegen `deposits.remaining` und bei Menge > 0 immer fünf Klötze; der Dorfplatz erhält nur Lager-/Werkbankgeometrie. | „Leseholz · 39“ und „Lose Steine · 36“ sind verbleibende Vorkommen, keine eingelagerten 39/36 Einheiten. Die Lageranzeige braucht eine eigene Darstellung. |
| Kamera lässt sich kaum wegbewegen | `TribeController._process()` begrenzt den Fokus auf 10 m, bei vorhandenem `tribal_neighbor` auf `NeighborState.SITE_RADIUS = 16 m`. WASD verwendet den Rahmen am Dorfanker. | Bestätigte explizite Bewegungsgrenze, kein bloßer FOV-Effekt. |
| Blickwinkel und Zoom wirken starr | `_activate()` verwendet orthogonale Projektion und `far = 400`; `_update_camera()` setzt den festen lokalen Versatz `(0, 22, 17)`. `zoom()` begrenzt die orthogonale Größe auf 16–40. | Keine Bedienung für Drehung oder Neigung. Sichtweite, Projektion, Zoom und Schwenkradius sind getrennte Einstellungen. |
| Zuweisungen dauern lange | `_commit_order()` und `_save_economy()` rufen synchron `SaveGameService.save_now()` auf. Der Pfad erfasst einen Snapshot, validiert ihn, serialisiert/parst/validiert erneut und schreibt atomar samt möglicher Historie. Erfolgreiche Aufträge bauen Dorfvisuals neu auf und leeren Routen/Ziele. `panel.refresh()` kann mehrfach pro Auftrag sowie alle 0,2 s laufen. | Konkrete Messkandidaten, noch keine nachgewiesene Hauptursache oder gemessene Dauer auf Lars' PC. Navigation wird bereits in begrenzten Abschnitten aufgebaut; nicht pauschal jeden Hänger diesem Aufbau zuschreiben. |
| Bedienung im Stamm ist unklar | `OnboardingProgress.CHAPTER_STEPS.tribe` enthält nur den Aufstieg. `FirstSteps` zeigt die laufende Hinweisbox nur in Phase 0. | Bestehende M10-Einführung weiterverwenden; für Phase 1 fehlen konkrete Lernschritte. |
| Draufsicht passt optisch nicht zum Planeten | Kamera und Dorfvisuals nutzen bereits `GameplaySpace` und lokale Kugelrahmen. Die starre Orthogonalansicht, großen Geländestufen und vielen dauerhaften Weltbeschriftungen prägen den Screenshot. | Visueller Prüfauftrag. Der Screenshot beweist weder eine falsche Kugelgeometrie noch einen allgemeinen Normalenfehler. Auf großen Planeten ist lokale Flachheit physikalisch normal. |

Einstiege: [Controller](../world/tribe/tribe_controller.gd),
[Stammespanel](../ui/tribe/tribe_panel.gd), [Dorfvisuals](../world/tribe/village_visuals.gd),
[Speicherdienst](../autoload/save_game_service.gd),
[Navigation](../world/tribe/village_navigation.gd),
[Einführung](../ui/frontend/first_steps.gd), [Kapitelmodell](../core/onboarding_progress.gd).
Die Datenbesitzer und Transaktionsgrenzen aus [MODULE_CONTRACTS](MODULE_CONTRACTS.md)
bleiben Grundlage aller folgenden Pakete.

## P0 — M6-ORDER-LATENCY: Aufträge ohne lange Unterbrechung

Zuerst Klick → Validierung/Routen → Snapshot → dauerhafter Abschluss → Visuals/UI
getrennt instrumentieren. Berufe, Sammeln, Arbeitsplatz, Bauen, Stoppen und
Fortsetzen mit einer und mehreren ausgewählten Einheiten vergleichen. Auch
automatische Versorgung und getragene Fracht einbeziehen.

- Kleiner neuer Dorfstand und gewachsener Spielstand; 3 und 6 Bewohner;
  mindestens 100 gemischte Zuweisungen, erster und wiederholter Auftrag getrennt.
  Build, Seed, Speichermedium, Preset und Hardware protokollieren.
- Eingabebestätigung, fachliche Annahme und dauerhaften Speicherabschluss getrennt
  zeigen. Ein ausstehender Auftrag darf nicht bereits „gespeichert“ heißen.
- Unveränderte Visuals/Controls behalten, betroffene Routen gezielt invalidieren.
  Teure Arbeit nur nach Messung portionieren oder auf unveränderlichen Daten
  auslagern; keine SceneTree-Zugriffe aus Hintergrundthreads.
- Vorläufiges Abnahmeziel auf dem Referenz-PC: sichtbare Eingabebestätigung
  p95 ≤ 100 ms, einfache warme Zuweisung p95 ≤ 250 ms bis Abschluss,
  keine zusätzliche Hauptthread-Blockade > 50 ms durch einen Befehl.
  Das sind **Zielwerte**, keine vorhandenen Messresultate. p99/Maximum und
  Hintergrundspeicherzeit ebenfalls ausweisen; reine Bestätigung genügt nicht.
- Speicherfehler, Doppelklick, schnelle Folgebefehle, Pause, Beenden/Neustart und
  Planetenwechsel prüfen. Kein verlorener Auftrag, keine doppelte Produktion,
  keine verlorene Fracht/Reservierung. Bisherige atomare Sicherung und Rollback
  erhalten; Autosave nicht einfach anstelle der Transaktion einsetzen.

Gemeinsame Bereiche: TribeController, SaveGameService, Dorfvisuals, UI;
Speicheranschluss mit ARCH-13 und Transport mit ARCH-27 abstimmen.

## P1 — M6-TRIBE-HUD: Alltag und Details trennen

Zielbild: oben eine schmale Ressourcen-/Bevölkerungsleiste; unten kompakte
Bewohnerauswahl und Befehle passend zur Auswahl. Bau, Berufe, Tiere und Nachbarn
öffnen gezielte Detailansichten. Ein ausgewählter Bewohner zeigt Auftrag,
aktuellen Arbeitsschritt und Arbeitsort; Hunger/Durst nur kompakt bzw. bei Bedarf.

- Standardansicht bei 1920 × 1080 und 100 % UI-Skalierung: mindestens 70 %
  zusammenhängende, unverdeckte Spielfläche. Die bisherigen ca. 58 % Panelhöhe
  dürfen nicht durch einen ebenso großen neuen Dauerdialog ersetzt werden.
- 1280 × 720 sowie DE/EN und 100/125/150 % prüfen; bei wenig Platz Details
  einklappen, lesbare Schrift und bedienbare Schaltflächen erhalten.
- Einzel-/Mehrfachauswahl, aktiver Auftrag, ausgewählter Arbeitsplatz und Grund
  gesperrter Aktionen sofort erkennbar. Aufträge und Berufe sprachlich trennen.
- Ressourcen nach Ressourcenkatalog: verfügbar, reserviert, unterwegs und
  Kapazität nachvollziehbar; Details bei Hover/Klick. Kein UI-eigener Vorratszähler.
- Karte, Bauvorschau, Auswahlrahmen, Tutorial, Esc und Buch dürfen weder wichtige
  Aktionen verdecken noch Klicks durchreichen. Issue-91-Modalschutz erhalten.
- Weltbeschriftungen bevorzugt für Auswahl/Hover/Probleme; Größen, Symbole und
  Farben über die vorhandene UI-Gestaltung vereinheitlichen.

## P1 — M6-TRIBE-CAMERA: frei und zur Oberfläche passend

- Mit der Maus drehen/neigen, Mausrad für weichen Zoom, kamerabezogenes WASD,
  einstellbare Geschwindigkeit und gut sichtbare Aktion „Zum Dorf“. Belegung,
  Empfindlichkeit und Neigung unter **Esc → Einstellungen**, speicherbar.
- Perspektivische schrägere Standardansicht gegen den jetzigen Orthogonalblick
  vergleichen; geeignete Winkel/Zoomgrenzen im Spieltest wählen. FOV ist bei
  Perspektive relevant, bei Orthogonalansicht die sichtbare Größe.
- Kamerabewegung vom Arbeits-/Bauradius entkoppeln. Erste Abnahme: mindestens
  100 m zusammenhängender Schwenkweg über geladene Landschaft abseits des Platzes,
  Rückkehr und Fokus auf ausgewählte Bewohner/eigene Siedlung. Größere Reichweite
  braucht begrenztes Nachladen; weder Teleportation der Bewohner noch automatische
  Erkundungsfreischaltung durch Kameraschwenk.
- Fokus auf die Kugeloberfläche projizieren, lokalen Aufwärtsvektor fortführen,
  Gelände-/Wasserkollision und Ursprungswechsel behandeln. Kein Abdriften auf einer
  festen Tangentialebene und keine Kamerasprünge bei Körper-/Siedlungswechsel.
- Kamerareichweite, tatsächliche Sichtweite/LOD und erreichbare Befehlsziele
  getrennt testen. Die Navigationsgrenze nicht lediglich auf 100 m hochsetzen:
  Wegsuche, Bauvalidierung und Save-Grenzen bleiben eigene Verträge.

## P1 — M6-STOCKPILE-VISUALS: Vorräte im Dorf sehen

- Eigene Lagerflächen beim Dorfplatz: Holzstapel, Steinhaufen, Fasern sowie
  passende Behälter/Körbe für Nahrung, Wasser, Milch und Eier. Eindeutige
  Silhouetten und materialgerechte Voxeloptik statt eines skalierten Einheitswürfels.
- Mehr tatsächlich eingelagertes Material erzeugt mehr sichtbare Lagen/Volumen;
  Entnahme und Verbrauch verkleinern es. Begrenzte Instanzzahl, wiederverwendete
  Meshes und Änderungen nur bei Mengenstufen; keine neue Simulation pro Klotz.
- Darstellung ausschließlich aus dem autoritativen Dorfzustand ableiten:
  freie Ware aus `stock`; noch im Lager gebundene Baumaterialien bei Bedarf als
  getrennte Reservierungsgruppe. `VillageConstruction.summary()` unterscheidet
  reserviert, getragen, geliefert und zurückgeführt. Unterwegs befindliche oder
  bereits verbaute Ware nie zugleich als frei eingelagerte Ware zeichnen.
- Vorkommen, Abholstellen und Lager unterscheidbar beschriften. Der Abbauhaufen
  darf schrumpfen, während das Lager durch die spätere Ablieferung wächst.
- Abnahme je Ressource: 0, 1, mittlerer Stand und Katalogkapazität; Sammeln →
  Transport → Ablieferung → Bau/Verbrauch → Rückgabe nach Abbruch; Save/Load und
  A–B–A-Reise zeigen dieselben Mengen, ohne neue Lager-Savefelder.

## P1 — M10-TRIBE-TUTORIAL: am echten Spiel lernen

Die vorhandene optionale Kapitelhilfe um Stammesbedienung erweitern; keine
zweite Fortschrittsdatei und keine zweite Wirtschaft. Ein Schritt markiert das
passende Element und erklärt kurz Ziel, Eingabe und erwartetes Ergebnis.

1. Kamera bewegen, drehen, zoomen und zum Dorf zurückkehren.
2. Einen Bewohner auswählen, Mehrfachauswahl ergänzen und Auswahl aufheben.
3. Sammelauftrag geben; Tätigkeit, getragenes Material und tatsächliche
   Ablieferung verfolgen. Vorkommen, freie Vorräte und Reservierungen erklären.
4. Auftrag, dauerhaften Beruf und konkreten Arbeitsplatz unterscheiden;
   einen Bewohner zuordnen, stoppen und wieder fortsetzen.
5. Nahrung/Wasser sichern; erklären, dass Versorgungspausen den Auftrag erhalten.
6. Werkzeug und Hütte: Materialkosten, Bauplatz, Reservierung, Transport,
   Baufortschritt sowie Pause/Abbruch/Rückgabe an einer echten Baustelle verstehen.

Optional, überspringbar, pausierbar und unter Esc wieder aufrufbar; bestehende
Stammesstände dürfen später einsteigen. Schritte nur durch tatsächlichen Erfolg
abschließen (`order_resolved` allein beweist noch keine Ablieferung). Keine
Fortschrittsbelohnung für bloßes Anklicken. Fehlender Vorrat, blockierter Weg und
Speicherfehler erklären den nächsten sinnvollen Schritt. DE/EN, Neubelegung,
Speichern/Neustart und alte/neuere Anleitungsversionen korrekt behandeln.

## P2 — M6-PLANET-PRESENTATION: stimmige Dorfansicht

Nach dem Kamerapaket feste Ansichten desselben Dorfs bei Nah-/Fernzoom und
verschiedenen Neigungen vergleichen: Gelände, Vegetation, Kreaturen, Lager,
Bauten, Schatten und Beschriftungen. Kleine und große Kugel sowie geneigte Lage
und Ursprungswechsel einbeziehen. Bodenabstand, radiale Ausrichtung und Maßstab
prüfen; schwebende/versunkene Elemente konkret belegen und korrigieren.

Unruhige Beschriftungen und harte LOD-/Farbübergänge beseitigen; geeignete
perspektivische Tiefenwirkung erhalten. Keine künstlich verstärkte Planetenkurve,
globale Terrainneugenerierung oder pauschale Erhöhung aller Sichtweiten.
Vorher/Nachher-Bilder bei gleichem Seed, Ort, Tageszeit und Preset sowie
Framezeiten/Objektzahlen gehören zur Abnahme. Fernwaldarbeit mit
RENDER-DISTANT-FOREST abstimmen.

## Reihenfolge, Grenzen und Abschluss

Zuerst P0 messen und beheben, danach HUD/Kamera, anschließend Lager und Tutorial;
abschließend Darstellung und gemeinsamer Windows-Spieltest. Diese Reihenfolge
ist eine Planung, keine zusätzliche Live-Belegung. Die [zentrale Runde #137](https://github.com/MajorDragonfly/voxelverse/issues/137)
bleibt der einzige Belegungsort. Controller, UI, Lokalisierung und Save-Anschluss
überschneiden sich: Schreibbereiche vor Vergabe mit `work_packet.py conflicts`
prüfen und nacheinander integrieren. Laufende M4-Wildtier-/Gruppennavigation
nicht ohne eigene Abstimmung ändern. Der Integrationsbesitzer übernimmt diese
offenen Abnahmepunkte beim nächsten Abgleich in die zentrale Statusquelle.

Relevante vorhandene Prüfverträge: `village`, `home_progression`,
`frontend_locale`, `campaign`, `spherical_gameplay`, `regions_simulation`,
`surface`, `terrain_art`, `discovery_map`; je Lieferung nur direkte Verbraucher
auswählen. Neue Tests erst mit der Umsetzung registrieren. Der Abschluss braucht
einen festen Windows-Build mit gemeinsamem Ablauf von Auswahl über Lieferung
und Bau bis Speichern/Neustart sowie Lars' erneute UI-/Kamera-Abnahme.

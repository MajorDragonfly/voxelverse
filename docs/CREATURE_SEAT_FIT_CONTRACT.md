# Körpervertrag B3 – Sitzauflage, Reitermaße und Bewegung

Ergänzt [B1](CREATURE_BODY_CONTRACT.md) und [B2](CREATURE_BODY_FIT_CONTRACT.md). D1 besitzt weiterhin die Eignungsentscheidung. Dieses Paket liefert reproduzierbare geometrische Nachweise und Werkstattkorrekturen.

## Gespeicherte Maße

Optionaler Block `blueprint.assembly.body_attachments.fit_profile`, eigenes **Schema 1**. Das äußere V7-Format und B1-Anschlussschema 1 bleiben unverändert.

```json
{"schema": 1, "rider_scale": 1.0, "leg_spacing": 0.48, "seat_height": 0.20}
```

| Feld | Bedeutung | Bereich |
|---|---|---|
| `rider_scale` | Größe der Referenzfigur relativ zur bisherigen Prüfgröße | 0,5–2,0 |
| `leg_spacing` | Abstand der linken/rechten Beinmitte | 0,28–2,4 |
| `seat_height` | Beckenmitte über dem Sattelanschluss | 0,12–0,6 |

Abstand und Sitzhöhe sind Entwurfseinheiten vor Multiplikation mit dem Körpermaßstab. Die Werkstatt zeigt diese Werte als Prozent. Dies sind Prüfmaße einer geometrischen Referenzfigur, kein neuer Bewohner- oder Reiterbesitzdatensatz.

`assembly/core/creature_rider_profile.gd` liest fehlende Blöcke mit den bisherigen Standardmaßen, ohne den Entwurf zu verändern. Erst eine ausdrückliche Bearbeitung speichert den Block. Fehlerhafte, unvollständige und zukünftige Blöcke werden erhalten und zur Prüfung abgelehnt. Anschlussbearbeitung und Spiegelung erhalten die Zusatzfelder.

Die sichtbaren Formen und Kollisionskörper kommen gemeinsam aus `creature_body_fit_shapes.gd`. Neben Becken, Rumpf, Kopf und Unterschenkeln verbinden zwei Oberschenkelformen den Sitz mit den seitlich verstellten Beinen. Deshalb heißt das feste Prüfprofil nun **`workshop_reference_v2`**, das Profil mit gespeicherten Maßen **`workshop_rider_v1`**. Historische B2-Berichte mit `workshop_reference_v1` bleiben historische Nachweise ihres damaligen Formensatzes. `BodyFit.inspect` ergänzt `rider_profile`; seine übrige Berichtsstruktur bleibt kompatibel.

## Sattelauflage

API: `creatures/runtime/creature_saddle_support.gd`, `inspect(blueprint, skin = null)`. Das Ergebnis ist JSON-kompatibel, Schema 1, Bezugssystem `BodyV4`. Die Funktion verändert den Bauplan nicht.

Neun Messstrahlen treffen die tatsächlichen Rumpfvoxel unter der Sattelunterseite. Sie liegen bei X = −0,16 / 0 / +0,16 und Z = −0,22 / 0 / +0,22 innerhalb der 0,36 × 0,48 großen Sitzfläche. Gemessen wird entlang der lokalen Sattel-Aufwärtsachse; positive Lücke bedeutet Abstand, negative Lücke Eindringen.

| Feld | Bedeutung |
|---|---|
| `active`, `complete`, `errors` | Anschluss aktiv; Abfrage ausführbar; etwaige Daten-/Geometriefehler. Ein deaktivierter Sattel hat `active=false`, `supported=false`. |
| `samples` | Je Punkt `underside`, gegebenenfalls `skin`, `gap`, `supported`. Positionen körperlokal, Abstände auf Körpermaßstab normiert. Kein Treffer bedeutet fehlende Auflage. |
| `supported_samples`, `supported` | Alle neun Punkte müssen zwischen −0,001 und +0,085 liegen; zusätzlich Neigung höchstens 35°. |
| `min_gap`, `max_gap`, `tilt_degrees` | Gemessene Lücken und Neigung. Bei fehlenden Treffern stets zusätzlich die einzelnen Punkte auswerten. |
| `rider_seat_gap`, `rider_seated` | Abstand der Beckenunterseite zur Satteloberseite; zulässig −0,001 bis +0,035. |

Diese Schwellen sind versionierte Werkstattkriterien. Neun Punkte sind keine Flächenintegration: kleine Unebenheiten zwischen ihnen können unerfasst bleiben. Überlappungen des vollständigen Sattels/Reiters müssen zusätzlich mit `BodyFit.inspect` geprüft werden. Lastverteilung, Tragfähigkeit und anatomische Beweglichkeit bleiben eigenständige Fragen.

`proposal(preview)` untersucht sieben nahe Rückenlagen. Es erhält Reitergröße, seitlichen Anschlussversatz und Rotation, richtet Sitzhöhe und Auflageabstand aus und erweitert bei Bedarf den Beinabstand. Nur eine vollständig kollisionsfreie Ruhepose mit neun passenden Auflagepunkten wird angeboten. Die Grenzen bleiben erhalten; bei ungeeigneter Rückenform oder Neigung gibt es keinen Vorschlag. Vor Übernahme stehen Lage, Höhe und Beinabstand im Statusfeld. Die Änderung von Anschluss und Reitermaßen erfolgt gemeinsam in einem Undo-Schritt.

## Bewegungsnachweis

API: `creatures/runtime/creature_fit_motion_review.gd`. `start(parent, blueprint)` erzeugt eine unsichtbare eigene Vorschau; `step()` führt begrenzte Arbeit aus, `cancel()` bricht ab und `dispose()` entfernt Ressourcen. Die Kopie nimmt weder an Physik noch an der Teileauswahl teil. Originalbauplan, Originalpose und laufender Test bleiben unverändert.

Sechs Szenarien: Laufen/Rennen auf Ebene, Rampe und Stufen der bestehenden Werkstatt. Auf der Ebene werden zwei Gangzyklen geprüft; auf Rampe/Stufen die ganze Strecke einschließlich Endpunkt, mindestens ein Zyklus. Zielauflösung: mindestens 32 Posen je Zyklus; höchstens 512 Posen je Szenario. Ein überschrittenes Limit wird als unvollständig gemeldet. Gelände und Bewegung verwenden die vorhandene analytische Teststrecke; die bestehende Gelenkabnahme prüft diese zusätzlich gegen ihre echten Collider.

| Berichtsfeld | Bedeutung |
|---|---|
| `schema`, `geometry_profile`, `rider_profile` | Version 1 und tatsächliche Referenzmaße/Formen. |
| `design_id`, `source_fingerprint` | Entwurfskennung und Fingerabdruck des überprüften Ausgangsstands. |
| `status`, `complete` | Laufend/abgeschlossen/abgebrochen/ungültig. Vollständig bedeutet vollständig abgearbeitete Stichproben. |
| `coverage`, `continuous_clearance` | Immer `sampled_poses` und `false`. Kein Nachweis des gesamten zwischen den Posen überstrichenen Raums. |
| `checked_sockets`, `samples_checked` | Tatsächlich geprüfte Kennungen und Gesamtzahl der Posen. |
| `support` | Körperlokaler Auflagenachweis des Ausgangsentwurfs. |
| `scenarios` | Strecke, Gangart, Dauer, angeforderte/tatsächliche Poseanzahl und zeitlicher Abstand. |
| `collision_samples`, `first_collision`, `findings` | Zahl betroffener Posen, erster Trefferzeitpunkt und erste Zeit jedes neuen Form-/Teil-/Seiten-Treffers. Spätere neue Treffer bleiben sichtbar, auch wenn bereits ein anderer Anschluss kollidiert. |
| `minimum_supporting_feet`, `max_foot_penetration` | Kleinste Zahl aufgesetzter Fußmarker und größte Bodenunterschreitung in Streckenkoordinaten. Kontaktgrenze 0,002. |
| `max_total_stretch` | Größter Faktor aus Ruhelängenanpassung und zusätzlicher Pose-Dehnung gegenüber den entworfenen Segmentlängen. |

Trefferpositionen bleiben wie in B2 `preview_local` der jeweiligen Pose. Maximal 128 verschiedene Treffer je Szenario; `findings_truncated=true` macht den Bericht unvollständig. `complete=true` allein bestätigt weder Kollisionsfreiheit noch aufgesetzte Füße. D1 muss erforderliche Kennungen, passende Prüfprofile, Treffer, Kontakt, Dehnung und Auflage getrennt auswerten.

Werkstatt: **F2 → Körper → Sattel & Geschirr prüfen → Reitermaße / Sitz an Rücken anpassen / Laufen, Rampe & Stufen prüfen**. Ein Treffer öffnet seine angehaltene Testpose. Entwurfsänderungen verwerfen laufende und alte Nachweise. Prüfung und Ergebnisse werden nicht im Spielstand gespeichert; die Maße und Anschlüsse überleben Speichern, Undo/Redo und Neustart.

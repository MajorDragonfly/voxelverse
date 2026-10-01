# INT30-07 / Fachchat V30-07: Kreaturenverhalten und Animationen

Gemeinsame Basis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435` (#220), bestätigt in Issue #137. Fachbranch `agent/int30-07-creatures`, PR #225 gegen `agent/integration-pt19-20260930`; keine Übernahme nach main. Zusammenspiel der bereits enthaltenen PRs #190 (KI/Kampf), #191 (Befreundung) und #194 (Ausdruck/Zustandszeichen).

Geprüfter Quellcommit: `8e51ed0b5b8f3e53f3d5e4a6965831820f7898f4`; Tree `fc615eb3798ba6280f95d3387f526065ba3fa6c2`; Quellfingerprint `137919003be9c565b1a3218918206521747738c95897e984dc12784320326983`. Godot `4.6.3.stable.official.7d41c59c4`, Linux, isolierte Nutzerdaten. Die vier Prüfungen in `final-four` liefen auf lokalem Commit `d5ce67b` mit demselben vollständigen Tree und Fingerprint, die sechs weiteren auf dem veröffentlichten Commit. Die spätere Nachweislieferung verändert nur Dokumentation und Belege.

## Belegte Korrekturen

- Soziale Aufmerksamkeit, Antwortzeit und Begrüßungs-/Hilfscooldowns folgen der Simulationszeit. Geschwindigkeit null friert sie ein; Weltpause bleibt wirksam.
- Der bestehende `motion_speed_scale`-Anschluss friert auch Gang, Atmung und Kiefer des Wildtiers ein und lässt sie fortsetzen.
- Verlust von Reichweite/Sichtkontakt und ein echter Fremdangriff lösen die vorübergehende Bewegungsblockade. Vertrauen und Beziehung bleiben gespeichert; auch ein gerade befreundetes Tier kann fliehen.
- Ein angenommenes neues Kampfziel sperrt einen Biss gegen das alte Ziel. Tote, entfernte oder nicht mehr zulässige Ziele geben Verfolgung und Angriff frei.
- Optionale Angreiferattribute werden ohne `bool(null)` ausgewertet; ein gewöhnlicher Node3D darf eine echte Gefahrenreaktion auslösen.
- Schmerzzeichen hat während der kurzen Schmerzreaktion Vorrang, anschließend zeigt das Zeichen wieder den echten Flucht-/Kampfzustand.
- Der Anker für Zustandszeichen berücksichtigt die vorhandene visuelle Anatomie einschließlich MultiMesh-Teilen. Die größte Form verdeckte zuvor das fest auf 1,9 m gesetzte Zeichen. Die Grenzen werden einmalig beim ersten sichtbaren Zeichen gelesen; keine Neuerzeugung von Meshes.

## Verhaltensfälle

| Fall | Prüfung / Ergebnis |
|---|---|
| Erfolgreiche Befreundung | Drei wirkliche Aktionen: Vertrauen 35 → 70 → 100, Beziehung ally; keine Mehrfachbelohnung. Datei-/Save- und frischer Prozess bleiben getestet. |
| Abgelehnte Begegnung | Unpassende frühe Spielgeste wird abgelehnt, keine Vertrauenssteigerung, echte Flucht; nach Beruhigung erneute ruhige Aktion erfolgreich. |
| Unterbrechung / Wiederaufnahme | Spieler verlässt Reichweite; normale KI übernimmt, Fortschritt bleibt. Rückkehr setzt beim nächsten Schritt fort. |
| Fremdangriff | Laufende Aufmerksamkeit und positive Geste unterbrochen, Schmerz → Angst/Flucht → normales Verhalten → erfolgreiche Wiederaufnahme. |
| Zielwechsel / Kampf | Vorbereiteter Biss gegen Spieler wird bei neuem Angreifer abgebrochen. Schaden trifft das neue Ziel, das alte bleibt unbeschädigt. Sichtverlust hinter neuer Deckung bricht ebenfalls ab. |
| Zielverlust / Rückkehr | Tote Ziele und entfernte Spieler verursachen keine endlose Verfolgung. Nestalarm hält Gruppengrenzen und Pause ein. |
| Pause | Nullgeschwindigkeit und SceneTree-Pause stoppen die jeweiligen Uhren. Fortsetzung funktioniert. |
| Körperanschlüsse | Vorhandene Socket-Transforms, Bauplan und Szenenknotenzahl bleiben bei Ausdruck und Gang stabil. |
| Scanner | Bestehende Inspektionsdaten und Unterdrückung der Weltzeichen während Inspektion bleiben erhalten; DE/EN-Texte geprüft. |

Die zehn ausgewählten Tests bestehen; vollständige Ergebnisse, Befehle und Log-Hashes stehen in [validation.json](evidence/int30-07/validation.json), Logs und Diagnosen in [checks.zip](evidence/int30-07/checks.zip). Import und Quell-/Assetverträge wurden ebenfalls geprüft. Der konservative Änderungsplan wählt die volle Suite (247 Tests und main); diese sowie Exporte/Produktionsreisen gehören dem Integrationschat.

Die ersten gezielten Regressionen scheiterten auf dem vorherigen Produktstand an vier Sozial-/Uhrfällen, Schmerzpriorität, alter Zielzulässigkeit/totem Ziel und dem großen Zeichenanker. Unter konkurrierender Last liefen vier bestehende Tests zunächst in 120-s-Limits; D2 auch in der ersten Wiederholung. Alle bestehen später mit unveränderten Assertions und Limits. Ein einzelner früherer Engine-C++-Startabbruch (signal 11) ist mitsamt erfolgreicher Wiederholung erhalten. Diese Fehlversuche zählen nicht als erfolgreiche Prüfungen.

## Körperformen und objektive Kontakte

| Beine | Körperform (B × H × L) | Maßstab | Größte Ausdrucksverschiebung des Fußkontakts | Körperoberkante / Zeichenhöhe |
|---:|---|---:|---:|---:|
| 2 | 0,8 × 0,7 × 1,5 | 0,65 | 0,371 mm | 0,837 / 1,900 m |
| 4 | 1,3 × 1,0 × 2,8 | 1,00 | 0,576 mm | 1,501 / 2,038 m |
| 6 | 1,8 × 0,9 × 3,8 | 1,45 | 0,521 mm | 2,106 / 2,750 m |

Sieben Absichten × drei Gangarten pro Form; radial gedrehter Elterntransform bei großer Weltposition. Das Kontaktkriterium beträgt unverändert 25 mm. Beim tatsächlichen Fremdtreffer lag der niedrigste gemessene Fußkontakt 15,854 mm über der flachen Referenzfläche. Diese Werte sind Kontaktzeugen am Rig; beliebiges Terrain und sämtliche möglichen Baupläne sind damit nicht abgenommen.

## Videos und Animationskosten

Die Posevideos zeigen deterministische Aufrufe der produktiven Pose-/Gangpipeline bei 30 Bildern/s. Die Begegnungsvideos zeigen echte KI mit öffentlichen `befriend()`- und Schaden-APIs bei 15 Bildern/s; ihre Gefühls- und KI-Zustände werden nicht gesetzt. Der Testspieler ist ein aktiver API-kompatibler Beobachter, die flache Fläche eine reproduzierbare Testarena. Diese Clips ersetzen keinen manuellen Durchlauf der Kampagne.

Die fertigen Aufnahmen haben 960 × 540 Pixel: 210 Bilder / 7 s pro Posevideo und 420 Bilder / 28 s pro Begegnungsvideo. Compatibility und Forward+ verwenden Software-Rendering (llvmpipe / Vulkan Lavapipe), keine Ziel-PC-GPU. Rohmetriken und Ausführungsdaten enthalten Renderer, Quellfingerprint, Enginehash, Umgebung, Befehle und Log-Hashes. Alle vier MP4s sind H.264/yuv420p. Die vollständige Decodierung bestätigt Bildzahl, Dauer und Auflösung; Stichproben der decodierten Bilder wurden mit den Original-PNGs verglichen (mittlere RGB-Abweichung 1,37–1,50 von 255).

| Video | Inhalt | Dauer |
|---|---|---:|
| [Begegnungen / Compatibility](evidence/int30-07/encounters-gl.mp4) | Erfolg 0–8 s; Ablehnung 8–16 s; Unterbrechung/Fremdangriff/Rückkehr 16–28 s | 28 s |
| [Begegnungen / Forward+](evidence/int30-07/encounters-forward.mp4) | Dieselben echten Fälle, einschließlich Schmerzzeichen bei ca. 19,27 s | 28 s |
| [Laufanimationen / Compatibility](evidence/int30-07/poses-gl.mp4) | Drei Formen zugleich: Ruhe, Gehen, Laufen, Ruhe | 7 s |
| [Laufanimationen / Forward+](evidence/int30-07/poses-forward.mp4) | Dieselbe deterministische Gang-/Ausdrucksfolge | 7 s |

Native Bildkontrolle: Körperteile bleiben verbunden; Gangwechsel und Körperreaktionen sind sichtbar; Zeichen für Spiel, Freundschaft, Flucht und Schmerz sind lesbar. Die große Form verdeckt das Schmerzzeichen nach der Ankerkorrektur nicht mehr. Die ruhige Rückkehr und erneute Befreundung sind in den tatsächlichen KI-Daten nachgewiesen. Native Maximalpenetration der Kontaktzeugen: 0,023 mm; maximaler Socket-Drift: 0 m. Rohdaten liegen unter `native/`, Videoprüfung und Hashes in [media.json](evidence/int30-07/media.json).

Die Renderdurchläufe laufen nacheinander. `pose_cpu_us` ist die Wandzeit für drei Poseaktualisierungen, also unter gemeinsamer Rechnerlast von Präemption betroffen. `frame_ms` umfasst das Warten auf den Renderer; bei aktivierter Aufnahme kommen außerhalb dieses Intervalls zusätzlich PNG-Lese-/Schreibkosten hinzu. Daraus wird keine FPS-Zusage und kein reiner Ausdrucks-Mehrkostenwert abgeleitet. Die zusätzliche Linux-Messung verwendet CPU-Ticks des Hauptthreads und acht gepaarte Batches mit abwechselnder Reihenfolge, jeweils 1.500 Aktualisierungen von drei Körpern nach dem Körperaufbau (300 Aufwärmschritte). 100 CPU-Ticks/s; keine Renderer-, Spawn- oder Meshaufbaukosten in den gemessenen Batches.

| CPU-Zeit je Aktualisierung aller drei Formen | Median | Bereich der Batchmittelwerte |
|---|---:|---:|
| Gang ohne Ausdruck | 0,217 ms | 0,160–0,320 ms |
| Gang mit Ausdruck | 0,433 ms | 0,353–0,487 ms |
| Gepaarte Ausdrucks-Mehrkosten | 0,217 ms | 0,160–0,280 ms |

Diese Messung enthält die Emotionsberechnung und die produktive Poseaktualisierung, aber keine Kontextsuche, KI, Markerprojektion oder adaptive Terrainphysik. Ausdruck erzeugt keine zusätzlichen Szenenknoten, verändert keine Baupläne und verschiebt keine Body-Sockets. Der Produktionsdriver liest den vorhandenen Kontext begrenzt (nah 5 Hz, fern 2 Hz) und drosselt entfernte Ausdrucksposen auf 0,12/0,5 s; Gang bleibt separat. Messergebnisse und ausführbarer Skripttext stehen unter [cost/](evidence/int30-07/cost/). Dies ist keine Ziel-PC- oder Herdenleistungsfreigabe.

Zur Wiederholung unter Linux den Skripttext `cost/animation_cost.gd.txt` außerhalb des Projekts als `.gd` speichern und mit `godot --headless --path . --audio-driver Dummy --script /tmp/int30-animation-cost.gd -- /tmp/int30-cost.json` ausführen. Der vollständige lokale Aufruf und Skripthash stehen in `cost/execution.json`.

Reproduktion der nativen Fälle (Ausgabepfade außerhalb des Projekts; gleicher importierter Quellstand):

```sh
godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 30 --script res://creatures/behavior/review/int30_creature_review.gd -- /tmp/int30-poses poses-on
godot --path . --display-driver x11 --rendering-method forward_plus --audio-driver Dummy --fixed-fps 15 --script res://creatures/behavior/review/int30_creature_review.gd -- /tmp/int30-encounters encounters
```

Für Ausdruck aus denselben Aufruf mit `poses-off` ausführen; er zeichnet keine PNGs auf. Unter Linux ohne Bildschirm Xvfb und einen vorhandenen Mesa-Treiber verwenden. Lokale vollständige Befehle stehen in den Ausführungsprotokollen.

## Zuständigkeiten und offene Abnahmen

Mesh-Caching, Spawnaufbau, gemeinsame Runtime-Dateien und Scanner/UI wurden nicht geändert. Der Ausdruck nutzt den bestehenden Preview-Anschluss. Koordination zu Anker und Zeichenvorrang wurde in Issue #137 für Chat 2 / Chat 5 festgehalten; keine Bestätigung anderer Chats wird unterstellt.

Objektive Fachprüfung und Bildkontrolle sind Nachweise dieses Quellstands. Subjektiver Spielspaß bleibt Lars’ Abnahme. Windows/Ziel-PC-FPS, große Herden, vollständige Kampagne/Produktionsreise, native Exporte und aktuelle Integrations-Pflichtchecks bleiben eigenständige Freigaben. Draft-PR und Merge-Sperre der Integrationsrunde werden beibehalten.

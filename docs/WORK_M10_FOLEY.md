# M10-FOLEY: Schritte und Wasser hörbar unterscheiden

Basis: `d378ca0ecd7f03429a5150df6358e0646ec06689` (`main` nach #92).
Branch: `agent/m10-foley-20260915`. Eigenständiger M10-Folgeauftrag nach
ARCH-17-AUDIO (#102), ohne dessen Implementierung vorauszusetzen.

Die bisherigen Schritte waren überwiegend kurze Rauschimpulse mit starkem Anfang;
das Unterwasserambiente bestand hauptsächlich aus tiefem Rauschen. Das Paket
überarbeitet die Klanggestaltung und nutzt die vorhandenen radialen Anschlüsse.

## Lieferung

- Sechs Schrittmaterialien mit je drei eigenen Varianten: Gras, Sand, Stein,
  Schnee, Holz, Wasser. Weicher Bodenkontakt, zeitversetzte Belastung und
  Materialreibung ersetzen die stark auf den Anfang konzentrierten Impulse.
- Landung, Wassereintritt und Schwimmzug sowie beide Wasserambientes überarbeitet.
  Eigenständiger Wasseraustritt, Ein-/Auftauchen und drei Blasenbewegungen ergänzen
  den Bestand. 23 bestehende und sechs neue WAV-Dateien, 29 in dieser Lieferung.
- Unabhängiger deterministischer Generator je Asset; keine fremden Aufnahmen oder
  Samples. Bestehende Pfade/IDs bleiben erhalten. Die vollständige Basisgenerierung
  ruft den neuen Besitzer für diese Klänge auf. Das Manifest führt SHA-256 und Pegel.
- Waten/Schwimmen liest `is_swimming` aus dem tatsächlichen Bewegungscontroller;
  alte Prüffiguren behalten den Tiefenfallback. Vertikale Schwimmzüge zählen mit.
- Die bestehende Blicktiefen-Hysterese bleibt für Filter und Übergangsklang
  maßgeblich. Zusätzliche Darstellungskadenz benötigt keine neue Wasserprobe,
  keine zusätzliche Stimme und keine gespeicherten Daten. Höchstens ein zusätzlicher
  Cue pro Schritt, Blasen frühestens nach 2,8 bis 5,2 aktiven Bewegungssekunden;
  Ein-/Auftauchen mindestens 0,65 Sekunden auseinander. Überlast darf optionale
  Klänge im bestehenden Pool ablehnen.
- Spawn, Teleport, Pause, Kamera-/Quellenwechsel erzeugen keinen künstlichen
  Eintrittsklang. Gleichzeitige Fuß-/Augenkreuzung vermeidet zwei Übergangscues.
  Eine bereits freigegebene Figur stoppt ihr Wasserambiente sofort statt erst
  beim nächsten Bindungsversuch. Die Hörtest-Szene enthält die neuen Ereignisse.

## Nachweise

[Ergebnisse, genaue Prüfrevisionen und Logs](evidence/m10-foley/results.json).
[38-Sekunden-Hörprobe](evidence/m10-foley/foley-preview.ogg) und
[Zeitmarken](evidence/m10-foley/foley-preview.json).
Die Hörprobe ist aus den echten WAV-Dateien zusammengesetzt, kein Spielmitschnitt;
alte/neue Schritte haben denselben Abspielpegel und keine Einzel-Normalisierung.

| Hörprobe | Inhalt |
|---|---|
| 0,0 / 4,2 / 8,4 / 12,6 / 16,8 / 21,0 Sekunden | Gras / Sand / Stein / Schnee / Holz / Waten; jeweils drei alte, dann drei neue Schritte |
| Ab 25,5 Sekunden | Ufer, Eintritt, Schwimmzug, Austritt |
| Ab 30 Sekunden | Eintauchen, Unterwasserbett, Blasenbewegung, Auftauchen |

Die Signalanalyse prüft alle 29 Dateien auf Format, Inventar, Clipping,
Endpunkte, Loopnaht und Variantenunterschiede. Die erste Variante je Material
enthielt vorher 46–67 % ihrer Energie in den ersten 35 ms; jetzt etwa 1–7 %.
Die Spitzen und RMS-Pegel wurden bewusst reduziert. Alle 29 PCM-Dateien wurden
in einem frischen temporären Verzeichnis byteidentisch neu erzeugt.

Der neue Laufzeittest verwendet den echten AudioManager mit importierten Klängen
und eine lokale Wasserfläche mit X-Normale: Waten, tiefes Nichtschwimmen,
horizontales/vertikales Schwimmen, Augenkreuzung/Hysterese, Bewegungsblasen,
Stillstand, Pause, Teleport, Kameraaustausch und Löschen der Figur. Maximal vier
Umweltabfragen je Schritt und weiterhin 16 räumliche Stimmen. Bestehende
Audioprüfungen decken außerdem echte radiale Adapter, Mischung/Verdeckung,
Bewegungsphysik und Mixer-Shutdown ab. Einmalige Registrierung unter `audio`.

```sh
python3 tools/audio/check_foley.py --baseline-ref d378ca0ecd7f03429a5150df6358e0646ec06689 --output /tmp/foley-signals.json
python3 tools/validate_godot.py --godot GODOT_4_6_3 --skip-main --skip-import \
  --tests audio/foley_runtime_test audio/audio_runtime_test audio/audio_expansion_test \
  audio/audio_scene_lifecycle_test audio/audio_shutdown_test audio/spherical_water_audio_test
```

`--skip-import` nur nach erfolgreichem Import derselben lokalen Ressourcen.
Ein initialer Test deckte das verzögerte Wasserambiente bei gelöschter Figur auf;
der Lauf bleibt im Nachweis erhalten. Subjektive Klangqualität, Ziel-PC-Mix,
Windows-/nativer Export und gemeinsame Kampagnenabnahme bleiben offen. Es wird
keine neue Tauch-/Sauerstoffphysik eingeführt. Laufende ARCH-02/-24/-25/-26/-30-
Implementierungen werden nicht bearbeitet.

Integration: Audio-Runtime, Bibliothek/Assets, Hörtest, Generator/Signalanalyse,
Audio-CI, neue Testregistrierung und paketbezogene Übergabe. Mit #102 die beiden
zusätzlichen Tests jeweils einmal in `contracts.json` übernehmen. Die eigentlichen
Runtime-Dateien dieser beiden Lieferungen überschneiden sich nicht. Zentrale
Statusseiten/Backlog bleiben bei der Integration.

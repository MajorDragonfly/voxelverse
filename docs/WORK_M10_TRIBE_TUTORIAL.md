# M10-TRIBE-TUTORIAL

Basis: `84841dd9b7b4e09bb500c5de704883606ddc4934` aus PR #157.
Branch: `agent/m10-tribe-tutorial-20260917`. Zuteilung in Issue #137.

## Bedienung

Die optionale Anleitung erklärt die Stammesphase in drei Kapiteln mit elf
Lernzielen: Kamera, einzelne Bewohner und Gruppen, Sammelaufträge, Lieferung ins
Lager, Versorgung, Werkzeug, Bauvorschau/Platzierung, Bauabschluss, Beruf und
Arbeitsplatz. Eine kurze Zeile im kompakten Dorfpanel nennt den nächsten Schritt.
Sie ersetzt dort die bisherige Zielzeile. „Hilfe“ öffnet dieselbe pausierte
Kapitelansicht wie **Esc → Erste Schritte**. Details erklären auch blockierte Wege,
Vorräte versus Transport/Reservierung, Steuerung und wechselnde Zuständigkeiten.

Kapitel sind frei wählbar; passende Aktionen zählen auch vor ihrem Kapitel.
Abschalten erhält vorhandene Fortschritte. Kapitelwahl setzt die Anleitung fort;
„Einführung neu beginnen“ startet nur die Kapitel der aktuellen Phase neu.
Neue Abenteuer sind vorbereitet. Vorhandene v1/v2-Spielstände erhalten die
Stammeshinweise erst nach ausdrücklicher Kapitelwahl. Texte sind deutsch/englisch,
Kameratipps verwenden die aktuell belegten Tasten.
Vorhandene Werkzeuge und fertige Gebäude werden nach dem Einschalten anhand des
wirklichen Dorfzustands berücksichtigt: Das Werkzeug kann nur einmal hergestellt
werden, und ein ausgebautes Dorf kann bereits alle Bauplätze belegen.

## Ein Besitzer, echte Ereignisse

`OnboardingProgress` bleibt der einzige Fortschrittsbesitzer im vorhandenen
optionalen Save-Teilnehmer. Schema 3 ergänzt darin `tribal`; v1/v2 behalten ihre
Kreaturenschritte. Unbekannte neuere oder gebrochene Versionsnummern bleiben
unverändert und über die Hilfe nur lesbar. Kein zweiter Speicher oder Writer.

Der Beobachter an `FirstSteps` verbindet sich mit dem jeweils aktiven
Stammescontroller. Kamera und Auswahl melden tatsächliche Benutzung; erfolgreich
gespeicherte Aufträge/Berufe melden ihre vorhandenen Commit-Ergebnisse.
`community_event` liefert Einlagerung, Verbrauch und Bauabschluss erst nach
angekommener Arbeit. Öffnen/Abbrechen einer Vorschau, Aufsammeln, blockierte Arbeit,
leere Vorräte und fehlgeschlagene Speicherungen ersetzen diese Ereignisse nicht.
Der Beobachter erzeugt weder Rohstoffe, Belohnungen noch Kampagnenfortschritt.

## Gezielte Prüfung

- `tribal_guidance_test`: partielle Kapitel, Migration, Kopien, Abschalten,
  Neustart in einem frischen Prozess, Schreibfehler und Zukunftsversionsschutz.
- `tribal_guidance_world_test`: öffentlicher Kugel-Spieltest, elf Lernziele über
  echte Bedienung/physische Arbeit, Tastenwechsel, gesperrter Weg, fehlgeschlagene
  Aufträge/Platzierung/Berufe, Vorschauabbruch, Pause, Fortsetzen, Live-Laden und
  Opt-in in einem bereits ausgebauten Dorf ohne erfundene Lieferungen.
  Bauvorräte werden im Test begrenzt aus endlichen Vorkommen ins Lager übertragen;
  Herstellung, Bau und Lieferwege laufen regulär. Kein Tutorialmarker wird dafür
  gesetzt. Layout: DE/EN, 720p/1080p und 100/125/150 % Schriftgröße.
- Direkte Verbraucher: vorhandene Einführung einschließlich Kugelwelt,
  Save-Teilnehmer, Stammeslokalisierung, Kamera und Bauvorschau.
- `.github/workflows/tribal-tutorial-validate.yml` führt acht gezielte Tests und
  den neuen Kugeltest zusätzlich mit OpenGL/Software-Rendering aus.
  `tools/review_tribal_tutorial.py` erzeugt fünf native PNGs und einen Bericht mit
  Quellcommit/Tree. Exakter Prüfnachweis und visuelle Abnahme stehen im PR.

Integration hängt von den bisherigen Stammespaketen #153/#156/#157 und den vier
Pflichtgates auf der Integrationsbasis ab. Dies ist keine Export- oder Ziel-PC-
FPS-Abnahme. Die Anleitung erweitert weder Arbeitsgebiet noch Planetenübersicht.

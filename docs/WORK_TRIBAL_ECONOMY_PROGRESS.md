# Auftrag 6 – Nachweise aus der fertigen Dorfwirtschaft

Stand: 9. September 2026. Branch `agent/tribal-progression`.
Historische Abnahme dieses Pakets. Die anschließende aktive Nachbarfraktion steht
in `WORK_TRIBAL_NEIGHBORS.md` auf einem separaten Folgebranch.
Gemeinsame Basis: `3a3e0272375e556f3ff65b7370582af79a9d48b5`.

## Umfang und Herkunft

Dieser Folgeschritt verbindet Stammesfortschritt mit dem abgeschlossenen M6-Paket.
Übernommen wurden ausschließlich dessen dokumentierter Implementierungscommit
`9d30a0c31bc5da066580a2b58db6be782f899f41` und Dokumentationscommit `d083dfd`;
lokale Cherry-Picks sind `3f4db91` und `1bf857e`. Der Konflikt in `_work_rate`
wurde so aufgelöst, dass sowohl Stammes-/Vermächtnisboni als auch der neue
Hunger-/Wassermangel-Abzug wirksam bleiben. Unfertige spätere Fachstände wurden
nicht übernommen. `ROADMAP.md` und `main` gehören weiter dem Integrationschat.

Die M6-Quelldokumentation und Bilder bleiben als historische Abnahme erhalten.
Ihre Angaben zum damaligen Veröffentlichungsstatus beziehen sich auf den
eigenständigen M6-Branch, nicht auf diesen zusammengeführten Fachstand.

## Ergebnis

- **Dauerhaft versorgt:** einmal 3 soziale Stammespunkte für 180 aktive
  Spielsekunden mit erneuerbarer Nahrung/Wasser, tatsächlichem Essen und Trinken
  aller Bewohner sowie abschließend mindestens 12 Nahrung und 6 Wasser.
- **Verlässliche Berufe:** einmal 3 soziale Stammespunkte für zwei verschiedene
  Berufe mit jeweils drei beobachteten erneuerbaren Arbeits-/Lieferzyklen und
  mindestens zwei beteiligten Bewohnern. Ein Titel oder eine Abholung genügt nicht.
- Unterbrochene Transporte behalten ihren Arbeitsnachweis beim Speichern/Laden;
  ein späterer Berufswechsel schreibt vergangene Arbeit keinem anderen Beruf zu.
- Ein Versorgungsausfall setzt die aktuelle Zeit-/Verbrauchsvoraussetzung zurück.
  Bereits verdiente Stammespunkte bleiben verdient; derselbe Erfolg zahlt nie
  erneut aus. Insgesamt sind jetzt maximal 24 soziale Stammespunkte erreichbar.
- Der Entwicklungspfad zeigt beide geprüften Voraussetzungen einschließlich
  Laufzeit, Verbrauch, Vorräten und Berufszählern. Mittelalter und Neuzeit bleiben
  an UI und produktiver Übergabeschnittstelle gesperrt.

Die tatsächliche Arbeit bleibt vollständig in M6. Auftrag 6 beobachtet synchron
Vorher/Nachher des abgeschlossenen Arbeitsschritts und die aktive Simulationszeit.
Es gibt keine zweite Produktion, Fernlieferung oder Offline-Nachholung. Die
vorhandenen UI-Flächen und Rückmeldesignale werden verwendet.

## Verträge und Bestandserhalt

`progression.schema = 5`, `tribal.schema = 2`, neuer begrenzter
`tribal.villages[id].economy.schema = 1`; äußeres Speicherformat bleibt 6.
M6 liefert `tribe.schema = 3` und `tribe.economy.schema = 1`.

Alte Stammesnachweise werden ohne nachträgliche Wirtschaftsbelohnung migriert.
Bestehende Punkte, Käufe, Bewohner, Fracht und Baubeteiligung bleiben erhalten.
Neuere verschachtelte Wirtschaftsnachweise aktivieren den vorhandenen
Überschreibschutz. Kopien binden die Nachweise an ihre neue Kampagne, ohne sie
neu auszuzahlen. Aktive Zeit und Verbrauch werden im gemeinsamen Dorfsnapshot
gespeichert; der pro Frame laufende Timer verschiebt keine Autosaves.

Der vollständige Stand steht in `TRIBAL_PROGRESSION_CONTRACT.md` (Version 2).
Nachbarstämme bleiben Fraktionen derselben eigenen Spezies; fremde Wildarten
werden keine Bürger. Bestätigung und vollständiger Bewohner-/Tiererhalt sind
weiter verpflichtende Bedingungen des noch fehlenden Epochenadapters.

## Prüfungen und Übergabe

Geprüfter Implementierungscommit: `d502f314baac7445464225b6c599263787373e73`.
Prüfergebnis: `validation/tribal-economy-progression.json`.

Godot 4.6.3, eigene ausführbare Datei ohne Portable-Marker, frische Save-Verzeichnisse.
Alle **12 Abschlussprüfungen** bestanden: Import, Art-Quellprüfung und zehn Tests.

| Testgruppe | Nachweis |
|---|---|
| Neuer Wirtschaftsnachweis (Modell) | Keine Punkte aus Titeln, alter Fracht, Alleinarbeit oder Replay; unterbrochene Fracht nach JSON; Versorgungsfenster, Verbrauch, Mangel-Reset, Pause, ungültige Zeit, Migration und Zukunftsschutz |
| Neuer Wirtschaftsnachweis (Dorf) | Vollständiger realer M6-Ablauf; zwei erfüllte Berufe, 180 aktive Sekunden, alle drei Bewohner versorgt; Pause/Save/Load, Kopie, separater Prozessneustart, keine doppelte Auszahlung und kein Mittelalterwechsel |
| Bisheriger Stammesfortschritt (Modell und Dorf) | Gemeinsame Arbeit, getrennte Käufe, wirklicher Bonus, Speicherrücksetzung, Erhaltungsvertrag, Fraktionen und bestätigter Stammesstart bleiben gültig |
| Wirtschaftsdaten und Gartenversorgung | Milchquittungen, erneuerbare Produktion und Altformat bleiben kompatibel |
| Verhalten, Skilltree, Entwicklungspfad, Spielstände | Kreaturenfortschritt, echte GUI-Käufe, lesende Ansicht und vorhandene Slotverwaltung bleiben nutzbar |

Im neuen Dorfprüflauf: 51 Lieferungen, 16 Mahlzeiten, 16 Trinkvorgänge;
Versorger und Holzarbeiter jeweils mindestens drei vollständige Zyklen. Bei
Abschluss 180/180 Spielsekunden, drei von drei Bewohnern mit Ess-/Trinknachweis,
12 Nahrung und 12 Wasser im Lager. 13 soziale Punkte aus gemeinsamen Vorräten,
Mahlzeiten und den beiden neuen Wirtschaftserfolgen; das Testdorf hatte seine
Hütten und Werkzeuge bereits vor der Beobachtung.

Der alte Auswahleingabetest wurde an M6 angepasst: Er klappt die Dorfleiste mit
ihrem echten Button ein, bevor er Bewohner per Weltklick und Ziehen auswählt.
Danach klappt er sie für die Aufträge wieder aus. Keine Eingabeprüfung entfernt.
Die neue Prüfung lief headless mit realer GUI und Physik. Keine neuen
Rasteraufnahmen oder Windows-Leistungswerte; eine manuelle Ziel-PC-Spielprüfung
bleibt erforderlich. M6-Bilder sind unveränderte Belege der ursprünglichen Abnahme.

Veröffentlichung ist von Lars freigegeben. Der GitHub-Upload erfolgt über die
verbundene GitHub-App, da dem lokalen Git-Transport Anmeldedaten fehlen. Dort
wird ein gemeinsamer Review-Commit auf der dokumentierten Startbasis erzeugt;
sein Datei-Baum muss exakt dem lokalen geprüften Übergabestand entsprechen.
Die lokalen Ursprungscommits bleiben erhalten. Kein Merge nach `main`.

## Als Nächstes

Eine aktive Nachbarfraktion der eigenen Spezies mit einer erfüllbaren Hilfs- oder
Handelslieferung. Anschließend fehlen weiterhin der spielbare Mittelaltermodus
und seine bestätigte, atomare Bestandsübernahme. Keine dieser Arbeiten wird durch
volle Konten oder erfüllte Wirtschaftsziele vorgetäuscht.

# ARCH-25-HUSBANDRY-UI

Basis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8` aus Integrations-PR #110.
Branch: `agent/arch25-husbandry-ui-20260915`.

## Ergebnis

Die verbleibende Tierhaltung im Dorf und die Bestätigung für den Wechsel von der
Kreaturen- zur Stammesphase verwenden den vorhandenen DE/EN-Sprachdienst.
54 zusätzliche Katalogmeldungen; vorhandene Auftrags- und Berufskennungen bleiben erhalten.

- Baukosten, Tierpfleger, Zuordnung, Freigabe, Platzwechsel, Platz-/Tierauswahl,
  Versorgung, Milch-/Eierproduktion und ihre Sperrgründe sind übersetzt.
- `HusbandryRuntime.describe()` liefert ausschließlich einen lesenden Zustand mit
  Ressourcenkennung, Produktionszustand und Zahlen. Die UI formatiert Texte und
  Dezimalzahlen. Bestehende deutsche Fachfehler werden im vorhandenen
  `TribePresentation` exakt zugeordnet; unbekannte Diagnosen bleiben wörtlich.
- Bestehende Controls, Auswahl, Fokus, Reiter, Pausebesitz und Fracht bleiben beim
  Sprachwechsel erhalten. Auswahltexte werden auch bei unveränderten IDs erneuert.
- Der Bestätigungsdialog übersetzt den bereits vorbereiteten Zustand bzw. den
  gespeicherten Fehler. Sprachwechsel ruft weder Vorbereitung noch Speichern auf.
  Ein fehlgeschlagener Wechsel bleibt gesperrt; Zurück öffnet die Kreaturenphase.
- Scrollbarer Erklärungstext und dauerhaft erreichbare Bestätigungs-/Zurücktasten;
  Schriftgrößen bis 150 Prozent einschließlich Auswahlmenüs. Lange Auswahltexte
  werden bei Bedarf gekürzt und vollständig im Tooltip gezeigt.
- Der veraltete Hinweis auf erst künftig verfügbare Nachbarstämme ist korrigiert:
  Kontakte und Hilfslieferungen existieren, Stammeskämpfe sind weiterhin Zukunft.

## Prüfung

`tests/husbandry_localization_test.gd` ist genau einmal unter `frontend_locale`
registriert. Er benutzt die vorhandene D3-Prüfszene mit echten Dorfcontrollern,
Baukosten, Materialwegen, zwei verschiedenen gezähmten Testtieren, belegtem
Milchtierplatz und belegter Legestelle. Er prüft echte GUI-Eingaben, laufenden
Futter-/Wassertransport, unveränderte Spielstände beim Sprachwechsel, gescheiterte
atomare Epochenbestätigung, Abbruch, erneute Bestätigung und Save/Load.

Die Layoutmatrix umfasst DE/EN, 800×600, 1280×720 und 1920×1080 sowie Schriftgrößen
100/150 Prozent für Tierhaltung und Bestätigung. Der Bewohnername nutzt die
vertraglich maximalen 32 Zeichen einschließlich eines wörtlichen Übersetzungsschlüssels
und `{count}`. Der Ladevergleich berücksichtigt JSON-Zahlentypen und numerische
Rundung mit relativer Toleranz 1e-9; IDs, Felder, Aufträge und Mengen bleiben geprüft.

```sh
python3 tools/validate_godot.py --godot GODOT_4_6_3 --skip-main \
  --tests husbandry_localization_test egg_husbandry_ui_test tribe_localization_test \
  tribal_age_test phase_handoff_test localization_test --output /tmp/husbandry-check
python3 tools/review_husbandry_localization.py --godot GODOT_4_6_3 \
  --headless --output /tmp/husbandry-details
```

Der zweite Befehl bewahrt zusätzlich den vollständigen Ergebnisdatensatz des neuen
Tests und Engineprotokolle auf. Ohne `--headless` erzeugt er auf einem Grafiksystem
zwölf Screenshots der gleichen Prüfung. Alle Spiel-/Einstellungsdaten sind isoliert.
Prüfstände, Ergebnisse und ursprüngliche korrigierte Befunde stehen in
[`evidence/arch25-husbandry/README.md`](evidence/arch25-husbandry/README.md).

## Übergabe und Grenzen

Schreibbereiche: `ui/tribe/tribe_panel.gd`, vorhandener Darstellungsadapter,
lesender Anschluss in `world/tribe/husbandry_runtime.gd`, Sprachkatalog samt PO-Dateien
und eine Testregistrierung. Keine Änderung an Speicherformat, SaveService,
Produktion, Tierbesitz oder Epochenfreischaltung. `description()` hatte genau einen
internen Verbraucher; dieser benutzt jetzt `describe()` und die UI-Formatierung.

Ziel ist der Integrationsbranch von #110. Bei weiteren Katalogänderungen nach
Schlüssel zusammenführen und PO-Dateien neu erzeugen; neue Testregistrierung genau
einmal übernehmen. Zentrale Statusseiten bleiben beim Integrationschat.
Der konservative Diffplan verlangt wegen geteilter Schreibbereiche die volle
Integration; die genannten Fachtests sind ausdrücklich ein abgegrenzter Nachweis.

Native grafische Abnahme, Windows-Export und Ziel-PC-/FPS-Messung sind nicht erfolgt.
In dieser Umgebung ließ sich kein X-Display starten (keine lokalen
Display-Sockets); geometrische UI-Prüfungen laufen mit Godots Headless-Treiber.
Die späteren Epochenkarten im Entwicklungsbuch sind ein eigener UI-Bereich und
bleiben außerhalb dieser Dorf-/Bestätigungslieferung.

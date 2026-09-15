# ARCH-25-HUSBANDRY-UI: Tierhaltung und Stammeswechsel DE/EN

Zielbranch: `agent/integration-vegetation-nest-20260915` (#110).
Head: `agent/arch25-husbandry-ui-20260915`.
Status: lokal vorbereitet; Veröffentlichung benötigt noch Nutzerfreigabe.

Tierhaltungsdetails und die Bestätigung zum Stammeszeitalter zeigten bisher
überwiegend deutsche Texte. Bei großer Schrift benötigte der Bestätigungsdialog
außerdem begrenzten Platz mit erreichbaren Aktionen.

- 54 DE/EN-Meldungen für Baukosten, Pflege, Tierzuordnung, Platzwechsel,
  Produktionszustände und Sperrgründe sowie Epochenbestätigung/-fehler.
- Lesender Produktionszustand; Zahlen und Texte werden von der UI formatiert.
  Sprachwechsel erhält Controls, Auswahl, Fokus, Namen, Fracht und Spielstand.
- Scrollbarer Erklärungstext und erreichbare Bestätigungs-/Zurücktasten bei
  800×600 und 150 Prozent. Fehler werden neu dargestellt, ohne Wechsel oder
  Speichervorgang zu wiederholen.
- Veralteten Hinweis auf erst künftig verfügbare Nachbarstämme korrigiert.

**Prüfung:** Sechs Fachtests sowie Import, Quellen- und Art-Prüfung bestanden.
Der neue Test prüft 518 Bedingungen mit zwei tatsächlich gebauten/belegten Plätzen,
realer Versorgung, GUI-Eingaben, Save/Load und gescheiterter atomarer Bestätigung.
Layoutmatrix: DE/EN, 800×600 / 1280×720 / 1920×1080, 100/150 Prozent.

Sauberer lokaler Quellcommit `b038fecf476825e99f8c405af640f2bd3ff0a1da`,
Tree `08e267ec8301420eaf3ac220d6d28e10c06b5e9c`; Basis `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8`.
Godot 4.6.3, Linux/headless, isolierte Testbenutzerdaten. Ursprüngliche korrigierte
Testbefunde und Rohlogs: `docs/evidence/arch25-husbandry/README.md`.

Kein Windows-/Grafik-/FPS- oder Gesamtintegrationsnachweis. Die späteren Epochenkarten
im Entwicklungsbuch bleiben ein eigener Bereich. Keine Änderungen an Speicherformat,
Produktion, Tierbesitz oder Epochenfreischaltung. Zentrale Statusseiten bleiben bei
der Integration; Katalogmeldungen nach Schlüssel zusammenführen und den neuen Test
einmal unter `frontend_locale` erhalten.

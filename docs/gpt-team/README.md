# Voxelverse: elf spezialisierte Rollen

Stand: 17.09.2026. Auftrag: [DEV-GPT-TEAM #161](https://github.com/MajorDragonfly/voxelverse/issues/161).

Dieses Paket liefert vollständige kopierbare Anweisungen für elf Rollen, die bestehende GitHub-Koordination, drei ergänzende Issue-Formulare und zwei importierbare Action-Schemata. Jeder Rollenlink enthält bereits die gemeinsamen Grundregeln. Es müssen keine Bausteine von Hand zusammengesetzt werden.

## Die Rollen

| ID | Vollständige Arbeitsanweisung | Geeignete Arbeitsumgebung |
|---|---|---|
| 01 | [Projektleitung & Integration](arbeitsanweisungen/01-projektleitung-integration.md) | Codex für Koordination/Integration; Custom GPT für Planung |
| 02 | [Gameplay & Fortschritt](arbeitsanweisungen/02-gameplay-fortschritt.md) | Codex für Umsetzung/Prüfung; Custom GPT für Entwürfe |
| 03 | [Kreaturen-KI & Sozialverhalten](arbeitsanweisungen/03-kreaturen-ki-sozialverhalten.md) | Codex für Umsetzung/Prüfung; Custom GPT für Entwürfe |
| 04 | [UI/UX & Tutorials](arbeitsanweisungen/04-ui-ux-tutorials.md) | Codex für Umsetzung/Prüfung; Custom GPT für Entwürfe |
| 05 | [Kreaturendesign & Animation](arbeitsanweisungen/05-kreaturendesign-animation.md) | Codex für Umsetzung/Prüfung; Custom GPT für Entwürfe |
| 06 | [Welt, Grafik & Effekte](arbeitsanweisungen/06-welt-grafik-effekte.md) | Codex für Umsetzung/Prüfung; Custom GPT für Entwürfe |
| 07 | [Musik & Sound](arbeitsanweisungen/07-musik-sound.md) | Codex für Umsetzung/Prüfung; Custom GPT für Entwürfe |
| 08 | [Technik, Performance & Werkzeuge](arbeitsanweisungen/08-technik-performance-werkzeuge.md) | Codex für Umsetzung/Prüfung; Custom GPT für Entwürfe |
| 09 | [Spieletest & Fehleraufnahme](arbeitsanweisungen/09-spieletest-fehleraufnahme.md) | Custom GPT mit Intake-Action |
| 10 | [Roadmap & Ideen](arbeitsanweisungen/10-roadmap-ideen.md) | Custom GPT mit Intake-Action |
| 11 | [Qualitätssicherung & Releases](arbeitsanweisungen/11-qualitaetssicherung-releases.md) | Codex für Umsetzung/Prüfung; Custom GPT für Entwürfe |

## So richtest du sie ein

1. Einen privaten Custom GPT pro gewünschter Rolle anlegen. **Name, Beschreibung und Gesprächseinstiege** stehen in [GPT-EINSTELLUNGEN.md](GPT-EINSTELLUNGEN.md).
2. Den **gesamten Inhalt** der zugehörigen Arbeitsanweisung in **Hinweise / Instructions** einfügen. Jede Anweisung bleibt unter 8.000 Zeichen; die gemeinsame Basis ist schon enthalten. Nicht nur die Beschreibung eintragen.
3. Für direkte GitHub-Dokumentation die [GitHub-Einrichtung](GITHUB-EINRICHTUNG.md) durchführen. Das Intake-Schema liest Voxelverse und erstellt Issues/Kommentare. Das Read-only-Schema ist für reine Beratung. Ohne Action/geeignete Verbindung hat ein Custom GPT durch seine Anweisung allein keinen Schreibzugriff.
4. Datenanalyse nach Bedarf für Dateiauswertung/Base64 aktivieren; Bildgenerierung bei Designrollen nur bei Bedarf. Ein Musik- oder Animationsprofil fügt keine Musikproduktions- oder 3D-Werkzeuge hinzu. Verfügbare Werkzeuge müssen tatsächlich geprüft werden.
5. **Entwicklungsrollen in Codex:** Einen Chat im bestehenden Voxelverse-Projekt starten, das passende Rollenprofil nennen bzw. die Anweisung einfügen und das konkrete GitHub-Issue beauftragen. Codex benötigt Zugriff auf Checkout, GitHub und für Laufzeitprüfungen die passende Engine. Ein Custom GPT mit der gelieferten Action erstellt dafür fachliche Entwürfe und dokumentierte Übergaben; er führt keinen Code-Push, Merge oder Engine-Test aus.
6. Mit den Leseproben aus der GitHub-Anleitung prüfen, ob der GPT tatsächlich main und #137 liest. Der erste echte Testbericht dient anschließend als Schreibprobe. Keine zusätzliche Testmeldung nötig.

Die GPTs sind mit diesem Paket nicht bereits in deinem Konto angelegt. Token-/Builder-Einrichtung erfolgt in deinem Konto. Authentifizierung, Import und konkrete Werkzeugverfügbarkeit sind erst dort live prüfbar. Schreibbestätigungen der Custom-GPT-Action bleiben wirksam; eine Arbeitsanweisung deaktiviert sie nicht.

## Was du anschließend sagen kannst

- **Spieletest:** „Hier sind meine Beobachtungen und Screenshots. Dokumentiere die Fehler und Verbesserungen in GitHub und ergänze vorhandene Meldungen.“
- **Roadmap:** „Ich möchte später Landungsschiffe umbauen können. Prüfe Überschneidungen und dokumentiere den Vorschlag mit sinnvollen Ausbaustufen.“
- **Projektleitung in Codex:** „Übernimm die neuen Spieletest-Issues in die nächste Runde und wähle ein freies sinnvolles Paket.“
- **Fachrolle in Codex:** „Arbeite als Rolle 03 nach docs/gpt-team/arbeitsanweisungen/03-kreaturen-ki-sozialverhalten.md. Setze das zugewiesene Paket aus Issue #… um.“
- **Qualitätssicherung:** „Prüfe den Fix gegen die Abnahmekriterien von Issue #… und gib mir einen kurzen Nachtest für diesen Build.“

Ein Issue-Eintrag startet keine andere Sitzung automatisch. Du startest die passende Rolle; innerhalb eines beauftragten Codex-Laufs kann die Koordination unabhängige Arbeiten an Unteragenten delegieren. Dauerhafte Hintergrund-GPTs, automatischer Chat-zu-Chat-Versand oder neue kostenpflichtige Dienste sind nicht eingerichtet.

## Gemeinsame Regeln und Zuständigkeiten

[ZUSAMMENARBEIT.md](ZUSAMMENARBEIT.md) beschreibt Erfassung, Duplikatprüfung, Statusmeldungen, Vergabe, Übergaben und Abnahme. [GEMEINSAME_REGELN.md](GEMEINSAME_REGELN.md) ist die gemeinsame Grundlage der elf kopierbaren Profile.

- GitHub-Issues enthalten Befunde und Ideen; die Beschreibung von [#137](https://github.com/MajorDragonfly/voxelverse/issues/137) ist weiterhin die einzige aktive Vergabeliste.
- Rollen sind Fachzuständigkeiten, keine zusätzlichen GitHub-Benutzer. Alle Aktionen mit einem persönlichen Token erscheinen unter dessen GitHub-Konto.
- KI entscheidet über Verhalten, Animation stellt es dar. Gameplay bestimmt Wirtschaft und Fortschritt, UI zeigt sie. Welt/Grafik und Audio reagieren auf verbindliche Spielzustände.
- Koordination besitzt Integration und bewerteten Fortschritt. Qualitätssicherung liefert unabhängige Prüfbelege. Die Fehleraufnahme behauptet keine eigene Reproduktion aus einem Screenshot.
- Aktuelle Repository-Regeln und Nutzerentscheidungen gelten vor datierten Wissenskopien. PR #9 bleibt vom Merge ausgeschlossen; laufende Besitzer werden nicht ersetzt.

## GitHub-Formulare

Im GitHub-Menü **New issue** stehen nach Integration in den Standardbranch zusätzlich bereit:

- **Spieletest: Fehler oder Verbesserung** – Build, Beobachtung, Erwartung, Reproduktion, Belege und Fachrolle.
- **Neue Idee oder Roadmap-Erweiterung** – Nutzen, Epoche, Entscheidung, kleinster Umfang und Abhängigkeiten.
- **QA: Nachtest eines bestehenden Befunds** – Originalissue, exakter Build, tatsächliches Ergebnis und offene Abnahme.

Das vorhandene Formular für abgegrenzte Arbeitspakete bleibt erhalten. Ein Custom GPT nutzt diese Formulare nicht automatisch: seine Action schreibt denselben inhaltlichen Aufbau gemäß Übergabeprotokoll. Es werden keine neuen Labels, Assignees, GitHub-Projects-Felder oder Botdienste benötigt.

## Pflege und Grenzen

Die Texte sind Rollenprofile, keine neu installierten Codex-Skills oder automatisch geladenen Custom-Agent-Konfigurationen. Sie lassen sich in beiden Arbeitsumgebungen verwenden. Gemeinsame Regeln bei Änderungen zuerst in GEMEINSAME_REGELN.md pflegen, anschließend den entsprechenden Abschnitt in allen elf kopierbaren Profilen angleichen und Längen prüfen. Fachänderungen nur im zuständigen Profil pflegen. Hinterlegte GPT-Anweisungen sind Kopien; bei Profiländerungen müssen sie erneut übernommen werden. Laufender Projektstatus wird dagegen über GitHub gelesen.

Der Read-only- und der Intake-Zugriff sind getrennte Schemata. Fachrollen erhalten keine neue technische Berechtigung durch ihren Namen. Welche Operationen tatsächlich funktionieren, bestimmen die konfigurierte Verbindung, der Token und die aktuelle Umgebung. Prüfergebnisse für dieses Einrichtungspaket stehen in [PRUEFUNG.md](PRUEFUNG.md).

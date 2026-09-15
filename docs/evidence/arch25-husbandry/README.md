# Prüfnachweise: ARCH-25-HUSBANDRY-UI

Geprüfter Quellcommit: `b038fecf476825e99f8c405af640f2bd3ff0a1da`.
Tree: `08e267ec8301420eaf3ac220d6d28e10c06b5e9c`.
Basis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8` aus #110.

**Ergebnis: sechs Fachtests erfolgreich**, zusätzlich Import, Quellenverträge und
Art-Ressourcenprüfung. Der neue Test umfasst 518 Prüfbedingungen und meldet keine
Abweichung beim Laden. Beide abschließenden Läufe verwenden denselben sauberen
getrackten Quellstand; der Detailrunner erfasst die Revision vor und nach dem Lauf.
Die Nachweise werden anschließend in einem reinen Dokumentationscommit ergänzt.

| Prüfung | Nachweis |
|---|---|
| Neue Tierhaltung und Epochenbestätigung, 518 Bedingungen | [Ergebnis](husbandry/results.json), [vollständiges Protokoll](husbandry/run.log) |
| Bestehende Eier-UI, Dorf-Übersetzungen, Stammesablauf, Phasenübergabe, Sprachdienst | [Ergebnisse](contracts/results.json) |
| Import, Quellenverträge und Art-Quellen | gleiche [Fachprüfdatei](contracts/results.json) und zugehörige Rohlogs |
| Zusammengefasste Umgebung und Quellstand | [results.json](results.json) |

Der neue Test baut per realem GUI einen Milchtierplatz und eine Legestelle,
ordnet zwei verschiedene gezähmte Testtiere zu und startet echte Versorgung.
Bei laufender Fracht friert er die Simulation ein und wechselt DE/EN, ohne
Spielstand, Auswahl, Controls, Quittungen oder Pausebesitzer zu ändern. Er prüft
auch Speichern/Laden, Freigabe und Umstellung des ausgewählten Platzes. Die
Epochenbestätigung enthält einen echten fehlgeschlagenen atomaren Schreibvorgang,
Sprachwechsel in diesem Fehlerzustand, Abbruch, erneute Bestätigung sowie einen
blockierten Einstieg außerhalb der Heimat. Die Warnung zur absichtlich blockierten
Speicherdatei im Protokoll ist der erwartete Fehlerfall.

Layout: beide Sprachen, drei Fenstergrößen (800×600, 1280×720, 1920×1080),
100/150 Prozent Textgröße; Schaltflächen, Dialoggrenzen und scrollbare Inhalte
werden durch echte Godot-Controls vermessen. Keine Screenshots oder native optische
Freigabe: Der lokale Xvfb-Start scheiterte an nicht verfügbaren Display-Sockets.
Der mitgelieferte Reviewrunner kann auf einem Grafiksystem zwölf Aufnahmen erzeugen.
Kein Windows-Export, Prozessneustartnachweis, Vollintegrationslauf oder Ziel-PC/FPS-Test.

## Ursprüngliche Befunde und Korrekturen

Die Verzeichnisse unter `initial/` bleiben unveränderte Rohbelege ihrer jeweiligen
Arbeitsstände. Sie sind keine zusätzlichen Freigaben für den abschließenden Stand.

1. `qa-initial`: Import und ursprüngliche Eier-UI/Phasenübergabe erfolgreich.
2. `qa-locale-initial` und `qa-locale-diagnostic`: Der erste neue Test verwendete
   einen Namen über der bestehenden 32-Zeichen-Grenze. Dadurch wurde der nächste
   Versorgungsauftrag zu Recht vom Savevalidator zurückgewiesen. Der Test verwendet
   jetzt genau 32 Zeichen; keine Erweiterung des Spielschemas.
3. `qa-locale-corrected` und `qa-reload-diagnostic`: Der pauschale Dictionaryvergleich
   scheiterte an Integer-/Floatrepräsentation nach JSON-Lesen und kleinsten
   Float-Rundungen. Der endgültige Vergleich prüft weiterhin sämtliche Felder
   rekursiv, erlaubt ausschließlich numerische Repräsentation mit relativer
   Toleranz 1e-9 und prüft Fracht zusätzlich ausdrücklich. IDs, Aufträge und
   Warenmengen werden nicht von der Prüfung ausgenommen.
4. Der frühe Delta-Report in `qa-reload-diagnostic` hielt veränderbare Referenzen;
   einige seiner After-Werte zeigen deshalb bereits nachfolgende Testaktionen
   (Freigabe und Platzwechsel). Der endgültige Test kopiert Abweichungen tief.
   `qa-locale-complete` und der abschließende saubere Lauf haben keine Abweichungen.
5. Lange Auswahleinträge behalten ihre vollständigen Tooltips; Baukosten bleiben
   mit zwei eigenen übersetzten Beschriftungen sichtbar. Das ist im Quellcommit
   enthalten. Die vorhandenen Fachtests wurden anschließend auf diesem Stand geprüft.

Die einzelnen Engineaufrufe des Standardrunners nutzen isolierte Benutzerdaten.
Der Detailrunner verwendet denselben Isolations-/Engineadapter und bewahrt seine
Ergebnisdatei sowie Engineprotokolle außerhalb des verworfenen Testbenutzerprofils.

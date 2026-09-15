# ARCH-25-TRIBE-UI: Aufträge und Berufe DE/EN

Basis: `d378ca0ecd7f03429a5150df6358e0646ec06689` (main nach PR #92).
Geprüfter Quellcommit: `7b5257a7b1cff215dd1bbcc97ca1d52cbd4d5cc4`.
Quelltree: `38cfdb778589a4dc59c7767fbc4dd946e57922b5`.
Branch: `agent/arch25-tribe-ui-2026-09-15`.

## Lieferung und Grenze

Die Reiter **Aufträge** und **Arbeitsplätze & Berufe**, Dorfvorräte,
Bewohneraktivitäten, Wachstumshinweise und Gruppenrückmeldungen verwenden den
bestehenden Sprachdienst. 155 zusätzliche DE/EN-Nachrichten; 721 insgesamt.
Auswahl, Fokus, Reiter, Berufsauswahl, Scrollposition, Namen, Aufträge, Fracht und
Save bleiben bei einem Sprachwechsel erhalten. Die bisherigen deutschen
Domänenmeldungen werden ausschließlich lesend in der Darstellung adaptiert;
unbekannte Diagnosen bleiben sichtbar. Kein neues Speicherformat, kein zweiter
Sprachdienst und keine Änderungen am Dorfcontroller oder an seinen Regeln.

Lange Texte umbrechen. Die vorhandene Schriftpräferenz wird bis 150 % angewandt.
In kurzen Fenstern mit großer Schrift scrollen Auswahl und Rückmeldungen mit den
Aufträgen; Platzierungshinweise bleiben bei ausgeblendeten Aufträgen sichtbar.
Tierhaltungsdetails, Epochenbestätigung und Weltbeschriftungen sind Folgepakete.
Dies ist ein abgeschlossener Teilauftrag, keine vollständige ARCH-25-Abnahme.

## Nachweise

Godot 4.6.3, Linux; isolierte Benutzer-/Einstellungsdaten. Arbeitsstand beim
Fachlauf ohne Änderungen an getrackten Dateien; Engine-Sidecars waren ungetrackt.
Der nachfolgende Evidenzcommit verändert ausschließlich diese Nachweise.

```sh
python3 tools/validate_godot.py --godot /path/to/godot \
  --tests tribe_localization_test tribal_age_test neighbor_localization_test \
  egg_husbandry_ui_test localization_test --skip-main --output /tmp/tribe-check
python3 tools/review_tribe_localization.py --godot /path/to/godot \
  --output /tmp/tribe-render
```

Der Grafikbefehl benötigt unter Linux einen Displayserver. Verwendet wurde Xvfb
mit OpenGL-Kompatibilität, Mesa llvmpipe und Dummy-Audio. Der vorhandene Runner
kapselt die Nutzerdaten. Alle fünf Fachtests sowie Import, Vertrags- und
Ressourcenprüfung bestanden. Der neue Test enthält 801 Prüfungen, darunter echte
GUI-Aufträge, Materialabholung, Stop/Fortsetzen, fehlgeschlagenes atomisches
Speichern, Save/Load und Berufszuweisung. Der bestehende Stammestest prüft unter
anderem Bauen, Phasenwechsel und Kampagnenwechsel. Das ist kein zusätzlicher
Nachweis eines kalten Prozessneustarts oder der gesamten Kugelkampagne.

48 Bildschirmaufnahmen: DE/EN, 1920×1080, 1280×720, 800×600, 100/150 % Schrift,
beide Reiter jeweils oben und zu den Aktionen gescrollt. Jede sichtbare Aktion
wurde auf Erreichbarkeit geprüft. Vier repräsentative Aufnahmen sind beigefügt
und visuell geprüft; vollständiges Aufnahmeverzeichnis und Produktionshashes
stehen in `visual-results.json`. Die Grafikprüfung lief mit identischem
Produktionscode vor der letzten zusätzlichen Berufszuweisungsprüfung im Test.
Diese zusätzliche Prüfung ist im anschließenden Fachlauf enthalten.

Die Screenshots zeigen die vorhandene Dorf-Prüfszene; der absichtliche Name
`TRIBE_BOOK {count}` prüft, dass Spielnamen nicht übersetzt oder interpoliert
werden. Kein Windows-Export, kein Hardware-/FPS-Nachweis und keine gemeinsame
Integrationsfreigabe. ARCH-24, ARCH-13 und ARCH-17 wurden nicht bearbeitet.

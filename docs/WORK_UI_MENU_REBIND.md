# UI-MENU-REBIND — Menüs über die Steuerung belegen

Fachlieferung vom 16. September 2026. Der Nutzer hat das nächste freie Paket
beauftragt; ARCH-24 bleibt beim anderen Fachchat. Keine Integration oder
Ziel-PC-Freigabe durch diese Lieferung.

## Feste Basis und Integration

- Gemeinsame Spieltestbasis: `d57b1ef385728728b132518a1ea05683888dcae0` (#125).
- Direkte Abhängigkeit: Atlas-Suche aus [#131](https://github.com/MajorDragonfly/voxelverse/pull/131).
  Auf GitHub `f51bdd023b1d239d392fa6d9bc38340d49ab406b`, lokal
  `d71d7ba0c25f6db6065aa5128f263c8a3bd303a7`, gleicher Tree
  `350df033dcdcf7a5f21742ff9ba942ed495a3ee0`.
- Branch `agent/ui-menu-rebind-20260916`; PR-Ziel ist der Atlas-Branch
  `agent/arch14-atlas-search-20260916`. #131 zuerst integrieren; anschließend
  das PR-Ziel im Integrationschat umstellen oder nur diese Folgecommits übernehmen.
- Gemeinsame Schreibbereiche: drei neue Input-Actions in `project.godot`,
  additive DE/EN-Katalogeinträge/Platzhalter und ein Testeintrag im Vertrag
  `frontend_locale`. Die parallele Atmosphären-Settingslieferung verändert
  `DisplaySettings`; dieses Paket verwendet dessen vorhandene Anschlüsse.
- Zentraler Projektstatus, Paketkatalog, Roadmap und fremde Fachlieferungen
  bleiben beim Integrationschat. Die Favoritenlieferung #132 ist unabhängig.

## Bedienung und Vertrag

Unter Einstellungen → Steuerung sind Entdeckungsbuch, Entwicklung und Weltkarte
mit jeweils Haupt- und Zweittaste belegbar. Standard: J, K, M. Einzelne Buchstaben
und Ziffern sind zulässig; feste Aktionen F/H/N/P, UI-/Funktionstasten, Maustasten
und mehrfach vergebene Tasten werden für diese Menüaktionen zurückgewiesen.
Mindestens eine Taste je Aktion bleibt erforderlich. Esc schließt die Menüs.
Die neuen Aktionen verwenden denselben Entwurf, „Übernehmen & speichern“ und
Standard-Reset wie die bisherigen Spielaktionen.

`InputPreferences` bleibt einziger Besitzer der lokalen Steuerungsdatei.
`open_journal`, `open_development` und `open_world_map` sind normale InputMap-Actions.
Die Menüs verwenden ihre aktuellen physischen Belegungen; modifierbehaftete
Kombinationen öffnen sie nicht. Logische Ereignisse ohne physischen Code bleiben
für synthetische Eingabe unterstützt. Keine neue Kampagnen-/Speicherarchitektur.

Ältere Profile enthalten diese drei Aktionen noch nicht. Beim Lesen werden nur
fehlende Menüaktionen ergänzt. Bereits belegtes M oder andere Spieltasten bleiben
erhalten; neue Aktionen weichen deterministisch auf freie Tasten aus, mit Hinweis
in den Einstellungen. Das Lesen schreibt keine Datei. Erst ausdrücklich
übernommene Änderungen speichern das ergänzte Profil. Bereits explizit gespeicherte
Menübelegungen werden ebenso streng validiert wie die Spieltasten; ein defektes
Profil verwendet den bestehenden Standard-Rückfall. Fehlgeschlagene Schreibvorgänge
ändern weder aktive Werte noch die vorherige Datei.

Menüschließen gibt Pause und Maus erst nach dem Eingabeframe frei. Andere modale
Oberflächen behalten ihre Pause; die Tastenerfassung in den Einstellungen hat
Vorrang. Menübuchstaben bleiben Text in der Buch-/Atlas-Suche. Im Atlas verlässt
Esc zunächst das Suchfeld. HUD-Knöpfe, Kartenknopf, Entwicklung-zu-Buch-Verweis,
Hilfe, Einführungs-/Scannerhinweise und Buchanleitung zeigen die aktuelle Belegung
in DE und EN. Es werden keine festen J/K/M-Tipps für diese Aktionen eingeblendet.

## Nachweis und Grenzen

Godot 4.6.3, Linux/headless mit isolierten Nutzerdaten. Der neue Test verwendet
die echten Spieler-/Menüszenen, echte Buttonklicks und Viewport-Tastenereignisse:
Altprofil inklusive M-Kollision, unveränderte Quelldatei, doppelte/feste Tasten,
Schreibfehler, Haupt-/Zweittasten, nur vorgemerkter Reset, eigener Engine-Neustart,
physische/logische Ereignisse, Suchfelder, Pause/Maus und dynamische DE/EN-Tipps.

Direkte Verbraucher: bestehende Eingabeprüfung, Frontend mit tatsächlichem
Kugelstart, Entwicklungsbuch, Entdeckungsbuch, Atlas einschließlich Suche sowie
Lokalisierung. Abschließender Quellcommit/Tree, Befehl, Ergebnisse und vollständige
Logs stehen in `evidence/ui-menu-rebind/` nach der Prüfung.

Native Bildprüfung, Windows-Export und Ziel-PC-Eingabe mit abweichendem
Tastaturlayout bleiben Integrations-/Ziel-PC-Abnahme. Keine Änderung der festen
Editor-/Laborsteuerung, keine Controllerbelegung und keine frei belegbaren
Tastenkombinationen. F/H/N/P bleiben vorhandene feste Spielaktionen.

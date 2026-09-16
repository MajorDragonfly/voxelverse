# BP-COMMUNITY-LIBRARY-FAVORITES

Fachbranch `agent/community-library-favorites-20260916`, feste Basis
`d57b1ef385728728b132518a1ea05683888dcae0` aus Spieltest-PR #125.
Die Atlas-Suche aus #131 ist eine getrennte Lieferung; dieser Branch enthält
keine Abhängigkeit darauf.

## Ergebnis

Kreaturenvorlagen lassen sich im bereits gemeinsamen Picker des Editors und des
Neues-Spiel-Menüs als Favoriten merken. Startvorlagen und lokale Pakete verwenden
dieselbe Bedienung. Die Liste zeigt einen Stern, der Favoritenfilter lässt sich
mit Start-/Lokalkatalog und der vorhandenen Suche kombinieren. Die Suche erfasst
jetzt zusätzlich Beschreibungen und Tags. Deutsch und Englisch sind angeschlossen.

Markieren verändert weder den Entwurf noch Kampagne, Fortschritt, Vorschaukamera
oder Auswahl. Der bekannte Übernehmen-/Startablauf prüft unverändert Freischaltungen
und Verwendbarkeit. Filter beschränken die Liste; ein bereits ausgewählter Entwurf
bleibt im Detail erhalten, auch wenn seine Markierung bei aktivem Filter entfernt
wird. So lässt sich die Aktion direkt rückgängig machen oder der Entwurf verwenden.

Die Erfolgsanzeige erscheint erst nach abgeschlossenem Schreiben. Bei Schreibfehlern
wird der gedrückte Knopf auf den bisherigen Zustand zurückgestellt; die Vorlage
bleibt verwendbar. Bei einer unlesbaren/neuen Bibliothek bleiben mitgelieferte
Vorlagen verwendbar, während lokale Änderungen gesperrt bleiben.

## Speicherung und Identitäten

`CreatureDesignLibrary` bleibt der einzige Besitzer der gerätelokalen Datei.
Schema 2 ergänzt `favorites` als begrenzte Liste in derselben atomaren JSON-Datei.
Keine zweite Einstellungsdatei, kein neuer SaveGameService-Teilnehmer, kein
Community-Dienst. Lesen eines Schema-1-Dokuments verändert dessen Bytes nicht;
erst eine echte Änderung führt zum Schemawechsel und erhält das alte Backup.

Markierungen gelten exakt für Kennung und Revision. Gleichnamige Varianten,
neuere Revisionen und lokal importierte Kopien einer Startvorlage erben keine
Markierung. Das Entfernen eines lokalen Pakets entfernt seine Markierung im
gleichen Schreibabschluss. Export enthält ausschließlich das vorhandene portable
Paket; Import auf einem anderen Gerät übernimmt keine Favoriten.

Eingebaute Auswahl-/Favoritenschlüssel verwenden jetzt `builtin/` statt
`builtin:`. Der bisherige Doppelpunkt war selbst in gültigen importierten
Designkennungen erlaubt und konnte deshalb eine lokale Vorlage mit einer
Startvorlage kollidieren lassen. Diese UI-Schlüssel wurden bisher nicht gespeichert;
bestehende lokale Designkennungen werden nicht umbenannt. Die bestehenden
Kampagnen-/Arten-/Körperverträge bleiben unverändert.

Schema-/Typfehler, doppelte oder ungültige Favoritenschlüssel, verwaiste lokale
Verweise und Überschreiten der Obergrenze sperren Änderungen. Ein vorhandenes
älteres Backup überschreibt dabei kein beschädigtes oder neueres Original.
Bekannte alte Startvorlagenrevisionen dürfen als Markierung erhalten bleiben.

## Prüfung und Integration

Der neue registrierte Fachtest prüft alte Dateien, unverändertes Lesen,
verlustfreien Schemawechsel, Backup, idempotente Aktionen, exakte Revisionen,
Namensraumkollision, Varianten, Export/Import, Entfernen/Neuimport, gesperrten
Schreibabschluss, fremde Formate und einen echten Neustart. Der UI-Teil verwendet
die tatsächlichen Controls und Mausereignisse, kombiniert Filter/Suche, wechselt
DE/EN ohne Namens-/Kameraverlust und prüft zwölf Größen-/Skalierungskombinationen.

Direkte Verbraucher sind die bestehende Bibliothek, portabler Paketvertrag,
Editor-/Startmenü-Picker und Sprachkatalog. Die vollständige bisherige
`creature_library_ui_test`-Kette umfasst Undo/Redo, Speichern und den tatsächlichen
Start der Kugelkampagne mit gewählter Kreatur. Es gibt keine neue Testzuordnung
außer `creature_library_favorites_test` unter `blueprints`.

Gemeinsame Schreibstellen: bestehende Bibliothek und Picker, acht neue
`BP_*`-Sprachschlüssel, eine erweiterte Suchbeschreibung, PO-Dateien und ein
Testregistry-Eintrag. ARCH-24-Geometrie, Editorimplementierung, Wetter, Flotte,
Dorfwirtschaft und zentrale Statusseiten sind nicht Teil dieses Pakets.

[Exakte Quellstände, Abschlussbericht und ursprüngliche Befunde](evidence/community-library-favorites/README.md).
Native optische Abnahme und Windows-/Ziel-PC-Prüfung bleiben offen. Das Paket
liefert lokale Favoriten; Online-Veröffentlichung/Galerie bleiben eigene Folgearbeit.

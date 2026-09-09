# Forschungsziele und Teile-Merkliste · M4B

Stand: 9. September 2026. Erweiterung von [PR #19](https://github.com/MajorDragonfly/voxelverse/pull/19), auf dessen veröffentlichtem Stand `73583c0`. Lokal geprüfter Laufzeitcode: `325a55a`.

Lars hat Forschungsziele, ein angepinntes Ziel im Spiel und eine Merkliste für gewünschte Körperteile beauftragt. Diese Funktionen gehören zum bestehenden gemeinsamen Artenbuch. Die laufenden Arbeiten an Skilltree-Boni, Begleitern, Planeten, Kreatureneditor, Menüs und Audio werden nicht zusammengeführt.

## Bedienung

1. **J → Forschungsziele:** Ziel auswählen und **Im Spiel verfolgen** drücken. Fortschritt und Abschluss erscheinen im Buch und unten rechts im Spiel. Ein Klick auf das Ziel öffnet genau seinen Eintrag, wenn der Mauszeiger freigegeben ist.
2. **J → Körperteile → Noch gesperrt:** Teil auswählen und **Auf Merkliste setzen** drücken. Der Filter **Merkliste** zeigt die vorgemerkten Teile. Bis zu 32 Wunschteile sind möglich.
3. Ein vorgemerktes Teil kann ebenfalls **Im Spiel verfolgt** werden. Es ersetzt dann das bisher angepinnte Forschungsziel. Es gibt immer genau einen angepinnten Eintrag.
4. Sobald ein Teil tatsächlich freigeschaltet ist, zeigt seine Vormerkung **Sammelziel erreicht**. Erreichte Ziele bleiben sichtbar, bis du sie entfernst oder ein anderes Ziel auswählst. **Von Merkliste entfernen** entfernt auch einen zugehörigen Pin.
5. Ein- und Austragen wird unmittelbar mit dem gemeinsamen Spielstand gespeichert. Erfolg erscheint erst nach erfolgreichem Schreiben. Bei einem Fehler bleibt die vorherige Auswahl erhalten und kann erneut geändert werden.

Der Schalter für den kurzen Spielhinweis steuert weiterhin die Einstiegshilfe. Das selbst gewählte Forschungsziel bleibt davon unabhängig sichtbar. Esc bzw. der Zurück-Button schließen das Buch wie bisher.

## Die ersten fünf Ziele

| Ziel | Bedingung | Grundlage |
|---|---|---|
| Erste Begegnung | 1 Art entdecken | Gespeicherte Arteneinträge |
| Artenvielfalt | 3 verschiedene Arten entdecken | Unterschiedliche gespeicherte Artenschlüssel |
| Leben im Wasser | 1 Wasserart beobachten | Entdeckte Art mit ökologischer Rolle `swimmer` |
| Neue Horizonte | 3 Regionen erkunden | Unterschiedliche gespeicherte Regionsschlüssel |
| Feldforscher | 10 verschiedene Arten entdecken | Gespeicherte Arteneinträge der Kampagne |

Vorhandene Entdeckungen zählen sofort. Wiederholte Beobachtungen oder Regionsbesuche erhöhen den Fortschritt nicht erneut. Gleiche Koordinaten beziehungsweise Spezies-Seeds auf verschiedenen Welten bleiben entsprechend dem bestehenden Entdeckungsvertrag getrennt.

Die Ziele sind persönliche Orientierung und gewähren selbst keine Punkte oder Teile. Die normale Entdeckung belohnt weiterhin über `ProgressionService`. Eine Merkliste ändert nicht, welches Teil eine neue Art freischaltet; eine bekannte Art gibt durch erneutes Beobachten kein weiteres Teil. Unbekannte Tierstandorte und garantierte Teilquellen werden nicht erfunden.

## Datenvertrag und Integration

`core/discovery/research_goals.gd` definiert die Ziele und leitet ihren Fortschritt aus Arten, Regionen und vorhandenen Freischaltungen ab. Es gibt keine separat gespeicherten Fortschrittszähler oder Abschlussbelohnungen.

`ProgressionService` sichert ausschließlich die Auswahl unter dem optionalen Feld `progression.research`:

```json
{
  "version": 1,
  "pinned": "species.three",
  "wished_parts": ["example_part_id"]
}
```

`example_part_id` ist hier nur ein Platzhalter für eine ID aus dem Teilekatalog. Ein Teil-Pin hat die Form `part:<ID>` und muss zur Merkliste gehören. Ein leerer Pin bedeutet kein gewähltes Ziel.

- `get_research_settings()` gibt eine Kopie zurück; `get_pinned_research()` liefert den abgeleiteten Anzeigestand.
- `set_research_pin()` und `set_part_wished()` prüfen die Auswahl, sichern den ganzen Spielstand und setzen bei Schreibfehlern die Auswahl zurück. Käufe und Forschungsänderungen sind gegen gegenseitige Schreibwiedereintritte gesperrt.
- `research_changed` aktualisiert Oberfläche und HUD nach erfolgreicher Änderung, Import und Neustart. Entdeckungs- und Freischaltsignale aktualisieren den abgeleiteten Fortschritt.
- Ohne das optionale Feld starten alte Spielstände mit leerer Auswahl; ihre bisherigen Entdeckungen zählen trotzdem. Ein neuer Spielstand erbt weder Pin noch Merkliste.
- Fehlende alte Teil-IDs und nicht mehr verfügbare Ziel-IDs bleiben sichtbar und können bewusst entfernt werden. Allein das Öffnen eines solchen Eintrags verändert die Speicherung nicht.
- Falsch geformte Metadaten werden vor einem Import abgelehnt. Eine neuere Forschungsversion blockiert den alten Leser einschließlich Rückfall auf ältere Sicherungen und Überschreiben.

Bei der späteren Zusammenführung mit dem Verhaltens- oder Menübranch müssen das optionale Feld, Import/Export/Validierung, `has_unsupported_contract()` und die neue Signal-/API-Anbindung im vorhandenen Fortschrittsdienst erhalten bleiben. Die globalen Speicher- und Fortschrittsschemas werden durch dieses Paket nicht hochgesetzt. Ältere Branches ohne diese Erweiterung verwalten Pin und Merkliste noch nicht.

Die gemeinsame Buchinstanz bleibt beim Spieler-HUD. J, der Skilltree-Button und der angepinnte HUD-Eintrag nutzen dieselbe Oberfläche. Keine neuen Eingaben am Spielercontroller und keine Änderungen am Artengenerator, Teile-Renderer oder Verhalten sind nötig.

## Abnahme

`tests/research_goals_test.gd` benutzt den echten Spieler mit seiner installierten Buchoberfläche. Geprüft werden echte Button-Klicks, Ziele und laufender HUD-Fortschritt, Wiederbeobachtung, Regionszählung, Teilvormerkung, Teilfreischaltung, Speichern/Rücknahme/erneuter Versuch, getrennte Kampagnen, alte und nicht mehr verfügbare Einträge sowie zukünftige Speicherverträge. Ein zweiter Godot-Prozess lädt denselben Spielstand erneut.

Der Exporttest übergibt auch diesem zweiten Prozess die tatsächlich exportierte PCK. Beide Prozesse arbeiten außerhalb des Quellverzeichnisses; der Release-Start selbst bleibt unverändert.

Die gezielten Forschungs-, Journal-, Skilltree-, Verhaltens-, Kampagnen- und Meta-Prüfungen bestehen. Import und Art-Quellen sind geprüft. Der Linux-Release besteht 13 Prüfungen. Vier neue Compatibility-Aufnahmen (Forschungsziel, angepinnter HUD-Hinweis, Merkliste, kleine Auflösung) wurden visuell kontrolliert. Die bestehenden Journal-Ansichten werden ebenfalls erneut aufgenommen.

Aktuelle Nachweise: [validation/research-goals.json](../validation/research-goals.json). Der Workflow `journal-validate.yml` prüft Journal und Forschung mit Compatibility und Forward+. `validate_export.py` prüft Forschung einschließlich separatem Ladeprozess auch unter Windows.

Die GitHub-Prüfungen der neuen Erweiterung und der manuelle Ziel-PC-Spieltest werden im Draft-PR getrennt vom zuvor abgenommenen Grundstand geführt.

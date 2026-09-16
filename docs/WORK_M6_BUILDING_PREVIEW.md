# Stammesphase: Bauvorschau

Folgeauftrag des Spieltest-Chats zu PR #153, auf `f6425e9f162f7e1ba6703b33c36fe6d2084df17e`.

- Beim Wählen eines frei platzierbaren Gebäudes folgt ein halbtransparentes
  Modell dem Mauszeiger. Grün und „Bauplatz frei“ markieren einen gültigen Platz;
  Rot und ein Grund markieren eine blockierte Platzierung. Der Eingang ist sichtbar.
- Rechtsklick bestätigt, Escape bricht ab. Über Bedienelementen, während einer
  Pause und ohne geladenen Boden wird die Vorschau ausgeblendet.
- Hütte und Zelt verwenden dieselben Modelle wie fertige Gebäude. Alle acht
  frei platzierbaren Bauarten erhalten eine Vorschau. Die Ausrichtung folgt der
  lokalen Planetenoberfläche. Eine freie Gebäudedrehung ist kein Teil dieser Lieferung.
- Vorschau und tatsächlicher Auftrag prüfen denselben Bauplatz. Der Klick prüft
  erneut; Vorschauen reservieren weder Material noch IDs und werden nicht gespeichert.
  Meshes bleiben bei unveränderter Bauart erhalten; stationäre Prüfungen laufen
  höchstens etwa siebenmal pro Sekunde statt bei jedem Renderbild.
- Die Scrollhöhe wird auf ganze Pixel aufgerundet, damit die letzte Wirtschaftsaktion
  bei vergrößerter Schrift vollständig sichtbar bleibt.

Gezielte Prüfung: `tribal_building_preview_test` prüft echte Maus-/Tastatureingaben,
freie und belegte Plätze, Abbruch, Pause, fehlende Mittel/Auswahl, Speicherrücknahme,
Neuladen und genau einmalige Materialkosten. `tribal_building_preview_world_test`
prüft den öffentlichen Kugel-Spieltest-Einstieg, Kamerastrahl und Oberflächennormale.
Die bestehenden Wirtschaftsprüfungen sichern die Scrollkorrektur ab.

Der Workflow „Tribal building preview“ führt diese Prüfungen mit Godot 4.6.3 aus
und erzeugt anschließend native Screenshots mit `tools/review_tribal_placement.py`.
Ergebnisse und Bilder stehen im jeweiligen Workflow-Artefakt `tribal-placement-review`.
Diese ergänzende Prüfung ersetzt keines der vier Integrationsgates.

# Bestätigter Einstieg ins Stammeszeitalter

Dieser Arbeitszweig verbindet den fertigen Entwicklungsweg aus PR #23 mit dem veröffentlichten Nestgruppenpaket aus PR #20 (fest geprüfter Stand `6ca5e484ea93870d4aab62bb0dec746846d00d0a`). Er implementiert den ersten Dorfablauf. Die offenen Pakete für Wildtierfütterung, Editor, Planeten, Menüs, Forschung und Audio werden nicht vorausgesetzt oder kopiert.

## Spielen

1. In der normalen Welt mit **N** einen trockenen, freien Heimatplatz gründen. Die beiden eigenen Gefährten mit **Heimkehren** dort sammeln; selbst zum Nest zurückgehen.
2. **Stammeszeitalter …** oben rechts öffnen. Die Umgebung muss sichere Wege, drei Fundstellen und zwei vollständige Bauplätze bieten. Fehlt Platz, bleibt die Kreaturenphase aktiv und das Fenster erklärt den Grund.
3. **Jetzt ins Stammeszeitalter fortschreiten** bestätigen. **In der Kreaturenphase bleiben** oder Escape schließt das Fenster ohne Spielstandsänderung. Der Wechsel erfolgt niemals automatisch durch Punkte oder das Öffnen einer Ansicht.
4. Bewohner anklicken, mit Umschalt ergänzen oder einen Auswahlrahmen ziehen. Rechtsklick schickt ausgewählte Bewohner zu geladenem Boden oder einer Fundstelle. Die drei Bewohner sind die bisherige Spielerfigur und die beiden gespeicherten Gefährten.
5. **Holz sammeln**, **Stein sammeln**, **Nahrung sammeln** zuweisen. Bewohner laufen zur Fundstelle, arbeiten dort und tragen Material zum Dorfplatz. Erst die Lieferung erhöht das Lager. Einzelne Bewohner können gleichzeitig verschiedene Aufgaben erledigen.
6. Mit **3 Holz / 2 Stein** ein Steinwerkzeug herstellen. Mit dem Werkzeug kostet jede Hütte **6 Holz / 3 Stein**. Mehrere Bewohner können an derselben Arbeit teilnehmen. Materialien werden einmalig für den Auftrag reserviert. Wiederholtes Zuweisen belastet das Lager nicht erneut.
7. **Versorgen** schickt die ausgewählten Bewohner zum Lager. Eine Nahrung sättigt einen hungrigen Bewohner um 25 Punkte. Hunger verlangsamt Bewegung und Arbeit. Zwei Hütten geben vier Schlafplätze für die drei Bewohner.

**WASD** bewegt die Übersichtskamera, das Mausrad zoomt. **Leertaste** pausiert die Dorfwirtschaft. **K** öffnet weiterhin den Entwicklungsweg und die getrennten Fähigkeitenansichten. Eine Pause, die ein anderes Menü besitzt, wird nicht übernommen.

## Umfang dieses Einstiegs

- Drei dauerhaft identische Bewohner, gemeinsame oder individuelle Aufträge, echte Laufwege und Materialtransporte.
- Eine gemeinsame Werkbank, ein Steinwerkzeug und zwei sichtbare Hütten an geprüften Bauplätzen. Der erste Ausbau schafft vier Schlafplätze; Bevölkerungswachstum folgt später.
- Je 48 Einheiten Leseholz, lose Steine und essbare Wurzeln. Diese endlichen Dorfressourcen sind von den Beerenbüschen und Fütterungsdaten des Wildtier-Chats getrennt. Erneuerbare Versorgung folgt im nächsten Ausbau.
- Das gekaufte Koordinationsvermächtnis erhöht tatsächlich die Arbeitsgeschwindigkeit. Stammespunkte, neue kaufbare Stammesfähigkeiten, Verteidigungswirkung, Nachbarstämme und Gruppenkämpfe sind noch nicht freigeschaltet. Der zivile Dorfeinstieg unterbindet den alten Einzelkreaturen-Schaden, damit nicht ausschließlich die bisherige Spielerfigur angegriffen werden kann.
- Die Dorfsteuerung bleibt in der geladenen Umgebung des Heimatplatzes. Es gibt kein Teleportieren über fehlende Wege, tiefe Stufen oder Wasser. Die Umgebung wird mit echten Kollisionen geprüft; neue Hindernisse stoppen einen Bewohner.
- Die übrigen Epochen bleiben gesperrt. Auch ihr späterer Eintritt braucht einen eigenen spielbaren Ablauf und eine ausdrückliche Bestätigung.

## Dauerhafter Übergang und Integration

SaveGameService schreibt **Speicherschema 6**; alte Kampagnen bis Schema 5 werden ohne automatisch erzeugten Stamm übernommen. Das ursprüngliche Nestgruppenformat bleibt Schema 1. Das neue `campaign.bodies[integer_seed].tribe` ist Schema 1 und enthält Herkunft, dieselben drei Objekt-IDs, Positionen, Aufträge, getragene Materialien, Sättigung, endliche Fundstellen, Lager, reservierte Baustelle, Werkzeug, Hütten und Mahlzeiten.

Der bestätigte Wechsel ersetzt genau einen vollständigen Spielstand atomar: Phase, Stamm und abgeschlossener Übergang werden gemeinsam geschrieben. Erst danach erhalten Kamera und Steuerung den Wechsel. Schreibfehler rollen Kampagne und Phase zurück; ein Neustart sieht entweder den vorherigen Kreaturenstand oder den vollständigen Stamm. Die Bestätigung ist an die aktuelle Kampagne, Welt, Nestgruppe und Spielerfigur gebunden. Veraltete, doppelte und unbestätigte Aufrufe werden abgewiesen. Eine neuere Stammesversion blockiert Laden und Überschreiben auch dann, wenn eine ältere Sicherung vorhanden ist.

Die Heimatgruppe bleibt als Herkunft erhalten; ihr Controller erzeugt in Phase 1 keine Gefährten mehr. Die tatsächliche Spielerfigur bleibt einmalig im Szenenbaum und dient mit ihrer wirklichen Position weiterhin dem bestehenden Streaming und Speichersystem. Ihre Einzelsteuerung und HUDs ruhen während der Gruppensteuerung. Fähigkeiten, Kreaturenbeziehungen, Spezies, Körperentwurf und die getrennten Punktebestände werden nicht neu erzeugt.

Die Schnittstellen für andere Chats bleiben die öffentlichen Körper-/Designreferenzen, Kampagnenereignisse und Körper-Erweiterungen. Eine spätere Integration des Menü-/Speicherpakets muss gezielt die Schema-6-Prüfung und den bestätigten atomaren Übergang übernehmen. Die Wildtierfütterung kann unabhängig fertiggestellt werden.

## Nächste Ausbauschritte

1. **Tragfähiges Dorf:** weitere Materialquellen erschließen, erneuerbare Nahrung und Wasser, Lagergrenzen, eigenständige Versorgungsaufträge und wiederaufnehmbare Wege um neue Hindernisse. Erst danach Bevölkerungswachstum und zusätzliche frei platzierbare Gebäude.
2. **Berufe und Stammesentwicklung:** Sammler, Handwerker und Baumeister, zugewiesene Werkzeuge, abgeschlossene Gemeinschaftsaufgaben als nachvollziehbare Stammespunkte. Eigener sozialer und aggressiver Baum; Kreaturenpunkte bleiben im bisherigen Baum.
3. **Nachbarstämme und Verteidigung:** gleichwertig adressierbare Gruppenmitglieder, Beziehungen, Hilfe/Handel und begrenzte Konflikte. Erst mit wirklichem Gruppenkampf wird das Verteidigungsvermächtnis wirksam.
4. **Antike/Mittelalter vorbereiten:** Landwirtschaft, beständige Versorgung, spezialisierte Produktion und Siedlungsverwaltung. Für den späteren bestätigten Wechsel zählen diese tatsächlich gespielten Grundlagen; keine automatische Umschaltung durch einen einzelnen Punktestand.

## Prüfung

`tribal_age_test.gd` bedient das echte Bestätigungsfenster und die Auftragsbuttons, prüft Abbruch, Schreibfehler, ungültige Bestätigungen, Übernahme derselben Bewohner, Weltklicks, Transport samt Laden, Werkzeug, zwei Hütten, Versorgung, Menüpause, neuere Formate und neue Kampagnen. `tribal_age_world_test.gd` stellt dieselbe Übergabe, echte Lieferungen, Laden und einen Kaltstart in einem zweiten Prozess in `main/main.tscn` auf erzeugtem Gelände sicher.

Der bestehende Heimatplatztest wartet auf Bodenkontakt und fertig geladene Umgebung statt auf eine feste Zahl von Renderframes. Die Dorfwegeprüfung setzt Kapseln auf die tatsächliche Höhe von Voxelstufen, damit der Mittelwert zweier Stufen keine falsche Kollision verursacht. Die ursprüngliche Spielerfigur übernimmt ihren tatsächlichen Sättigungswert; ein Kaltstart setzt auch das sichtbare Nest an den gespeicherten Ort. Die Exportprüfung enthält beide neuen Tests und den Neustart in einem zweiten Prozess; der GUI-Workflow erzeugt Bilder des bestätigten Wechsels, der Gruppe, der Lieferung, des Werkzeugs, des Dorfes und des normalen Geländes.

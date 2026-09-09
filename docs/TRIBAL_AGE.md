# Bestätigter Einstieg ins Stammeszeitalter

Dieser Arbeitszweig verbindet den fertigen Entwicklungsweg aus PR #23 mit dem veröffentlichten Nestgruppenpaket aus PR #20 (fest geprüfter Stand `6ca5e484ea93870d4aab62bb0dec746846d00d0a`). Er implementiert den ersten Dorfablauf. Die offenen Pakete für Wildtierfütterung, Editor, Planeten, Menüs, Forschung und Audio werden nicht vorausgesetzt oder kopiert.

## Spielen

1. In der normalen Welt mit **N** einen trockenen, freien Heimatplatz gründen. Die beiden eigenen Gefährten mit **Heimkehren** dort sammeln; selbst zum Nest zurückgehen.
2. **Stammeszeitalter …** oben rechts öffnen. Die Umgebung muss sichere Wege, drei Fundstellen und zwei vollständige Bauplätze bieten. Fehlt Platz, bleibt die Kreaturenphase aktiv und das Fenster erklärt den Grund.
3. **Jetzt ins Stammeszeitalter fortschreiten** bestätigen. **In der Kreaturenphase bleiben** oder Escape schließt das Fenster ohne Spielstandsänderung. Der Wechsel erfolgt niemals automatisch durch Punkte oder das Öffnen einer Ansicht.
4. Bewohner anklicken, mit Umschalt ergänzen oder einen Auswahlrahmen ziehen. Rechtsklick schickt ausgewählte Bewohner zu geladenem Boden oder einer Fundstelle. Die drei Bewohner sind die bisherige Spielerfigur und die beiden gespeicherten Gefährten.
5. **Holz sammeln**, **Stein sammeln**, **Nahrung sammeln** zuweisen. Bewohner laufen zur Fundstelle, arbeiten dort und tragen Material zum Dorfplatz. Erst die Lieferung erhöht das Lager. Einzelne Bewohner können gleichzeitig verschiedene Aufgaben erledigen.
6. Mit **3 Holz / 2 Stein** ein Steinwerkzeug herstellen. Mit dem Werkzeug kostet jede Hütte **6 Holz / 3 Stein**. Mehrere Bewohner können an derselben Arbeit teilnehmen. Materialien werden einmalig für den Auftrag reserviert. Wiederholtes Zuweisen belastet das Lager nicht erneut.
7. **Jetzt essen** schickt die ausgewählten Bewohner zum Lager. Eine Nahrung sättigt einen hungrigen Bewohner um 25 Punkte. Hunger verlangsamt Bewegung und Arbeit. Zwei Hütten geben vier Schlafplätze für die drei Bewohner.
8. **Wurzelgarten · 4 Holz / 1 Stein** baut mit dem Steinwerkzeug die vorhandene Wurzelfundstelle aus. Nach 15 Arbeitssekunden ist der Garten fertig. Solange weniger als acht Wurzeln bereitliegen, wächst alle 20 Spielsekunden eine nach. Die Ernte muss weiterhin gesammelt und zum Lager getragen werden. Vorhandene wilde Wurzeln bleiben erhalten.
9. **Versorgung sichern** ist ein Dauerauftrag: Ausgewählte Bewohner ernten Nahrung, bis zwölf Portionen eingelagert oder unterwegs sind. Anschließend warten sie am Dorfplatz und nehmen ihren Auftrag nach Verbrauch selbstständig wieder auf. Mehrere Sammler teilen sich dasselbe Ziel; getragene Nahrung zählt bereits dazu.
10. Arbeitende Bewohner unter 40 % Sättigung gehen selbstständig essen, sofern Nahrung im Lager liegt. Sie liefern getragenes Material vorher ab und setzen danach ihren ursprünglichen Auftrag fort. **Anhalten** stoppt auch diese Eigeninitiative; getragene Vorräte bleiben erhalten. Alle Aufträge einschließlich einer begonnenen Essenspause werden gespeichert.

**WASD** bewegt die Übersichtskamera, das Mausrad zoomt. **Leertaste** pausiert die Dorfwirtschaft. **K** öffnet weiterhin den Entwicklungsweg und die getrennten Fähigkeitenansichten. Eine Pause, die ein anderes Menü besitzt, wird nicht übernommen.

## Umfang dieses Einstiegs

- Drei dauerhaft identische Bewohner, gemeinsame oder individuelle Aufträge, echte Laufwege und Materialtransporte.
- Eine gemeinsame Werkbank, ein Steinwerkzeug und zwei sichtbare Hütten an geprüften Bauplätzen. Der erste Ausbau schafft vier Schlafplätze; Bevölkerungswachstum folgt später.
- Zu Beginn je 48 Einheiten Leseholz, lose Steine und essbare Wurzeln. Holz und Stein bleiben endlich. Der gebaute Wurzelgarten erneuert Nahrung. Die Dorfressourcen sind von den Beerenbüschen und Fütterungsdaten des Wildtier-Chats getrennt.
- Das Lager fasst je 48 Holz, Stein und Nahrung. Getragene Materialien reservieren ihren Lagerplatz. Sammler warten bei vollem Lager und behalten ihren Auftrag. Der Versorgungsauftrag hält gezielt zwölf Portionen bereit.
- Der Wurzelgarten ist eine erste kultivierte Sammelstelle. Wasserwirtschaft, Landwirtschaft, individuelle Werkzeuge und weitere Berufe folgen später. Wachstum verwendet ausschließlich laufende Simulationszeit: Pause, Laden und Zeit außerhalb des Spiels erzeugen keine zusätzliche Ernte; volle Gärten sammeln keinen Wachstumsvorrat an.
- Das gekaufte Koordinationsvermächtnis erhöht tatsächlich die Arbeitsgeschwindigkeit. Stammespunkte, neue kaufbare Stammesfähigkeiten, Verteidigungswirkung, Nachbarstämme und Gruppenkämpfe sind noch nicht freigeschaltet. Der zivile Dorfeinstieg unterbindet den alten Einzelkreaturen-Schaden, damit nicht ausschließlich die bisherige Spielerfigur angegriffen werden kann.
- Die Dorfsteuerung bleibt in der geladenen Umgebung des Heimatplatzes. Es gibt kein Teleportieren über fehlende Wege, tiefe Stufen oder Wasser. Die Umgebung wird mit echten Kollisionen geprüft; neue Hindernisse stoppen einen Bewohner.
- Die übrigen Epochen bleiben gesperrt. Auch ihr späterer Eintritt braucht einen eigenen spielbaren Ablauf und eine ausdrückliche Bestätigung.

## Dauerhafter Übergang und Integration

SaveGameService schreibt **Speicherschema 6**; alte Kampagnen bis Schema 5 werden ohne automatisch erzeugten Stamm übernommen. Das ursprüngliche Nestgruppenformat bleibt Schema 1. `campaign.bodies[integer_seed].tribe` ist jetzt **Schema 2**: Herkunft, dieselben drei Objekt-IDs, Positionen, Aufträge, getragene Materialien, Sättigung, Fundstellen, Lager, reservierte Baustelle, Werkzeug, Hütten und Mahlzeiten sowie `garden`, `growth` und `grown`. `stage = meal` hält eine Essenspause fest, während `order` den ursprünglichen Auftrag behält. Dorfstände aus Schema 1 werden nach erfolgreicher Prüfung im Speicher ergänzt; Bewohner, Vorräte und Bauarbeiten bleiben erhalten, ein Garten wird nicht kostenlos erzeugt. Die alte Datei bleibt bis zum nächsten erfolgreichen atomaren Speichern erhalten.

Der bestätigte Wechsel ersetzt genau einen vollständigen Spielstand atomar: Phase, Stamm und abgeschlossener Übergang werden gemeinsam geschrieben. Erst danach erhalten Kamera und Steuerung den Wechsel. Schreibfehler rollen Kampagne und Phase zurück; ein Neustart sieht entweder den vorherigen Kreaturenstand oder den vollständigen Stamm. Die Bestätigung ist an die aktuelle Kampagne, Welt, Nestgruppe und Spielerfigur gebunden. Veraltete, doppelte und unbestätigte Aufrufe werden abgewiesen. Eine neuere Stammesversion blockiert Laden und Überschreiben auch dann, wenn eine ältere Sicherung vorhanden ist.

Die Heimatgruppe bleibt als Herkunft erhalten; ihr Controller erzeugt in Phase 1 keine Gefährten mehr. Die tatsächliche Spielerfigur bleibt einmalig im Szenenbaum und dient mit ihrer wirklichen Position weiterhin dem bestehenden Streaming und Speichersystem. Ihre Einzelsteuerung und HUDs ruhen während der Gruppensteuerung. Fähigkeiten, Kreaturenbeziehungen, Spezies, Körperentwurf und die getrennten Punktebestände werden nicht neu erzeugt.

Die Schnittstellen für andere Chats bleiben die öffentlichen Körper-/Designreferenzen, Kampagnenereignisse und Körper-Erweiterungen. Eine spätere Integration des Menü-/Speicherpakets muss gezielt die Schema-6-Prüfung und den bestätigten atomaren Übergang übernehmen. Die Wildtierfütterung kann unabhängig fertiggestellt werden.

## Nächste Ausbauschritte

1. **Tragfähiges Dorf:** erneuerbare Nahrung, Lagergrenzen und eigenständige Versorgungsaufträge sind umgesetzt. Als Nächstes weitere Materialquellen erschließen, Wasser und wiederaufnehmbare Wege um neue Hindernisse. Erst danach Bevölkerungswachstum und zusätzliche frei platzierbare Gebäude.
2. **Berufe und Stammesentwicklung:** Sammler, Handwerker und Baumeister, zugewiesene Werkzeuge, abgeschlossene Gemeinschaftsaufgaben als nachvollziehbare Stammespunkte. Eigener sozialer und aggressiver Baum; Kreaturenpunkte bleiben im bisherigen Baum.
3. **Nachbarstämme und Verteidigung:** gleichwertig adressierbare Gruppenmitglieder, Beziehungen, Hilfe/Handel und begrenzte Konflikte. Erst mit wirklichem Gruppenkampf wird das Verteidigungsvermächtnis wirksam.
4. **Antike/Mittelalter vorbereiten:** Landwirtschaft, beständige Versorgung, spezialisierte Produktion und Siedlungsverwaltung. Für den späteren bestätigten Wechsel zählen diese tatsächlich gespielten Grundlagen; keine automatische Umschaltung durch einen einzelnen Punktestand.

## Prüfung

`tribal_age_test.gd` bedient das echte Bestätigungsfenster und die Auftragsbuttons, prüft Abbruch, Schreibfehler, ungültige Bestätigungen, Übernahme derselben Bewohner, Weltklicks, Transport samt Laden, Werkzeug, zwei Hütten, Versorgung, Menüpause, neuere Formate und neue Kampagnen. `tribal_age_world_test.gd` stellt dieselbe Übergabe, echte Lieferungen, Laden und einen Kaltstart in einem zweiten Prozess in `main/main.tscn` auf erzeugtem Gelände sicher.

`tribal_age_supply_test.gd` lädt einen bestehenden Schema-1-Dorfstand, baut über echte Mausbefehle einen Garten, setzt eine gespeicherte Baustelle fort und beobachtet Wachstum, Ernte, Transport und die gemeinsame Vorratsgrenze. Ein hungriger Steinträger liefert zuerst ab, isst und kehrt zur Arbeit zurück. Eine weitere Essenspause wird unterwegs gespeichert und geladen; Versorgung ersetzt die verbrauchten Portionen selbstständig. Der Test prüft außerdem Pause, Anhalten, volle Gärten, Lagerreservierungen und die Bedienbarkeit im schmalen Fenster. Dieselbe Prüfung läuft grafisch und gegen die exportierten Windows-/Linux-Pakete.

Der bestehende Heimatplatztest wartet auf Bodenkontakt und fertig geladene Umgebung statt auf eine feste Zahl von Renderframes. Die Dorfwegeprüfung setzt Kapseln auf die tatsächliche Höhe von Voxelstufen, damit der Mittelwert zweier Stufen keine falsche Kollision verursacht. Die ursprüngliche Spielerfigur übernimmt ihren tatsächlichen Sättigungswert; ein Kaltstart setzt auch das sichtbare Nest an den gespeicherten Ort. Die Exportprüfung enthält beide neuen Tests und den Neustart in einem zweiten Prozess; der GUI-Workflow erzeugt Bilder des bestätigten Wechsels, der Gruppe, der Lieferung, des Werkzeugs, des Dorfes und des normalen Geländes.

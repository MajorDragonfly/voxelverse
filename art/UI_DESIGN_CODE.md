# Voxelverse · Designcode Expedition

Verbindliche Gestaltungsgrundlage für bestehende und neue Oberflächen. Die
Spielwelt bleibt das Hauptbild: Die UI hilft beim Entdecken, Entscheiden und
Gestalten. Sie verbindet die Kreaturenphase mit Stamm, Zivilisation und Raumfahrt.

## Eigenständige Richtung

Ein Expeditionsbuch aus dunklem Stein, hellem Papier und sparsamem Messing.
Präzise Konturen, kantige Silhouetten und echte Modellvorschauen passen zur
Voxelwelt. Keine künstlich gealterten Papiertexturen, Neonrahmen, dekorativen
Fortschrittswerte oder austauschbaren Karten für jeden Absatz.

Referenzen liefern Bedienprinzipien, keine kopierten Grafiken:

- **Anno:** Ressourcen sind durch beständige Symbole erkennbar; Handlung,
  Auswahl und Details haben verschiedene Gewichte. Die UI gehört zur Welt.
- **No Man’s Sky:** Entdeckung, Katalog und Inventar verbinden visuelle Objekte
  mit gezielt abrufbaren Details. Neue Informationen sind leicht auffindbar.
- **Spore:** Kreatur, Entwicklung und Epochen werden bildlich vermittelt. Die
  eigene Spezies bleibt der Mittelpunkt; unerforschte Inhalte bleiben verborgen.

Primäre Referenzen: [Anno UI-Entwicklung](https://www.anno-union.com/de/devblog-das-user-interface-team-und-ein-tiefer-einblick-ins-visuelle-design/)
und [No Man’s Sky Waypoint](https://www.nomanssky.com/waypoint-update/).
Dies sind Gestaltungsreferenzen, keine Behauptung identischer Spielsysteme.

## Gemeinsame Tokens

Implementierung: `ui/design/design_system.gd`. Die vorhandenen
`MenuStyle`-/`ProgressionStyle`-Schnittstellen verwenden diese Quelle.

| Rolle | Farbe | Einsatz |
|---|---|---|
| Ink | `#181e1b` | Hintergrund, tiefste Ebene |
| Panel | `#252c26` | Lesefläche, Dialog |
| Text | `#eee7d7` | Inhalt und aktive Beschriftung |
| Muted | `#a6b0a0` | Ergänzungen, Metadaten |
| Accent | `#cfad6c` | Auswahl, Hauptaktion, Tastaturfokus |
| Social | `#75b29a` | positive soziale Rückmeldung |

Gefahr, Wasser und Nahrung behalten fachliche Signalfarben. Kritische Zustände
brauchen zusätzlich Symbol, Wort oder Zahl. Farbe allein genügt nicht.
Der Basistext hat auf Panel über 4,5:1 Kontrast; Flächenkontrast ersetzt keinen
Fokusrahmen. Der Fokus muss auch auf einer primären Messingfläche sichtbar sein.

- Abstände folgen möglichst 4/8/12/16/24/32 px; bestehende geprüfte HUD-Bänder
  und Schriftskalierung haben Vorrang vor dekorativen Änderungen.
- Kanten bleiben zurückhaltend: 1 px Kontur, kleine Radien, kein Leuchtschein.
- Titel, Handlung, Inhalt und Metadaten haben verschiedene Schriftgewichte und
  Größen. Großbuchstaben nur für kurze Kapitelmarken, nicht für Absätze.
- Hauptaktion: gefüllter Akzent. Normale Handlung: dunkle Fläche. Navigation:
  ruhigere Fläche. Gefahr ist nie die optisch bevorzugte Standardhandlung.
- Normal, Hover, gedrückt, deaktiviert und Tastaturfokus sind jeweils definiert.
  Popup, Auswahl, Eingabe, Schieberegler und Scrollbar gehören zum selben System.

## Symbole und kleine Bilder

`ui/design/game_symbols.gd` enthält die gemeinsame, gecachte SVG-Symbolfamilie.
Jede Fachbedeutung bekommt eine erkennbare Silhouette; gleichbedeutende Begriffe
dürfen einen dokumentierten Alias verwenden. Neue Symbole müssen bei 20–24 px
unterscheidbar sein. Keine Emoji-/Fontabhängigkeit und keine unbeschrifteten
Rätselbuttons. Die Symbolwahl erfolgt über stabile IDs, niemals über übersetzte
Textteile. `Symbols.apply(button, id, extent)` erhält Beschriftung und Aktion.

- Holz, Stein, Nahrung und Wasser verwenden überall dieselben Motive.
- Karte, Buch, Spezies, Bauen, Werkzeuge, Speichern und Einstellungen bilden
  eine wiederkehrende Navigation.
- Epochen haben eigene Bildzeichen; Auswahl und Sperre sind zusätzliche Zustände.
- Echte Kreaturen-, Bauteil- und Gebäudevorschauen verwenden vorhandene, validierte
  Daten. Eine ausgewählte Vorschau wird wiederverwendet statt eine 3D-Szene pro
  Listenzeile anzulegen. Unentdeckte/gesperrte Inhalte zeigen keine geheimen Werte.
- Fremde Onlineeinträge erhalten erst nach geprüfter Übernahme eine echte
  Modellvorschau. Metadaten werden nicht als tatsächliches Modell ausgegeben.

## Bedienregeln je Oberfläche

| Oberfläche | Informations- und Bedienhierarchie |
|---|---|
| Hauptmenü | Fortsetzen und letzter echter Spielstand zuerst; neues Spiel/Saves danach; Einstellungen/Hilfe danach; Entwicklungseinstiege nachgeordnet |
| Spielstände | Name und Fortschritt zuerst; Datum/Ort als Metadaten; Details auf Anfrage; Kopieren/Löschen deutlich getrennt |
| Spiel-HUD | Spielwelt frei halten; kompakte Vitalwerte und kontextuelle Handlungen; Warnung und aktuelle Aktion erkennbar |
| Entdeckungen | Kategorie → Objektliste → tatsächliche Vorschau → Werte/Vergleich; Filter bleiben sichtbar |
| Entwicklungsbuch | Epochenpfad und aktueller Schritt zuerst; Freischaltung/Voraussetzung/Handlung darunter; Sperren sichtbar |
| Dorf | Ressourcenleiste; Auswahl/Bewohner; symbolisierte Aufträge, Arbeit und Bau; Details bei Auswahl |
| Bibliothek/Galerie | Suche/Filter, Auswahl, echte Vorschau, Import/Export; Quellen- und Prüfstatus erkennbar |
| Editoren | Eigener Entwurf im Zentrum; Werkzeugfamilien an den Rändern; Modelländerung, Rückgängig und Speichern leicht erreichbar |
| Einstellungen | Fachreiter; zusammengehörige Regler; Wert direkt am Regler; Übernehmen und Zurück bleiben erreichbar |
| Technik/Werft | Aktuelle Auswahl, echte Anforderungen, Vorschau und konkrete nächste Handlung |
| Karten/Wetter/Ausrüstung | Dieselben Tokens und Symbol-IDs; Fachlogik und zusätzliche Layoutänderungen mit dem jeweiligen Besitzer integrieren |

## Verantwortung und Erweiterung

Ein neues UI-Modul beginnt mit `Design.theme()` oder einem bestehenden
Style-Adapter. CanvasLayer-Kinder erben den gemeinsamen Window-Theme; ein eigener
Theme darf nur begründet erweitert werden. Theme-Instanzen bleiben unabhängig,
damit eine responsive Vorschau nicht andere Menüs verändert. Alte explizite
Flächenfarben werden im Style-Adapter nur aus einer benannten Farbzuordnung
übersetzt; fachliche Signal-/Modellfarben bleiben erhalten.

Vorhandene stabile IDs, Aktionsnamen, Lokalisierung, Saveports und Eingaben werden
beibehalten. Laufende Fachbesitzer behalten ihre Dateien. Für gemeinsame
Anschlüsse gilt die serielle Integration in Issue #137. Dieser Designcode ist
keine zweite Belegungsliste und ersetzt keine Fach- oder Ziel-PC-Abnahme.

## Sicht- und Bedienabnahme

Zu prüfen sind vollständige Ansichten bei 1280×720 und 1920×1080, zusätzlich die
vorhandenen kleinen Layoutfälle, UI-Skalierung und Deutsch/Englisch. Keine
abgeschnittene Hauptaktion, überdeckte Werte oder horizontale Textwände.
Tastaturfokus, Tab/Enter, Escape, Popup-Auswahl, Scrollen und bestehende
Schließen-/Pauseverträge müssen funktionieren. Bilder werden aus dem echten UI
aufgenommen; Entwürfe und Software-Rendererbilder sind keine Ziel-PC-FPS-Abnahme.

Weltgestaltung folgt weiterhin `art/STYLE_GUIDE.md`: lesbare organische Großformen,
kontrollierte Biome und Materialien sowie erkennbare Assets. Eine neue UI allein
beweist keine überarbeitete Landschaft, Animation oder Audioqualität.

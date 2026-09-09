# Voxelverse – verbindliche Designvorgabe

**Version 1.0 · 9. September 2026**  
**Geltung:** Alle neuen und überarbeiteten sichtbaren Spielelemente, insbesondere Entdeckungsbuch, Entwicklungsbuch, Skills, HUD, Menüs, Editoren und spätere Verwaltungsansichten.  
**Leitgedanke:** Eine lebendige Voxelwelt mit einer ruhigen, klaren Oberfläche. Gleiche Informationen sehen überall gleich aus und lassen sich überall gleich bedienen.

Diese Datei beschreibt die verbindliche **Sollgestaltung** im Auftrag von Lars. Sie dokumentiert keine bereits erfolgte Umgestaltung des Spiels. Die bestehenden Farben, Stat-Symbole und Datenanschlüsse werden als Grundlage verwendet. Neue Festlegungen und noch fehlende Bausteine sind unten erkennbar getrennt.

## 1. Die zehn Grundregeln

1. **Übersicht vor Dekoration.** Jede Ansicht beantwortet zuerst: Was sehe ich? Was ist wichtig? Was kann ich als Nächstes tun?
2. **Eine gemeinsame Gestaltung.** Schrift, Abstände, Farben, Schaltflächen, Karten und Zustände stammen aus gemeinsamen Definitionen.
3. **Eine Bedeutung, ein Symbol.** Ein Stat behält in Buch, Scanansicht, Editor, HUD und Tooltip dasselbe Symbol, denselben Namen und dieselbe Formatierung. Ein anderes Symbol wird nicht gewählt, nur weil es dort schöner aussieht.
4. **Symbole unterstützen verständliche Beschriftungen.** In Büchern und Detailansichten steht neben jedem Stat-Symbol sein Name. Kompakte Anzeigen folgen den ausdrücklich beschriebenen Ausnahmen.
5. **Das Wichtigste zuerst.** Übersichten zeigen wenige entscheidende Angaben. Zusätzliche Informationen sind gezielt erreichbar und werden nicht in jede Karte gepackt.
6. **Echte Vorschauen.** Kreaturen und Körperteile werden mit ihrer tatsächlichen Voxelgestalt dargestellt. Gesperrte Katalogeinträge verwenden eine Silhouette, freigeschaltete Einträge die vollständige Vorschau.
7. **Status bleibt eindeutig.** Unbekannt, entdeckt, gesperrt, freischaltbar, freigeschaltet und ausgewählt sind unterschiedliche Zustände.
8. **Die Welt bleibt sichtbar.** Das normale HUD ist kompakt. Informationsfenster erscheinen passend zur Handlung; dauerhafte Tiernamen außerhalb des Scanmodus entfallen.
9. **Die Gestaltung bleibt über alle Spielphasen vertraut.** Neue Funktionen erweitern die vorhandene Oberfläche. Die Stammes-, Mittelalter- oder Weltraumphase erhält kein unabhängiges Bedienkonzept.
10. **Gemeinsam erweitern.** Fehlende Symbole oder Bausteine werden einmal zentral ergänzt. Kein Chat legt eine eigene Variante eines bereits vorhandenen Elements an.

## 2. Visuelle Identität

Voxelverse wirkt ruhig, erkundungsorientiert und hochwertig. Die Welt liefert Farbe, Formen und Persönlichkeit; die Oberfläche ordnet Informationen.

- Dunkle, leicht petrolfarbene Flächen bilden einen stabilen Hintergrund.
- Helle, leicht warme Schrift sorgt für gute Lesbarkeit.
- Ein zurückhaltendes Hellgrün kennzeichnet Auswahl und Hauptaktionen.
- Kleine kantige Piktogramme und sparsame abgeschrägte Details stellen die Verbindung zur Voxelwelt her.
- Panels bleiben flächig, mit dünnen Rändern und kleinen Eckenradien. Keine großflächigen Glanzeffekte, Glasflächen, schweren Holzrahmen oder dekorativen Pergamentseiten.
- Ein „Buch“ ist eine verständliche Sammlung mit Navigation und Einträgen. Eine echte Buchfalz, umblätternde Seiten oder ein lederner Rahmen sind dafür nicht erforderlich.
- Keine Emoji als Produktionssymbole, keine Mischung aus Pixel-, Comic-, Fotografie- und dünnen Linien-Iconsets.
- Die 3D-Welt bleibt organisch aufgebaut und fein voxelartig. Schrift und Bedienflächen müssen dafür nicht pixelig oder grob werden.

Die bestehende Weltgestaltung in `art/STYLE_GUIDE.md` bleibt maßgeblich für Gelände, Vegetation, Materialien und Detailstufen. Diese Vorgabe ergänzt sie um die gemeinsame Oberfläche und deren Übergang zur Spielwelt.

## 3. Gemeinsame Farben

### 3.1 Oberflächenpalette

Die Basis stammt aus dem vorhandenen Hauptmenü. Diese Werte sind die Zielwerte für alle Ansichten. Farben werden über die folgenden semantischen Namen bezogen, nicht pro Fenster neu eingetragen.

| Token | Hexwert | Verwendung |
| --- | --- | --- |
| `surface.background` | `#081820` | Fensterhintergrund, tiefste Ebene |
| `surface.panel` | `#102831` | Hauptflächen und Karten |
| `surface.hover` | `#20444C` | Hover und hervorgehobene Unterflächen |
| `surface.pressed` | `#345747` | Gedrückte dunkle Buttons |
| `surface.disabled` | `#122229` | Nicht ausführbare Bedienelemente |
| `border.subtle` | `#31525A` | Dekorative Trenner und Panelränder |
| `border.control` | `#789394` | Erkennbare Grenzen von Eingaben und sekundären Buttons |
| `text.primary` | `#EDF1DF` | Überschriften, Werte, aktive Texte |
| `text.secondary` | `#A5B9B7` | Hinweise und ergänzende Angaben |
| `text.disabled` | `#657C7D` | Ausschließlich nicht verfügbare Aktionen |
| `accent.primary` | `#C6DF91` | Auswahl, Fokus, Hauptaktion |
| `status.success` | `#94CBB8` | Erfolg oder günstige Veränderung |
| `status.warning` | `#E2C99D` | Handlungsbedarf oder fehlende Voraussetzung |
| `status.danger` | `#EE9AA6` | Gefahr, Fehler oder ungünstige Veränderung |
| `progress.social` | `#80CBB2` | Sozialpunkte und sozialer Entwicklungspfad |
| `progress.aggression` | `#E8AE7D` | Aggressionspunkte und aggressiver Entwicklungspfad |
| `progress.tribe` | `#B8C2F1` | Stammespunkte, sobald verwendet |
| `progress.discovery` | `#C6DF91` | Entdeckungspunkte, sofern als eigene Währung vorhanden |

`border.control` sowie die Zuordnung für Stammespunkte sind neue Festlegungen. Bestehende Stat-Symbole behalten ihre eigenen festgelegten Motivfarben; sie werden nicht pauschal mit `accent.primary` eingefärbt.

### 3.2 Anwendung

- Pro Karte höchstens eine dominante Hervorhebungsfarbe. Stat-Symbole bleiben klein; ihre Farben rechtfertigen keine bunt gefüllten Stat-Karten.
- Primäre Buttons: `accent.primary` als Fläche und `surface.background` als Text; diese lesbare Kombination bleibt auch bei Hover und Druck bestehen, Rückmeldung erfolgt über Rand beziehungsweise einen dezenten Innenversatz. Sekundäre Buttons: dunkle Fläche, heller Text, erkennbarer Rand; deren Fläche nutzt die Hover-/Pressed-Tokens.
- Auswahl und Tastaturfokus haben einen 2 Einheiten starken Akzentrand. Eine Auswahl erhält zusätzlich einen Marker oder eine eindeutige Beschriftung.
- Eine Warnung wird durch Symbol und Text erklärt. Farbe allein übermittelt keine Information.
- Text erhält keine Transparenz. Transparenz ist nur bei Hintergrundflächen erlaubt.
- Buch- und Menüflächen sind deckend. Kompakte HUD-Flächen verwenden zunächst 94 % Deckkraft; bei ungenügender Lesbarkeit werden sie deckend.
- Eigene Prüfvorgabe: normaler Text mindestens 4,5:1 Kontrast zum tatsächlichen Hintergrund; bedienrelevante Konturen und Symbole mindestens 3:1. Dekorative Trenner dürfen zurückhaltender sein.
- Deaktivierte Texte dürfen gedämpft sein; der erklärende Sperrgrund bleibt mit `text.secondary` normal lesbar.

## 4. Schrift und Sprache

### 4.1 Schriftfamilie

**Zielschrift: Noto Sans**, zentral gebündelt mit Regular 400, Semibold 600 und Bold 700. Alle Spielelemente verwenden dieselben Font-Ressourcen. Dateibündelung und Lizenzdatei gehören zum gemeinsamen UI-Paket.

Diese Schriftfestlegung ist neu; sie wird mit der gemeinsamen Theme-Umstellung eingeführt. Solange das Schriftpaket fehlt, verwenden die betroffenen Ansichten dieselbe zentrale Godot-Standardschrift als dokumentierten Übergang. Einzelne Chats dürfen keine eigene Ersatzschrift pro Fenster einführen.

- Fließtext und Erläuterungen: Regular.
- Navigation, Buttons und Zahlen: Semibold.
- Große Überschriften: Bold.
- Keine Pixel- oder Zierschrift für Stat-Werte, Menüs oder Beschreibungstexte.
- Die Voxelverse-Wortmarke darf eine eigene Gestaltung haben. Daraus entsteht keine zweite Textschrift für das Spiel.
- Ziffern in Spalten verwenden gleich breite Zahlzeichen, soweit die gebündelte Font-Ressource das unterstützt. Ansonsten wird die Spaltenbreite fest reserviert.

### 4.2 Größen

Alle Größen in dieser Vorgabe sind logische UI-Einheiten bei der bestehenden Referenzfläche **1920 × 1080** und UI-Skalierung 100 %.

| Rolle | Größe | Gewicht | Beispiel |
| --- | --- | --- | --- |
| Großer Menütitel | 40 | Bold | Hauptmenü-Abschnitt |
| Fenstertitel | 32 | Bold | Entdeckungsbuch |
| Bereichstitel | 24 | Semibold | Körperbauwerte |
| Reiter / Eintragstitel | 22 | Semibold | Arten; Name eines Körperteils |
| Standardtext / Button / Stat | 20 | Regular / Semibold | Angriff; Freischalten |
| Kompakter Text | 18 | Regular | Herkunft, Kostenhinweis, HUD-Zahl |
| Kurzer Zusatz | 16 | Regular | Versionshinweis, unkritische Metadaten |

- Entscheidungsrelevante Informationen niemals in der kleinsten Stufe verstecken.
- Zeilenhöhe für mehrzeiligen Text: ungefähr 1,35 bis 1,45 der Schriftgröße.
- Beschreibungen möglichst 45–75 Zeichen pro Zeile. Sehr breite Textblöcke werden begrenzt.
- Links ausgerichtete Texte und rechts ausgerichtete Zahlen. Zentrierung nur für kurze leere Zustände, Scanrückmeldung und einzelne Hauptaktionen.
- Keine langen Texte in GROSSBUCHSTABEN und keine mit Leerzeichen nachgebauten Tabellen.

### 4.3 Wortwahl und Zahlen

- Oberfläche vollständig auf Deutsch. Gleiche Aktionen erhalten überall denselben Namen.
- Hauptbegriffe: **Entdeckungsbuch**, **Entwicklung** als kurzer Navigationstitel des Entwicklungsbuchs, **Kreatureneditor**, **Freischalten**, **Voraussetzungen**, **Auf Merkliste setzen**.
- Buttons nennen die Handlung: „Freischalten“, „Im Buch ansehen“, „Zurück“. Allgemeines „OK“ nur für eine reine Bestätigung ohne weitere Bedeutung.
- Interne IDs, Debugnamen, Seeds, Vertragsversionen und Implementierungsdetails erscheinen nur in dafür vorgesehenen Diagnoseansichten.
- Dezimalkomma; Körperbauwerte mit bis zu zwei Dezimalstellen ohne unnötige Endnullen. Beispiele: `12`, `12,5`, `12,75`.
- Prozentwerte mit Abstand: `25 %`. Messwerte nur mit tatsächlich definierter Einheit. Ein anatomischer Tempowert ist nicht automatisch `m/s`, Sprungkraft nicht automatisch `m`.
- Aktuelle Gesundheit: `72 / 100`. Kosten: `10 Sozialpunkte`. Veränderungen: `+2` oder `−1,5`.
- Nicht verfügbare Daten: Gedankenstrich `—` und verständliche Erklärung. Nie durch eine scheinbar echte `0` ersetzen.
- Lange Namen dürfen umbrechen. In Listen höchstens zwei Titelzeilen, dann Auslassung; der vollständige Name bleibt in der Detailansicht erreichbar.

## 5. Symbolregister: eine feste Bedeutung pro Kennung

### 5.1 Vorhandene Stat-Symbole – wiederverwenden

Das bestehende Register ist `ui/discovery/stat_symbols.gd`; die SVG-Dateien liegen unter `ui/discovery/icons/`. Die folgenden zwölf Kennungen und Dateien bestehen bereits im geprüften Projektstand. Ihre sichtbaren Bezeichnungen folgen dem gemeinsamen Körperbauvergleich.

| Kennung | Sichtbarer Name | Motiv | Motivfarbe | Quelldatei |
| --- | --- | --- | --- | --- |
| `attack` | Angriff | Kantiger Fangzahn | `#EDAB91` | `attack.svg` |
| `defense` | Verteidigung | Schild | `#94CBB8` | `defense.svg` |
| `health` | Lebenskraft | Herz | `#EE9AA6` | `health.svg` |
| `speed` | Tempo | Fußspuren mit Bewegungslinien | `#EFD49C` | `speed.svg` |
| `jump` | Sprungkraft | Aufsteigender Sprungpfeil | `#D5B2ED` | `jump.svg` |
| `swim` | Schwimmen | Flosse über Wellen | `#91D3EA` | `swim.svg` |
| `perception` | Wahrnehmung | Auge | `#B8C2F1` | `perception.svg` |
| `grip` | Greifkraft | Hand | `#E7C28F` | `grip.svg` |
| `diet_plant` | Pflanzenkost | Blatt | `#AFCF8E` | `diet_plant.svg` |
| `diet_meat` | Fleischkost | Fleischstück mit Knochen | `#E2A38E` | `diet_meat.svg` |
| `flight` | Flugwert | Flügel | `#BFDCDE` | `flight.svg` |
| `hunger_drain` | Nahrungsbedarf | Schale mit aufsteigenden Strichen | `#E2C99D` | `hunger_drain.svg` |

**Die Quelldatei ist die verbindliche Formreferenz.** Motivbeschreibungen sind keine Aufforderung, das Symbol neu zu zeichnen. Auch die jeweilige dunkle Plakettenfarbe und die vorhandenen hellen Details gehören zum Symbol.

### 5.2 Gleiche Symbolfamilie, präzise Wertbedeutung

Ein gemeinsames Symbol macht unterschiedliche Messgrößen nicht zu identischen Werten.

- `health` zeigt im Körperbauvergleich **Lebenskraft**. Im HUD bezeichnet dasselbe Herz **Gesundheit** als aktuellen Wert und Maximum. Die Beschriftung und das Zahlenformat benennen diese absichtliche Unterscheidung.
- Ein Angriffswert ist kein garantierter Schaden. Ein Flugwert verspricht keinen freigeschalteten Flugmodus.
- **Nahrungsbedarf** ist Verbrauch und keine gefüllte Hungerleiste. Dafür entsteht kein Alias, der stillschweigend beide Bedeutungen vermischt.
- **Pflanzenkost/Fleischkost** sind Eignungswerte. Die daraus abgeleitete Ernährungsart „Pflanzenfresser“, „Fleischfresser“ oder „Allesfresser“ wird als eigener Textstatus dargestellt.
- Sozial-, Aggressions-, Entdeckungs- und Stammespunkte bleiben getrennte Währungen. Sie erhalten unterschiedliche Symbole und ausgeschriebene Namen.

### 5.3 Neue Symbole – zentrale Ergänzung bei Bedarf

Die folgenden Einträge sind eine **Designreservierung**, kein Nachweis vorhandener Grafiken oder Spielfunktionen. Vor einer Implementierung wird geprüft, ob ein aktiver Arbeitszweig bereits eine passende gemeinsame Kennung eingeführt hat. Solche Kennungen werden übernommen und zentral zugeordnet; keine konkurrierenden Daten-IDs anlegen.

| Semantischer Designname | Sichtbarer Begriff | Verbindliche Motividee | Abgrenzung |
| --- | --- | --- | --- |
| `vital.satiety` | Sättigung | Gefüllter Magen | Füllstand; getrennt vom Nahrungsbedarf |
| `vital.hydration` | Flüssigkeit | Einzelner Tropfen | Körperzustand; getrennt vom Wasservorrat |
| `resource.water` | Wasser | Gefäß mit Tropfen | Gemeinsamer Vorrat |
| `resource.food` | Nahrung | Vorratskorb | Vorrat; keine Ernährungsart |
| `resource.wood` | Holz | Gestapelte Holzstücke | Baumaterial |
| `resource.stone` | Stein | Zwei kantige Steine | Baumaterial |
| `resource.milk` | Milch | Gefäß mit heller Füllung | Menge einer Ressource |
| `role.milk` | Milch geeignet | Euter | Eignung einer Tierart |
| `role.draft` | Zugtier geeignet | Joch | Eignung, keine laufende Arbeit |
| `role.mount` | Reittier geeignet | Sattel | Eignung, keine Reitfreischaltung |
| `role.companion` | Begleiter geeignet | Pfote | Eignung einer Tierart |
| `animal.trust` | Vertrauen | Zwei verbundene Glieder | Bindung eines individuellen Tiers; kein Gesundheitssymbol |
| `currency.social` | Sozialpunkte | Zwei Sprechblasen | Sozialer Entwicklungspfad |
| `currency.aggression` | Aggressionspunkte | Zwei gekreuzte Krallen | Entwicklungspunkte; kein Angriffswert |
| `currency.discovery` | Entdeckungspunkte | Lupe über einem kleinen Stern | Nur verwenden, wenn diese Währung vorhanden ist |
| `currency.tribe` | Stammespunkte | Drei Figuren | Gemeinschaftsfortschritt |
| `nav.discovery` | Entdeckungsbuch | Offenes Buch | Sammlung und Nachschlagen |
| `nav.development` | Entwicklung | Verzweigter Pfad | Skills und Entwicklungsstufen |
| `nav.editor` | Kreatureneditor | Drei verbundene Körpermodule | Körpergestaltung |
| `action.scan` | Scannen | Vier Zielklammern | Aktive Beobachtung |
| `action.wishlist` | Merkliste | Lesezeichen | Gemerkter Eintrag |
| `state.locked` | Gesperrt | Geschlossenes Schloss | Nicht nutzbar |
| `state.unlocked` | Freigeschaltet | Haken | Nutzbar / erworben |
| `state.warning` | Hinweis | Dreieck mit Ausrufezeichen | Erklärter Handlungsbedarf |
| `state.unknown` | Unbekannt | Fragezeichen | Noch keine gesicherten Informationen |

### 5.4 Zeichenstil und Verwendung

- Bestehender Zeichenraum: `32 × 32`, kantige gefüllte Formen, abgeschrägte quadratische Plakette, höchstens Grundfläche, Motivfarbe und kleines helles Detail.
- Neue Symbole übernehmen Gewicht, Randabstände und Detailgrad der vorhandenen SVGs. Keine importierte zweite Iconbibliothek.
- Standard in Stat-Zeilen: `28 × 28`; kompakt im HUD: `24 × 24`; mindestens `20 × 20`. Kategorien dürfen `32 × 32` verwenden.
- Die Stat-Plakette wird weder gespiegelt noch beliebig gedreht. Ein größerer Einsatz behält das Seitenverhältnis.
- Ein Stat behält Motiv und Farbe in allen Ansichten. Vergleichsfarben, Auswahl oder Sperrstatus stehen daneben beziehungsweise am Container; sie färben nicht den Stat selbst um.
- Standardaufbau einer Stat-Zeile: **Symbol · Bezeichnung · rechtsbündiger Wert**. Zwischen Symbol und Text liegen 8 Einheiten.
- In Büchern, Editorwerten, Vergleichen und Scan-Details bleiben Bezeichnungen sichtbar. Nur etablierte HUD-Leisten und Kartenmarker dürfen ohne dauerhaften Namen auskommen; ihre Bedeutung bleibt über eingeblendete Hilfen beziehungsweise die Legende erreichbar.
- Navigationssymbole stehen in neutraler heller Farbe auf dunkler Fläche. Aktiver Reiter und Fokus werden am Reiter markiert.
- Fehlt ein neues Symbol noch, erscheint vorübergehend der vollständige Text. Kein zufälliges Emoji und kein irreführendes Ersatzsymbol.

## 6. Layout, Abstände und Skalierung

### 6.1 Gemeinsames Raster

| Token / Element | Sollmaß bei 1920 × 1080 |
| --- | --- |
| Abstandsreihe | 4, 8, 12, 16, 24, 32, 48 |
| Symbol zu Text | 8 |
| Abstand innerhalb einer Informationsgruppe | 8–12 |
| Karten-Innenabstand | 16 |
| Fenster-Innenabstand | 24 |
| Abstand zwischen Hauptbereichen | 24–32 |
| HUD-Sicherheitsabstand zum Rand | 24 |
| Standard-Eckenradius | 4 |
| Dünner Rand | 1 |
| Fokus- und Auswahlrand | 2 |
| Standard-Buttonhöhe | 48 |
| Hauptaktion im Startmenü | 56 |
| Sichtbares Funktionssymbol | 24–28 |
| Klickfläche für ein kleines Funktionssymbol | Mindestens 44 × 44 |

- Ein Fenster hat eine klare Außenfläche und wenige Inhaltsebenen. Keine Kette aus ineinander liegenden Boxen mit jeweils eigenem Rand.
- Buchfenster nutzen vorzugsweise 90 % der verfügbaren Breite, maximal 1600 logische Einheiten, und höchstens 92 % der Höhe. Sie bleiben zentriert.
- Fenstertitel und Schließen-Schaltfläche haben in allen großen Ansichten denselben Platz. Navigation folgt direkt darunter.
- Scrollen erfolgt im Inhaltsbereich. Reiter, Suche und die zugehörige Hauptaktion bleiben erreichbar.
- Ein unabhängiger linker Katalog und eine rechte Detailansicht dürfen jeweils scrollen. Keine ineinander verschachtelten Scrollflächen innerhalb derselben Detailspalte.
- Kopfzeilen, Zahlen und Kartenränder sind sauber ausgerichtet. Keine manuelle Ausrichtung durch Leerzeichen.

### 6.2 Kleine Fenster und große Schrift

- Prüfansichten: 1920 × 1080, 1280 × 720 und 2560 × 1080; zusätzlich große Schrift beziehungsweise 150 % UI-Skalierung.
- Das gesamte Fenster darf bei kleinen Auflösungen nicht so weit verkleinert werden, dass Texte unlesbar werden. Bedienrelevanter Text bleibt nach Skalierung mindestens etwa 16 Bildschirmpixel, unkritischer Zusatztext mindestens 14.
- Bei Platzmangel wechselt die Zweispaltenansicht zu **Liste → Detail mit Zurück**. Sie schrumpft nicht endlos weiter.
- Lange Reiterleisten erhalten erreichbare Überlaufnavigation. Keine winzigen Reiter und keine zweite, unübersichtliche Reiterzeile.
- In breiten Formaten wachsen Inhaltsbereiche, während HUD und Minimap an ihren vorgesehenen Rändern bleiben. Textzeilen werden nicht beliebig breit.
- Große Schrift verändert Umbruch und Layout; sie darf keine Bedienelemente abschneiden.

## 7. Gemeinsame Bausteine und Zustände

Diese Bausteine sind Gestaltungsverträge. Vorhandene Implementierungen werden dafür genutzt oder gemeinsam erweitert; die Namen sind keine Aufforderung, parallele Klassen neu anzulegen.

| Baustein | Fester Aufbau |
| --- | --- |
| Fenster | Titel, Schließen, Navigation, Inhalt, gegebenenfalls Aktionsbereich |
| Listeneintrag | Kleine Vorschau, Name, eine Zusatzzeile, ein vorrangiger Status |
| Vorschaukarte | Quadratische Vorschau, Name, Status; Werte in der Detailansicht |
| Stat-Zeile | Gemeinsames Symbol, gemeinsamer Name, ausgerichteter Wert |
| Vergleichszeile | Symbol und Name, Wert A, Wert B, beschriftete Differenz |
| Statusmarke | Kleines Statussymbol und kurze Beschriftung |
| Hinweisfeld | Ein Satz zur Ursache, bei Bedarf eine konkrete nächste Handlung |
| Tooltip | Begriff, kurze Erklärung, gegebenenfalls Einheit oder Wirkung |
| Leerer Zustand | Verständlicher Titel, ein erklärender Satz, passende nächste Handlung |
| Benachrichtigung | Ein Symbol, kurze Aussage, optionaler Verweis zum betreffenden Eintrag |

### 7.1 Zustände

| Zustand | Darstellung | Verhalten |
| --- | --- | --- |
| Normal | Dunkle Fläche, heller Text | Bedienbar |
| Hover | Etwas hellere Fläche | Keine Layoutverschiebung |
| Fokus | Klarer Akzentrand | Tastaturbedienung gleichwertig zur Maus |
| Ausgewählt | Akzentrand und Auswahlmarker | Bleibt beim Bewegen der Maus erkennbar |
| Gesperrt | Silhouette, Schloss, lesbarer Grund | Details ansehen möglich; Nutzung gesperrt |
| Freischaltbar | Silhouette, klare Aktionsmarke „Freischaltbar“ | Genau eine erkennbare Freischaltaktion |
| Freigeschaltet | Vollständige Darstellung und Haken | Nutzbar; keine dauerhafte Erfolgsanimation |
| Wird geladen | Reservierte Vorschaufläche und kurzer Ladehinweis | Layout bleibt stabil |
| Daten fehlen | Neutraler Platzhalter und Erklärung | Nicht als „Gesperrt“ oder als Nullwert darstellen |
| Fehler | Hinweis mit Ursache und erreichbarer Handlung | Benutzereingaben bleiben erhalten, soweit möglich |

„Neu“ ist ein zusätzlicher kleiner Marker, kein eigener Freischaltzustand. Er verschwindet nach dem bewussten Öffnen des Eintrags. Auswahl und Freischaltung können gleichzeitig bestehen und werden getrennt markiert.

### 7.2 Bedienung

- Hover zeigt Zusatzinformationen; eine Mausbewegung löst keinen Kauf und keine Zustandsänderung aus.
- Ein Klick wählt einen Eintrag; die sichtbare Aktion führt die Änderung aus. Keine nur per Doppelklick erreichbare Kernfunktion.
- `Esc` schließt zuerst die oberste Ebene und stellt anschließend den vorherigen Fokus wieder her.
- Es gibt gleichzeitig nur ein großes Buch-/Editor-/Menüfenster. Der Wechsel zwischen Entdeckungsbuch und Entwicklung übergibt Fokus und Pausezustand über den vorhandenen Ablauf.
- Tastenhinweise stammen aus der tatsächlichen Belegung. `E`, `J` und `K` sind keine dauerhaft hartkodierten Ersatztexte für veränderbare Bindings.
- Kritische, dauerhafte Übergänge haben eine ausdrückliche Bestätigung mit benannter Folge. Normale Navigation und reversible Auswahl benötigen keine Bestätigungsdialoge.

## 8. Entdeckungsbuch

### 8.1 Aufgabe und Aufbau

Das Entdeckungsbuch beantwortet: **Was habe ich entdeckt, wie sieht es aus, was kann es und wo finde ich es?**

- Kopf: „Entdeckungsbuch“, dezenter Fortschritt des aktuellen Bereichs, Schließen.
- Darunter die vorhandenen Bereiche: **Arten, Körperteile, Regionen, Nächste Schritte, Forschungsziele**. Ein späteres Register eigener Tiere wird an diese gemeinsame Navigation angeschlossen.
- Suche und Filter stehen zusammen oberhalb der Liste. Ein Filter zeigt seinen aktiven Zustand und lässt sich zurücksetzen.
- Links auf großen Bildschirmen etwa ein Drittel für Einträge, rechts etwa zwei Drittel für Vorschau und Details.
- Auswahl, Suchbegriff, Filter und Scrollposition bleiben beim Wechsel zur Detailansicht und zurück erhalten.
- „Nächste Schritte“ nennt eine vorrangige Handlung und höchstens zwei Alternativen. Bereits vorhandene Hilfen bleiben zugänglich.

### 8.2 Arten

**Liste:** Vorschau, Artname, Fundregion und gegebenenfalls eine vorrangige Rollenmarke. Keine vollständige Stat-Tabelle in jedem Listeneintrag.

**Detailreihenfolge:**

1. Artname, große tatsächliche Kreaturenvorschau und kurzer Entdeckungsstatus.
2. Ernährung und bekannte Rollen/Eignungen.
3. Die sechs vorhandenen Hauptwerte in stabiler Reihenfolge: **Angriff, Verteidigung, Lebenskraft, Tempo, Sprungkraft, Schwimmen**.
4. Weitere Werte in einem ausdrücklich erreichbaren Bereich „Weitere Werte“.
5. Körperteile, Fundorte und Forschungsschritte in klar getrennten Abschnitten.

- Vergleich mit der eigenen Kreatur ist eine gezielte Ansicht/Aktion; er muss nicht die gesamte Standarddetailseite dauerhaft belegen.
- Individuelle Tiere und Arten sind verschiedene Einträge. „Milch geeignet“ beschreibt eine Art; Name, Besitzer, Vertrauen und aktueller Auftrag gehören zum individuellen Tier.
- Tierrollen kommen aus dem gemeinsamen Artenvertrag. Ein Designchat leitet „Reittier“ nicht allein aus Größe oder Aussehen ab.
- Unentdeckte prozedurale Arten werden nicht mit echten Namen, exakter Anatomie oder versteckten Werten vorweggenommen. Falls unbekannte Einträge gezeigt werden, verwenden sie eine generische unbekannte Silhouette.

### 8.3 Körperteile

- Die Übersicht zeigt erkennbare, gleich große Vorschaukarten mit echten Körperteilformen.
- Freigeschaltet: vollständiges Modell in konsistenter Beleuchtung.
- Gesperrt: einfarbige Silhouette derselben bekannten Katalogform, mit Schloss und Freischaltvoraussetzung.
- Freischaltbar, aber noch nicht erworben: weiterhin Silhouette, plus eindeutige Aktionsmarkierung.
- Die Silhouettenregel betrifft die einzelne gesperrte Katalogkarte. Eine bereits gescannte Kreatur darf ihren beobachteten vollständigen Körper zeigen, auch wenn der Spieler deren Teile noch nicht selbst verwenden kann.
- Namen und Voraussetzungen bekannter Katalogteile dürfen lesbar bleiben. Geheime Inhalte werden nur gezeigt, wenn die gemeinsame Entdeckungslogik sie bereits offenlegt.
- Detailansicht: größere Vorschau, Einsatzbereich, Freischaltstatus, relevante Stat-Veränderungen, Herkunft und gegebenenfalls Merkliste.
- Nicht mehr auflösbare Teile alter Spielstände erscheinen als „Vorschau nicht verfügbar“; sie werden nicht nachträglich als gesperrt ausgegeben.

### 8.4 Vergleichswerte

- Spalten benennen ihre Grundlage: beispielsweise „Dein Körperbau“, „Art“, „Art − du“.
- Körperbauwerte werden mit Körperbauwerten verglichen, aktuelle Spielwerte mit derselben aktuellen Berechnungsgrundlage. Boni und momentane Zustände werden nicht stillschweigend eingemischt.
- Zahlen stehen rechtsbündig, Symbole und Bezeichnungen links. Gleiche Zeilen behalten dieselbe Reihenfolge.
- Ein positives Vorzeichen ist nicht grundsätzlich gut. Beim Nahrungsbedarf ist weniger Verbrauch günstiger; die Bewertung wird aus der zentralen Stat-Definition gelesen.
- Eine Zahl wird nur dann als Verbesserung markiert, wenn ihre fachliche Richtung bekannt ist. Sonst bleibt die Differenz neutral.

## 9. Entwicklungsbuch und Skills

Die Entwicklung beantwortet: **Was kann meine Spezies bereits, was kann ich als Nächstes freischalten und was brauche ich dafür?**

- Derselbe Fensterrahmen, dieselbe Schrift und dieselben Stat-Zeilen wie im Entdeckungsbuch.
- Oben die aktuell relevanten Punktarten, jeweils mit eigenem Symbol, Name und Anzahl. Keine anonyme Gesamtpunktzahl aus verschiedenen Währungen.
- Entwicklungspfade sind optisch gruppiert. Zunächst werden die aktuelle Stufe und unmittelbar erreichbare nächste Schritte betont.
- Ein Skill zeigt Name, kurze Wirkung, Status und Kosten. Seine ausführlichen Voraussetzungen stehen in einer festen Detailfläche.
- Sperrgründe stehen ausdrücklich da, beispielsweise „Benötigt: …“. Die Liste verwendet tatsächliche Voraussetzungen aus dem Fortschrittsdienst.
- Freigeschaltete Skills haben das vollständige gemeinsame Skillmotiv und einen Haken. Noch nicht freigeschaltete Skills haben dessen dunkle Silhouette; Voraussetzungen und Wirkung bleiben bei bekannten Skills lesbar.
- Skills, die ein Körperteil freigeben, verwenden die Körperteilvorschau. Abstrakte Skills erhalten ein zentrales Skillmotiv und kein erfundenes Körperteilbild.
- Verbindungslinien nur für echte Abhängigkeiten. Keine dekorativen Verbindungen und kein riesiges Netz ohne erkennbare Leserichtung.
- Änderungsvorschau in derselben Stat-Sprache: zum Beispiel gemeinsames Angriffssymbol, „Angriff“, `12 → 14`, daneben `+2`. Beispielzahlen sind keine Balancevorgabe.
- Nach einem Kauf werden Punkte, Status und Vorschau gemeinsam aktualisiert. Ein Erfolg wird einmal gemeldet.
- Spätere Phasen dürfen als Ausblick erkennbar sein, erhalten aber keine aktiv wirkende Kaufaktion ohne spielbare Voraussetzungen.
- Der Übergang zur Stammesphase bleibt eine ausdrückliche Handlung wie „Jetzt in das Stammeszeitalter fortschreiten“. Folgen für Steuerung und Spielablauf werden vor der Bestätigung verständlich genannt.
- Die Oberfläche führt keine neue Fortschritts-, Belohnungs- oder Speicherlogik ein.

## 10. HUD, Scanmodus und Minimap

### 10.1 Feste Bildschirmbereiche

| Position | Inhalt | Regel |
| --- | --- | --- |
| Oben links | Kompakter eigener Status | Gesundheit, Sättigung, Flüssigkeit; weitere Leisten nur bei bestehender Mechanik |
| Unter dem eigenen Status | Dringender Zustands- oder Gruppenhinweis | Nur aktuell relevante Information |
| Oben rechts | Kurzer Orts-/Zielhinweis | Keine permanente Diagnosewand |
| Rechts beim aktiven Scan | Informationen zum anvisierten bekannten Tier | Nur im Scanmodus und nur für das aktuelle Ziel |
| Bildschirmmitte | Kleines Fadenkreuz und Scanfortschritt | Blick auf das Ziel bleibt frei |
| Unten mittig | Aktuell mögliche Interaktion / ausgewählte Gruppenbefehle | Wenige passende Aktionen mit tatsächlicher Tastenbelegung |
| Unten rechts | **Reservierter Platz für die Minimap** | Keine dauerhaften anderen Widgets in diesem Bereich |
| Unten links | Zusammengefasste Entdeckungs- und Erfolgsmeldungen | Maximal zwei gleichzeitig |

### 10.2 Statusanzeigen

- Richtwert für den eigenen Statusblock: etwa 240–280 Einheiten breit; bei drei Leisten etwa 140–170 hoch. Kleine Schrift ist kein Mittel zur Platzersparnis.
- Gesundheit verwendet das gemeinsame Herz. Leisten sind horizontal, mit kleinem Symbol, gleich bleibender Position und verständlicher Zahl.
- **Füllstand steigt immer mit Versorgung beziehungsweise Gesundheit.** Voll bedeutet gut versorgt; leer bedeutet Mangel. Deshalb heißen die Versorgungsleisten „Sättigung“ und „Flüssigkeit“.
- Falls die vorhandenen Spieldaten stattdessen Hunger/Durst als zunehmenden Mangel speichern, übersetzt der gemeinsame Anzeigeadapter die Richtung. Die Speicher- und Spielmechanik bleibt unverändert.
- Gesundheit: Herzfarbe `#EE9AA6`; Sättigung: `#E2C99D`; Flüssigkeit: `#91D3EA`. Die Grundfarbe bleibt stabil; kritischer Zustand ergänzt Warnsymbol, Beschriftung und einen kurzen Impuls.
- Warnschwellen werden aus der vorhandenen Spiellogik bezogen. Ein UI-Chat erfindet keine anderen Gefahrengrenzen.
- Ausdauer, Sauerstoff oder weitere Leisten erscheinen erst, wenn dafür eine tatsächliche Mechanik besteht, und nur im passenden Kontext.
- Koordinaten, FPS, Höhenwerte, Temperatur-Rohwerte und Entwicklungs-Shortcuts werden aus dem normalen Spiel-HUD in die Diagnoseansicht verlagert.

### 10.3 Scanmodus

- Außerhalb des Scanmodus keine dauerhaften weißen Tiernamen oder Arteninformationen über Wildtieren.
- Der Scanmodus zeigt einen klaren Fortschrittsring um das Fadenkreuz und eine kurze Handlungsanweisung.
- Fortschritt, Reichweite und Verhalten bei Zielverlust folgen dem vorhandenen Scanner. Die Gestaltung legt keine zweite Scanregel fest.
- Eine bereits erkannte Art zeigt beim Anvisieren sofort eine kompakte Karte: Name, bekannte Rolle/Ernährung und wenige entscheidende Werte mit den gemeinsamen Symbolen. Weitere Werte sind im Buch erreichbar.
- Beim Verlassen des Modus verschwinden Scanring und Artenkarte gemeinsam.
- Der Ring ist ein bewusst rundes Funktionselement: Er vermittelt kontinuierlichen Fortschritt. Die sonst kantige Formensprache erzwingt keinen schlechter lesbaren Kreisersatz.
- Kampfrückmeldungen dürfen ein tatsächlich betroffenes Ziel kenntlich machen; sie werden nicht zur permanenten Artenbeschriftung umfunktioniert.

### 10.4 Minimap als festgelegtes Ziel

Die Minimap ist ein geplanter Baustein; diese Vorgabe behauptet keine fertige Implementierung.

- Unten rechts, mit demselben Randabstand wie das übrige HUD.
- Zielgröße etwa `208 × 208` Einheiten; bei kleinen Fenstern etwa `160 × 160`, sofern die Marker lesbar bleiben.
- Quadratische dunkle Einfassung, Radius 4, zurückhaltende Geländefarben, klare Markerkonturen.
- Norden bleibt oben; das Spielersymbol zeigt die Blickrichtung. Eine spätere Drehoption wird global eingestellt.
- Heimat, angeheftetes Ziel, eigene Tiere und ausgewählte Gruppe verwenden feste, zentral definierte Marker. Farbe ist nie das einzige Unterscheidungsmerkmal.
- Kein Tier- oder Ressourcenradar für noch unbekannte Informationen. Die Karte zeigt nur, was der Spielzustand und die Entdeckungsregeln erlauben.
- Der freie Blick in die Welt und Gruppenbefehle dürfen nicht durch die Karte verdeckt werden. Bei offenem großem Fenster wird sie ausgeblendet.

## 11. Kreatureneditor und gemeinsame Vorschauen

- Gleiche Bibliothekskarten und Sperrzustände wie im Entdeckungsbuch.
- Große Arbeitsfläche in der Mitte, Teileauswahl links, Eigenschaften des ausgewählten Teils rechts. Verfügbare Aktionen stehen nahe bei der jeweiligen Auswahl.
- Drehen, Skalieren, Positionieren und Symmetrie verwenden einheitliche Bedienelemente mit sichtbaren Zahlen. Eine aktive Symmetrie ist dauerhaft erkennbar.
- Ein Teil besitzt dieselbe `part_id`, dieselbe Form und dieselben Beiträge in Editor und Buch. Für Vorschauen wird der gemeinsame Renderer mit den tatsächlichen Daten verwendet.
- Standardansicht für Katalogbilder: ruhige Dreiviertelansicht, Blick auf die linke Körperseite und Vorderseite; Kopf im Bild nach links. Gleiche Beleuchtung, neutraler dunkler Hintergrund und ausreichend Rand.
- Vorschauen werden proportional eingepasst, niemals gestreckt. Flügel, Hörner und mehrere Beinpaare dürfen nicht abgeschnitten werden.
- Ein gleich großes Vorschaubild behauptet keine gleiche Körpergröße. Größenvergleiche bekommen eine gemeinsame Skala oder eine sichtbare Maßangabe.
- Die Detailvorschau ist drehbar. Die Darstellung folgt beim Ziehen dem Zeiger wie ein angefasstes Objekt; Ziehen nach rechts darf nicht entgegengesetzt wirken. Das Verhalten ist in Editor und Buch identisch.
- Modellbewegung wird nicht durch Klicks auf UI-Flächen ausgelöst. Beim Ziehen an einer Formsteuerung bleibt die Kamera ruhig.
- Hauttyp und Farbe zeigen dieselbe Oberflächenwirkung wie im Spiel. Eine Texturauswahl wird nicht durch eine Vorschau mit zusätzlicher Haar- oder Schuppengeometrie verfälscht.
- Silhouetten verwenden die echte Modellmaske ohne Materialdetails. Ein gesperrtes Teil wird nicht durch ein allgemeines Schlossbild ersetzt.
- Fehlende Altdaten werden erklärt. Keine erfundenen Ersatzkreaturen, die wie der gespeicherte Originalstand aussehen sollen.

## 12. Weltobjekte und spätere Spielphasen

- Pflanzen, Büsche, Steine und Kreaturen haben eine erkennbare Gesamtform, nachvollziehbare Materialgruppen und Details, die diese Form unterstützen.
- Neue Beerenbüsche müssen zur aktuellen Vegetationsfamilie passen: erkennbare Strauchstruktur, gezielte Fruchtgruppen und ein einheitlicher Voxelmaßstab. Keine Rückkehr zu groben alten Platzhalterformen.
- Wiederkehrende Objekte werden im Nah-, Mittel- und Fernbild beurteilt. Silhouette und Materialcharakter bleiben erkennbar; Details dürfen mit Entfernung vereinfacht werden.
- Katalogbild und Weltobjekt beziehen sich auf dasselbe Asset beziehungsweise denselben gespeicherten Bauplan.
- In der Stammesphase erweitern Gruppenporträts, Vorräte und Befehle das vertraute HUD. Sie übernehmen Symbole und Bausteine aus den vorhandenen Ansichten.
- Stammesmitglieder und gezähmte Tiere werden visuell unterscheidbar gelistet; eine Tierrolle stellt das Tier nicht als Bürger dar.
- Hütten und Zelte gehören zur frühen Dorfphase. Ein vollständiger Gebäudeeditor ist ein späterer, gesonderter Bereich ab der vorgesehenen Mittelalterarbeit.
- Mittelalter, Neuzeit und Weltraum dürfen eigene Inhaltsmotive und dezente Akzente ergänzen. Schrift, Stat-Symbole, Navigation und Bedienzustände bleiben bestehen.
- Die Oberfläche zeigt nur tatsächlich implementierte und zugängliche Funktionen als bedienbar.

## 13. Bewegung, Rückmeldung und Ton

- Hover/Fokus: unmittelbar bis ungefähr 120 ms; kleine Fensterübergänge: 120–180 ms; Erfolgshinweise: etwa 180–250 ms.
- Keine federnden Karten, dauernd hüpfenden Symbole, blinkenden Stat-Zahlen oder langen Buchanimationen.
- Layout bleibt während Animationen stabil. Eine Zahl reserviert ihren Platz, statt Nachbarelemente zu verschieben.
- Scanfortschritt wird kontinuierlich dargestellt; Erfolgs- und Sperrmarkierungen bleiben anschließend ruhig.
- Benachrichtigungen verwenden vorhandene Erfolgsereignisse. Mehrere ähnliche Entdeckungen werden zusammengefasst und nicht von mehreren Ansichten doppelt gemeldet.
- Unkritische Meldungen verschwinden nach ungefähr 4 Sekunden. Handlungsrelevante Fehler bleiben erreichbar; ein kleiner Verlauf beziehungsweise das zuständige Fenster bewahrt wichtige Information.
- Für Auswahl, Freischaltung und Fehler werden die vorhandenen gemeinsamen Audioanschlüsse verwendet. Ein UI-Chat bringt kein zweites Soundpaket mit eigener Lautheitslogik mit.
- Eine reduzierte Bewegungsoption unterdrückt nicht notwendige Bewegung. Wichtige Zustände sind auch ohne Ton erkennbar.

## 14. Technischer Anschluss für alle Entwicklungs-Chats

### 14.1 Bestehende Grundlagen

Im geprüften `main`-Stand bestehen bereits mehrere Stilhelfer. Diese Vorgabe vereinheitlicht deren Zielgestaltung und verlangt keine parallele vierte Gestaltung.

| Bestehender Pfad | Bedeutung für diese Vorgabe |
| --- | --- |
| `ui/frontend/menu_style.gd` | Ausgangspunkt der gemeinsamen Oberflächenpalette und Buttonzustände |
| `ui/progression_style.gd` | Bestehende Fortschrittsgestaltung; Sozial-/Aggressionsfarben übernehmen |
| `ui/discovery/stat_symbols.gd` | Verbindliches bestehendes Stat-Symbolregister |
| `ui/discovery/icons/` | Bestehende gemeinsame SVG-Formreferenzen |
| `core/discovery/species_comparison.gd` | Bestehende Stat-Kennungen, Bezeichnungen und Zahlenformatierung |
| `ui/discovery/discovery_journal.gd` | Vorhandenes gemeinsames Entdeckungsbuch und Navigation |
| `ui/discovery/journal_preview.gd` | Bestehender Anschluss für Körperbauvorschauen |
| `ui/creature_inspection_hud.gd` | Scanansicht an gemeinsame Symbole und Wertzeilen anschließen |
| `ui/hud_presentation.gd` / `ui/progression_hud.gd` | Bestehende HUD-Bereiche und Anschlussstellen |
| `art/STYLE_GUIDE.md` | Bestehende Welt- und Assetgestaltung |

Die Pfade sind ein überprüfter Anschlussstand, keine Behauptung über alle parallel laufenden Branches. Vor Änderungen den aktuellen Stand und die Zuständigkeit prüfen.

### 14.2 Gemeinsame Implementierungsregeln

1. Farben, Schriftgrößen, Abstände und Zustandsstile in einer gemeinsamen Theme-Quelle zusammenführen. Alte Stilhelfer können während der Umstellung delegieren; sie pflegen keine neuen unabhängigen Werte.
2. Das vorhandene Symbolregister weiterverwenden. Falls es später aus dem Discovery-Ordner an einen neutralen Ort umzieht, geschieht das als eigene gemeinsame Änderung mit kompatiblem Weiterleitungsanschluss.
3. Stat-Kennungen und sichtbare Metadaten zentral zuordnen: Icon, Bezeichnung, Wertgrundlage, Format, tatsächliche Einheit und Bewertungsrichtung. Keine kopierten Wörterbücher je Fenster.
4. Derselbe semantische Wert wird über dieselbe gemeinsame Stat-Zeile angezeigt. Ein Scanfenster baut dafür keine Leerzeichen-Tabelle und der Editor kein zweites SVG-Set.
5. Neue Designnamen aus dieser Datei sind keine neuen Speicher- oder Gameplay-IDs. Bestehende Verträge und gespeicherte Kennungen bleiben erhalten.
6. Ein UI-Baustein liest Zustand und sendet die vorgesehene Aktion an den bestehenden Dienst. Er berechnet keine eigene Zähmung, Fortschrittspunkte, Tierrollen oder Save/Load-Regeln.
7. Änderungen an Schrift, zentralem Theme, Symbolregister und Vorschauverhalten erhalten einen klaren gemeinsamen Besitzer pro Arbeitspaket. Andere Chats konsumieren die Änderung in ihren eigenen Bereichen.
8. Fremde unfertige Branches werden nicht für eine Designanpassung zusammengeführt. Abhängigkeiten und noch nicht integrierte Bausteine werden im jeweiligen Übergabebericht benannt.

### 14.3 Anwendung dieser Datei im Projekt

**Vorgesehener kanonischer Projektpfad:** `docs/VOXELVERSE_DESIGN.md`. Diese Lieferung stellt zunächst die Datei `Voxelverse-Designvorgabe.md` bereit; sie behauptet keine bereits erfolgte Aufnahme in das Repository.

Bei der Aufnahme in das Projekt:

1. Inhalt unter dem kanonischen Pfad einchecken und in `ROADMAP.md` sowie `docs/NEXT_PARALLEL_WORK.md` verlinken.
2. In vorhandene Projektanweisungen einen kurzen Verweis aufnehmen; vorhandene Anweisungen nicht ersetzen.
3. Alle UI-Aufträge auf dieselbe kanonische Datei verweisen lassen. Keine je Chat abgewandelte Kopie als neue Hauptquelle führen.

Vorgesehener kurzer Projektverweis:

> Für alle neuen und überarbeiteten sichtbaren Elemente gilt `docs/VOXELVERSE_DESIGN.md`. Lies die Vorgabe vor Designarbeiten. Verwende das gemeinsame Theme, das vorhandene Symbolregister und dieselben Stat-Metadaten. Ergänze fehlende Bausteine zentral. Erhalte bestehende Datenverträge und die Zuständigkeiten anderer Arbeitszweige.

Bis zur Repository-Aufnahme können Entwicklungs-Chats diese gelieferte Datei direkt als gemeinsame Vorgabe lesen. Bereits laufende Chats erhalten neue Vorgaben nicht automatisch; sie müssen auf die Datei verwiesen werden.

### 14.4 Änderungen an der Vorgabe

- Neue Einträge zentral ergänzen und eine kurze Änderungshistorie führen. Keine zweite Designvorgabe erfinden.
- Bestehende Symbolkennungen behalten ihre Bedeutung. Eine wirklich andere Bedeutung erhält einen neuen Eintrag.
- Bei visuellen Widersprüchen gelten ausdrückliche aktuelle Nutzerwünsche, danach diese Vorgabe, danach ältere UI-Einzelgestaltung. Welt- und Datenverträge gelten weiterhin in ihrem jeweiligen Fachbereich.
- Fachliche Konflikte werden benannt und an der gemeinsamen Quelle gelöst; ein einzelner Chat ändert nicht stillschweigend globale Regeln.

## 15. Reihenfolge für die Umsetzung

Diese Reihenfolge hält die laufenden Arbeiten anschlussfähig. Sie ist keine automatische Beauftragung zusätzlicher Spielfunktionen.

1. **Gemeinsame Grundlage:** Theme, Schrift, Abstände, Symbolregister und Stat-Zeile vereinheitlichen.
2. **Entdeckungsbuch und Entwicklung:** Gemeinsamer Fensterrahmen, klare Navigation, echte Vorschauen, Silhouetten und einheitliche Statusmarken.
3. **HUD und Scanansicht:** Kompakte Statusanzeigen links, relevante Zielinformationen, dieselben Stat-Symbole, freie Fläche unten rechts.
4. **Editor und übrige Menüs:** Gemeinsame Karten, Eigenschaftenfelder, Vorschauverhalten und Bedienzustände übernehmen.
5. **Neue Bereiche:** Minimap, Dorfverwaltung und spätere Phasen mit denselben Bausteinen ergänzen, sobald der jeweilige Funktionsauftrag vorliegt.

## 16. Abnahme vor einer Design-Übergabe

Eine überarbeitete Ansicht gilt erst als gestalterisch abgeschlossen, wenn die für sie relevanten Punkte überprüft sind.

- [ ] Derselbe Stat verwendet in jeder berührten Ansicht dieselbe SVG-Ressource, dieselbe fachliche Bezeichnung und dasselbe Format.
- [ ] Körperbauwerte, aktuelle Zustände, Ressourcen, Tierrollen und Punktarten werden nicht miteinander verwechselt.
- [ ] Farben, Schrift und Abstände stammen aus der gemeinsamen Grundlage; dokumentierte Übergänge sind sichtbar benannt.
- [ ] Eine Person erkennt ohne Erklärung den aktuellen Zustand und die wichtigste nächste Handlung.
- [ ] Freigeschaltete Körperteile zeigen die tatsächliche Form; gesperrte Einträge zeigen die richtige Silhouette. Fehlende Daten sind davon unterscheidbar.
- [ ] Gleiche Kreatur und gleiches Körperteil sehen in Welt, Buch und Editor konsistent aus.
- [ ] Hauptinformationen bleiben bei 1280 × 720 und großer Schrift lesbar und erreichbar; lange deutsche Namen brechen sauber um.
- [ ] Hover, Fokus, Auswahl, Sperrung, leere Liste und fehlende Vorschaudaten wurden in den betroffenen Bausteinen angesehen.
- [ ] Maus, Tastatur, Fensterwechsel und `Esc` erzeugen keine doppelten Fenster, verlorenen Fokus oder ungewollten Aktionen in der Welt.
- [ ] HUD-Text bleibt vor hellem Himmel, Wasser und dunklem Wald lesbar. Die Mitte und die Minimap-Fläche bleiben frei.
- [ ] Außerhalb des Scanmodus erscheinen keine dauerhaften Artennamen über Wildtieren.
- [ ] Sperr- und Warnzustände bleiben ohne Farberkennung verständlich. Kritische Rückmeldungen funktionieren auch ohne Ton.
- [ ] Neue UI-Rückmeldungen entstehen einmal über vorhandene Ereignisse; Spielzustand und Speicherlogik bleiben konsistent.

Der Übergabebericht nennt die verwendete Designversion, die betroffenen Ansichten, wenige aussagekräftige Bildschirmaufnahmen und konkrete verbleibende Abweichungen. Für eine reine Dokumentänderung genügt die inhaltliche Prüfung; Spieltests gehören zur tatsächlichen UI-Umsetzung.

## 17. Geprüfte Projektgrundlage und Änderungshistorie

Die Anschlussprüfung dieser Vorgabe bezieht sich auf den am 9. September 2026 gelesenen `main`-Snapshot **`3a3e0272375e556f3ff65b7370582af79a9d48b5`**. Laufende andere Arbeitszweige sind damit nicht als geprüft ausgewiesen.

- Vorhandene Weltgestaltung: [art/STYLE_GUIDE.md](https://github.com/MajorDragonfly/voxelverse/blob/3a3e0272375e556f3ff65b7370582af79a9d48b5/art/STYLE_GUIDE.md).
- Ausgangspalette und Menübausteine: [ui/frontend/menu_style.gd](https://github.com/MajorDragonfly/voxelverse/blob/3a3e0272375e556f3ff65b7370582af79a9d48b5/ui/frontend/menu_style.gd).
- Vorhandene Entwicklungspalette: [ui/progression_style.gd](https://github.com/MajorDragonfly/voxelverse/blob/3a3e0272375e556f3ff65b7370582af79a9d48b5/ui/progression_style.gd).
- Bestehende Symbole: [ui/discovery/stat_symbols.gd](https://github.com/MajorDragonfly/voxelverse/blob/3a3e0272375e556f3ff65b7370582af79a9d48b5/ui/discovery/stat_symbols.gd) und [SVG-Ordner](https://github.com/MajorDragonfly/voxelverse/tree/3a3e0272375e556f3ff65b7370582af79a9d48b5/ui/discovery/icons).
- Vorhandene Stat-Bedeutungen: [core/discovery/species_comparison.gd](https://github.com/MajorDragonfly/voxelverse/blob/3a3e0272375e556f3ff65b7370582af79a9d48b5/core/discovery/species_comparison.gd).
- Vorhandenes Buch: [ui/discovery/discovery_journal.gd](https://github.com/MajorDragonfly/voxelverse/blob/3a3e0272375e556f3ff65b7370582af79a9d48b5/ui/discovery/discovery_journal.gd).

| Version | Datum | Änderung |
| --- | --- | --- |
| 1.0 | 09.09.2026 | Erste gemeinsame Designvorgabe: bestehende Farben und zwölf Stat-Symbole gesichert; Schrift, Layout, Zustände, Vorschauen, Buch, Entwicklung, HUD, Minimap-Ziel und Zusammenarbeit festgelegt. |

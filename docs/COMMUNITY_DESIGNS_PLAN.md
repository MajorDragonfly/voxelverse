# Voxelverse – gemeinsame Designbibliothek und Community-Baupläne

**Integration vom 10. September 2026:** BP-COMMUNITY.1/.2 sind für Kreaturen geliefert: portables Paket, lokale Bibliothek, Editorübernahme und Anfangskreatur-Auswahl. [Bedienung](COMMUNITY_BLUEPRINT_LIBRARY.md), [Vertrag](WORK_COMMUNITY_BLUEPRINT_CONTRACT.md) und [gemeinsamer Prüfstatus](INTEGRATION_2026-09-10.md). Online-Dienst, Galerie und weitere Bauplanarten bleiben geplant.

Stand: 9. September 2026 · **Status: geplant** · Querschnittspaket **BP-COMMUNITY**.
Einordnung: [ROADMAP.md](../ROADMAP.md); konkrete Übersicht: [FEATURE_BACKLOG.md](FEATURE_BACKLOG.md).

## Ziel

Community-Mitglieder können ihre Designs veröffentlichen. Andere Spieler finden sie in einer gemeinsamen Galerie, laden sie in ihre eigene Voxelverse-Installation und verwenden sie in einem anderen Spielstand. Eigene Gestaltung im Editor bleibt eine freiwillige Möglichkeit: Eine passende Vorlage auswählen und übernehmen muss für die Nutzung genügen.

Das gilt für Kreaturen, Gebäude, Fahrzeuge und Raumschiffe einschließlich Expeditionsschiffen und Beibooten. Weitere unterstützte Bauplanarten werden über denselben Vertrag ergänzt. Fertige mitgelieferte Startvorlagen sorgen außerdem dafür, dass jede bereits spielbare Bauplanart auch ohne Community-Download und ohne eigene Editorarbeit nutzbar ist.

## 1. Ein gemeinsamer Ablauf

**Veröffentlichen:** Lokalen Entwurf wählen → überprüfbare Vorschau ansehen → Titel/Beschreibung/Kategorie ergänzen → bewusst veröffentlichen → Community-Eintrag erhalten.

**Verwenden:** Galerie durchsuchen → Design und Anforderungen ansehen → herunterladen → in die eigene lokale Designbibliothek übernehmen → am passenden Spielort auswählen und verwenden. Änderungen im Editor sind optional.

**Verwalten:** Eigene Entwürfe, heruntergeladene Designs und mitgelieferte Vorlagen stehen in derselben Bibliotheksoberfläche. Herkunft und Autor bleiben erkennbar. Erneutes Herunterladen derselben Version erzeugt keine unübersichtlichen Duplikate.

## 2. Unterstützte Entwürfe und Verwendung

| Bauplanart | Verwendung im eigenen Spiel | Voraussetzungen |
|---|---|---|
| Kreatur | Bei der Erschaffung oder einem erlaubten Umbau der eigenen Kreatur eine vollständige Vorlage übernehmen; anschließend bei Wunsch anpassen | Vorhandene Körper-/Teileverträge und geltende Freischaltungen; Speziesidentität und Kampagnenfortschritt bleiben erhalten |
| Gebäude | Vorlage wählen und als Bauauftrag am gewünschten geeigneten Ort platzieren | Passende Epoche, Bauplatz, Ressourcen, Zugänge und bestehende Bauregeln; der freie Gebäudeeditor bleibt für die Mittelalterphase vorgesehen |
| Fahrzeug | Fertigen Entwurf in der vorhandenen Bau-/Produktionsauswahl verwenden | Spielbare Fahrzeugart, passende Technik und Ressourcen |
| Expeditionsschiff | Fertigen Großschiffentwurf für Bau oder erlaubten Umbau auswählen | Weltraumphase, freigeschaltete Baumaße, Module, Ressourcen und Versorgungsregeln |
| Landungs-/Bordschiff | Vorlage bauen und ein individuelles Schiff dem eigenen Hangar zuordnen | Tatsächliche Landungs-/Flugfähigkeit, passende Hangargröße und verfügbare Kapazität |
| Weitere Bauplanarten | Über denselben Bibliotheks- und Prüfweg ergänzen | Eigener versionierter Typadapter und ein bereits spielbarer Verwendungsweg |

**Herunterladen überträgt einen Entwurf.** Das Bauen, Erschaffen oder Umbauen verwendet die normalen Regeln der Kampagne. Ein fremder Bauplan bringt keine fremden Bewohner, Schiffe als bereits bezahlte Gegenstände, Vorräte, Beziehungen, Forschungspunkte oder Spielstände mit.

Die Bibliothek zeigt zuerst passende, aktuell verwendbare Vorlagen. Fehlende Teile, Technologien, Baugröße oder Material werden vor der Verwendung verständlich angezeigt. Wenn ein Entwurf nicht passt, lassen sich passende Alternativen auswählen; eine manuelle Reparatur im Editor darf nicht die einzige Fortsetzung sein.

## 3. Galerie und Bedienung

- Kategorien für Kreaturen, Gebäude, Fahrzeuge und Schiffstypen; gemeinsame Suche nach Namen, Beschreibungen und Tags.
- Filter für Spielphase, benötigte Teile/Technik, Größe und aktuelle Verwendbarkeit. Sortierung und Darstellung nutzen gemeinsame UI-Bausteine.
- Eintrag mit Vorschaubild, Name, Autor, kurzer Beschreibung, Kategorie, Version und Anforderungen; Details mit echter Modellvorschau und den belegten Bau-/Fähigkeitsdaten.
- Klar getrennte Aktionen: herunterladen, verwenden und optional bearbeiten. Zum Verwenden eines fremden Designs muss kein eigenes Design veröffentlicht werden.
- Lokale Favoriten bzw. eine Merkliste erleichtern das Wiederfinden. Eigene abgewandelte Entwürfe werden als separate Varianten mit nachvollziehbarer Herkunft gespeichert.
- Mitgelieferte Vorlagen sind vom ersten nutzbaren Einstieg einer Bauplanart an verfügbar. Sie funktionieren mit den jeweils zugänglichen Teilen und Ressourcen.
- Heruntergeladene Vorlagen und Startdesigns bleiben nach erfolgreicher Übernahme offline verwendbar. Eine laufende Kampagne benötigt für bereits vorhandene Baupläne keine dauerhafte Verbindung zum Katalog.
- Fehler beim Upload oder Download behalten den lokalen Entwurf und bieten einen nachvollziehbaren erneuten Versuch.

## 4. Portabler Bauplanvertrag

Das bestehende gemeinsame Bauplanfundament bleibt die Quelle. Es gibt keinen zweiten Community-Kreaturenrenderer und kein separates Schiffsformat, das neben dem lokalen Editor gepflegt wird.

Ein portables Paket enthält mindestens:

- Bauplanart, Format-/Katalogversionen, stabile Entwurfskennung und konkrete Revision.
- Geometrie-/Körperbeschreibung, verwendete Teilekennungen, Anschlüsse, Transformationen, Farben, Materialmuster und zulässige Konfiguration.
- Erforderliche Teile/Module, kompatible Spiel-/Schemafassungen und tatsächliche Voraussetzungen.
- Titel, Beschreibung, Autor-/Herkunftsangabe, Tags und geeignete Vorschaudaten.

**Entwurf und Spielobjekt bleiben getrennt:** Ein Community-Eintrag besitzt eine Katalogidentität. Die lokal übernommene Revision ist ein Bauplan. Ein daraus gebautes Gebäude oder Schiff bekommt eine eigene Objekt-ID und den Besitzer des Zielspielstands. Bei einer Kreaturenvorlage wird ein erlaubter Entwurfswechsel vorgenommen; die importierte Vorlage überschreibt nicht die eigene Spezies-/Fraktionsidentität.

Gemeinsam mit den Typadaptern werden Paketgröße, Teilezahl und erlaubte Datenfelder begrenzt. Die erste Version transportiert deklarative Bauplandaten und Vorschauen, keine ausführbaren Skripte oder beliebigen Mods. Unbekannte Teile oder ungültige Anschlüsse werden beim Import verständlich gemeldet. Das Spiel berechnet Kosten und Fähigkeiten aus seinem tatsächlichen Teilekatalog; hochgeladene Zahlen sind keine Autorität für Spielwerte.

Kampagnenorte, individuelle Tier-/Bewohnerdaten, Inventare und andere nicht zum ausgewählten Entwurf gehörende Speicherdaten werden nicht exportiert. Die Vorschau des Uploads zeigt genau das gewählte Design und seine öffentlich sichtbaren Angaben.

## 5. Versionen, Änderungen und Erhalt

- Eine Veröffentlichung ist eine eindeutige Revision. Aktualisierungen können als neue Revision desselben Community-Eintrags erscheinen.
- Ein Download speichert die konkrete Revision einschließlich der für die lokale Verwendung nötigen Daten. Ein bloßer Online-Link genügt nicht.
- Neue Online-Versionen verändern vorhandene Kreaturen, Gebäude oder Schiffe nicht automatisch. Der Spieler kann eine neue Revision ansehen und einen erlaubten Wechsel ausdrücklich auslösen.
- Entfernte oder zurückgezogene Online-Einträge löschen keine bereits übernommenen lokalen Entwürfe oder daraus gebauten Objekte.
- Lokale Änderungen werden als eigene Variante gespeichert; der ursprüngliche Download bleibt wieder auffindbar. Bei einer erlaubten Weiterveröffentlichung bleiben Quellen-/Autorenangaben nachvollziehbar.
- Alte gültige Pakete werden über versionierte Migration gelesen; unbekannte Zukunftsversionen erhalten eine klare Fehlermeldung ohne Überschreiben vorhandener Entwürfe.
- Unterbrochene Importe, doppelte Downloads und kollidierende Namen werden atomar bzw. über eindeutige Kennungen behandelt.

## 6. Online-Dienst und Zuständigkeit

Ein eigener Community-Dienst stellt Katalog, Veröffentlichungsidentitäten, Suche und Paketübertragung bereit. Der Client verwendet begrenzte Seiten/Downloads und lokale Zwischenspeicherung. Der genaue Anbieter und Anmeldeweg werden im Dienstpaket ausgewählt; diese Planung behauptet keinen bereits vorhandenen Server.

Autoren erhalten einen klaren Weg, ihre eigenen Einträge zu veröffentlichen, zu aktualisieren und zurückzuziehen. Vor Veröffentlichung werden zulässige Bauplandaten und sichtbare Metadaten geprüft. Für den öffentlichen Katalog werden Melden, Prüfung und Entfernen von Einträgen als begrenzte Verwaltungsfunktionen eingeplant. Diese Funktionen gehören zum gemeinsamen Dienst und verändern keine fremden lokalen Spielstände.

| Zuständigkeit | Beitrag |
|---|---|
| Bauplan-/Speichergrundlage | Portables Format, Versionen, lokale Bibliothek und Trennung zwischen Entwurf und Weltobjekt |
| Kreaturen-/Gebäude-/Fahrzeug-/Schiffbereiche | Gemeinsame Typadapter, echte Vorschau, Kompatibilität und jeweiliger Verwendungsablauf |
| Oberfläche und Sprache | Suche, Vorschau, verständliche Anforderungen, Download-/Verwendungsaktionen und Übersetzungen |
| Community-Dienst | Upload/Download, Katalog, Autorenverwaltung und Veröffentlichungsrevisionen |
| Integration | Zusammenspiel mit Freischaltungen, Baukosten, Save/Load und bestehenden Kampagnen prüfen |

## 7. Reihenfolge und konkrete Aufgaben

BP-COMMUNITY ist phasenübergreifend und wartet nicht auf die Weltraumphase. Das portable Format wird früh mit den Editorverträgen abgestimmt. Der erste vollständige Community-Ablauf kann für Kreaturen geliefert werden; Gebäude, Fahrzeuge und Schiffe folgen jeweils mit ihren spielbaren Systemen. Die laufenden Kugelumzugsaufträge behalten Vorrang.

| ID | Status / Aufgabe | Voraussetzung | Abnahme |
|---|---|---|---|
| BP-COMMUNITY.1 | **Integriert für Kreaturen:** portables Bauplanpaket und gemeinsamer Import-/Exportvertrag | M2B, vorhandene Entwurfs-/Teilekennungen | Gültiges Kreaturendesign zwischen getrennten Installationen/Spielständen übertragen; Farben, Teile und Anschlüsse erhalten; keine fremden Kampagnendaten übernehmen |
| BP-COMMUNITY.2 | **Integriert für Kreaturen:** lokale Designbibliothek und passende Startvorlagen | BP-COMMUNITY.1, vorhandene Vorschau/Verwendung | Eine Vorlage ohne Editorarbeit auswählen und im erlaubten Ablauf nutzen; speichern, neu starten und offline wiederverwenden |
| BP-COMMUNITY.3 | **Geplant:** Community-Dienst und Veröffentlichung | BP-COMMUNITY.1, Identitäts-/Katalogvertrag | Nutzer A veröffentlicht ein geprüftes Design mit Vorschau; Eintrag ist auffindbar; neue Revision und Rücknahme sind eindeutig |
| BP-COMMUNITY.4 | **Geplant:** Galerie, Download und unmittelbare Nutzung | BP-COMMUNITY.2/.3, funktionsfähiger erster Typadapter | Nutzer B lädt das Design in einen unabhängigen Spielstand, verwendet es ohne eigenen Bau im Editor und behält es nach Neustart/offline |
| BP-COMMUNITY.5 | **Geplant:** zusätzliche Bauplanarten und langfristige Kompatibilität | Vollständiger erster Community-Ablauf und jeweils spielbares Fachsystem | Gebäude/Fahrzeuge/Schiffe über denselben Weg verwenden; Technik-/Kosten-/Hangarregeln, Versionswechsel und Altstände prüfen |

**Gemeinsame Abnahme:** Zwei unabhängige Nutzer bzw. Installationen teilen einen Entwurf über den Online-Katalog. Der Empfänger findet, prüft, lädt und verwendet ihn ohne eigene Editorarbeit. Herkunft, Vorschau und Design bleiben korrekt; eigenes Spielwissen, Besitz und Fortschritt werden nicht überschrieben. Downloads funktionieren nach Übernahme auch ohne Verbindung. Eine später veröffentlichte oder entfernte Revision ändert keine vorhandenen Spielobjekte ungefragt.

# M4-WILDLIFE-HUNTING · Jagd und Aasfressen

Basis: `df3aab820a92fa0f62ae52ccf557a6c70e6f1851`,
`agent/m4-social-play-20260916` / PR #128.
Branch: `agent/m4-wildlife-hunting-20260916`.
Gestapeltes Fachpaket: zuerst #128 integrieren; kein Merge und keine Gesamtfreigabe.

## Spielablauf

Hungrige Raubtiere suchen sichtbare wilde Pflanzenfresser, verfolgen sie mit der
vorhandenen Hindernissteuerung und beißen innerhalb der bestehenden Reichweite
und Abklingzeit. Beute nutzt ihre vorhandene Flucht-/Schadensreaktion. Ein Tod
hinterlässt den bestehenden endlichen Kadaver. Raubtiere und Aasfresser gehen zu
solchem Aas und übertragen höchstens zehn Nahrungseinheiten pro 0,8 Sekunden in
ihre Sättigung. Ab 75 Sättigung endet die Mahlzeit mit acht Sekunden Ruhe.
Aasfresser beginnen keine Jagd auf lebende Tiere. Jagden können scheitern;
Reichweite, Revier, Sicht, Boden und Fortschritts-/Zeitgrenzen gelten weiterhin.

In neu generierten trockenen Regionen wird ein deterministischer Anteil von
1/16 der gewöhnlichen Bewohner zum Aasfresser. Die Raubtierquote bleibt 1/4.
Bereits erzeugte Regionen, gespeicherte Rollen, IDs und eingefrorene Körper
werden nicht neu ausgewürfelt. D1-Pflichtarten bleiben vollständig unverändert.
Die drei neuen Zustandsbeschreibungen sind auf Deutsch und Englisch vorhanden.

## Bestehende Besitzer und Schutzregeln

- `hunting_brain.gd` liegt zwischen Trinken und Sozialspiel. Gefahr, Heimkehr,
  laufende Wasserbeschaffung und ausdrückliche Aufmerksamkeit haben Vorrang.
  Satte Tiere können weiterhin das Sozialspiel aus #128 verwenden.
- Hunger liegt im bestehenden `foraging`-Bedürfnis; Tod/Gesundheit/Aas im
  bestehenden Begegnungsdatensatz, auf der Kugel im regionalen Tierrecord.
  Keine neue Save-Version, Währung, Belohnung oder Populationsverwaltung.
- Pflichtarten, eigene Spezies, Artgenossen, Freunde und registrierte/beanspruchte
  Tiere werden nicht als Nahrung gewählt. D2 wird über seinen aktiven
  `current_registry()`-Port und den gespeicherten Körperbestand gelesen.
- Eine Mahlzeit bestätigt beide Bestände im gemeinsamen SaveService-Snapshot.
  Fehler nehmen Nahrung und Sättigung zurück; konkurrierende Fresser können
  endliches Restfutter nicht verdoppeln. Der Stammes-Gesundheitsanschluss erhält
  dafür einen optionalen sofortigen Commit ohne Spielerbelohnung.
- Ein gescheiterter Gesundheits-/Nahrungssave ohne Kampagnenereignis ersetzt
  nicht mehr das ganze Kampagnenobjekt: sonst würden Hungerreferenzen anderer
  geladener Tiere veralten. Ereignis-/Belohnungstransaktionen behalten ihre
  bisherige vollständige Rücknahme.
- Jagdziel, Bisszeit und Sperrliste sind flüchtig. Laden, Entladen, Tod, Pause,
  Simulationsgeschwindigkeit null, ungültiger Körper und gesperrtes Schreiben
  erzeugen weder Bisse noch Mahlzeiten. Kein Offline- oder Fernjagen.
- Die vorhandene Nachbarsuche sammelt höchstens 32 lebende Tiere/Kadaver;
  die Jagdauswahl untersucht höchstens acht Kandidaten je Wahrnehmungstakt.
  Höchstens acht zuletzt unerreichbare Ziele werden zwölf Sekunden gemieden.

## Prüfung und Integration

Die neuen Tests sind einmal unter `wildlife` in der gemeinsamen Testzuordnung
registriert. Der Physikprüfstand verwendet echte Kreaturenszenen und beobachtet
Verfolgung, Flucht, Tod und Mahlzeit. Für den erfolgreichen Jagdfall wird eine
langsamere Beute eingestellt; das ist kein Beleg, dass jede Jagd gelingt.
Weitere Fälle: Freunde/Besitz/Pflichtarten/Körper/Spezies, Aufmerksamkeit,
Sättigung, Sichtwand, fehlender Boden, Stillstand, entferntes Ziel, feste
Suchbudgets, Pause, konkurrierende Verbraucher, Schreibfehler in Phase 0/1
sowie echter Save und frischer Godot-Prozess.

Die Weltprüfung startet den regulären Kugel-Spielweg. Sie erzeugt Tiere über
den bestehenden Regionsgenerator und stellt einen Kadaver sowie einen hungrigen
Aasfresser auf geladenem Radialgelände bereit. Anschließend laufen Annäherung,
Fressen, Fehler-Rücknahme, Entladen/Wiedererscheinen und ein Prozessneustart über
den echten regionalen Speicher. Sie ist kein zufälliger Populations-Langzeittest.

Direkte Verbraucher: vorhandene Wildtier-KI, Pflanzenfressen, Trinken,
Sozialspiel und Kreatureninteraktionen einschließlich Belohnungs-Rollback.
Ergebnisse, Befehle, Quell-Tree und unveränderte Logs werden im Paketnachweis
unter `evidence/m4-wildlife-hunting` festgehalten.

Gemeinsame Anschlüsse sind `ProgressionService`, `CampaignPopulation`, der
Begegnungskomponent, die bestehende Wahrnehmung, Katalog/PO und Testregistrierung.
Katalog- und Testlisten mit parallelen Paketen additiv vereinigen; PO-Dateien
aus dem vereinigten Katalog regenerieren. Zentrale Status-/Backlog-Dateien liegen
weiter beim Integrationschat. Der neue Merge-Tree braucht seine Integrationsprüfung.

Offen bleiben gerenderte/native Ziel-PC-Abnahme, Langzeitbalance der Population
und Messung der Snapshotkosten bei vielen gleichzeitig fressenden Tieren.
Headless-Fachprüfungen sind keine Export-, Gesamt- oder FPS-Freigabe.

Abgeschlossen: alle sieben gezielten Tests bestanden, inklusive 42 neuer
Jagdprüfungen und vollständigem Kugel-Neustartnachweis. Details und unveränderte
Logs: [evidence/m4-wildlife-hunting](../evidence/m4-wildlife-hunting/README.md).

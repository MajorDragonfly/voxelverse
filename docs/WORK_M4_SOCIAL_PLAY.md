# M4-SOCIAL-PLAY — gegenseitiges Spiel der Wildtiere

Basis: `d57b1ef385728728b132518a1ea05683888dcae0` aus PR #125,
Branch `agent/m4-social-play-20260916`.

## Verhalten im Spiel

Gesunde, versorgte Wildtiere derselben Art können sich in der Kreaturen- und
Stammesphase selbstständig begegnen: annähern, einander zuwenden, mit kurzen
seitlichen Schritten abwechselnd zum Spielen auffordern und gemeinsam ruhen.
Der vorhandene Ausdruckstreiber zeigt Neugier, Zuneigung, Verspieltheit und
Zufriedenheit. Die Begrüßung nutzt das vorhandene Freundschaftslaut-Ereignis.
Vier Zustandsanzeigen stehen auf Deutsch und Englisch bereit.

Voraussetzungen: dieselbe stabile Körper-/Artidentität, derselbe aktive
Physikraum, freie Sicht, geladener Boden, maximal sieben Meter Suchdistanz,
mindestens 70 % Gesundheit sowie jeweils 60 % Sättigung und Flüssigkeit.
Laufende Nahrungssuche, Wasserbedarf, Erholung nach einer Mahlzeit, Gefahr,
Heimkehr und ausdrückliche Spieleransprache haben Vorrang. Vorhandene
Raubtiere können außerhalb ihrer Gefahr-/Verfolgungsreaktionen ebenfalls
untereinander spielen. Wasserlebewesen und gezähmte Arbeitstiere gehören
nicht zu diesem Erstumfang.

Annäherung höchstens fünf Sekunden; Begrüßung 1,3 Sekunden, Spiel 4,8 Sekunden,
Ruhe 1,2 Sekunden. Nach Abschluss oder Abbruch folgen zwölf bis 22 Sekunden
individuelle Abklingzeit. Beim Erscheinen eines Tiers verhindern fünf bis neun
Sekunden Anfangsruhe sofortige Begegnungsketten. Abstände berücksichtigen die
bestehenden Kollisionsradien, mindestens 2,4 Meter. Kein Teleport, Sprungimpuls
oder Kampfschaden; die vorhandene Lenkung prüft Boden, Hindernisse und Wasser.

## Besitz, Prioritäten und Lebenszyklus

`social_play_brain.gd` erweitert den vollständigen Trink-/Fress-/Gefahrablauf
am bestehenden Wildtier-Szeneneinstieg. Die vorhandene Wahrnehmung stellt
höchstens 32 Nachbarn bereit; die zusätzliche Partnersuche betrachtet pro
Versuch höchstens acht davon, maximal einmal je Simulationssekunde. Es gibt
keine zweite Gruppensuche, keinen neuen Populationseintrag und keine
Archivabfrage für die Partnersuche.

Zwei Tiere teilen genau ein flüchtiges `WildlifePlaySession`-Objekt. Schwache
Referenzen halten keine entfernten Szenen am Leben. Ein Teilnehmer schreibt
die Sitzungszeit höchstens einmal pro Physikframe; beide können abbrechen.
Ein drittes Tier kann einen gebundenen Partner nicht übernehmen. Die Richtung
wird aus aktuellen Positionen und der radialen Hochachse berechnet, daher
entsteht beim Ursprungswechsel kein veraltetes absolutes Spielziel.

Tod, Verletzung, Bedarf, Bedrohung, Ansprache, Phasen-/Körperwechsel,
Deaktivierung, Entfernung, verlorener Boden oder Sichtkontakt lösen beide
Teilnehmer. Fehlender Wegfortschritt ist zeitlich begrenzt. Pause und
Simulationsgeschwindigkeit null frieren Ablauf und Bewegung ein. Laden
verwirft die flüchtige Begegnung und setzt die Anfangsruhe zurück.

Bestehende Beziehung, Gesundheit, Punkte, Entdeckungen, Tieridentitäten,
Körpermodelle und Speicherformate bleiben bei ihren bisherigen Besitzern.
Das Spielen verbraucht keine zusätzlichen Ressourcen und erzeugt keine Boni;
die bestehenden Hunger-/Durstuhren laufen normal weiter. Ein Neustart erhält
die gespeicherten Bedürfnisse und Identitäten, ohne eine alte Spielpose oder
einen alten Partner wiederherzustellen.

## Prüfung und Übergabe

`wildlife_social_play_test` ist genau einmal unter `wildlife` registriert.
Er prüft den tatsächlichen vollständigen Bewegungsablauf mit Kollisionsboden,
Unterbrechungen für beide Teilnehmer, Wand-/Sichtprüfung, Dritttierkonkurrenz,
Art-/Körpergrenzen, Pause, Entfernung, Speichern/Laden und einen frischen
Godot-Prozess. Hinzu kommen DE/EN, radiale Richtungen/Ursprungsverschiebung
sowie die gemeinsame Uhr bei 30/60/120 Hz. Bestehende direkte Verbraucher:
`wildlife_ai_test`, `wildlife_foraging_test`, `wildlife_drinking_test`,
`creature_expression_test`, `spherical_creature_test`.

```sh
python3 tools/validate_godot.py --godot /pfad/zu/godot --skip-main \
  --tests wildlife_social_play_test wildlife_ai_test wildlife_foraging_test \
  wildlife_drinking_test creature_expression_test spherical_creature_test
```

Die lokale Prüfung erfolgt mit Godot 4.6.3 unter Linux/headless, isolierten
synthetischen Nutzerdaten und Quellenbeobachtung. [Protokolle und genaue
Quellzuordnung](evidence/m4-social-play/README.md). Headless-Bewegungs- und
Posenprüfungen ersetzen keine optische/Hörabnahme im nativen Windows-Spiel
oder FPS-Messung auf dem Ziel-PC.

Gemeinsame Schreibbereiche: zwei Zeilen Nachbaranschluss im Basishirn,
Wildtierszeneneinstieg, vier Ausdruckszuordnungen, vier additive
Katalogmeldungen mit generierten PO-Dateien und genau ein Testregistry-Eintrag.
ATMOSPHERE-SETTINGS-DETAIL, WEATHER-02 und Planetenrenderarbeiten bleiben bei
ihren parallelen Besitzern. Die Integration erhält deren unabhängige
Katalog-/Testergänzungen und aktualisiert die zentralen Status-/Backlogseiten.

Offene Folgearbeit: optische/Hörabnahme der Bewegung im Spiel, weitere
artspezifische Spielmuster sowie Streicheln durch Stammesbewohner. Langfristige
Tierfreundschaften, Fortpflanzung und Arbeitstierbefehle werden hier nicht
vorweggenommen. Kein automatischer Merge.

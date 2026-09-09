# Verhaltensfortschritt über alle Spielphasen

Planungsstand 9. September 2026. Kreaturenhandlungen und vier unmittelbare Fähigkeiten werden im zugehörigen Gameplay-Paket angeschlossen. Die folgenden fünf Phasen sind hier **Entwurf**, keine freigeschalteten Spielmodi. Der Skilltree zeigt die Vorschau und tatsächlich gekaufte Vermächtnisse an.

## Gemeinsame Regeln

Jede Phase besitzt ihren eigenen Sozial- und Aggressionsbestand. Alte Punkte bleiben im alten Baum ausgebbar; sie werden nicht in Geld, Ressourcen oder die Punkte der nächsten Phase umgewandelt. Beide Wege lassen sich kombinieren. Verdienst setzt einen abgeschlossenen, bedeutsamen Vorgang voraus, keinen Klick, Schadenstick oder laufenden Produktionszyklus.

Ein Knoten wirkt entweder in seiner Phase oder über ein ausdrücklich definiertes Vermächtnis. Die aktuellen Kreaturenfähigkeiten enden mit der Kreaturenphase. Gemeinsinn und Wehrhaftigkeit liefern ab Stamm jeweils +10 % auf Gruppenkoordination bzw. Gruppenverteidigung; bisher existiert die geprüfte Berechnung, die jeweiligen Gruppenverbraucher folgen mit der spielbaren Phase. Keine Boni nach Laden erneut auf gespeicherte Endwerte aufaddieren. Körperfähigkeiten, Technik und Verhaltenswahl bleiben getrennte Quellen.

Die zwei späteren Knoten je Ast sollten zunächst eine praktische Spezialisierung und einen bewusst gewählten Langzeiteffekt bieten. Konkrete Kosten und weitere Bonuswerte werden erst festgelegt, sobald die zugehörigen Spielhandlungen testbar sind. Der Kreaturenprototyp mit 24 Punkten je Ast wird nicht ungeprüft auf eine ganze Galaxie übertragen. Änderungen persistenter Kaufkosten benötigen Regelversion und Migration.

## Geplanter Ausbau

| Phase | Sozialer Weg | Aggressiver Weg | Spielerwirkung und nächste Übergabe |
|---|---|---|---|
| Stamm | Gemeinsame Versorgung, Hilfe für Nachbarn, abgeschlossenes Bündnis | Lager verteidigen, Jagdgruppe führen, begrenzten Stammeskonflikt entscheiden | Kooperation/Unterstützung oder Ausdauer/Verteidigung der Gruppe. Bekannte Spezies, echte Mitglieder, Heimatort und Beziehungen in die Siedlung übergeben. |
| Antike / Mittelalter | Erfüllte Handelsabkommen, Siedlungshilfe, ausgehandelter Frieden | Belagerung abwehren, Feldzug mit definiertem Ziel abschließen | Diplomatie, Versorgung oder militärische Organisation. Institutionen, Siedlungen und Besitz werden zur Grundlage des Staates. |
| Weltmacht | Internationale Kooperation, belegte humanitäre Hilfe, gemeinsame Forschung | Eigene Gebiete schützen, strategische Konfliktziele erreichen | Wirtschaftsverbünde und diplomatische Reichweite oder Logistik und Verteidigung. Staaten behalten Kolonien, Verträge und Technologie beim Eintritt ins All. |
| Weltraum | Erfolgreicher Erstkontakt, Koloniehilfe, interstellare Vereinbarung | Kolonie verteidigen, Konflikt um ein System entscheiden | Zivilisationsnetzwerke und friedliche Expansion oder Flottenkoordination und Grenzschutz. Reale Galaxie-, System- und Körperkennungen statt lokaler Koordinaten verwenden. |
| Multiversum | Gemeinsame Expedition, Abkommen zwischen Universen | Universenübergreifende Bedrohung mit definiertem Ziel abwehren | Langfristige Richtungswahl auf bestehender Zivilisation. Konkrete Mechanik erst nach erprobter Weltraumphase bestimmen. |

## Belohnungen müssen mit der Größe des Spiels mitwachsen

Die Kreaturenphase belohnt ein Individuum höchstens einmal. Für spätere Phasen ist das allein zu grob: Derselbe Nachbar kann über eine lange Kampagne mehrere echte Handelsverträge erfüllen. Dort wird eine stabile Auftrags-/Vertrags-/Konfliktkennung zur Belohnungseinheit, mit beteiligten Fraktionen und belegtem Ausgang. Kein wiederholtes Kündigen/Neuschließen desselben Vertrags zum Punkten; keine selbst verursachte Notlage, die anschließend als Hilfe zählt; kein einzelner Treffer als gewonnener Krieg.

Die jetzige Ereignisschnittstelle bleibt die Grundlage. Jeder Phasenproduzent muss vor seiner Freigabe eigene Abschlussbedingungen, Wiederholungsregeln, Obergrenzen und gespeicherte Belege erhalten. Deshalb weist das heutige Modell Belohnungsereignisse außerhalb der Kreaturenphase weiterhin ab. Eine Phasenauswahl in der Vorschau verändert weder Kampagne noch Spielstand.

## Nächster echter Phasenwechsel: Kreatur → Stamm

1. Nestgruppen-Chat liefert reale Mitglieder mit Herkunft, Heimat und steuerbaren Befehlen. Eine befreundete fremde Wildtierart wird nicht automatisch zur eigenen Spezies oder zum Stammesmitglied.
2. Ein kleiner spielbarer Stamm kann sammeln, versorgen, bauen und auf einen Nachbarn reagieren. Erst dann gibt es sinnvolle Stammespunkte und konkrete Skilltree-Knoten.
3. Übergangsvoraussetzungen folgen aus diesem Spielablauf und besitzen erreichbare soziale, aggressive und gemischte Wege. Punktesummen allein dürfen keine unfertige Phase öffnen.
4. Der vorhandene atomare Phasenübergang übernimmt Spezies-ID, Fraktions-ID, Ort, Mitglieder, Besitz, Beziehungen, alte Wallets und Käufe in einem Snapshot. Ein unterbrochener Übergang darf weder doppelte Mitglieder noch verlorene Vermächtnisse erzeugen.
5. Die erste Gruppenhandlung fragt `group_cooperation` bzw. `group_defense` ab. Erst ihre gemessene Anwendung rechtfertigt im UI den Status „aktiv“ für das Vermächtnis.

Abnahme: soziale, aggressive und gemischte Ausgangslage jeweils vollständig spielen; Wechsel während Speichern/Neustart prüfen; alte Beziehungen und Bestand vor/nach vergleichen; fremde Körper-/Fraktionskennungen ablehnen; Effekte mit und ohne Vermächtnis messen. Der normale Übergang bleibt bis zu dieser Abnahme gesperrt.

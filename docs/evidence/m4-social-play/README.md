# M4-SOCIAL-PLAY — Prüfnachweis

Implementierung: `ff0bdf618595fd9fd463845f6c0aa363fb1038e6`.
Quell-Tree: `14b66f45b540f3dd5ae33353979131adb6fb310c`.
Basis: `d57b1ef385728728b132518a1ea05683888dcae0` (PR #125).

## Ergebnis und Prüfumfang

Sechs Fachtests sowie Quell-/Sprachgate erfolgreich. Godot
`4.6.3.stable.official.7d41c59c4`, Linux/headless, isolierte synthetische
Nutzerdaten je Test. [Originaler Ergebnisbericht](focused/results.json).

| Test | Ergebnis |
|---|---|
| wildlife_social_play_test | 76 Bedingungen, echter Bewegungsablauf und erfolgreicher neuer Godot-Prozess |
| wildlife_ai_test | Bestehende Gefahr-, Sicht-, Gruppen-, Heimkehr- und Hindernisabläufe bestanden |
| wildlife_foraging_test | Bestehende Nahrungssuche/-aufnahme und Persistenz bestanden |
| wildlife_drinking_test | Bestehende Wasser-, Prioritäts-, Speicher- und Pausenprüfungen bestanden |
| creature_expression_test | Vorhandene Ausdrücke, Begrüßung, Lebenszyklus und Neustart bestanden |
| spherical_creature_test | Vorhandener echter Kugelablauf mit Scan, Editor-Rückkehr, Heimat, Wasser und Audio bestanden |

Der neue Bewegungsfall durchläuft Annäherung, Begrüßung, Spiel und Ruhe.
Beobachteter kleinster Abstand 2,433 m, gelaufene Strecke eines Teilnehmers
6,372 m. Beide Tiere bleiben am Boden; der Ablauf endet regulär und erzeugt
weder Gesundheit noch Beziehung, Punkte oder Entdeckungen. Diese synthetischen
Bewegungswerte sind kein FPS- oder optischer Qualitätsnachweis. Geometrische
Richtungen sind unter gedrehter Hochachse und Ursprungsverschiebung geprüft;
der vorhandene Kugeltest prüft den gemeinsamen Szeneneinstieg. Eine neue
vollständige Langzeit-/Reise-/Windows-Abnahme wird nicht behauptet.

Import und Art-Quellgate bestanden im [ersten Lauf](initial/results.json).
Die späteren Läufe verwenden denselben bereits importierten Ressourcenstand
mit `--skip-import`. Neue Skript-UIDs entstanden beim ersten Import. Die
folgenden Änderungen betrafen nur Skriptlogik und Testvorbereitung.

## Quellzuordnung

Der erfolgreiche Fachlauf erfolgte vor dem Quellcommit auf der genannten
Basis mit identifizierten Arbeitsänderungen. Sein Quellfingerprint war
`031a9b1b2277fd0377b2aca9e7c9d1354077ab0e51271b64b5c640f241c7af99`.
Start- und Endmanifest sind bytegleich; das [vollständige Startmanifest](focused/source-files-start.jsonl)
wird einmal aufbewahrt. Vor dem Commit wurden alle 3.411 beobachteten Pfade
gegen dieses Manifest abgeglichen. Der Quellcommit enthält exakt diese
Implementierung und Tests; anschließend war der Arbeitsbaum sauber.
[Zuordnung und Dateihashes](source-map.json).

Der folgende Dokumentationscommit ergänzt ausschließlich diese Nachweise und
die Paketübergabe. Die Originalberichte behalten ihren tatsächlichen
Basiscommit, die damaligen Arbeitsänderungen und Originalpfade. Es wird kein
nachträglicher sauberer Testlauf auf einem anderen Commit vorgetäuscht.

## Erhaltene Erstbefunde

Im ersten neuen Testlauf funktionierten vollständiges Spiel und Neustart.
Einige als gesund gedachte Testtiere starteten durch das vorhandene,
seedabhängige Begegnungssystem bereits mit 55 % Gesundheit und wurden von der
70-%-Bedingung korrekt abgewiesen. Die Fixture setzt für positive Spieltests
jetzt explizit volle Gesundheit; ein eigener Verletzungsfall prüft den Abbruch.
Der vereinfachte Beobachter hatte außerdem nicht den Vertrag eines angreifenden
Spielers (`bite_reach`); der Gefahrfall verwendet nun einen echten externen
Angriff über den vorhandenen Tieranschluss. Bedingungen an Gesundheit oder
Gefahr wurden nicht gelockert. [Initiale Logs](initial/wildlife_social_play_test.log)
und [Diagnoselauf](diagnostic/wildlife_social_play_test.log) bleiben erhalten.

Optische/Hörabnahme, nativer Windows-Export und Leistung auf Lars' Ziel-PC
bleiben offen. Atmosphere Detail und Weather 02 sind nicht Teil dieses Pakets.

# Auftrag 4 – D2 Zähmung

Stand: 9. September 2026.

**Ergebnis: D2-Prüfszene und überprüfter D1-Adapter fertig. Die vollständige
Kampagnenintegration bleibt offen.** Zu Beginn fehlte D1. Während der Arbeit
wurde sein separat versionierter Datenvertrag verfügbar und gezielt geprüft.
Die noch laufende Generator-/Spawnarbeit und eine produktive Freigabe der
Fauna in Phase 1 wurden nicht übernommen.

## Stand und Branch

- Gemeinsame Ausgangsbasis: `3a3e0272375e556f3ff65b7370582af79a9d48b5`.
- Fachbranch: `agent/d2-domestication`.
- Veröffentlichter Implementierungscommit:
  `75abefa2a15e7b6dffaafb840e3199489c3cc296`.
- Exakt gleicher lokal geprüfter Dateibaum:
  `8c3c0e22fb87f3fe0fb9f00f53b4b094a2cbc424`
  (lokaler Implementierungscommit `a287520b268511a4936b5ec6831696dc1e402427`).
- Unverändert übernommener D1-Teilvertrag:
  `bb43b61482ab129b72a66b5299a6bfec80a1e128`,
  lokal als `0a815b9` übernommen. Bei Integration nach D1 dessen identische
  fünf Vertragsdateien berücksichtigen; keine zweite Eignungsimplementierung.
- Kein Merge nach main; ROADMAP.md bleibt beim Integrationschat.

## Spielbarer Ablauf im Labor

1. In Godot 4.6.3 `world/domestication/lab/domestication_lab.tscn` öffnen und
   mit F6 starten, alternativ:

   `godot --path . res://world/domestication/lab/domestication_lab.tscn`

2. Die Szene startet in der Stammesphase. Mit WASD/Pfeiltasten den blauen
   Betreuer zum fremden Tier führen. Viermal „Futter anbieten“, jeweils zwei
   Sekunden in Sicht und höchstens 4,5 m entfernt bleiben.
3. Pro abgeschlossener Gabe sinkt der Vorrat um eine Wurzel und steigt
   Vertrauen um 25. Erst bei 100 erhält das konkrete Tier den Besitzer.
4. Folgen, Warten und Heimkehr ausführen. Der graue Fels blockiert Sicht und
   Bewegung; der gelbe Platz ist die gespeicherte Heimat.
5. Speichern, Szene schließen und erneut öffnen. ID, fremde Art, Körperbezug,
   Ort, Besitzer, Vertrauen, Auftrag und Vorräte bleiben erhalten.
6. Die Prüfschalter zeigen die Grenzen: Phase 0, falsches Futter, Befreunden,
   Flucht, Abbruch, Schaden/Tod. „Prüfstand zurücksetzen“ betrifft nur das Labor.

Die Szene speichert unter `user://d2_lab/snapshot.json`, mit .bak und
geprüfter temporärer Datei. Für isolierte Läufe kann nach `--` ein
`--d2-save <Datei>` übergeben werden. Die reguläre Kampagne wird nicht
geschrieben; auch ihr Schließ-Autosave ist in dieser Szene deaktiviert.

## Verträge und geänderte Dateien

Der vollständige Vertrag steht in [D2_DATA_CONTRACT.md](D2_DATA_CONTRACT.md).
Neue Produktionsbausteine innerhalb des D2-Pakets:

- `world/domestication/animal_state.gd`: Version 1, Validierung und stabile
  individuelle Identität, eigener Besitz ohne Bürgerstatus.
- `world/domestication/domestication_controller.gd`: Zähmung, Kostenübergabe,
  Vertrauen, Unterbrechung, Befehle, Tod, Registerkopien und bestätigte Ereignisse.
- `world/domestication/d1_taming_policy.gd`: Lesender Adapter auf D1 Vertrag 1.
- `world/domestication/lab/`: begrenzte Physikszene, Testkörper, eigenes
  Prüfstandspeichern und Bedienung; nicht als Kampagnen-Autoload einbauen.
- Drei neue Tests: `domestication_state_test.gd`,
  `domestication_lab_test.gd`, `domestication_d1_adapter_test.gd`.
- Unveränderter D1-Vertrag mit Dokumentation und `domestication_contract_test.gd`.

Keine Änderungen an autoload/, project.godot, Stamm, Wildtierbasis,
Begegnungsdatenbank, Kreatureneditor oder Kampagnenspeicherschema.
Keine automatische Art-/Objektneugenerierung und keine Bürgerrekrutierung.

## Nachweise

Godot `4.6.3.stable.official.7d41c59c4`; alle vier abschließenden Läufe
erfolgreich, ohne Scriptfehler oder Objektlecks:

| Prüfung | Ergebnis |
|---|---|
| D1-Vertrag | Eignung der drei Rollen, Grenzen, neue Versionen, Körperdaten-Rundlauf |
| D2-D1-Adapter | 17 Prüfungen: echte D1-Nahrung/Lernfähigkeit, fehlende/ungeeignete Arten, keine Mutation |
| D2-Zustand | 73 Prüfungen plus zweiter Godot-Prozess: Identitäten, Kosten, Besitzer, Aufträge, Reservierung, Tod, Abbruch, Speicherfehler |
| D2-Szene | 21 Prüfungen: echte Physik, Sicht, Füttern/Pause, Folgen/Warten/Heimkehr, Laden/Tod, unveränderte Kampagne |

Der Neustarttest lädt eine Gabe bei 0,75 Sekunden und 25 Vertrauen, setzt
ohne doppelte Kosten fort und erreicht Besitz mit genau vier verbrauchten
Wurzeln. Er prüft danach gespeicherte Befehle/Besitzer. Weitere Prüfungen
decken unvollständige .tmp-Dateien, beschädigte Hauptdatei, gültige Sicherung,
neuere Schemata und echte Schreibfehler ab.

| Physikmessung | Wert |
|---|---:|
| Weg bis zum Betreuer | 5,777 m |
| Restabstand beim Folgen | 1,596 m |
| Drift bei Warten | 0,000 m |
| Ortsänderung bei Heimkehr | 14,241 m |
| Restabstand am Heimatplatz | 0,355 m |
| Hindernis durchquert | nein |

Maschinenlesbarer Bericht: [validation/d2.json](validation/d2.json).
Reproduktion:

```sh
python tools/validate_godot.py --godot <Godot-4.6.3> --skip-main --tests domestication_contract_test domestication_d1_adapter_test domestication_state_test domestication_lab_test --output <Pruefordner>
```

## Grenzen und nächste Integration

- Die vollständig generierten D1-Arten/Vorkommen sind noch nicht angebunden.
  Der Vierbeiner ist ein klar benannter Testkörper mit D1-Beispieleignung.
- Aktive Stammesfauna fehlt in der gemeinsamen Basis teilweise: Wildtier-KI,
  Nahrung, Trinken und soziale Schadensspeicherung haben Phase-0-Grenzen.
  Diese Lieferung entfernt sie nicht pauschal und reaktiviert keine alten
  Spielerangriffe auf einen Gruppen-Cursor.
- Der Integrationschat muss dieselbe Wildtier-object_id an D2 übergeben,
  alte/wilde Zustandsbesitzer und erneutes Spawnen dieser ID sperren und
  Tierregister sowie tatsächliche Stammesvorräte gemeinsam speichern.
- Ein realer Stammesbewohner muss als Betreuer dienen. Der Laborbetreuer
  dient nur dem kontrollierten Bewegungsnachweis.
- Hunger/Durst sind reservierte Zustandsfelder; Versorgung, Milch,
  Fortpflanzung, Reiten und Pflügen gehören zu D3/D4.
- Navigation ist ausschließlich für die begrenzte Laborebene geprüft.
  Die Kugeloberfläche benötigt ihren eigenen Adapter.
- Grafische manuelle Abnahme unter Windows ist noch offen. Die Prüfungen
  liefen headless; es wird kein fertiger Windows-Spielbuild behauptet.

Für die Roadmap: D2 **vorbereitet und geprüft**, produktive D2-Abnahme erst
nach D1-Spawnanschluss, freigegebener Phase-1-Fauna und gemeinsamem Save/Load.

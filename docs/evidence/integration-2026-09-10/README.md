# Gemeinsame Integrationsnachweise vom 10. September 2026

Der [Integrationsbericht](../../INTEGRATION_2026-09-10.md) ordnet die Ergebnisse ein. `summary.json` benennt Quellen, Laufzeit, Umfang und Grenzen; `godot-checks.json` enthält sämtliche ursprünglichen Checks und die gezielten Wiederholungen. Die ursprünglichen Fehler bleiben dokumentiert. `*-passed.log` enthält die abschließenden Spiel-/Neustartmarker; vollständige Python-Toolausgaben stehen in `python-tooling.log`. Die gekürzten Godot-Protokolle entfernen lediglich Ressourcen-Lademeldungen, keine Fehler- oder Ergebniszeilen.

Die 151 Godot-Tests liefen in vier getrennten Prozessen mit jeweils isolierten Speicherverzeichnissen. Start, Abschaltung während verschiedener Ladestufen und Streaming wurden separat geprüft. Nach Änderungen an den zwei Prüfabläufen wurden deren reale Kampagnenketten gezielt wiederholt. Headless-Messungen sind kein Nachweis für Grafikqualität, native Exportpakete oder 1080p60 auf dem Ziel-PC.

## Wiederholen

Godot 4.6.3 verwenden. Die Quellprüfung übernimmt Vertragszuordnung, Sprachkatalog, Import, Art-Quellen und Fehler-/Timeout-Erkennung. Ein vollständiger serieller Durchlauf ist möglich mit:

```sh
python tools/validate_godot.py --godot /pfad/zu/Godot_4.6.3 --output /tmp/voxelverse-validation
```

Die Python-Prüfung benötigt für ihre tatsächlichen Godot-Neustartfälle zusätzlich `GODOT_BINARY`, `ATLAS_BACKUP_PROJECT` und `PLACE_BACKUP_PROJECT`. Für den Schema-2-Vergleich wurde der unveränderte Quellstand `57a330fc5e064ea0cda221e2f8e86140e8685f8f` importiert; `PLACE_BACKUP_PROJECT` verweist auf den aktuellen Integrationscheckout. Mit diesen gesetzten Variablen:

```sh
python -m unittest discover -s tests/tooling -p '*_test.py' -v
```

Die korrigierten Kampagnenfälle können separat laufen:

```sh
python tools/validate_godot.py --godot /pfad/zu/Godot_4.6.3 --skip-import --skip-main --output /tmp/voxelverse-campaigns --tests egg_species_campaign_test spherical_gameplay_test
```

Die Reiseprüfung lässt tatsächlich gespielte Frames kurzzeitig mit zwei Frames pro Sekunde laufen, um offene Fernsimulationszeit zuverlässig auszulösen. Sie verändert keine Kampagnenzeit direkt und baut kein künstliches Tier-/Produktionsregister. Der vollständige Ablauf erzeugt Tier, Tierplatz und Milch über echte Spielbefehle, prüft misslungene Speicherung, Pause, A–B–A, frische Prozesse und die abschließende körperliche Einlagerung der Milch.

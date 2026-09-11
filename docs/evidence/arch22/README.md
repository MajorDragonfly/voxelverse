# ARCH-22 – Prüfnachweise

[Übergabe und Bedienung](../../WORK_ARCH22_EGG_PRODUCTION.md). Veröffentlichter Implementierungscommit: `68bf25e0f39175c96c29c42dae027e2fb9105d56`, geprüfter Dateibaum: `b6d44cf52b45e76b127e807ec6d85a9f1519cfbe`.

`summary.json` enthält die 13 verschiedenen bestandenen Headless-Tests, Import-/Art-/Vertragsprüfung, konkrete Reisebilanzen, Diagnosevorläufe und SHA-256-Prüfsummen der Implementierungsdateien. Die unveränderten `runner-*.json` dokumentieren die tatsächlichen Teilaufrufe. `logs/*.log.gz` sind die vollständigen komprimierten Originalprotokolle; `log_sha256` bezieht sich auf die dekomprimierten Bytes. Die Gesamtzahl 154 benennt registrierte Tests, nicht eine vollständig ausgeführte Suite.

Die finale Kugelprobe besteht in 424,189 Sekunden. Sie startet aus der regulären Kugelkampagne, zähmt eine echte erzeugte Eierart und verwendet dieselben Arbeits-/Speicherports wie das Spiel. Ihre Reiseprüfung verlangt separate Prozesse für den entfernten und den zurückgekehrten Spielstand. Zusätzliche kontrollierte Modell- und UI-Proben prüfen Altformate, volle Lager, 100-Eier-Ausgabe, Rollback, fehlerhafte Daten und Bedienbarkeit.

Gezielte neue Abnahme mit Godot 4.6.3:

```sh
python tools/validate_godot.py --godot /pfad/zu/Godot_4.6.3 --skip-main --tests egg_production_contract_test egg_husbandry_ui_test spherical_egg_production_test --output /tmp/voxelverse-arch22
```

Die bestehenden zehn Regressionen wurden ebenfalls ausgeführt:

```sh
python tools/validate_godot.py --godot /pfad/zu/Godot_4.6.3 --skip-import --skip-main --tests resource_production_contract_test tribal_age_husbandry_contract_test tribal_age_husbandry_test tribal_age_economy_contract_test tribal_age_growth_contract_test village_work_snapshot_test far_simulation_test tribal_economy_progress_test tribal_progression_test spherical_developed_migration_test --output /tmp/voxelverse-arch22-regression
```

Absichtlich ausgelöste Speicherwarnungen gehören zu den Negativfällen. Parser-/Laufzeitfehler, `ERROR`, Objektlecks und fehlende Erfolgsbedingungen bleiben Testfehler. Noch offen: gemeinsame Integration, grafischer Spieltest auf dem Ziel-PC und native Exportabnahme. Die UI-Probe misst Controls bei 1280 × 720 und 800 × 600 ohne Bildausgabe.

# Übergabe BP-COMMUNITY.1

Reserviert und bearbeitet in diesem Chat am 10. September 2026:
**Portabler Kreaturenbauplan: Export, Prüfung und vorbereiteter Rückimport.**

- Branch: `agent/community-blueprint-contract-2026-09-10`.
- Basis: ARCH-23, [PR #50](https://github.com/MajorDragonfly/voxelverse/pull/50),
  Quellbaum `366cdadcbe31d52d5b4eee2d5bac056d30f36c61`.
- Abhängigkeit: ARCH-23 zuerst integrieren; der Folge-PR richtet sich zunächst
  gegen dessen Branch und enthält ausschließlich dieses neue Fachpaket.
- Neue Dateien: `assembly/exchange/creature_blueprint_package.gd`,
  `assembly/exchange/creature_package_schema.gd`, zugehöriger Integrationstest
  und diese Vertrags-/Übergabedokumentation.
- API, Datenfelder, Grenzen und Anschluss: [COMMUNITY_BLUEPRINT_CONTRACT.md](COMMUNITY_BLUEPRINT_CONTRACT.md).
- Lokale Prüfergebnisse: [COMMUNITY_BLUEPRINT_VALIDATION.json](COMMUNITY_BLUEPRINT_VALIDATION.json).

Der Transfer verwendet den vorhandenen V7-Codec und Renderer, erhält die eigene
Spezies-/Kampagnenidentität und übernimmt ausschließlich geprüfte Formdaten.
Download/Prüfung bereiten eine Kopie vor. Der vorhandene Editor besitzt weiterhin
Undo, Revisionsvergabe und den expliziten Speicherabschluss. Geprüft unter Linux
Headless mit Godot 4.6.3; keine Windows-Abnahme oder Online-Dienst-Abnahme.

## Getrennt laufende Arbeit

ARCH-01, -02, -05, -17, -20, -24, -25, -28 und -29 wurden als anderweitig
vergeben behandelt. Ihre Arbeitszweige wurden nicht übernommen und ihre Dateien
nicht bearbeitet. Insbesondere bleibt ARCH-28 bei dem vom Benutzer genannten Chat.

## Nächster sinnvoller Fachauftrag

**BP-COMMUNITY.2: lokale Vorlagenbibliothek und Startvorlagen** kann auf diesem
Vertrag aufbauen. Aufgaben: sichtbare Import-/Exportauswahl, vorhandene Vorschau,
Übernahme als eine rückgängig machbare Editoraktion, gespeicherte Varianten mit
ID-/Revisionskonflikten, Startvorlagen ohne Pflicht zum Selbstgestalten und klare
Meldungen zu fehlenden Freischaltungen. Eine Vorlagenwahl darf keinen fremden
Fortschritt übernehmen. Keine neue Speicher- oder Renderimplementierung anlegen.

Das Folgepaket wird inzwischen im nachgelagerten Fachbranch umgesetzt; siehe
[Übergabe BP-COMMUNITY.2](WORK_COMMUNITY_BLUEPRINT_LIBRARY.md). Die Integrationsfolge
ARCH-23 → BP-COMMUNITY.1 → BP-COMMUNITY.2 bleibt verbindlich.

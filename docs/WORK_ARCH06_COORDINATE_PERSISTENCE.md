# ARCH-06 – verlustfreie Ortszahlen und Fachinventar

Stand: 10. September 2026. Abgeschlossener nächster Teilauftrag aus
[NEXT_PARALLEL_WORK.md](NEXT_PARALLEL_WORK.md): große Double-Koordinaten
verlustfrei serialisieren und die vorhandenen Fachorte inventarisieren.
ARCH-22/Eierproduktion bleibt beim anderen Fachchat.

- Basis: `bb2f83b56267964baa7037720c4daca26fe3d007` (integriertes `main`, einschließlich CI-Korrektur #77).
- Codecommit: `55765f6b9502f9923a732ad6d4f9d26a12c037c3`.
- Branch: `agent/arch06-coordinate-precision-2026-09-10`.
- Lieferung als Fachbranch; keine automatische Übernahme nach `main`.
- Save-, Kampagnen-, Regions- und Fachschemas bleiben unverändert. Ein genauerer JSON-Zahlentext benötigt keine neue Datenform.

## Fehler und Änderung

`AtomicJson.write()` verwendete die gerundete Standardausgabe von Godot-JSON.
Dadurch ging beispielsweise der Nachkommaanteil von `1000000000010.125`
verloren. Auch sehr kleine Unterschiede der Cube-Sphere-Koordinaten `u`/`v`
konnten beim Speichern verschwinden. Der Regionsspeicher schrieb unabhängig
davon mit derselben unzureichenden Präzision.

Der gemeinsame Anschluss `AtomicJson.stringify(value, indent)` verwendet jetzt
`JSON.stringify(value, indent, true, true)`. Spielstand, Sicherung, Historie und
neue Regionsblobs behalten damit die vollständigen Double-Werte. Regionshashes
werden weiter aus genau den geschriebenen Bytes gebildet. Bestehende Blobs
werden unter ihren alten Hashes gelesen und nicht umgeschrieben; neue Werte
können gemeinsam mit historischen Blobs in einer Wurzel liegen.

Der verwaltete Bauplantext in `CampaignDesignStore` verwendet denselben
Serializer wie seine lose Datei. Sonst würde eine genau gespeicherte Datei beim
Übernehmen in den Kampagnensnapshot wieder gerundet. Die historischen
Umzugs-Fingerprints behalten bewusst ihre bisherige Normalisierung; eine
nachträgliche Änderung würde bestehende v1/v2-Manifeste entwerten.

Die ARCH-30-Präzisionsprobe ist jetzt eine verpflichtende Regression und meldet
`system_coordinate_save_precision: ready=true`. Die Aussage betrifft den
Serializer. Schiffe sind weiterhin ein Datenentwurf und kein registrierter
spielbarer Save-Teilnehmer.

## Nachweise

Godot `4.6.3.stable.official.7d41c59c4`, Linux headless, pro Test isolierte
Benutzerdaten. Neun gezielte Godot-Testprogramme sind bestanden:

| Prüfung | Ergebnis |
|---|---|
| `coordinate_persistence_test` | 139 Bedingungen im Elternprozess, 9 in einem wirklich neuen Godot-Prozess; exakte Float-Bits statt gerundeter Ausgabe oder Näherungsvergleich |
| `expedition_contract_test` | Großes Systemkoordinaten-Beispiel bleibt erhalten; bestehende Übergabe-/Neustart- und Fehlerschreibprüfungen bestehen |
| `save_slots_test` | Kopie, Historie, Wiederherstellung, Schreibfehler und Zukunftsversionen |
| `spherical_campaign_contract_test` | Frühe Altstände, Quellschutz und gemeinsamer Kugelsave |
| `spherical_developed_migration_test` | Entwickelte Altstände, Bewohner/Tiere/Fracht und Umzugsmanifest |
| `region_store_test` | Cachewechsel, unveränderliche alte Wurzeln und Schutz fehlerhafter Blobs |
| `blueprint_contract_test` | Bauplanversionen, Originalschutz und Neustart |
| `surface_adapter_contract_test` | 18 Flächen-/Pol-/Kantenfälle mit je 3 Objekten; maximale gemessene Abweichung nach Ursprungskorrektur 0,0000024171 m |
| `surface_adapter_test` | Vorhandener radialer Laufzeitadapter |

Die neue Prüfung umfasst positive/negative große Zahlen, kleine Zahlen,
Adressen auf allen sechs Flächen, echte Eviction nach mehr als 96 Regionen,
Neustart, wiederholtes Speichern, Slotkopie, bytegleich erhaltene Altbackups,
Schreibfehler vor Veröffentlichung und Schutz unbekannter Saveversionen. Sie
vergleicht ausschließlich die Laufzeitfelder des Spielers; der gemeinsame
Savebesitzer ergänzt regulär Identitäts-/Bauplanreferenzen.

Vor der Codeänderung reproduzierte die neue Prüfung den Fehler im Atomic-Writer
und nach Regions-Eviction. Im ersten Nachlauf waren diese Fehler beseitigt;
der neue Test verglich den Spieler noch irrtümlich ohne die vom Savebesitzer
hinzugefügten Metadaten. Nach Begrenzung dieses Vergleichs auf seine tatsächlichen
Laufzeitfelder besteht auch die gemeinsame Save-/Neustartprüfung. Die
ursprünglichen Runner-Ergebnisse bleiben im Evidenzverzeichnis erhalten.

Zusätzlich bestanden Editorimport, Art-Quellenprüfung und Vertragsregistrierung
(152 Tests, jeweils genau einmal zugeordnet). Das ist keine erneute vollständige
152-Test-Abnahme und keine Grafik-/Ziel-PC-Messung.

[Evidenz und Dateihashes](evidence/arch06/summary.json),
[Prüfprotokolle](evidence/arch06/).

Reproduktion:

```bash
python tools/validate_godot.py --godot /pfad/zu/Godot_v4.6.3-stable_linux.x86_64 \
  --skip-main --tests coordinate_persistence_test expedition_contract_test \
  save_slots_test spherical_campaign_contract_test spherical_developed_migration_test \
  region_store_test blueprint_contract_test surface_adapter_contract_test surface_adapter_test \
  --output /tmp/voxelverse-arch06
```

## Übergabe und Grenzen

Die vollständige [Ortsinventur](ARCH06_PLACE_INVENTORY.md) benennt die bisherigen
Besitzer, Felder, Versionen und verbliebenen Anschlüsse. Der nächste konkret
vorgegebene ARCH-06-Teilauftrag ist damit geliefert. Das gesamte historische
ARCH-06 einschließlich zukünftiger Siedlungs-, Reiter-/Pflug- und Schiffsorte
wird dadurch nicht pauschal abgeschlossen.

Die Änderung korrigiert die Serialisierung, nicht bereits früher gerundete
Dateien und nicht den Präzisionsverlust durch einen vorzeitigen globalen
`Vector3`. Die endliche Auflösung von Double-Zahlen bleibt ebenfalls bestehen.
JSON-Dateien mit vielen Fließkommazahlen können etwas größer werden; der
Regionswriter prüft weiterhin die tatsächlichen Bytes gegen sein Größenbudget.
Bestehende spielmechanische Raster, D1-Kanonisierung, IDs und Manifestalgorithmen
werden nicht geändert. Keine neue Epoche und keine Eierproduktion.

Geändert: `core/persistence/{atomic_json,region_store,design_store}.gd`,
Kommentar in `core/campaign/spherical_migration.gd`,
`tests/coordinate_persistence_test.gd` samt UID,
`tests/expedition_contract_test.gd`, `tools/validation/contracts.json` sowie
dieser Übergabebericht, das Fachinventar und Evidenz.

Bei der nächsten Integration: diese Dateien übernehmen, die neue Prüfung im
Vertrag `campaign` genau einmal erhalten und den ARCH-06-Eintrag der zentralen
Arbeitsverteilung auf diesen Teilabschluss verweisen. ARCH-30s historischer
Bericht mit `ready=false` beschreibt seinen damaligen Stand; dieser Bericht
liefert den aktuellen Nachweis. Die zentrale Roadmap bleibt beim
Integrationsverantwortlichen.

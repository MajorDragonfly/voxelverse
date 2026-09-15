# ARCH-27 – Übergabe des regionalen Transportkerns

**Auftrag:** M6/M7/M8, ARCH-27: begrenztes regionales Wegenetz und wiederaufnehmbare Transportzustände. **Basis:** veröffentlichtes `main` `bb2f83b56267964baa7037720c4daca26fe3d007`. **Branch:** `agent/arch27-regional-transport-2026-09-10`. **Geprüfter Codecommit:** `880bc5ac4df1fb84bde2aae729a9168dc50172cf` (unverändert aus dem geprüften Arbeitsstand übernommen).

Dieses Paket liefert den unabhängig möglichen ersten Vertrags-/Modellschritt. ARCH-26 wurde vom Nutzer als parallel laufend benannt und bleibt bei dessen Fachchat. Die Gesamt-ARCH-27-Abnahme ist nicht abgeschlossen; es wurden keine fremden unfertigen Zweige übernommen und keine neue Kampagnenfunktion freigeschaltet. Zentrale Roadmap und Arbeitsverteilung bleiben bei der Integration.

## Lieferung

- `world/tribe/transport/regional_routes.gd`: Schema 1, gerichtete körperfeste Gateway-Verbindungen, deterministische Auswahl nach Dauer, Kapazitäts-/Sperrprüfung, begrenzte Netze und gespeicherte Routenkopien.
- `world/tribe/transport/regional_transport.gd`: Schema 1, Reservieren/Abholen/Reisen/Ankommen/Abliefern, Abbruch vor Abholung, physischer oder zeitlich simulierter Rückweg, Verlust, genau ein Simulationsbesitzer, überholte Vorschläge abweisen.
- `tests/regional_transport_test.gd`: gezielte Modell-/Neustart-/Fehlerprüfung; genau einmal in `tools/validation/contracts.json` unter `regions_simulation` registriert.
- [Vollständiger Vertrag und Folgeanschluss](ARCH27_REGIONAL_TRANSPORT_CONTRACT.md). Bestehender Ressourcen-/Ortsvertrag bleibt maßgeblich; keine Änderungen an SaveGameService, GameState, TribeController, Ressourcen-/Sprachkatalogen oder Tierhaltung.

## Tatsächlicher Nachweis

Godot **4.6.3.stable.official.7d41c59c4**, headless im isolierten Testbenutzerdatenverzeichnis:

- Editorimport und bestehende Assetquellenprüfung bestanden.
- Vertrags-/Sprachgate: 152 registrierte Tests in 17 Verträgen, keine fehlende oder doppelte Zuordnung. Das ist keine Ausführung aller 152 Tests.
- `regional_transport_test`: **224 Prüfbedingungen**, dazu **zwei separate Godot-Prozesse mit jeweils fünf Bedingungen**. Neuer Prozess einmal während der offenen Lieferung, einmal nach gemeinsamer Verbuchung vor Empfangsbestätigung.
- Route über mehrere Regionen/Flächengrenze, Auswahl unabhängig von Einfügereihenfolge, Kapazität, Umweg, unerreichbares Ziel und Route über dem 64-Verbindungen-Budget.
- Gesperrte/eviktierte Verbindung, geändertes Zertifikat und verschobener Endpunkt; keine nachträgliche Gutschrift blockierter Reisezeit.
- Vollständig entfernte Hin-/Rückreise sowie Fern→Nah-Übergabe am Gateway, veralteter Worker, unzulässiger Wechsel auf halber Strecke, reine Zeit ohne physische Nahankunft.
- Vorzeitige Ablieferung, doppelter Befehl, Reservierungsfreigabe, bereits geladene Ware, Rücktransport, Ausladen unmittelbar an der Quelle und terminaler Verlust.
- Schreibfehler durch blockierten `.tmp`-Pfad: vorheriger Snapshot mit Quell-/Zielfixture und Ladung bleibt vollständig; Erfolg publiziert Zielbestand und entladene Fracht gemeinsam. Dies prüft die erwartete Besitzergrenze mit Testbeständen, noch keine zwei echten Siedlungen.
- Ungültige Typen, Zukunftsschema, verbogene Route, falsche Fraktion und rückwärts laufende Zeit abgewiesen, Eingaben unverändert.

Die [Nachweisdaten](evidence/arch27/summary.json) nennen Ausführung, Laufzeiten und geprüfte Dateihashes. Der spätere Dokumentationscommit ändert den geprüften Code nicht.

Reproduktion auf einem bestehenden Godot-4.6.3-Checkout:

```bash
python tools/validate_godot.py --godot /path/to/godot --tests regional_transport_test --skip-main
```

## Offene Grenzen

Keine Aussagen zu FPS, Ziel-PC, Darstellung oder nativen Exporten. Der Test verwendet zertifizierte Modellverbindungen und vorgegebene körperfeste Beobachtungen, keinen neuen Landschaftsnavigator oder sichtbare Träger. Keine Erhöhung von Bewohner-, Speicher- oder Aktivobjektgrenzen. Ein Netz ist ein begrenzter geladen/geplanter Korridor, keine automatische globale Verkehrsplanung.

ARCH-26/07/13 müssen Siedlungs-/Vorrats-/Ladungs-/Save-Anschluss gemeinsam integrieren. Besonders Milchtransfer darf bestehende Produktions-/Verbrauchsbelege nicht umgehen. Laufende Transporte wechseln Besitzer nur an bestätigten Übergangspunkten; Neuplanung nach geänderten Zertifikaten und genauer Laufzeitanschluss mitten auf einer Verbindung folgen anschließend. ARCH-27 erst nach der im Vertrag beschriebenen echten Zwei-Siedlungs-Abnahme vollständig schließen.

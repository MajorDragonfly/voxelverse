# ARCH-30 — Übergabe des Datenentwurfs

**Auftrag:** Freies Folgepaket aus dem Architekturbacklog; ARCH-01/02/05/13/14/
17/18/20/24/25/28/29 sind durch Lars parallel vergeben, ARCH-23 hat bereits
einen eigenen PR. Übernommen ist der vorgezogene **Datenentwurf von ARCH-30**
für das bestehende M9-EXPEDITION. Laufzeitintegration und M9-Spielabnahme bleiben
geplant. Dieser Lieferstand wird nicht als fertige Raumfahrtphase markiert.

**Basis:** `ea900f2e09946660694a9e59399b4680a5655a85` (`origin/main`).
**Geprüfter lokaler Quellencommit:** `cddb4dff8fbabe1feabdbab14219c10f1af0c06a`.
**Geprüfter Quellenbaum:** `0d141560bf42941a991c2ee0a090d1243367fe60`.
Die nachfolgende Evidenz-/Übergabeänderung enthält ausschließlich Dokumentation.
Beim Upload über GitHub können Commit-Metadaten abweichen; der PR nennt dann
die Remote-Zuordnung zum identischen geprüften Git-Baum.

## Lieferung

- [SPACE_EXPEDITION_CONTRACT.md](SPACE_EXPEDITION_CONTRACT.md): Identitäten,
  gepinnte Entwürfe, drei Ortsformen, einmaliger Transportverweis,
  Passagier-/Kontrollzuordnung, abgeleitete Hangarbelegung, gemeinsamer Commit,
  Alt-/Zukunftsversionen und Anschlüsse an M9.1–M9.6.
- `tests/fixtures/expedition_contract_draft.gd` und `.json`: reine, begrenzte
  Referenzprüfung plus synthetischer Datensatz; keine Laufzeitkonsumenten.
- `tests/expedition_contract_test.gd`: ausführbarer Godot-Prüfstand für den
  Datenentwurf. `AtomicJson` wird nur im isolierten Test benutzt.

Es gibt keine Änderungen an Autoloads, Kampagne, Speicherformat, gemeinsamen
Katalogen, `project.godot`, CI, Roadmap oder fremden Arbeitsdokumenten.
ARCH-20 und die anderen offenen Feature-Branches wurden nicht mit übernommen.
Der Schiffs-Bauplananschluss wurde gegen ARCH-23s Vertragsdokument bei
`e6378087b46fae8758a7dc7a75185a5df3dc037f` gelesen; er ist vor tatsächlicher
Verwendung mit dessen integriertem Stand abzugleichen.

## Nachweis

Godot **4.6.3.stable.official.7d41c59c4**, Linux headless, isolierte Benutzerdaten.
Reproduktion mit dem vorhandenen Runner:

```bash
python tools/validate_godot.py --godot /pfad/zu/Godot_v4.6.3-stable_linux.x86_64 \
  --skip-main --tests expedition_contract_test --output /tmp/arch30-validation
```

Der Elternprozess prüft **312 Bedingungen**, zwei echte neue Godot-Prozesse
prüfen jeweils **5** weitere Bedingungen. Die Neustarts erfolgen nach
Vorbereitung vor dem Commit sowie nach Commit vor Quittierung. Ein blockierter
temporärer Schreibpfad weist nach, dass weder Live-Datei noch Backup oder
veröffentlichter Speicherzustand teilweise verändert werden. Der bestehende
Runner prüft auch Exitcodes, Skript-/Parserfehler und Shutdown-Leaks.

Enthalten sind insbesondere falsche Datentypen/Versionen, Besitzkonflikte,
Mischadressen, Körper/System-Verwechslung, sechs Würfelflächenkanten, fehlende
Hosts/Bays, Selbstbelegung/Zyklen, zweimal belegte Bays, gedrehte Passung,
duplizierte Probenreferenzen, Sitz-/Frachtgrenzen, Energiebilanz, Bauplan-Pinning,
alte Vorschläge, unveränderte Alt-Saves und Schutz unbekannter Entwurfsquellen.

Die [Rohprotokolle und Ergebnisse](evidence/arch30/results.json) belegen diesen
Prüfstand. Sie sind keine Flug-, Export-, Grafik- oder Ziel-PC-Abnahme. Die
Neustarts verwenden eine isolierte vollständige Testdatei und beweisen noch
keine Speicherteilnahme einer realen M9-Kampagne.

## Offene Integrationsaufgaben

1. **Präzision:** Der Probebericht meldet
   `system_coordinate_save_precision: ready=false`. Der bestehende gemeinsame
   JSON-Schreiber rundet `1000000000010.125`; verlustfreie Double-Serialisierung
   und Wiederladen müssen vor dem M9-Save-Anschluss vom Speicherbesitzer
   integriert und abgenommen werden. Atomizitätsprüfungen hier verwenden
   Koordinaten, die der vorhandene Writer exakt erhält.
2. **Fach-/Save-Anschluss:** ARCH-04/06/23 integrieren/abgleichen; M8 und
   ARCH-16/18/27/28 erfüllen. Echte Ankunft, Flug, Reservierung, Modulkapazitäten,
   Kosten, Energieversorgung und Recovery durch die Fachbesitzer bestätigen.
   Gemeinsam mit Speicherteilnahme den Schutz zukünftiger Pflichtversionen
   einschließlich Backup-Rückfall prüfen. Kein zweiter Schiffs-Speicherdienst.
3. **ARCH-29:** Wenn [PR #53](https://github.com/MajorDragonfly/voxelverse/pull/53)
   integriert wird, den neuen Test in `tools/validation/contracts.json`
   registrieren. Exakter zusätzlicher Vertragsblock:

   ```json
   {
     "id": "expedition_design",
     "title": "Expedition: Orts- und Übergabenentwurf",
     "work": "ARCH-30 / Vorbereitung M9-EXPEDITION",
     "tests": ["expedition_contract_test"]
   }
   ```

   Ein etwaiges M9-Szenario erhält höchstens Status `partial` und nennt
   ausdrücklich das offene Präzisionstor sowie fehlende Flug-/Saveintegration.
   Der bisherige Runner entdeckt `*_test.gd` bereits automatisch. Die parallele
   Registry wird in diesem Branch nicht vorweggenommen.
4. **Status:** Datenentwurf zur Integration geliefert; vollständiger
   Laufzeitvertrag und Lars' M9-Spieltest bleiben offen. Der PR führt nichts
   nach `main` zusammen und schaltet keine Epoche frei.

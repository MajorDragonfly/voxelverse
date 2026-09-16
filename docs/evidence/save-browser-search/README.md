# UI-SAVE-BROWSER-SEARCH — Prüfnachweis

Vier Fachtests sowie Quell-/Sprachgate und Quellintegrität bestanden.
Godot `4.6.3.stable.official.7d41c59c4`, Linux/headless, isolierte synthetische
Nutzerdaten je Prüfschritt.

- Basis: `d57b1ef385728728b132518a1ea05683888dcae0` (#125).
- Lokal geprüft: `88bb03515bcdd6894f2cb47d7475f93d0aa154a2`.
- Identischer veröffentlichter Quellcommit:
  `421c8d347b034c55cb6be753642afbdbb7afe676`.
- Exakt verglichener Quell-Tree: `f335a44d9687a5dec19e322aeade4cc5d0e9526e`.
- Arbeitsstand bei allen Abschlussprüfungen sauber; Anfangs-/Endmanifeste
  identisch, `provenance.status = stable`.

```sh
python3 tools/validate_godot.py \
  --godot /workspace/scratch/2c2866d70564/godot \
  --tests save_browser_search_test save_slots_test localization_test frontend_test \
  --skip-main --skip-import \
  --output /workspace/scratch/97e7c57ff0f3/save-search-final-check
```

| Prüfung | Ergebnis | Sekunden |
|---|---|---:|
| Spielstandsuche, 760 Bedingungen inkl. zwölf Layoutkombinationen | bestanden | 4,78 |
| Bestehende Slot-/Kopie-/Historienverträge und Fehlerfälle | bestanden | 1,67 |
| DE/EN, ungesicherte Namen und dynamische Texte | bestanden | 1,87 |
| Frontend mit realem Kugelstart, Kopieren, Laden und Wiederherstellung | bestanden | 61,00 |

Der neue Test verwendet 31 Slotfälle aus echten SaveGameService-Dateien,
darunter Historie ohne Hauptdatei, Backup ohne Hauptdatei, beschädigte und
neuere Quellen. Reines Browsen/Filtern/Sortieren/Sprachwechsel erhält sämtliche
Dateihashes und den aktiven Kampagnenzustand. Suche über 1.005 Zusammenfassungen,
mehrseitige Auswahl, echte Klicks/Tasteneingaben, unabhängige Kopie, konkrete
historische Wiederherstellung und fehlgeschlagene Umbenennung sind enthalten.

[Unveränderter Abschlussbericht](results.json) ·
[Originalprotokolle und vollständige finale Quellmanifeste](validation-logs.tar.gz) ·
[Prüfsummen](sha256.json).

## Ursprüngliche Befunde

Die früheren Logs/Berichte sind im Archiv enthalten; sie werden nicht als
Abschlussfreigabe gewertet:

1. `save-search-initial-check`: Import und Art-/Quellgate bestanden. Die erste
   Query verwendete fälschlich `all()` auf einem PackedStringArray. Der dadurch
   im Test wartende Prozess wurde unterbrochen; der Teilbericht ist unvollständig.
   Explizite Wortiteration korrigiert dies. `save-search-locale-check` bestand.
2. `save-search-contract-check`: Im neuen Test war der Typ eines dynamisch
   gelesenen Historienindex nicht inferierbar; expliziter Integer ergänzt.
3. `save-search-ui-check`: Die Sortierung erhielt wie gewünscht den ausgewählten
   Slot auf seiner neuen Seite; die Prüfung startet nun ausdrücklich auf Seite
   eins. Zudem war die Liste bei 800×600/150 % zu niedrig. Kompakte Filterbreiten,
   ausgeblendete leere Statuszeile und kleinere Abstände/Bedienzeilen korrigieren
   dies. Der Zwischenlauf `save-search-layout-check` und der erfolgreiche
   `save-search-compact-check` dokumentieren die konkrete Nachbesserung.
4. Vor dem sauberen Quellcommit erfolgte ein erfolgreicher Editorimport für die
   neuen Script-UIDs (`save-search-import.log`). Danach wurde der unveränderte
   Programmstand mit allen vier direkten Verbrauchern geprüft.

Warnungen über absichtlich blockierte Schreibziele gehören zu den Negativfällen.
Kein Engine-/Scriptfehler wurde als Erfolg gewertet oder herausgefiltert.

## Grenzen

Die Layoutprüfung verwendet reale Godot-Controlrechtecke und Eingaben im
Headless-Modus. Keine native Bild-, Windows-Export- oder Ziel-PC-Freigabe.
Die UI erzeugt maximal zwölf Slotknöpfe/Listenvorschauen je Seite; der bestehende
SaveGameService liest beim Öffnen/Aktualisieren weiterhin alle Slotdateien.
Keine Aussage über vollständige Integration oder begrenzte Datei-Latenz.

Der Nachweiscommit ergänzt ausschließlich diesen Ordner; der geprüfte
Programm-/Teststand bleibt unverändert.

# INT30-10: Dorfwelt und Speicherung

Die kombinierte Dorfansicht aus #199 ist als echte Kugelkampagne vorhanden: eine aus gelieferten Materialien fertig gebaute Hütte, Dorfplatz, tatsächliche Lagerbestände und ein sichtbar arbeitender Bewohner. Dorfplatz- und Ressourcenbeschriftungen verschwinden jetzt wie die Hüttenbeschriftung oberhalb 70 m und kehren unterhalb 60 m zurück. Die Geometrie und gespeicherten Bestände ändern sich beim Kamerwechsel nicht.

## Geprüfter Stand

| Stand | Commit / Tree |
|---|---|
| Bestätigte gemeinsame Basis, PR #220 | `2b1ac023db4074c2ce6b7db8fbab09ab929a8435` / `5f815f478ceeabefcfc50a6388e3e4b0daa2ac45` |
| Sauberer lokaler Prüfcommit | `36ab1d864db0c52ce171295d17c49e7a1f99a115` / `2d0dcf559fc9b3cac4d5b28fc64bd1fcd98ff9c6` |
| Veröffentlichter, identischer Codebaum | `8aa6ab980e34fc5ba3c27a9dd962d3ab356c1076` / `2d0dcf559fc9b3cac4d5b28fc64bd1fcd98ff9c6` |

Godot `4.6.3.stable.official.7d41c59c4`, Linux, isolierte erzeugte Nutzerdaten; native Aufnahmen mit GL Compatibility, Mesa llvmpipe 25.2.8 und Xvfb, 1280 × 800. Quellmanifeste vor und nach jedem Abschlusslauf stimmen überein; Quellhash `c3c2eb420fc500e40f69b976917f92be0308ea539276c61f01913bd11d08d177`. Dieser Bericht und seine Belege werden anschließend als reine Evidenzänderung angehängt.

Die fixierten Inputs #196 (`049b32a`), #198 (`d1f11ef`), #200 (`15c2d1d`) und #201 (`446093e`) sind sämtlich Vorfahren der Basis. Produktionsänderung ausschließlich in `world/tribe/village_visuals.gd`. Stammescontroller/-panel und Vegetationsshader wurden nicht bearbeitet. SaveService, Teilnehmerregistrierung, Schemas und Anschlusssignale bleiben unverändert.

## Ergebnis und Wiederaufnahmefälle

| Prüfung | Tatsächlicher Beleg |
|---|---|
| Bau, Arbeit und Transport | Öffentlicher Kugel-Spielweg, ausdrücklicher Stammesübergang, reale Holz-/Steinlieferung und Werkzeugbau im Ursprungslauf; keine gesetzten Hütten oder erfundenen Lagerbestände |
| Neuer Prozess mit Baumaterial | Drei Bewohner halten je ein Holz für dieselbe unfertige Hütte. Lager 3 Holz / 1 Stein. Neuer Prozess erhält IDs, Aufträge, Fracht und Projekt; Hütte und Wohnplatz entstehen genau einmal, Lager bleibt 3 / 1; anschließendes Laden wiederholt den Abschluss nicht |
| Neuer Prozess mit Sammelfracht | Ein Bewohner hält ein tatsächlich gesammeltes Holz. Neuer Prozess liefert genau eine Einheit: Lagerholz 3 → 4. Erneutes Laden erzeugt keine weitere Einheit |
| Nah → Fern → Nah | Physisch zertifizierte Wege und gehaltene Fracht gehen über `prepare_body_departure` an den Fernbesitzer. Neuer Prozess liefert 4 → 5 Holz. Zwölf Aufrufe desselben Cursors ändern nichts. `complete_body_arrival` übernimmt nah; der Fernbesitzer darf danach nicht mehr schreiben |
| Pause und geschlossenes Spiel | Je Fall 20 pausierte Frames ohne Änderung von Dorf oder Kampagnenzeit; frischer Prozess erhält den gespeicherten Cursor. Ein manueller Tagesdelta im Titel ohne aktiven Spielkörper erzeugt weder Nachholarbeit noch Bestandsänderung |
| Bestands-/Körperkonsistenz | Modellvalidierung, drei eindeutige Bewohner und keine zusätzlichen HomeGroup-Akteure; gelieferte, reservierte und transportierte Güter bleiben getrennt |
| Bodenhaftung | Alle sieben echten Kugel-Lagerlots nach Laden: Bodenabstand < 0,03 m, radialer Normalenabgleich > 0,9999; zusätzlich vorhandene Gegenprobe mit erst später erscheinendem Collider bestanden |
| Auftragslatenz | 100 dauerhaft quittierte `wait`-Befehle im fertigen Kugeldorf: p50 158,083 ms, p95 210,168 ms, Maximum 334,110 ms. Median SaveService-Anteil 153,637 ms, Visuals 0,480 ms. Vorratsmeshes bleiben dieselben |

Der Abschlusslauf verwendet den unveränderten echten Baufracht-Spielstand aus dem Ursprungslauf erneut. Sein SHA-256 ist `c3eac8ad44d0dd08eefc350eb3875bcec4966bfe936fb4ad8b195938867ae518`. Der Ursprungslauf war wegen eines zu knappen zusätzlichen Wandzeitguards rot; er hatte alle Materialien geliefert und den Baufortschritt bis 7,6167 fortgesetzt. Die neue Probe behält die Grenze für Kampagnenzeit und einen getrennten, begrenzten Wandzeitguard. Physikzustände werden durch den normalen SaveService wiederhergestellt. Der endgültige Lauf ist mit allen drei frischen Prozessen grün (260,535 s), der separate native Lauf grün (91,129 s).

Die Latenzen sind Containerbeobachtungen, keine Ziel-PC-/FPS-Abnahme. Der SaveService-Anteil ist für Chat 5 und die Integration ausgewiesen; aus einer anderen Hostlast wird kein Produktionsfehler abgeleitet.

## Aufnahmen

- [Nah: fertige Hütte, Dorfplatz und echte Vorräte](01_finished_village_near.png)
- [Fern: gleiches Dorf ohne Beschriftungsballung](02_finished_village_far.png)
- [Zurück nach nah](03_finished_village_near_return.png): identischer PNG-Hash zum ersten Nahbild
- [Tatsächlich fortgesetzte Arbeit](04_finished_village_actual_work.png): realer Werkzeugimpuls, Arbeitsfortschritt 0,166667; Arbeiter-ID im Renderbericht

Die Nahaufnahmen zeigen frei 3 Holz / 1 Stein. Die Beschriftungen 36 Leseholz, 42 lose Steine und 48 Wurzeln bezeichnen die verbleibenden **Quellen**, nicht den Lagerbestand. Das Dorf wurde weder dekorativ vorgebaut noch für die Bilder mit Gütern aufgefüllt.

## Nachweise und Wiederholung

[`resume-final/results.json`](resume-final/results.json) und [`village-report.json`](resume-final/village-report.json) enthalten Quellstand, Befehle, Loghash, alle 100 Latenzproben und Fälle. [`render-final/results.json`](render-final/results.json) bindet die vier PNG-Hashes an den geprüften Codebaum; das native Log enthält keine Engine-, Shader- oder Abbaufehler. [`stockpile-recheck/results.json`](stockpile-recheck/results.json) dokumentiert den unveränderten vorhandenen Kugel-Vorratstest, erfolgreich in 34,844 s innerhalb seines 120-s-Budgets.

[`village-resume-cases.zip`](village-resume-cases.zip) enthält echte Spielstandsbytes vor den drei Neustarts, Erwartungen, Kindprozesslogs und den ursprünglichen Baufrachtzustand. Die Dateien enthalten eingebettete Designdaten und keine externen Regionsreferenzen. Für eine Wiederholung importiert die Probe die exakten Bytes in ihren eigenen verwalteten Slotordner; der Produktionsservice akzeptiert weiterhin ausschließlich verwaltete Spielstandpfade.

```bash
python3 docs/evidence/int30-10-village-save/review_village.py \
  --project "$PWD" --godot /path/to/Godot --output /path/outside/repo/int30-functional

python3 docs/evidence/int30-10-village-save/review_village.py \
  --project "$PWD" --godot /path/to/Godot --output /path/outside/repo/int30-render \
  --phase render --snapshots /path/outside/repo/int30-functional
```

Optional `--source /path/to/original-physical-construction.save.json` wiederholt den belegten Baufracht-Einstieg. Unter Linux ohne Display zusätzlich `--xvfb /path/to/Xvfb`; ein installiertes Xvfb benötigt keine Bearbeitung des Spiels. `--phase captions` führt die kleine kombinierte Hysterese-Gegenprobe aus. Der Helfer prüft strikte Logs und unveränderte Quellen; aus einem Testplan wird kein Prüferfolg abgeleitet.

[`previous-runs.zip`](previous-runs.zip) bewahrt die Vorläufe einschließlich fehlgeschlagener Proben. 17 vorhandene gezielte Fachtests waren auf stabilem vorherigem Snapshot grün (Quellhash `f69c62fc4c189ac5d9bb7d7e4137e809f02eb276f7a94abc05421b4e63b18427`); seitdem änderten sich ausschließlich neue Proben und ihre UID-Dateien. Beim ersten sauberen Abschlusscheck erreichte der vorhandene Kugel-Vorratstest 120 s und blieb rot; neun andere vorhandene Tests bestanden. Der oben verlinkte unveränderte Nachtest schließt diesen Befund. Weitere Probeprobleme waren ein unzulässiger externer Slotpfad, ein Quellsnapshot über einem lokalen Commitwechsel und eine nicht ausdrücklich ausgewählte Fern-Speichersitzung. Diese Vorläufe zählen nicht als Freigaben. Die Ferncaption-Gegenprobe war vor der Produktionskorrektur rot und danach grün.

## Übergabe und Grenzen

[`validation-registration.patch`](validation-registration.patch) ist ein mit `git apply --check` geprüfter Vorschlag an Chat 1: zwei Wrapper mit UID-Dateien, einmalige Zuordnung im Dorfvertrag und 900 s für die neue Probe mit drei kalten Prozessen. Gemeinsame Registry und Runner wurden nicht geändert. Chat 5 kann die bestehenden `save_started`, `game_loaded`, `game_saved` und Save-Teilnehmer verwenden; Änderungen daran bleiben bei der gemeinsamen Abstimmung.

PR [#227](https://github.com/MajorDragonfly/voxelverse/pull/227) bleibt Entwurf gegen den Integrationsbranch. Die lokale Fachprüfung ersetzt weder die vollständigen Integrations-/Exportprüfungen noch Windows-, Ziel-PC-, Spielspaß- oder endgültige Sichtabnahme. Kein main-Merge, kein Auto-Merge, kein Schließen der vier Eingangs-PRs. Alle weiteren Dateihashes stehen in `artifact-hashes.json`.

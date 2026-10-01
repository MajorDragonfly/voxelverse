# Anschluss an Chat 1: Surface-CI-Provenienz

Der Surface-CI-Lauf [36773077628](https://github.com/MajorDragonfly/voxelverse/actions/runs/36773077628)
auf Fachkopf `40b15e5556dd48e42a97eb430ba2c2e5aad9d41d` ist fehlgeschlagen.
Der heruntergeladene Compatibility-Beleg enthält bereits acht vollständige
Baselinebilder, `passed=true`, keine Capturefehler und einen fehlerfreien
Renderlog. Der Wrapper verwirft anschließend die Baseline als verändert:
`Incomplete or changed surface comparison: .../before`.

Ursache: Der Wrapper kopiert absichtlich das aktuelle Messskript in die alte
Baseline. Das Skript ist dort bereits als andere Revision getrackt. Der
anschließende pauschale `git diff --name-only HEAD` weist daher genau diese
beabsichtigte Messskriptinjektion zurück. Das ist kein nachgewiesener
Materialfehler und keine grüne Gesamt-CI.

[surface-provenance.patch](surface-provenance.patch) ist ein **nicht angewandter**
Vorschlag auf der zentralen Revision `0ab9d20b0f448864c6e104c093b3ce97532e95e5`.
Anwenden mit `git apply --unidiff-zero surface-provenance.patch`; der Patch
enthält keine Kontext-Leerzeilen und wurde auf exakt dieser Revision angewandt
und auf Gleichheit mit dem geprüften Vorschlag kontrolliert.

Nur der exakt gehashte, absichtlich injizierte Pfad darf im Baselinevergleich
abweichen. Andere getrackte Änderungen, Änderungen während der Aufnahme und
ein wechselnder HEAD bleiben Fehler. Die bestehende explizite Szenenfreigabe
in `tools/capture_surface_transitions.gd` muss erhalten bleiben; dieser Patch
ersetzt sie nicht. Fehlerfilter, Erwartungen und Fristen werden nicht verändert.

Sieben tatsächliche Git-Provenienzfälle bestehen, siehe [cases.json](cases.json).
Nur der Godot-Prozess ist in diesen Fällen gestubbt: **keine Renderabnahme**.
Wiederholung vom Repositoryroot:

```sh
python3 docs/evidence/int30-03-materials/integration-attachments/verify.py --project .
```

Chat 1 besitzt `tools/` und CI; der Fachbranch verändert beide nicht. Erst nach
zentraler Prüfung/Übernahme ist ein neuer Surface-CI-Lauf aussagekräftig.

Nachweis des ersten Fehlers:

| Gegenstand | Wert |
| --- | --- |
| GL-Job | `110084091240` |
| Artifact | `11124194278` |
| Artifact-ZIP SHA256 | `b19e986fa4f72e069692a9a8a0036d224dbb40a94e432b6e17f1e7414042300f` |
| Baseline-render.log SHA256 | `e5c79dcaa9e11aa7998f49c4d48bb515821a9ab94c5caadc224422e5d3d3e34b` |
| Terrain-Kollisionsdigest | `ec3dd66af91a5c486b2d014d27b7f08b49a8db007b08db84936dd541730f50ed` |
| Oberseitennormalen: maximale Abweichung | `0` |

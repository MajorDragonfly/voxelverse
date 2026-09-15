# ARCH-17-AUDIO: begrenzte Tier-Audioverwaltung

Basis: `d378ca0ecd7f03429a5150df6358e0646ec06689` (`main` nach #92).
Branch: `agent/arch17-audio-budget-20260915`. Teilauftrag zu ARCH-17/M10.

Die bisherige Registrierung kopiert alle drei Kreaturengruppen alle 0,5 Sekunden
und vergibt ihre 64 Plätze nach Reihenfolge. Entfernte Quellen behalten dabei
Beobachter; später gefundene nahe Tiere bleiben ohne automatische Reaktionen.
Alle 64 Beobachter besitzen außerdem einen eigenen Frame-Callback.

## Lieferung

- Schrittweise Tiefensuche im aktiven Szenenbaum; keine vollständigen Gruppenlisten.
  Der Suchzustand enthält nur schwache Referenzen und höchstens 128 Stackeinträge.
  Nach einer vollständigen Runde folgen 0,25 Sekunden Abstand. Nachträgliche
  Gruppenzuordnung und geänderte Szenen werden in weiteren Runden erfasst.
- Hörbare Quellen bis 48 m erhalten Beobachter; automatische Beobachter bleiben
  bis 56 m erhalten. Nähere Quellen können weiter entfernte verdrängen, mit 4 m
  Abstand gegen ständige Wechsel. Der Spieler verdrängt nötigenfalls einen
  automatischen Nichtspieler-Beobachter und wird selbst nicht verdrängt.
- Höchstens acht Beobachter je Frame abfragen; verstrichene **Spielzeit** je
  Beobachter weitergeben. Bestehende Gesundheits-/Aktionssignale reagieren direkt.
  Keine Produktion, Gesundheits-, Beziehungs-, Identitäts- oder Saveänderung.
- Generation und Besitzprüfung sperren alte Callbacks. Entfernen trennt alle
  Signale und stoppt Quellstimmen sofort. Clear und erneutes Anhängen funktionieren
  im selben Frame; ein aus dem Baum entferntes Tier erhält nach Rückkehr einen
  neuen Beobachter. Szenenwechsel verwirft die laufende Suche.
- Räumliche Kreaturen-/Aktionsstimmen folgen ihrer lebenden Quelle. Entfernte,
  unsichtbare, deaktivierte oder fremde Quellen werden im festen 16-Stimmen-Pool
  gestoppt. Anonyme Punktklänge bleiben unterstützt. Vorhandene radiale
  Ursprungskorrektur bleibt der einzige Rebase-Anschluss.

## Arbeitsgrenzen

| Arbeit | Obergrenze |
|---|---:|
| Registrierte Beobachter | 64 |
| Suchschritte einschließlich Rückweg je Frame | 64 |
| Suchstack | 128 |
| Beobachterabfragen je Frame | 8 |
| Automatische Anhängeversuche je Frame | 2 |
| Alle Anhängeversuche einschließlich expliziter API je Frame | 4 |
| Reguläre Freigaben/Ersetzungen je Frame | 2 |
| Räumliche Stimmen / aktualisierte Stimmen je Frame | 16 |

Ein volles Register prüft höchstens 64 vorhandene Plätze pro begrenztem
Anhängeversuch. Bei Überlast liefert die bestehende optionale Audio-API `false`;
sie speichert keine wachsende Warteschlange. Eine erneut angefragte Quelle kann
im nächsten Frame zugelassen werden. Ganze Szenen/Shutdown geben alle höchstens
64 Beobachter sofort frei. Bis zum Frameende können zusätzlich höchstens zwei
regulär freigegebene Nodes existieren; beim vollständigen Clear entsprechend
höchstens 64 alte Nodes. Diese besitzen dann keine Signale, Stimmen oder Arbeit.

Die Grenzen sind Arbeitsmengen, keine harte Millisekunden- oder FPS-Garantie.
Sehr tiefe Teilbäume jenseits 128 Ebenen werden bei automatischer Suche übersprungen
und in `depth_skips` gezählt. Explizite Audioaufrufe bleiben möglich. Die Suchzeit
bis zur ersten automatischen Registrierung wächst mit der Szenengröße; direkte
Reaktionen können ihren Beobachter sofort im reservierten Budget anfordern.

## Prüfung und Übergabe

`tests/audio/creature_audio_budget_test.gd` verwendet den echten AudioManager,
402 Tiere, 2.048 weitere Szenenobjekte, echte Signale und importierte Klangdateien.
Er prüft Grenzen in jedem Schritt, verspätet gefundene nahe Quellen, volle
Register, faire Abfrage, alte Gesundheitsbeobachtung, A–B–A des Hörers, Hysterese,
Pause, Clear/Erneuerung im selben Frame, Entfernen/Wiederherstellen, Signalabmeldung,
explizite Überlast/erneuten Versuch, Ursprungskorrektur, fremde Viewports und
Szenenaustausch bei laufender Suche. Einmal unter `audio` registriert.

Die bestehende Audioprüfung umfasst zusätzlich Mischung/Verdeckung, Aktionen,
Scanner/Gruppenrückmeldung, Musik, radiales Wasser und echten Mixer-Shutdown.

```sh
python3 tools/validate_godot.py --godot /path/to/godot \
  --contracts audio --skip-main --skip-import --output /tmp/arch17-audio
# --skip-import nur nach erfolgreichem Import derselben lokalen Ressourcen.
godot --headless --path . --script res://tools/benchmark_creature_audio.gd
```

Die Messroute verwendet auf Basis und Änderung dasselbe Skript: 402 Tiere,
2.048 Szenenobjekte, 1.080 Schritte mit 1/60 Sekunde, Hörer A–B–A. Bei der Basis
werden auch die bisherigen einzelnen Beobachter-Callbacks mitgemessen. Zeit für
Audiomixer, Darstellung und übriges Spiel ist nicht eingeschlossen.

Genaue Quell-/Tree-IDs, Ergebnisse und Protokolle stehen in
[evidence/arch17-audio/results.json](evidence/arch17-audio/results.json).
Die Fachlieferung beansprucht keinen Gesamtspiel-, Windows-Export-, Hör- oder
Ziel-PC-FPS-Nachweis. ARCH-17 bleibt insgesamt offen.

Schreibbereiche: drei Dateien unter `audio/runtime`, ein neuer Fachtest, dessen
Registrierung, eine neue Messhilfe und diese Übergabe samt Nachweisen. Terrain,
SaveService, Dorf, Editor, Übersetzungskatalog und zentrale Statusseiten werden
nicht geändert. Bei der Integration die zusätzliche Testregistrierung mit
parallelen Paketen erhalten; PROJECT_STATUS/Backlog aktualisiert die Integration.

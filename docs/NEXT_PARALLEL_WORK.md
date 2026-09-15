# Nächste Voxelverse-Arbeiten

Aktuelle gemeinsame Basis: `agent/playtest-latest-20260915` aus der
[Spieltest-Integration](INTEGRATION_2026-09-15_PLAYTEST.md). Den festen Commit der
aktuellen PR-Übergabe verwenden; native CI und Ziel-PC-Freigabe getrennt beachten.

ARCH-17-PUBLISH-TAIL, ARCH-13-RETENTION-LIFECYCLE, ARCH-24-PART-REVISIONS,
ARCH-25-HUSBANDRY-UI, ARCH-26-WORKPLACE-INSTANCES und ARCH-27-SITE-TRANSPORT
sind geliefert und integriert. Ebenso Stammes-Teststart, Schwanzfamilien,
Tieremotionen/Augen, Wetter/Schnee, Atmosphäre/Presets und ARCH-29-RUN-PROVENANCE.
Diese Einstiegsaufträge nicht erneut starten. Die alternative ARCH-29-Lieferung
#122 bleibt zugunsten der gemeinsamen Implementierung #120 draußen.

## Offene Folgearbeit

- **ARCH-19-TARGET-PC:** Gemeinsamen Windows-Build auf Lars' PC spielen und messen;
  Grafikpreset, Auflösung und beobachtete Fehler mit Build-ID festhalten.
- **ATMOSPHERE-SETTINGS-DETAIL:** Einzelregler gemäß [Roadmap](../ROADMAP.md).
- **WEATHER-02/03/04/05:** Persistente Klimaprofile, Heimatweltschutz, spätere
  Extremstürme, Schutz-/KI-Verhalten und Audio/UI gemäß [Wetterplan](WEATHER_PLAN.md).
- Noch laufende Planeten-Renderarbeiten bleiben beim bisherigen Fachchat;
  Übernahme erst nach konkreter veröffentlichter Übergabe.

Der ausführbare Paketkatalog enthält nur noch die offene Ziel-PC-Abnahme.
Neue Teilaufträge und gemeinsame Schreibbereiche einmal im Integrationschat
zuordnen. Keine zweite Speicher-, Transport- oder Atmosphärenarchitektur.

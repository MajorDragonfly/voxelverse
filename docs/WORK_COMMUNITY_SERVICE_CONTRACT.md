# BP-COMMUNITY-SERVICE-CONTRACT

Basis: `176d088d34324de14952bc7506fe9763a22cf4b0` auf main.
Branch: `agent/community-service-contract-20260917`.
Auftrag: nächstes freies Arbeitspaket, 17.09.2026. Zentrale Runde #137 und
konkrete bereits gelieferte Pakete beim Start abgeglichen. PERF-COLD-START
ist bereits #152; WEATHER-03 ist #151. Der Community-Client besitzt keine
Abhängigkeit von diesen Lieferungen oder laufenden M4-/Stammes-/Körperarbeiten.

## Gelieferter Anschluss

`assembly/exchange/community_catalog_client.gd` stellt einen explizit
konfigurierten, lesenden HTTP-Client bereit. Es gibt keinen Standardserver und
keine Verbindung beim Spielstart. Die spätere Galerie kann ihn als Kindknoten
verwenden; er funktioniert auch im pausierten Menü. Die heutige lokale
Bibliotheksoberfläche bleibt benutzbar. Keine neue Online-Schaltfläche wird
ohne verfügbaren Dienst angezeigt.

Die Aufrufe `search(query, limit)`, `next_page()` und
`download(entry, library_path)` liefern entweder einen unmittelbaren Fehler
oder `{ok: true, request_id: N}`. Ein angenommener Auftrag endet genau einmal
mit `completed(N, result)`, auch bei Abbruch. Nur ein Auftrag ist gleichzeitig
aktiv. Abbruch oder Entfernen des Clients verwirft den laufenden Transfer;
erneuter Versuch ist ein ausdrücklicher neuer Aufruf. Es gibt keine automatische
Wiederholung oder Hintergrundaktualisierung.

Ein erfolgreicher Download führt ausschließlich `CreatureDesignLibrary.add()`
aus. Die vorhandene Bibliothek besitzt Atomizität, Revisionskonflikte und
Offline-Dateien. Der Picker liest sie nach `reload()` über denselben bisherigen
Anschluss. Erst seine bestehende ausdrückliche Verwendung übernimmt einen
Entwurf in den Editor oder eine neue Kampagne. Spielstände, Freischaltungen,
aktive Kreatur und Fortschritt werden beim Download nicht geändert.

## Dienstvertrag v1

| Aufruf | Antwort |
|---|---|
| `GET /v1/creatures?limit=24&q=...&cursor=...` | JSON mit `schema: 1`, `entries` und `next_cursor` |
| `GET /v1/creatures/{design_id}/revisions/{revision}` | Exakte UTF-8-Bytes eines bestehenden Kreaturenpakets |

Ein Katalogeintrag enthält ausschließlich `kind: "creature"`, `design_id`,
`revision`, `title`, `author`, `bytes` und `sha256`. Identität und Revision
verwenden die vorhandenen Paketgrenzen. Titel/Autor sind auf je 120 UTF-8-Bytes
begrenzt. `sha256` sind 64 kleine Hexzeichen über die tatsächlichen unkomprimierten
Downloadbytes, einschließlich deren Zahlenkodierung und Leerzeichen. Ein Digest
belegt die Übereinstimmung mit dem gewählten Eintrag, keine Autorenidentität.

Der Server vergibt einen opaken Cursor im bestehenden begrenzten ID-Zeichensatz;
ein leerer Cursor beendet die Folge. Anfrage und Cursor werden URL-kodiert. Ein
Retry muss dieselbe Cursorseite liefern können. Wiederholte Revisionen und
Cursorschleifen werden abgelehnt, ohne den letzten erfolgreichen Seitenstand
fortzuschreiben. Neue Suche setzt den begrenzten Seitenzustand zurück.

| Grenze | Verhalten |
|---|---|
| 24 Einträge / Seite, höchstens 8 Seiten / Suche | Höchstens 192 verfolgte Revisionen; jede Folgeseite wird einzeln angefordert |
| 64 KiB pro Katalogantwort | HTTP-Limit auch bei Übertragung ohne Content-Length |
| 2 MiB pro Paket, genaueres Limit aus `bytes` | Begrenzung während Empfang; exakte Länge und SHA-256 vor Paketprüfung |
| 10 Sekunden pro Anfrage | `timeout`, keine pauschale Verlängerung oder automatische Wiederholung |
| Eine Verbindung, keine Redirects, keine Kompression | Keine vom Katalog gelieferten Download-URLs; Pfad aus geprüfter Identität |

`configure()` akzeptiert eine HTTPS-Origin ohne Pfad, Zugangsdaten, Query oder
Fragment. Die normale Godot-TLS-Prüfung bleibt aktiv. Nur der explizite zweite
Parameter erlaubt `http://127.0.0.1:PORT` für den lokalen Prüfstand. Anbieter,
Konten und öffentliche Bereitstellung sind nicht ausgewählt.

Nach Größen-/Digestprüfung führt der vorhandene Paketcodec seine vollständige
Prüfung durch. Paketidentität, Revision, Titel und Autor müssen dem gewählten
Eintrag entsprechen. Ein anderes Paket, unbekannte Versionen, unerlaubte Felder,
kaputte Downloads und fehlgeschlagene Bibliotheksschreibvorgänge liefern Fehler.
Bereits vorhandene Revisionsdaten bleiben erhalten. Neue Revisionen werden
zusätzlich gespeichert und verändern frühere lokale Entwürfe nicht.

## Prüfung und verbleibende Abnahme

`community_catalog_client_test` ist genau einmal im Vertrag `blueprints`
registriert. Der lokale TCP-Prüfstand beantwortet echte HTTPRequests, einschließlich
mehrerer Seiten, ungültiger Antworten, Header-/Chunked-Größenlimits, Redirect,
Abbruch, Timeout und Pausen-/Knotenlebenszyklus. Downloads werden gegen die
tatsächliche Bibliothek geprüft: doppelte Revision, neue Revision, Konflikt,
Prüfsumme, Identität, Zukunftsversion, fremder Fortschritt und fehlgeschlagener
atomarer Schreibabschluss. Nach Abschalten des Dienstes liest ein neuer
Godot-Prozess beide Revisionen und bereitet sie über den vorhandenen Importweg
offline zur Verwendung vor. Die Tests verwenden isolierte Nutzerdaten.

Die konkreten Quellstände, Befehle und Ergebnisse stehen in der PR-Übergabe.
Die vorhandenen Bibliotheks-/Paket-/Pickerprüfungen decken die direkten Verbraucher
ab. Vollständige CI, native Exporte und Ziel-PC-Abnahme bleiben getrennte Nachweise.
Dieses Paket liefert den Clientvertrag und dessen lokalen Dienstprüfstand;
öffentlicher Dienst, Veröffentlichung, Konten, Galeriegestaltung und zusätzliche
Bauplanarten bleiben nachgelagerte Aufgaben.

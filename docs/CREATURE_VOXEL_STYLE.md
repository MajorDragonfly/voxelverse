# Kreaturen-Werkstatt in Voxeloptik

Lars hat am 9. September 2026 die gewünschte Darstellung präzisiert: Die direkte Gestaltung soll sich an Spore orientieren, Kreaturen und Werkstatt sollen zur Voxelgrafik von Voxelverse passen. Dieser Ausbau folgt auf die erste Kreaturen-Werkstatt in PR #12.

## Darstellung und Bedienung

Körper, Augen, Mäuler, Gliedmaßen, Hörner und Schmuck bestehen aus kleinen Würfeln mit ebenen Flächen. Haut- und Musterfarben werden pro Voxel gesetzt; die Oberfläche hat keine geglätteten Normalen und keine glänzende Kunststoffwirkung. Augen behalten Iris, Pupille und Lichtpunkt. Zwei bewegliche Beinsegmente und ein voxelisiertes Gelenk bleiben an der vorhandenen Knieanimation befestigt.

Körperpunkte, Auswahlrahmen, Teilekarten und die gekachelte Arbeitsfläche sind ebenfalls kantig. Die vier Arbeitsbereiche Formen, Teile, Farbe und Testen sowie die Tastatur- und Mausbedienung bleiben erhalten. Die direkte Formung verändert weiterhin die zugrunde liegende Körperkurve; die Darstellung setzt diese in Würfel um. Symmetrie, Andocken, Farben, Entwurfs-IDs, Speichern und Rückgängig verwenden weiterhin die bestehenden V7-Verträge.

Beim Anbauen werden die tatsächlich sichtbaren Körpervoxel getroffen. Leere Zellen innerhalb der Körpergrenzen akzeptieren kein Teil. Der Treffer wird auf die bestehenden Anatomieanker übertragen, damit Anbauteile beim späteren Formen mitgeführt werden. Die Körperdarstellung gilt gemeinsam für Editor, Spieler und prozedurale Wildtiere.

![Voxel-Werkstatt mit Langhals](../art/review/creature_voxel_studio/grazer_parts.png)

## Geometrie

`creature_voxel_mesh.gd` erzeugt nur die nach außen sichtbaren Flächen benachbarter Würfel. Ein zusammenhängender Körper benötigt eine Mesh-Oberfläche; bewegliche Teile behalten ihre eigenen kleinen Meshes. Es entsteht kein Szenenknoten pro Würfel. Wiederkehrende Teilgeometrie wird in einem begrenzten Cache wiederverwendet.

Die Körperzellen sind in allen drei Richtungen gleich groß. Der Standardabstand beträgt 0,105 Einheiten mal Körpermaßstab. Bei sehr großen Formen wird das Raster anhand der längsten Ausdehnung auf ungefähr 64 Zellen begrenzt. Diese Begrenzung verhindert, dass langgezogene Entwürfe unbegrenzt viele Zellen erzeugen. Extrem dünne Stellen werden mindestens durch ein kleines symmetrisches Voxelprofil repräsentiert.

Die gespeicherten Entwürfe enthalten weiterhin die formbare Anatomie und Farben, keine gerenderten Würfel. Vorhandene Entwürfe benötigen keine neue Dateiversion. Der historische Schalter `sculpted_surface` bleibt als interne Kompatibilität erhalten: `true` wählt jetzt die bearbeitbare Voxeloberfläche, `false` den alten Voxel-Scheibenpfad für bestehende Vergleichsprüfungen.

## Prüfung und Grenzen

Die gezielte Werkstattprüfung kontrolliert zusätzlich exponierte Würfelflächen ohne innere Doppelpolygone, kubisches Raster, harte Normalen, konstante Flächenfarben, korrekte Dreiecksrichtung und Treffer auf sichtbaren Zellen einschließlich Lücken. Die vorhandenen Prüfungen für echte GUI-Eingaben, Drag-and-drop, Körperformung, Symmetrie, Speicherung, Undo/Redo und zwei-, vier- und sechsbeinige Bewegung bleiben erhalten.

Der aktuelle Code `b474fff` besteht **51/51 Projektprüfungen**, **6/6 gezielte Werkstattprüfungen** und **12/12 Prüfungen je Windows-/Linux-Export**. Alle vier Werkstattansichten wurden in Godot bei 1600×900 gerendert und visuell geprüft. Die zwei Wildtier-Referenzen wurden ebenfalls visuell geprüft und benötigen 40 beziehungsweise 33 Mesh-Nodes; der Standardkörper verwendet weiterhin 21 Geometrie-Nodes. Die vollständigen Ergebnisse stehen in [validation/creature-voxel-style.json](../validation/creature-voxel-style.json). Die Normalenprüfung berücksichtigt die geringe Rundungsabweichung der komprimierten Normalen beim Auslesen aus Godot; schräge oder geglättete Flächen bestehen die Prüfung weiterhin nicht.

Die vollständige Umgebungsrenderprüfung ist in **Forward+ und Compatibility** erfolgreich. Die Renderprüfung verwendet einen Software-Renderer und belegt keine Bildrate auf dem Ziel-PC.

Dies ist eine Anpassung der Darstellung und der zugehörigen Trefferberechnung. Die in M3A dokumentierten offenen Punkte zu frei aufgebauten Gelenkketten, Schwimmen/Fliegen, Spielerkollision und Geländeabnahme bleiben bestehen. Der Spieler verwendet weiterhin die bestehende Bewegungskapsel. Ein manueller Spieltest auf Lars’ Rechner und die gemeinsame Integration mit der parallelen Planetenarbeit stehen weiterhin aus.

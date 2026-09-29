# M6-PLANET-PRESENTATION: lager piles after terrain streaming

The warehouse lots used to attempt a floor ray once, when the village anchor
was first synced. If the physics collider was still streaming, that miss was
cached together with the unchanged anchor. The lot then remained at the
provisional anchor height even after the floor appeared.

`VillageStockpiles` now retries only the lots without a floor, at most once
per 0.25 seconds. It stops physics processing as soon as all seven lots are
grounded. The retry changes only scene transforms: inventory, saves, mesh
instances and resource stages remain owned by the existing paths. Paused play
does not advance the retry.

The deterministic missing-floor fixture starts its lots 1 m above the later
collider. It failed against the base tree and passes after the fix; it also
checks that the mesh pool and inventory are unchanged and polling stops.
The real spherical stockpile test still checks all seven radial orientations,
floor contacts, hover and durable order/inventory behavior.

The larger planet-presentation review remains open: compare small and large
worlds, slopes, near and far zoom, camera inclinations, labels and origin
shifts on the integrated PT17 camera/vegetation/village tree. This isolated
grounding correction does not claim that visual or target-PC acceptance.

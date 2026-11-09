# OpenStreetMap

`OsmRouteMap` uses `flutter_map` with `latlong2`. Route points come from saved `ActivitySample.latitude/longitude`, not normalized illustration offsets. Activities without geographic coordinates show an explicit empty state; historical locations are not inferred.

Used in feed route previews, activity post details, private saved activity details, live GPS recordings, and recording save previews. Onboarding illustrations and example venue/league graphics remain illustrations.

The default tile endpoint is `https://tile.openstreetmap.org/{z}/{x}/{y}.png`. Deployments can change it with `--dart-define=OSM_TILE_URL=...`. Application identification is `id.klubby.app`; attribution remains visible and links to the OSM copyright page. `flutter_map`'s built-in network caching remains enabled. No bulk download or offline-area prefetch is implemented.

References:

- https://operations.osmfoundation.org/policies/tiles/
- https://docs.fleaflet.dev/

The public tile service requires internet and is subject to its usage policy. Recorded routes and statistics remain stored locally even when tiles cannot be fetched.

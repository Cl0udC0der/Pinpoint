# Map and geocoding providers for Pinpoint

Research for the open question **"Map API provider"** in [`docs/open-questions.md`](../open-questions.md). It compares providers so the user can choose one at the next design session. It does not make the decision. The decision should be recorded as an ADR.

- **Researched:** 2026-10-12. Every URL below was accessed on 2026-10-12 unless noted.
- **Method:** official pricing pages, terms of service, product docs and source repositories. Where a primary page could not be fetched (JavaScript-only, 403, 404 or TLS failure), this is stated and the claim is marked **unverified**.
- **Vocabulary:** as in [`CONTEXT.md`](../../CONTEXT.md). Each school is a **Feature**. "Private Schools SY 2025–2026" is a **Dataset**, and each school year is a **Snapshot**. Barangays, municipalities and so on are **Administrative Areas**. Travel-time areas are **Isochrones** (deferred).

## Summary

Pinpoint has two hard requirements: geocoded points must be **stored permanently**, and they must be **reusable on any map**, such as MapLibre. Those two requirements rule out more providers than price or accuracy does.

1. **Google Maps Platform is excluded by its terms, not its price.** Geocoding API latitude/longitude may be cached for at most 30 consecutive days. Google Maps Content from the Geocoding API "must not" be used with a non-Google map ([Service Specific Terms §6.2–6.3](https://cloud.google.com/maps-platform/terms/maps-service-terms)). Its coverage of the Philippines is officially rated "good" ([coverage](https://developers.google.com/maps/coverage)), so it remains useful as a manual reference while QA-checking points.
2. **HERE (self-serve) is excluded unless a separate contract is signed.** HERE Platform Terms forbid caching or storing Results outside the platform for more than 30 days ([HERE Platform Terms §6.3(j)](https://legal.here.com/en-gb/terms/here-platform-terms)).
3. **Mapbox sells "Permanent" geocoding at $5.00 per 1,000** (about **$59** for the 11,868 schools). However, its docs also say responses may only be used "in conjunction with a Mapbox map" ([Geocoding API docs](https://docs.mapbox.com/api/search/geocoding/)). The Philippines **does not appear** in Mapbox's geocoding coverage table ([Mapbox data coverage](https://docs.mapbox.com/help/dive-deeper/mapbox-data.md)).
4. **Esri ArcGIS Location Platform** sells "stored" geocodes at $4 per 1,000 (about **$47**). Its terms let a customer keep stored results after a paid subscription ends ([pricing](https://location.arcgis.com/pricing/); [E300 terms, footnote 66](https://www.esri.com/content/dam/esrisites/en-us/media/legal/product-specific-terms-of-use/e300.pdf)). Esri rates the Philippines **Level 2 ("good")** for geocoding ([coverage](https://doc.arcgis.com/en/arcgis-online/reference/geocode-coverage.htm)). Whether stored results may be shown on a non-Esri map is **not stated** in what I could find.
5. **OSM-based options explicitly allow permanent storage and any map.** These are self-hosted Nominatim/Photon, Geoapify, LocationIQ, Stadia Maps (Standard plan or higher) and MapTiler (with caveats). The 12k geocode costs **$0** on free daily quotas, or up to about **$80** for one month of Stadia Standard. The weakness is **Philippine address data in OpenStreetMap**: no OSM-based vendor publishes a Philippines-specific coverage statement, and evidence of quality is anecdotal.
6. **Accuracy for Philippine street addresses is the biggest unknown for every provider.** Only Google, Esri, HERE and TomTom publish a per-country rating, and those are coarse. A **pilot geocode of a sample of ~200 schools** against 2–3 shortlisted providers before choosing is strongly suggested. See [Fit against requirements](#fit-against-pinpoints-requirements).

## Comparison table

Prices are USD list prices. The "12k one-off" column uses 11,868 single-address forward geocodes, with results stored permanently where the provider allows it.

| Provider | Permanent storage of geocodes? | Show on non-vendor map (e.g. MapLibre)? | PH geocoding coverage (official) | Est. cost, 11,868 geocodes | Map display free tier | Isochrones |
|---|---|---|---|---|---|---|
| **Google Maps Platform** | **No**: lat/lng max 30 days ([§6.3](https://cloud.google.com/maps-platform/terms/maps-service-terms)) | **No** ([§6.2](https://cloud.google.com/maps-platform/terms/maps-service-terms)) | Geocoding "good" ([coverage](https://developers.google.com/maps/coverage)) | $9.34 (10k free, then $5/1k); **non-compliant use** | 10k Dynamic Maps loads/mo ([pricing](https://developers.google.com/maps/billing-and-pricing/pricing)) | Isochrones API in **Preview**; expected 10k free, then $3/1k ([billing](https://developers.google.com/maps/documentation/isochrones/usage-and-billing)) |
| **Mapbox** | Yes, with `permanent=true` ([docs](https://docs.mapbox.com/api/search/geocoding/)) | **Doubtful**: docs say "only… in conjunction with a Mapbox map" ([docs](https://docs.mapbox.com/api/search/geocoding/)) | **PH not listed** in coverage table ([coverage](https://docs.mapbox.com/help/dive-deeper/mapbox-data.md)) | **$59.34** ($5/1k, no free tier) ([pricing](https://www.mapbox.com/pricing)) | 50k GL JS loads/mo ([pricing](https://www.mapbox.com/pricing)) | Yes: 100k free, then $2/1k ([pricing](https://www.mapbox.com/pricing)) |
| **Esri ArcGIS Location Platform** | Yes, with `forStorage=true`, paid ([docs](https://developers.arcgis.com/documentation/mapping-and-location-services/geocoding/geocode-addresses/)) | Not stated (**unverified**) | **Level 2, "good"** ([coverage](https://doc.arcgis.com/en/arcgis-online/reference/geocode-coverage.htm)) | **$47.47** ($4/1k stored) ([pricing](https://location.arcgis.com/pricing/)) | 2M basemap tiles or 1k sessions/mo ([pricing](https://location.arcgis.com/pricing/)) | Service areas: 5k free, then $50/1k ([pricing](https://location.arcgis.com/pricing/)) |
| **HERE** | **No** beyond 30 days without a separate agreement ([Platform Terms §6.3(j)](https://legal.here.com/en-gb/terms/here-platform-terms)) | Not stated | Geocode "Full: premium house no., street level", but search quality "Entry" ([geocode coverage](https://docs.here.com/geocoding-and-search/docs/geocode-local-coverage); [search quality](https://docs.here.com/geocoding-and-search/docs/coverage)) | Probably $0 in free tier (**unverified**); **non-compliant storage** | **Unverified** | Isoline Routing exists; base-plan price **unverified** |
| **TomTom** | **Unverified** (terms not found) | **Unverified** | 3 of 4 coverage columns ticked for PH ([market coverage](https://developer.tomtom.com/geocoding-api/documentation/product-information/market-coverage)) | $0 (20k free/mo) ([pricing](https://docs.tomtom.com/pricing)) | 200k vector tiles/mo ([pricing](https://docs.tomtom.com/pricing)) | Reachable Range: 2.5k free/mo ([pricing](https://docs.tomtom.com/pricing)) |
| **Nominatim (self-hosted)** | Yes (ODbL; individual results are insubstantial extracts) ([OSMF guideline](https://osmfoundation.org/wiki/Licence/Community_Guidelines/Geocoding_-_Guideline)) | Yes, credit OSM ([guideline](https://osmfoundation.org/wiki/Licence/Community_Guidelines/Geocoding_-_Guideline)) | No official statement; depends on OSM data | $0 + your server | n/a (pair with Protomaps/MapLibre) | Self-host Valhalla or ORS |
| **Nominatim (public osm.org)** | Yes (same licence) | Yes | Same | $0, about 3.3 h at 1 req/s; one-off bulk "may be permissible" ([policy](https://operations.osmfoundation.org/policies/nominatim/)) | n/a | n/a |
| **Geoapify** | Yes: "we do not restrict you from storing results", keep attribution ([FAQ](https://www.geoapify.com/geocoding-api/)) | Yes (no restriction found) | No PH statement; OSM / open data | $0 (3,000 credits/day, so ~4 days; batch up to 50% cheaper) ([pricing](https://www.geoapify.com/pricing/)) | Tiles 0.25 credit each ([details](https://www.geoapify.com/pricing-details/)) | Isoline: 1 credit per 5 min of range ([details](https://www.geoapify.com/pricing-details/)) |
| **LocationIQ** | "You can store response data forever" ([ToS](https://locationiq.com/tos)) | Yes (no restriction found) | No PH statement; OSM, OpenAddresses and others ([attribution](https://locationiq.com/attribution)) | $0 (5,000/day, so ~3 days) ([pricing](https://locationiq.com/pricing)) | Maps Lite $45/mo for 10k views/day ([pricing](https://locationiq.com/pricing)) | Not listed |
| **Stadia Maps** | Yes on **Standard ($80/mo) or higher**; prohibited below ([ToS §8](https://stadiamaps.com/terms-of-service/)) | Yes (no restriction found) | No PH statement; "powered by OpenStreetMap" ([product](https://stadiamaps.com/products/geocoding-search/)) | **$80** (one month of Standard; 237,360 credits used) ([pricing](https://stadiamaps.com/pricing/)) | Free plan non-commercial; 1 credit/tile ([pricing](https://stadiamaps.com/pricing/)) | 20 credits/request ([pricing](https://stadiamaps.com/pricing/)) |
| **MapTiler** | Terms allow geocoding results "outside of the Service"; FAQ says permanent storage OK "for most use cases"; JS client docs say "do not store" ([terms](https://www.maptiler.com/terms/cloud/); [FAQ](https://www.maptiler.com/search/); [client-js](https://docs.maptiler.com/client-js/)) | Yes for geocoding results ([terms](https://www.maptiler.com/terms/cloud/)) | No PH statement | ~$52 on Flex (if 1 geocode = 1 search session; **unverified**) ([pricing](https://www.maptiler.com/cloud/pricing/)) | Free 5k sessions (non-commercial); Flex $30 for 25k ([pricing](https://www.maptiler.com/cloud/pricing/)) | Not on pricing page |
| **openrouteservice (HeiGIT hosted)** | **Unverified** (ToS page is JavaScript-only) | Probably (OSM-based); **unverified** | No PH statement; OSM-based | $0 (1,000 geocodes/day, so ~12 days) | n/a | 500/day free, 20/min |

## How to read the costs

- **One-off 12k geocode:** every compliant option costs under $100. Cost is **not** a deciding factor for the first Dataset.
- **Future Datasets and Snapshots:** each new Snapshot needs geocoding only for **new or changed addresses**, because a Feature's point belongs to its Snapshot but can be copied forward when the address is unchanged (see [ADR-0001](../adr/0001-trust-source-ids-across-snapshots.md)). Per-geocode prices stay the same: Mapbox $5/1k, Esri $4/1k, Stadia covered by a monthly plan, OSM vendors free within daily quotas.
- **Aggregated student residences** (a future Dataset) are personal data ([open question](../open-questions.md)). Sending residence addresses to any hosted geocoder sends personal data to a third party. **Self-hosted Nominatim/Photon** avoids that entirely, which may matter more than price.
- **Map display:** an analyst tool with few users will very likely stay within the free tiers of Mapbox, Google, Esri and TomTom. Self-hosted Protomaps tiles cost only static file hosting. Exact load volumes are unknown, so no figure is computed.

---

## Per-provider details

### Google Maps Platform

**Geocoding quality / coverage (PH).** Google's coverage table marks the Philippines ⬤ ("available… with good data quality and availability") for Geocoding, 2D/3D Map Tiles, Traffic, Driving and Walking directions. Biking directions and speed limits are not available ([coverage details](https://developers.google.com/maps/coverage)). It is widely regarded as the strongest PH geocoder, but that is anecdotal. The rating above is the only official statement.

**Storage and display terms (decisive).** From the [Google Maps Platform Service Specific Terms](https://cloud.google.com/maps-platform/terms/maps-service-terms) (version last modified June 10, 2026), Geocoding API section:

- §6.2: "Customer must not use Google Maps Content from the Geocoding API in conjunction with a non-Google map."
- §6.3.1: "Customer may temporarily cache latitude (lat) and longitude (lng) values from the Geocoding API for up to 30 consecutive calendar days, after which Customer must delete the cached latitude and longitude values."
- §6.3.2: indefinite caching is allowed only "solely to support the direct, End User facing functionality of the Customer Application that initiated the request… Cached data must be logically isolated to the specific End User… and must not be used across multiple End Users."
- Place IDs may be stored indefinitely ([Geocoding policies](https://developers.google.com/maps/documentation/geocoding/policies)). Storing only place IDs would require re-geocoding for every analysis, so it doesn't meet the requirement.

Pinpoint's model is one shared, permanent table of Feature points used for Buffer, Choropleth and Heat Maps, possibly on MapLibre. That model conflicts with both §6.2 and §6.3.

**Pricing** ([price list](https://developers.google.com/maps/billing-and-pricing/pricing)):

- Geocoding (Essentials): 10,000 free per month, then $5.00 per 1,000 (10,001–100,000), $4.00, $3.00, $1.50 and $0.38 at higher tiers.
- Dynamic Maps (Maps JavaScript): 10,000 free loads per month, then $7.00 per 1,000.
- Map Tiles API 2D tiles: free cap listed as 100,000, then $0.60 per 1,000. (The WebFetch summary and the raw table headers disagreed slightly on tier boundaries, so check before relying on it.)
- Routes Compute Routes Essentials: 10,000 free, then $5.00 per 1,000.
- Subscriptions are also offered: Starter $100/mo for 50,000 combined calls, Essentials $275/mo for 100,000 ([overview](https://developers.google.com/maps/billing-and-pricing/overview)).
- The pricing list page contains no statement of the old $200 monthly credit. The overview page mentions "a monthly credit for qualifying Google Maps Platform SKUs" without amounts ([overview](https://developers.google.com/maps/billing-and-pricing/overview)). Treat the free per-SKU caps as the operative free tier.
- **12k estimate:** (11,868 − 10,000) × $5/1,000 = **$9.34** in one month, or $0 if split across two months. This is moot, since the terms forbid the use.

**Isochrones.** A new **Isochrones API** is in **pre-GA Preview**. Expected GA pricing is 10,000 free per month, then $3.00 per 1,000, with a 300 requests/minute quota per project ([Isochrones billing](https://developers.google.com/maps/documentation/isochrones/usage-and-billing); [Isochrones overview](https://developers.google.com/maps/documentation/isochrones)). Its storage terms were not reviewed; Preview offerings fall under the same Service Specific Terms.

**Caveats.** A billing account is required. Attribution must be the Google Maps logo where possible ([policies](https://developers.google.com/maps/documentation/geocoding/policies)).

### Mapbox

**Geocoding quality / coverage (PH).** Mapbox's Geocoding coverage table lists countries with ●/○/— by level (Region…Address). **The Philippines is absent from the table**, while Malaysia, Singapore, Taiwan and Thailand are listed ([Mapbox data coverage](https://docs.mapbox.com/help/dive-deeper/mapbox-data.md)). The page notes that some data is available at city level without appearing in the list and suggests testing in the playground. A May 2026 blog post announced address coverage in 45 more countries "across… Southeast Asia" but does not name the Philippines ([Mapbox blog, 2026-05-01](https://www.mapbox.com/blog/mapbox-geocoding-adds-45-new-countries-and-73-2-million-addresses)). **Treat PH street-level quality as unproven.**

**Storage and display terms.**

- "Temporary results are not allowed to be cached, while Permanent results are allowed to be cached and stored indefinitely." Permanent requires `permanent=true` and "a valid credit card on file or an active enterprise contract" ([Geocoding API docs](https://docs.mapbox.com/api/search/geocoding/)).
- The pricing page says Permanent results "are only available for your own personal or business use, and cannot be used for distribution or sublicense." It also says "If you're interested in using this API, please contact Mapbox sales" ([pricing](https://www.mapbox.com/pricing)).
- **Display:** the same API doc says "You may only use responses from the Geocoding API in conjunction with a Mapbox map." The page does not say whether this applies to Permanent results. Mapbox's own help page describes Permanent results as usable "for analytics, reporting, and offline applications" ([temporary vs permanent](https://docs.mapbox.com/help/dive-deeper/understand-temporary-vs-permanent-geocoding/)). **Ambiguous: get written confirmation from Mapbox before showing permanent geocodes on MapLibre or another vendor's tiles.**
- The Mapbox ToS (last updated March 31, 2024) has no geocoding-specific clause I could find ([ToS](https://www.mapbox.com/legal/tos)). The product terms page did not render server-side, so it was **not reviewed**.

**Pricing** ([pricing](https://www.mapbox.com/pricing)):

- Temporary geocoding: 100,000 free per month, then $0.75 per 1,000.
- Permanent geocoding: **$5.00 per 1,000** for 1–500,000, then $4.00. **No free tier.**
- GL JS map loads: 50,000 free per month, then $5.00 per 1,000.
- Vector Tiles API: 200,000 free tile requests, then $0.25 per 1,000. Raster: 750,000 free.
- Isochrone API: 100,000 free per month, then $2.00 per 1,000. Directions: the same.
- **12k estimate:** 11,868 × $5/1,000 = **$59.34**.

**Caveats.** The default rate limit is 1,000 requests per minute. The doc contradicts itself on batch size: one section says a batch holds up to 1,000 queries, while the error table says "Batch queries must include 50 queries or less" ([docs](https://docs.mapbox.com/api/search/geocoding/)).

### Esri ArcGIS Location Platform

**Geocoding quality / coverage (PH).** The Philippines is in **Level 2**: "a good geocoding experience. Address searches often result in PointAddress and StreetAddress level matches, but sometimes match to StreetName and Admin levels" ([Geocode data coverage](https://doc.arcgis.com/en/arcgis-online/reference/geocode-coverage.htm)). Release notes report "Increased PointAddress match rates in… Philippines" (April 2025) and PH match-narrative support (2026) ([release notes](https://developers.arcgis.com/rest/geocode/whats-new-world-geocoding-service/)).

**Storage and display terms.**

- "If you need to store or persist the geocoding service results in any way, you are required to use the forStorage parameter" ([geocode docs](https://developers.arcgis.com/documentation/mapping-and-location-services/geocoding/geocode-addresses/)).
- Product-Specific Terms E300 (November 13, 2025), footnote 66, which applies to ArcGIS Location Platform: "Only Customers with a paid Online Services subscription or ArcGIS Location Platform subscription for stored geocodes may store geocoded results… Customer may continue to store geocoded results generated through a paid subscription" ([E300 PDF](https://www.esri.com/content/dam/esrisites/en-us/media/legal/product-specific-terms-of-use/e300.pdf)).
- Footnote 109: "Basemap Styles are for use only with ArcGIS Location Platform Basemap Services" (same PDF).
- **Display of stored geocodes on non-Esri maps:** no explicit permission or prohibition found. **Unverified; ask Esri.** An older (2020) Esri Master Agreement reportedly limits redistribution of geocoded results. I did not verify the current Master Agreement.

**Pricing** ([pricing](https://location.arcgis.com/pricing/)):

- Geocodes (not stored): 20k free, then $0.50 per 1,000.
- Geocodes (stored) and batch geocodes (stored): **$4 per 1,000**, with no free tier.
- Basemap tiles: 2M free, then $0.15 per 1,000. Basemap sessions: 1k free, then $4 per 1,000.
- Service areas (Isochrones): 5K free, then $50 per 1,000. Routes: 20K free, then $0.50 per 1,000.
- **12k estimate:** 11,868 × $4/1,000 = **$47.47**.

**Caveats.** A paid subscription is needed for stored geocodes. Esri's ecosystem works best with the ArcGIS Maps SDK, though its REST services can be called from anywhere.

### HERE

**Geocoding quality / coverage (PH).** The geocode coverage table lists the Philippines as "full: premium house no., street level", with HERE Map Content ([geocode local coverage](https://docs.here.com/geocoding-and-search/docs/geocode-local-coverage)). The separate *search quality* table rates the Philippines **"Entry"** ("Entry-level search experience"; English supported, Filipino not supported) ([coverage](https://docs.here.com/geocoding-and-search/docs/coverage)).

**Storage terms (decisive).** HERE Platform Terms (effective 18 Sept 2023) §6.3(j): you may not "Cache or store outside of the Platform any Results… for more than 30 days… unless Results are used solely for your internal testing, evaluation, or record retention for audit and legal compliance purposes" ([HERE Platform Terms](https://legal.here.com/en-gb/terms/here-platform-terms)). A HERE knowledge-base article on a paid "Permanent Geocoding" licence showed up in search results, but the page now returns 404, so it is **unverified**.

**Pricing.** The base plan pricing pages (`here.com/get-started/pricing`, `developers.here.com/plans`) either returned no pricing text or failed TLS. **Unverified:** search snippets of the HERE plans page cite 30,000 free geocodes per month, then $0.83 per 1,000. HERE's supplemental pricing page defines a batch geocode transaction as "each individual address… within a batch Geocode Request" ([supplemental pricing](https://www.here.com/pricing/supplemental-pricing)). The commercial-terms table (asset plans, not the base plan) lists Isoline Routing at $0.001650 per transaction ([commercial terms](https://www.here.com/pricing/commercial-terms)).

**Caveats.** A credit card is reportedly required for the base plan (search snippet, **unverified**).

### TomTom

**Geocoding quality / coverage (PH).** The market-coverage table (columns: Address points, House number, Street level, City level) shows **three ticks** for the Philippines ([Geocoding market coverage](https://developer.tomtom.com/geocoding-api/documentation/product-information/market-coverage)). The text extract does not show which column is missing. It is probably address points, but this is **unverified**.

**Storage and display terms.** **Not verified.** I could not locate TomTom's developer terms text on caching or storage. The Geocode endpoint's (deprecated) `storeResult` flag says such queries are "billed according to the terms of use" ([Geocode docs](https://developer.tomtom.com/geocoding-api/documentation/geocode)). That suggests stored geocodes are a distinct licence.

**Pricing** ([pricing](https://docs.tomtom.com/pricing)): free monthly requests per API with "no upfront credit card needed". Geocoding API: 20K free per month. Map Display vector or raster tiles: 200K free. Reachable Range (Isochrones): 2.5K free. Per-1,000 overage prices were not readable in the extract (**unverified**).

- **12k estimate:** $0 (within 20K/month), subject to the storage terms, which are unknown.

### OpenStreetMap stack (self-hosted)

**Components and current versions** (GitHub, accessed 2026-10-12):

| Component | Role | Licence | Latest release |
|---|---|---|---|
| [Nominatim](https://github.com/osm-search/Nominatim) | Geocoder | GPL-3.0 | v5.3.2 (2026-04-19) |
| [Photon](https://github.com/komoot/photon) | Geocoder (search-as-you-type) | Apache-2.0 | 1.3.0 (2026-08-07) |
| [MapLibre GL JS](https://github.com/maplibre/maplibre-gl-js) | Web map renderer | BSD-3-Clause ([LICENSE](https://github.com/maplibre/maplibre-gl-js/blob/main/LICENSE.txt)) | v6.14.0 (2026-10-11) |
| [Protomaps basemap](https://docs.protomaps.com/basemaps/downloads) | Vector tiles as one PMTiles file | ODbL Produced Work; OSM attribution required | Daily builds (v4) |
| [Valhalla](https://github.com/valhalla/valhalla) | Routing and [Isochrones](https://valhalla.github.io/valhalla/api/isochrone/api-reference/) | MIT | 3.9.1 (2026-10-06) |
| [openrouteservice](https://github.com/GIScience/openrouteservice) | Routing and Isochrones | GPL-3.0 | v10.0.1 (2026-09-24) |

**Data.** The Geofabrik Philippines extract is 581 MB and "contains all OSM data up to 2026-10-11" ([Geofabrik](https://download.geofabrik.de/asia/philippines.html)). GraphHopper publishes weekly Photon database dumps, including a Philippines country dump ([Photon README](https://github.com/komoot/photon); [dump index](https://download1.graphhopper.com/public/asia/philippines/index.html)). Nominatim needs at least 2 GB RAM; the 128 GB / 1 TB guidance is for a full planet ([Nominatim install](https://nominatim.org/release-docs/latest/admin/Installation/)). A Philippines-only import is far smaller. The exact requirements for PH were not measured.

**Geocoding quality / coverage (PH).** **No official statement exists.** Quality depends on OSM's Philippine street names and house numbers. A 2019 Thinking Machines post said only ~29.6% of the Philippines had been mapped then ([Thinking Machines](https://stories.thinkingmachin.es/mapbox-partnership-announcement/)). That figure is secondary and dated. I tried to count OSM house-number objects in the Philippines via Overpass, but both public Overpass servers were overloaded, so **no current figure**. In practice (anecdotal, my prior knowledge), many Philippine addresses resolve only to street or barangay level in Nominatim. Schools are often mapped as OSM POIs (`amenity=school`), so searching by school name plus municipality may beat searching by address. **Verify in a pilot.**

**Storage and display terms.** The OSMF Geocoding Guideline says individual geocoding results are "insubstantial extracts". It gives "Geocoding store locations" as an example: results added to a store database "are not subject to the share-alike requirements, and the store location database records themselves need not include attribution". Displaying cached results "on a non-OSM map" is also fine, with OSM credited ([OSMF Geocoding Guideline](https://osmfoundation.org/wiki/Licence/Community_Guidelines/Geocoding_-_Guideline)). Share-alike applies only if results are used to rebuild "a substantial part" of the OSM database.

**Public (OSMF) services, if not self-hosting.**

- **Nominatim (nominatim.openstreetmap.org):** "an absolute maximum of 1 request per second" and an identifying User-Agent are required. "Bulk geocoding of larger amounts of data is not encouraged". "Smaller one-time bulk tasks may be permissible" when run single-threaded on one machine with results cached ([Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/)). 11,868 requests ≈ 3.3 hours. Whether 12k counts as "smaller" is a judgement call. Recurring Datasets should self-host or use a vendor.
- **OSM tiles (tile.openstreetmap.org):** best-effort, "no SLA or guarantee". "Commercial services… should be especially aware that access may be withdrawn at any point" ([tile usage policy](https://operations.osmfoundation.org/policies/tiles/)). Not suitable as Pinpoint's production basemap.
- **Photon demo (photon.komoot.io):** "Extensive usage will be throttled or completely banned" ([README](https://github.com/komoot/photon)).

**Pricing.** Software and data cost $0. Costs are a server for Nominatim/Photon and Valhalla, plus static hosting for PMTiles. **12k estimate: $0 plus compute.**

**Caveats.** You run and update it yourself. Attribution "© OpenStreetMap contributors" is required.

### Geoapify (hosted, OSM / open data)

- **Coverage:** no PH-specific statement. "Our services are based on Open Data" ([Geocoding API FAQ](https://www.geoapify.com/geocoding-api/)).
- **Storage:** "we do not restrict you from storing results. However, you have to keep all the attributions to the data source with the stored object or make it visible in some other way when you reuse the data" ([FAQ](https://www.geoapify.com/geocoding-api/)). Terms (v5, 2 Feb 2024): OSM attribution is always required, and Geoapify attribution is mandatory on the Free plan ([T&C](https://www.geoapify.com/term-and-conditions/)).
- **Display:** no restriction to Geoapify maps found.
- **Pricing** ([pricing](https://www.geoapify.com/pricing/); [details](https://www.geoapify.com/pricing-details/)): Free plan gives 3,000 credits/day, no card, commercial use allowed. API 10 is $59/mo for 10,000 credits/day. A geocode costs 1 credit, and batch geocoding saves "up to 50%". A map tile costs 0.25 credit (≈50 tiles per interactive session). An isoline costs "1 credit counted for each 5 minutes of isochrone". The rate limit is up to 30 requests/second depending on plan.
- **12k estimate:** **$0** over ~4 days on Free (~2 days if batch halves credits), or $59 for one month of API 10 to finish in ~1–2 days.

### LocationIQ (hosted, OSM-based)

- **Coverage:** no PH statement. Data comes from OSM, Geonames, Who's On First and OpenAddresses ([attribution](https://locationiq.com/attribution)).
- **Storage:** "If you have a free account, you can cache request-response pairs… for upto 48 hours. If you are a customer, you can cache request-response pairs for as long as you're a customer. You can store response data forever. We do not allow server-side caching of Map Tiles" ([ToS](https://locationiq.com/tos)). "Store response data forever" seems to permit permanent coordinates, but the 48-hour cache line could be read as conflicting on the Free plan. **Ask before relying on Free.**
- **Pricing** ([pricing](https://locationiq.com/pricing)): Free gives 5,000 requests/day at 2 req/s, commercial use allowed with a link back. Developer is $100/mo for 25,000/day. Maps Lite is $45/mo for 10,000 map views/day (a raster view = 16 tiles, a vector view = 4). Routing is on Free and Developer and up. **No isochrone product listed.**
- **12k estimate:** **$0** over ~3 days on Free, or $100 for one Developer month.

### Stadia Maps (hosted, OSM-based)

- **Coverage:** "powered by OpenStreetMap data… highest coverage in North America, Europe, and major urban centers worldwide" ([product page](https://stadiamaps.com/products/geocoding-search/)). No PH statement.
- **Storage:** ToS (effective March 18, 2026; an updated version takes effect November 9, 2026) prohibits "permanently storing results for future use (e.g., as a database column)… from the Stadia Maps Geocoding APIs without an active Standard, Professional, or Enterprise subscription" ([ToS](https://stadiamaps.com/terms-of-service/)). Stadia's own guide warns that "dropping to a lower tier may affect your right to retain data you already stored" ([storage guide](https://stadiamaps.com/learn/geocoding-data-storage/)). **This is a recurring cost if points must be retained.** Check the Nov 2026 ToS text.
- **Pricing** ([pricing](https://stadiamaps.com/pricing/)): Free gives 200k credits/mo, "Commercial use not allowed". Starter is $20 for 1M credits. **Standard is $80 for 7.5M credits.** A geocode (incl. bulk) costs 20 credits, a vector or raster tile 1 credit, an Isochrone 20 credits.
- **12k estimate:** 11,868 × 20 = 237,360 credits, so **$80** (one month of Standard, needed for storage rights). Keeping storage rights may mean staying on Standard.

### MapTiler (hosted, OSM-based)

- **Coverage:** no PH statement.
- **Storage (conflicting sources):**
  - Cloud terms: "Only bulk downloading allowed is for the Geocoding API service. The attribution of the database created has to be clearly marked…" and "Results of the search services, such as Geolocation API, Geocoding API and Routing API, are allowed for usage outside of the Service" ([Cloud terms](https://www.maptiler.com/terms/cloud/)).
  - FAQ: "Yes, for most use cases, you are allowed to store the results of MapTiler geocoding permanently" ([Search page FAQ](https://www.maptiler.com/search/)).
  - JS client docs: "use geocoding functions only from client-side (browser) and do not 🚫 store or redistribute MapTiler Cloud API data. In case of doubt, consult the terms" ([client-js](https://docs.maptiler.com/client-js/)).
  - **Get written confirmation.**
- **Pricing** ([pricing](https://www.maptiler.com/cloud/pricing/)): Free gives 5k map sessions and 1k search sessions/mo, "Suitable for testing, PoC, prototyping, personal, or non-commercial use". Flex is $30/mo for 25k map sessions, 3k search sessions and 500k requests. Overage is $2.50 per 1k sessions or search sessions.
- **12k estimate:** about **$52** = $30 + (11,868 − 3,000) × $2.50/1,000, **if** each server-side geocode counts as one search session. This is **unverified**: how API-key geocoding requests are billed versus sessions was not confirmed.
- **Isochrones:** not on the pricing page.

### openrouteservice (HeiGIT hosted)

- **Plans:** the plans page is a JavaScript app. I read quotas from its bundled plan definitions ([plans](https://account.heigit.org/info/plans)). The **Standard** plan is labelled "Free to use for everyone". Geocode search is 1,000/day (100/min), Isochrones 500/day (20/min), Directions 2,000/day. The **Collaborative** plan (humanitarian, academic, governmental or not-for-profit) is tagged "non-commercial".
- **Storage / licence of results:** **unverified** (the ToS page is JavaScript-only). The geocoder is Pelias over OSM and other open data (prior knowledge).
- **12k estimate:** $0 over ~12 days. Its main value for Pinpoint is free hosted Isochrones for prototyping, or self-hosting (GPL-3.0).

### Others not researched

Azure Maps and AWS Location Service were outside the brief and are not covered.

---

## Philippine Administrative Area boundary data

Pinpoint assigns a Feature to an Administrative Area by **where its point falls** ([CONTEXT.md](../../CONTEXT.md)). It therefore needs **barangay polygons** keyed to **PSGC codes**, independent of the map vendor.

| Source | Levels / barangay? | Licence | Latest version | Notes |
|---|---|---|---|---|
| **PSA PSGC** (codes and names only, no geometry) | Region → barangay | Government publication; licence not reviewed | **2Q 2026, as of 30 June 2026**, released 13 July 2026 (via search results; [psa.gov.ph/classification/psgc](https://psa.gov.ph/classification/psgc) returned 403 to my fetches) | The authoritative code list. Quarterly updates rename, merge and create barangays. The national barangay count (~42,000) is from prior knowledge and **unverified**. |
| **HDX / OCHA COD-AB (v03)** | Admin 0–4 (4 = barangay) | **CC BY-IGO** | HDX files updated 2026-05-28; boundaries "created by the source" 9 Feb 2018, "reviewed" 1 Apr 2024 ([HDX](https://data.humdata.org/dataset/cod-ab-phl)) | Source: NAMRIA and PSA. **The HDX description says "Admin 4: 11920", but the published xlsx has 42,048 admin-4 rows** (counted 2026-10-12). Trust the data, not the blurb. Geometry dates from 2018, so post-2018 PSGC changes are missing. |
| **geoBoundaries (gbOpen)** | ADM3 (1,647 units); **no ADM4** via API | CC BY 3.0 IGO | Built Dec 12, 2023 ([API](https://www.geoboundaries.org/api/current/gbOpen/PHL/ADM3/)) | Derived from the NAMRIA/PSA/OCHA data. |
| **GADM 4.1** | Levels 0–3 (L1 = 81 provinces, L3 = barangay) | **Non-commercial only**: "Redistribution or commercial use is not allowed without prior permission" ([licence](https://gadm.org/license.html)) | 4.1 (files dated July 2022) ([download](https://gadm.org/download_country.html)) | Has no Region level. Restrictive licence. |
| **altcoder/philippines-psgc-shapefiles** | Levels 1–4 incl. "Barangays and Sub-Municipalities" | Repo states MIT ([repo](https://github.com/altcoder/philippines-psgc-shapefiles)) | README says updated to PSGC 4Q 2023; repo pushed 2026-10-11 | Community project applying PSGC changes to public boundaries. The MIT label may not cover upstream NAMRIA/OCHA rights. |
| **NAMRIA** | Official national mapping agency | Not published online; administrative maps are listed as free products by request, digital products for purchase ([citizen's charter PDF](https://namria.gov.ph/Downloads/CitizensCharter/2026/External/Request%20for%20Free%20Products%20and%20Services.pdf)) | n/a | Licence for redistribution or commercial use **unclear**. OSM contributors have said NAMRIA data can't be imported (informal). |
| **OSM boundaries** | Barangay = `admin_level=10`; sitio/purok = 11 ([OSM wiki](https://wiki.openstreetmap.org/wiki/Tag:boundary%3Dadministrative)) | ODbL | Continuous (Geofabrik daily) | **Completeness of barangay polygons is unverified.** No PSGC codes guaranteed. |

**Takeaway.** For a first version, COD-AB v03 (CC BY-IGO, 42k barangay polygons) joined to the current PSGC code list is the most usable open option. Expect mismatches for barangays created, merged or renamed since 2018. This choice does not depend on the map vendor.

---

## Fit against Pinpoint's requirements

Legend: ✅ meets · ⚠️ partly or needs confirmation · ❌ fails · ? unknown

| Requirement | Google | Mapbox | Esri | HERE | TomTom | OSM self-host | Geoapify | LocationIQ | Stadia | MapTiler |
|---|---|---|---|---|---|---|---|---|---|---|
| Store coordinates permanently | ❌ | ✅ (paid) | ✅ (paid) | ❌ (30 days) | ? | ✅ | ✅ | ⚠️ (Free-plan wording) | ⚠️ (Standard+, ongoing) | ⚠️ (conflicting docs) |
| Reuse on any map (MapLibre) | ❌ | ⚠️ | ? | ? | ? | ✅ | ✅ | ✅ | ✅ | ✅ |
| PH street-level quality, official | ✅ "good" | ❌ not listed | ✅ Level 2 | ⚠️ Entry search | ⚠️ | ? | ? | ? | ? | ? |
| 12k one-off cost | n/a | $59 | $47 | n/a | $0? | $0 + server | $0 | $0 | $80 | ~$52 |
| Isochrones available | Preview | ✅ | ✅ (pricey) | ✅ | ✅ | ✅ (Valhalla/ORS) | ✅ | ❌ | ✅ | ? |
| Keeps personal data in-house (residences) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |

### Tentative shortlist (for discussion, not a decision)

1. **Esri ArcGIS Location Platform, stored geocodes.** It is the only provider found that combines an official "good" PH rating, explicit permanent-storage rights that survive the subscription, and a low cost (~$47). **Open item:** confirm in writing that stored geocodes may be displayed on MapLibre / non-Esri basemaps.
2. **OSM stack: self-hosted Nominatim or Photon + MapLibre + Protomaps, with Valhalla later for Isochrones.** It has no storage or display restrictions, costs $0 per geocode, and keeps future residence data in-house. Geoapify or LocationIQ free tiers could stand in for self-hosting on the first Dataset. **Open item:** PH address quality is unproven. Expect more street- or barangay-level fallbacks, and plan for name-based POI matching plus manual correction.
3. **Mapbox Permanent Geocoding**, only if a pilot shows good PH results **and** Mapbox confirms permanent results may be shown on a non-Mapbox map. Coverage tables suggest it is the weakest of the paid options for the Philippines.

**Suggested next step before the design session:** pilot ~200 randomly sampled schools (stratified by region, urban and rural) through Esri (stored), one OSM option (Geoapify, Nominatim, or both) and optionally Mapbox. Record each provider's match type (rooftop, street, barangay, municipality). Spot-check distances against Google Maps by eye: a manual visual check, not stored. Pilot volumes fit within free tiers or cost a few dollars.

**Architecture note, whichever provider wins:** store each Feature's point with `geocoder`, `geocoder_version/date`, `match_type` and `confidence` attributes on the Snapshot. A provider can then be swapped, or individual points re-geocoded or hand-corrected, without changing analysis code.

---

## Claims I could not verify

- HERE base-plan geocoding price and free tier (pages unreachable). HERE's paid "Permanent Geocoding" licence (KB page now 404).
- TomTom terms on storing geocodes and on use with non-TomTom maps. TomTom overage prices. Which of the four coverage columns is unticked for the Philippines.
- Esri's position on showing stored geocodes on non-Esri basemaps. The current Esri Master Agreement redistribution clause.
- Mapbox product-terms text (page did not render). Whether "only… in conjunction with a Mapbox map" applies to Permanent results.
- MapTiler billing unit for server-side geocoding (search session vs request). How MapTiler's storage statements reconcile.
- openrouteservice terms of service (JavaScript-only page).
- LocationIQ: whether the Free plan's 48-hour cache limit restricts permanent storage.
- PSA national barangay count and the PSGC page itself (403). The 2Q 2026 release details come from search results.
- Current OSM house-number coverage for the Philippines (Overpass servers overloaded).
- Anything marked "prior knowledge" above.

## Sources

All accessed 2026-10-12.

**Google:** [Service Specific Terms](https://cloud.google.com/maps-platform/terms/maps-service-terms) · [Geocoding policies](https://developers.google.com/maps/documentation/geocoding/policies) · [Pricing list](https://developers.google.com/maps/billing-and-pricing/pricing) · [Pricing overview](https://developers.google.com/maps/billing-and-pricing/overview) · [Coverage](https://developers.google.com/maps/coverage) · [Isochrones overview](https://developers.google.com/maps/documentation/isochrones) · [Isochrones billing](https://developers.google.com/maps/documentation/isochrones/usage-and-billing)

**Mapbox:** [Pricing](https://www.mapbox.com/pricing) · [Geocoding API docs](https://docs.mapbox.com/api/search/geocoding/) · [Temporary vs permanent](https://docs.mapbox.com/help/dive-deeper/understand-temporary-vs-permanent-geocoding/) · [Data coverage](https://docs.mapbox.com/help/dive-deeper/mapbox-data.md) · [ToS](https://www.mapbox.com/legal/tos) · [Blog 2026-05-01](https://www.mapbox.com/blog/mapbox-geocoding-adds-45-new-countries-and-73-2-million-addresses)

**Esri:** [Location Platform pricing](https://location.arcgis.com/pricing/) · [Geocode addresses / forStorage](https://developers.arcgis.com/documentation/mapping-and-location-services/geocoding/geocode-addresses/) · [E300 Product-Specific Terms (Nov 13, 2025)](https://www.esri.com/content/dam/esrisites/en-us/media/legal/product-specific-terms-of-use/e300.pdf) · [Geocode data coverage](https://doc.arcgis.com/en/arcgis-online/reference/geocode-coverage.htm) · [Release notes](https://developers.arcgis.com/rest/geocode/whats-new-world-geocoding-service/)

**HERE:** [Platform Terms](https://legal.here.com/en-gb/terms/here-platform-terms) · [Geocode local coverage](https://docs.here.com/geocoding-and-search/docs/geocode-local-coverage) · [Search coverage](https://docs.here.com/geocoding-and-search/docs/coverage) · [Supplemental pricing](https://www.here.com/pricing/supplemental-pricing) · [Commercial terms](https://www.here.com/pricing/commercial-terms)

**TomTom:** [Pricing](https://docs.tomtom.com/pricing) · [Geocoding market coverage](https://developer.tomtom.com/geocoding-api/documentation/product-information/market-coverage) · [Geocode docs](https://developer.tomtom.com/geocoding-api/documentation/geocode)

**OSM stack:** [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/) · [Tile usage policy](https://operations.osmfoundation.org/policies/tiles/) · [OSMF Geocoding Guideline](https://osmfoundation.org/wiki/Licence/Community_Guidelines/Geocoding_-_Guideline) · [Nominatim install](https://nominatim.org/release-docs/latest/admin/Installation/) · [Nominatim repo](https://github.com/osm-search/Nominatim) · [Photon repo](https://github.com/komoot/photon) · [Photon dumps](https://download1.graphhopper.com/public/asia/philippines/index.html) · [MapLibre GL JS](https://github.com/maplibre/maplibre-gl-js) · [Protomaps downloads](https://docs.protomaps.com/basemaps/downloads) · [Valhalla](https://github.com/valhalla/valhalla) · [Valhalla isochrone API](https://valhalla.github.io/valhalla/api/isochrone/api-reference/) · [openrouteservice repo](https://github.com/GIScience/openrouteservice) · [Geofabrik Philippines](https://download.geofabrik.de/asia/philippines.html) · [Thinking Machines 2019 (secondary)](https://stories.thinkingmachin.es/mapbox-partnership-announcement/)

**Hosted OSM vendors:** [Geoapify pricing](https://www.geoapify.com/pricing/) · [Geoapify pricing details](https://www.geoapify.com/pricing-details/) · [Geoapify geocoding FAQ](https://www.geoapify.com/geocoding-api/) · [Geoapify T&C](https://www.geoapify.com/term-and-conditions/) · [LocationIQ pricing](https://locationiq.com/pricing) · [LocationIQ ToS](https://locationiq.com/tos) · [LocationIQ attribution](https://locationiq.com/attribution) · [Stadia pricing](https://stadiamaps.com/pricing/) · [Stadia ToS](https://stadiamaps.com/terms-of-service/) · [Stadia storage guide](https://stadiamaps.com/learn/geocoding-data-storage/) · [Stadia geocoding product](https://stadiamaps.com/products/geocoding-search/) · [MapTiler pricing](https://www.maptiler.com/cloud/pricing/) · [MapTiler Cloud terms](https://www.maptiler.com/terms/cloud/) · [MapTiler search FAQ](https://www.maptiler.com/search/) · [MapTiler client-js](https://docs.maptiler.com/client-js/) · [openrouteservice plans (JS app)](https://account.heigit.org/info/plans)

**Boundaries:** [PSA PSGC](https://psa.gov.ph/classification/psgc) (403 to automated fetch) · [HDX COD-AB Philippines](https://data.humdata.org/dataset/cod-ab-phl) · [geoBoundaries API PHL ADM3](https://www.geoboundaries.org/api/current/gbOpen/PHL/ADM3/) · [GADM licence](https://gadm.org/license.html) · [GADM download](https://gadm.org/download_country.html) · [altcoder PSGC shapefiles](https://github.com/altcoder/philippines-psgc-shapefiles) · [NAMRIA free products charter](https://namria.gov.ph/Downloads/CitizensCharter/2026/External/Request%20for%20Free%20Products%20and%20Services.pdf) · [OSM admin levels](https://wiki.openstreetmap.org/wiki/Tag:boundary%3Dadministrative)

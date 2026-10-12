# Open questions

Questions deferred from design grilling sessions, to be picked up in the next one.

## Student residence data (deferred 2026-10-12)

Where does student residence data come from, and how is it protected?

- Is it uploaded by the Analyst (e.g. a school's own enrolment list), synthetic, or already aggregated at the source?
- Residences are personal data under the Philippine Data Privacy Act (RA 10173). Where is it stored, who can see it, and does it ever leave the Analyst's machine?
- Are individual residences ever shown, or only Aggregate Points?

## Map API provider (deferred 2026-10-12)

Which map and geocoding provider should Pinpoint use? Pick one after researching each provider's capabilities and costs.

- Requirement: Features must be located to street-level accuracy (the general position on the street).
- Requirement: geocoded coordinates must be stored permanently and reused for analysis. Some providers' terms forbid this (e.g. Google limits caching and requires display on a Google map).
- Candidates: Google Maps Platform, Mapbox, an OpenStreetMap stack (Nominatim/Photon + MapLibre), and possibly others.
- For each provider, compare: geocoding accuracy for Philippine addresses, storage and display terms, pricing (one-off geocoding of ~11,868 schools plus future Datasets, map display loads), and support for Isochrones.
- Once decided, record it as an ADR.

## Grouping finer than a barangay ("Locality") (deferred 2026-10-12)

Should individuals be grouped below the Barangay by a shared address line (e.g. every student whose address names a given subdivision)? Decide once residence data and more details arrive.

- Watch out: some address lines that look like subdivisions are official barangays (e.g. Sikatuna Village, Quezon City).
- Candidate name: **Locality**, a named place within a Barangay that has no official boundary.
- Spelling variants ("Loyola Grand Villas", "LGV", "Loyola Grand Villa Subd."): merge them automatically, by hand, or with merges the tool suggests and the Analyst confirms?
- Can a Locality span several Barangays, or must it be split at barangay boundaries?
- Where would its Aggregate Point sit, given there's no boundary to take a geometric centre from?

## Feature identity across Snapshots (watch, see ADR-0001)

We currently trust source IDs, which breaks trends when DepEd changes a `school_id`. Revisit once year-over-year analysis matters or DepEd publishes its ID crosswalk.

## Web app vs Python visualization (deferred 2026-10-12)

The interactive web app hosts the primary features, but the final feature set isn't settled. Which features belong in the web app, and which are easier to visualize with a Python library?

- A suggested split: data that is constantly updated or explored interactively goes in the web app; one-off or static analyses go to Python.
- Which of Buffer, Choropleth and Heat Maps, and the comparisons between them, fall on each side?

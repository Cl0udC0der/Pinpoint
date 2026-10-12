---
status: accepted
---

# Trust source IDs for Feature identity across Snapshots (for now)

A Feature is identified across Snapshots by its source ID (for schools, DepEd's `school_id`), so a new ID means a new Feature. DepEd warns that `school_id` can change between school years when schools merge, split or change their curricular offerings. This decision therefore **breaks year-over-year trends for those schools**: one real school can appear as two unrelated Features. We accept this for now because no crosswalk exists and the affected schools are a minority. DepEd says it intends to publish ID-mapping data in future releases.

**Revisit this decision** once multiple Snapshots are loaded and year-over-year analysis matters, or once DepEd publishes its ID crosswalk.

## Considered Options

- **Pinpoint-owned identity with a crosswalk**: correct across ID changes, but it needs mapping data that doesn't exist yet.
- **Automatic matching by name and position**: risks wrongly merging distinct schools that share a name or a compound.

## Consequences

- Keep the source ID as an attribute of each Snapshot, not as the Feature's primary key, so a Pinpoint-owned identity can be added later without reshaping the data.
- A Feature's point (coordinates) belongs to the Snapshot, because campuses can move between years.
- Any year-over-year analysis must warn that trends may break where source IDs changed.

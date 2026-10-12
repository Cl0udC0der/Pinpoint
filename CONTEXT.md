# Pinpoint

Pinpoint is a geospatial analysis and visualization tool for analysts and researchers. It places real-world entities (schools, student residences, and others) on a map and compares them spatially to produce analytical maps and insights.

## Language

### People

**Analyst**:
The primary user: an analyst or researcher using Pinpoint to gain and visualize spatial insights.
_Avoid_: Customer, end user

### Spatial data

**Feature**:
A single real-world entity placed on the map, such as one school, located to street-level accuracy.
_Avoid_: Location, site, pin

**Dataset**:
A named set of Features of one kind from one source, such as "Private Schools SY 2025–2026".
_Avoid_: Layer, collection

**Snapshot**:
The state of a Dataset as of one point in time, such as school year 2025–2026. A Dataset may have many Snapshots. A Feature's point and attributes belong to a Snapshot. A Feature is identified across Snapshots only by its source ID, so a changed ID reads as a different Feature (see ADR-0001).
_Avoid_: Version, release

**Data Flag**:
A marker on a Feature within a Snapshot showing that its data is incomplete or under special circumstances, such as a school reporting zero enrolment. Flagged Features are kept, never dropped.
_Avoid_: Error, invalid record

**Administrative Area**:
An official Philippine boundary at any PSGC level (region, province, city/municipality, barangay). Features belong to an Administrative Area by where their point falls, not by their written address.
_Avoid_: Zone, district

**Barangay**:
The smallest Administrative Area, and the finest level at which individuals are grouped by official boundary.
_Avoid_: Village, neighbourhood

**Aggregate Point**:
A single point, placed at the geometric centre of an Administrative Area, that stands for the count of Features (such as students or schools) within that area at the current Aggregation Level.
_Avoid_: Cluster

**Aggregation Level**:
The Administrative Area level (region, province, city/municipality or barangay) at which Features are combined into Aggregate Points. It follows the map's zoom by default, and the Analyst can override it.
_Avoid_: Granularity, zoom level

### Analysis

**Distance**:
Straight-line (as-the-crow-flies) distance between two points, unless stated otherwise.
_Avoid_: Travel distance

**Isochrone**:
The area reachable from a point within a given travel time. A desired but deferred capability.

### Analytical maps

**Buffer Map**:
A map showing the zone within a set Distance around one or more points, and the Features or Aggregate Points that fall inside it. An Aggregate Point counts entirely or not at all, depending on whether its point falls inside the zone.

**Choropleth Map**:
A map that shades administrative areas by a measured value.

**Heat Map**:
A map showing the density of points as a continuous colour surface, with no regard to administrative boundaries.

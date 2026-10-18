-- Pinpoint database schema.
--
-- Built from DepEd's private-school enrollment workbook
-- (deped_private_basic_education_schools_sy2025-2026.xlsx, tabs "Directory" and
-- "Full DepEd Data"). Fixed reference rows live in seed/reference.sql; the loader is
-- etl/load_deped_enrollment.py.
--
-- Dialect: SQLite (3.31+). PRAGMA foreign_keys = ON.
--
-- Shape (3NF, plus one cache table):
--   dataset ─< snapshot ─< school_snapshot >─ school          (CONTEXT.md, ADR-0001)
--                               ├─< enrollment >─ enrollment_category >─ grade_level >─ school_level
--                               │                                    └─ shs_strand
--                               └── school_snapshot_enrollment  (totals cache, rebuilt from enrollment)
--   region ─< province ─< municipality ─< barangay             (geographic hierarchy)
--          └< province ─< legislative_district
--   region ─< division ─< school_district                      (DepEd hierarchy, separate)
--   lookups: sector, school_management, annex_status,
--            curricular_offering ─< curricular_offering_level >─ school_level
--
-- Dependencies found in the data that drive this design:
--   * province -> region holds; division -> province does NOT (provinces have several
--     divisions, and "Davao Occidental" division spans two provinces). So the DepEd and
--     geographic hierarchies are kept apart, both hanging off region.
--   * Names are not unique on their own: division "San Carlos City" exists in Region I
--     and NIR; 92 municipality names repeat across provinces; school district names
--     repeat across divisions. Every child is keyed by (parent, name).
--   * school_district and legislative_district are NOT determined by barangay
--     (748 and 315 counter-examples), so they are attributes of each school.
--   * offers_es / offers_jhs / offers_shs are fully determined by curricular_offering
--     (transitive dependency) and move to curricular_offering_level.
--   * source_dataset, source_url, extraction_date are constant per load and belong to
--     the snapshot, not to each school.
--
-- "Full DepEd Data" tab:
--   * Its 16 school columns are identical to the Directory tab ("Modified Curricular
--     Offering Classification" = curricular_offering), so only the 66 grade-by-sex
--     columns are new. They are a repeating group (33 grade/strand categories x 2 sexes)
--     and become rows in enrollment.
--   * A blank cell is not a zero. Blanks cover a whole school level at once (and both
--     sexes together); 31 ES, 18 JHS and 91 SHS levels are offered but unreported.
--     Reported zeros are stored as rows; blank cells have no row.
--
-- Enrollment totals:
--   * enrollment is the source of truth. The Directory's per-level and per-sex totals
--     are sums over it, kept in school_snapshot_enrollment because Snapshots are
--     immutable once loaded and the maps filter and size Features by these totals.
--     Summing on every read cost ~400 ms for a single school (SQLite cannot push a
--     WHERE through the GROUP BY); the cache answers the same query in ~1 ms.
--   * The loader fills the cache from school_snapshot_enrollment_calc and checks it
--     against the source workbook. Never write to it by hand.

PRAGMA foreign_keys = ON;

------------------------------------------------------------------------------
-- Provenance: Dataset and Snapshot
------------------------------------------------------------------------------

CREATE TABLE dataset (
    dataset_id   INTEGER PRIMARY KEY,
    name         TEXT NOT NULL UNIQUE,   -- 'Private Schools'
    source_url   TEXT NOT NULL           -- 'https://www.deped.gov.ph/machine-ready-files/'
);

CREATE TABLE snapshot (
    snapshot_id         INTEGER PRIMARY KEY,
    dataset_id          INTEGER NOT NULL REFERENCES dataset (dataset_id),
    school_year         TEXT NOT NULL,   -- 'SY 2025-2026'
    source_dataset_name TEXT NOT NULL,   -- 'DepEd Enrollment in SY 2025-2026'
    extraction_date     TEXT NOT NULL,   -- ISO date, '2026-07-28'
    UNIQUE (dataset_id, school_year)
);

------------------------------------------------------------------------------
-- Geographic hierarchy (as written in the source address, not point-in-polygon)
------------------------------------------------------------------------------

CREATE TABLE region (
    region_id  INTEGER PRIMARY KEY,
    name       TEXT NOT NULL UNIQUE      -- 'Region IV-A', 'NCR', 'BARMM', 'NIR'
);

CREATE TABLE province (
    province_id  INTEGER PRIMARY KEY,
    region_id    INTEGER NOT NULL REFERENCES region (region_id),
    name         TEXT NOT NULL,          -- trimmed; NCR uses 'NCR FOURTH DISTRICT' etc.
    UNIQUE (region_id, name)
);

CREATE TABLE municipality (
    municipality_id  INTEGER PRIMARY KEY,
    province_id      INTEGER NOT NULL REFERENCES province (province_id),
    name             TEXT NOT NULL,      -- city or municipality
    UNIQUE (province_id, name)
);

CREATE TABLE barangay (
    barangay_id      INTEGER PRIMARY KEY,
    municipality_id  INTEGER NOT NULL REFERENCES municipality (municipality_id),
    name             TEXT NOT NULL,
    UNIQUE (municipality_id, name),
    UNIQUE (municipality_id, barangay_id)   -- target for school_snapshot's composite FK
);

CREATE TABLE legislative_district (
    legislative_district_id  INTEGER PRIMARY KEY,
    province_id              INTEGER NOT NULL REFERENCES province (province_id),
    name                     TEXT NOT NULL,  -- '1st District', 'Lone District', ...
    UNIQUE (province_id, name)
);

------------------------------------------------------------------------------
-- DepEd administrative hierarchy
------------------------------------------------------------------------------

CREATE TABLE division (
    division_id  INTEGER PRIMARY KEY,
    region_id    INTEGER NOT NULL REFERENCES region (region_id),
    name         TEXT NOT NULL,
    UNIQUE (region_id, name)
);

CREATE TABLE school_district (
    school_district_id  INTEGER PRIMARY KEY,
    division_id         INTEGER NOT NULL REFERENCES division (division_id),
    name                TEXT NOT NULL,
    UNIQUE (division_id, name)
);

------------------------------------------------------------------------------
-- Lookups (source values have trailing spaces, e.g. 'Sectarian '; store trimmed)
------------------------------------------------------------------------------

CREATE TABLE sector (
    sector_id  INTEGER PRIMARY KEY,
    name       TEXT NOT NULL UNIQUE      -- 'Private' (Public, SUC/LUC, PSO in full source)
);

CREATE TABLE school_management (
    school_management_id  INTEGER PRIMARY KEY,
    name                  TEXT NOT NULL UNIQUE  -- 'Non-Sectarian', 'Sectarian', ...
);

CREATE TABLE annex_status (
    annex_status_id  INTEGER PRIMARY KEY,
    name             TEXT NOT NULL UNIQUE  -- 'School with no Annexes', 'Mother school', ...
);

CREATE TABLE school_level (
    school_level_id  INTEGER PRIMARY KEY,
    code             TEXT NOT NULL UNIQUE,  -- 'ES', 'JHS', 'SHS'
    name             TEXT NOT NULL,         -- 'Elementary School', ...
    sort_order       INTEGER NOT NULL UNIQUE
);

CREATE TABLE curricular_offering (
    curricular_offering_id  INTEGER PRIMARY KEY,
    name                    TEXT NOT NULL UNIQUE  -- 'Purely ES', 'All Offering', ...
);

-- Which levels an offering covers; replaces offers_es / offers_jhs / offers_shs.
-- Not derivable from enrollment: some offered levels have no reported learners.
CREATE TABLE curricular_offering_level (
    curricular_offering_id  INTEGER NOT NULL REFERENCES curricular_offering (curricular_offering_id),
    school_level_id         INTEGER NOT NULL REFERENCES school_level (school_level_id),
    PRIMARY KEY (curricular_offering_id, school_level_id)
) WITHOUT ROWID;

------------------------------------------------------------------------------
-- Enrollment categories: the 33 grade/strand groups behind the 66 source columns
------------------------------------------------------------------------------

CREATE TABLE grade_level (
    grade_level_id   INTEGER PRIMARY KEY,
    school_level_id  INTEGER NOT NULL REFERENCES school_level (school_level_id),
    code             TEXT NOT NULL UNIQUE,  -- 'K', 'G1'..'G12', 'ESNG', 'JHSNG'
    name             TEXT NOT NULL,         -- 'Kindergarten', 'Grade 1', 'ES non-graded', ...
    sort_order       INTEGER NOT NULL UNIQUE
);

CREATE TABLE shs_strand (
    shs_strand_id  INTEGER PRIMARY KEY,
    code           TEXT NOT NULL UNIQUE,  -- 'ABM', 'STEM', 'TVL', 'SSHS_ACAD', ...
    name           TEXT NOT NULL          -- 'Accountancy, Business and Management', ...
);

-- One row per source column pair, e.g. 'g11_stem' -> (Grade 11, STEM).
-- shs_strand_id is NULL for every non-SHS grade.
CREATE TABLE enrollment_category (
    enrollment_category_id  INTEGER PRIMARY KEY,
    grade_level_id          INTEGER NOT NULL REFERENCES grade_level (grade_level_id),
    shs_strand_id           INTEGER REFERENCES shs_strand (shs_strand_id),
    source_prefix           TEXT NOT NULL UNIQUE,  -- column stem in the source: 'kinder', 'g7', 'g11_stem'
    first_school_year       TEXT,                  -- e.g. 'SY 2025-2026' for SSHS tracks; NULL = always
    UNIQUE (grade_level_id, shs_strand_id)
);

------------------------------------------------------------------------------
-- Schools: Feature identity + per-Snapshot attributes (ADR-0001)
------------------------------------------------------------------------------

-- Pinpoint-owned identity. Today it is 1:1 with DepEd's school_id; it exists so an
-- ID crosswalk can merge Features later without reshaping school_snapshot.
CREATE TABLE school (
    school_pk  INTEGER PRIMARY KEY
);

CREATE TABLE school_snapshot (
    school_pk                INTEGER NOT NULL REFERENCES school (school_pk),
    snapshot_id              INTEGER NOT NULL REFERENCES snapshot (snapshot_id),

    source_school_id         INTEGER NOT NULL,   -- DepEd 6-digit school_id
    school_name              TEXT NOT NULL,      -- not unique: 11,520 names / 11,868 schools

    -- Written address. barangay is missing for 5 schools (e.g. Subic Bay Freeport).
    municipality_id          INTEGER NOT NULL REFERENCES municipality (municipality_id),
    barangay_id              INTEGER,
    street_address           TEXT,               -- missing for 99 schools
    legislative_district_id  INTEGER NOT NULL REFERENCES legislative_district (legislative_district_id),

    school_district_id       INTEGER NOT NULL REFERENCES school_district (school_district_id),

    sector_id                INTEGER NOT NULL REFERENCES sector (sector_id),
    school_management_id     INTEGER NOT NULL REFERENCES school_management (school_management_id),
    annex_status_id          INTEGER NOT NULL REFERENCES annex_status (annex_status_id),
    curricular_offering_id   INTEGER NOT NULL REFERENCES curricular_offering (curricular_offering_id),

    -- The Feature's point belongs to the Snapshot (campuses move). Not in the
    -- source workbook; filled by geocoding.
    latitude                 REAL CHECK (latitude  BETWEEN -90  AND 90),
    longitude                REAL CHECK (longitude BETWEEN -180 AND 180),

    PRIMARY KEY (school_pk, snapshot_id),
    UNIQUE (snapshot_id, source_school_id),
    -- A barangay, when given, must lie in the school's municipality.
    FOREIGN KEY (municipality_id, barangay_id) REFERENCES barangay (municipality_id, barangay_id)
);

CREATE INDEX school_snapshot_municipality ON school_snapshot (municipality_id);
CREATE INDEX school_snapshot_barangay     ON school_snapshot (barangay_id);
CREATE INDEX school_snapshot_district     ON school_snapshot (school_district_id);

-- Learners per school, Snapshot, grade/strand and sex ("Full DepEd Data" tab).
-- Source cells are floats ('132.0') but always whole; store as INTEGER.
CREATE TABLE enrollment (
    school_pk               INTEGER NOT NULL,
    snapshot_id             INTEGER NOT NULL,
    enrollment_category_id  INTEGER NOT NULL REFERENCES enrollment_category (enrollment_category_id),
    sex                     TEXT NOT NULL CHECK (sex IN ('M', 'F')),
    learners                INTEGER NOT NULL CHECK (learners >= 0),
    PRIMARY KEY (school_pk, snapshot_id, enrollment_category_id, sex),
    FOREIGN KEY (school_pk, snapshot_id) REFERENCES school_snapshot (school_pk, snapshot_id)
) WITHOUT ROWID;

-- For "learners in grade X across all schools" queries.
CREATE INDEX enrollment_category_sex ON enrollment (snapshot_id, enrollment_category_id, sex);

------------------------------------------------------------------------------
-- Enrollment totals: calculation (view) and cache (table)
------------------------------------------------------------------------------

-- The one definition of a school's totals. A level total is NULL when DepEd reported
-- nothing for that level (no enrollment rows), so "unreported" stays distinct from 0.
CREATE VIEW school_snapshot_enrollment_calc AS
SELECT
    ss.school_pk,
    ss.snapshot_id,
    SUM(CASE WHEN gl.school_level_id = 1 THEN e.learners END) AS es_enrollment,
    SUM(CASE WHEN gl.school_level_id = 2 THEN e.learners END) AS jhs_enrollment,
    SUM(CASE WHEN gl.school_level_id = 3 THEN e.learners END) AS shs_enrollment,
    COALESCE(SUM(CASE WHEN e.sex = 'M' THEN e.learners END), 0) AS total_male,
    COALESCE(SUM(CASE WHEN e.sex = 'F' THEN e.learners END), 0) AS total_female
FROM school_snapshot ss
LEFT JOIN enrollment          e  ON e.school_pk = ss.school_pk AND e.snapshot_id = ss.snapshot_id
LEFT JOIN enrollment_category ec ON ec.enrollment_category_id = e.enrollment_category_id
LEFT JOIN grade_level         gl ON gl.grade_level_id = ec.grade_level_id
GROUP BY ss.school_pk, ss.snapshot_id;

-- Cache of school_snapshot_enrollment_calc, one row per school_snapshot. Filled by the
-- loader once per Snapshot; safe because Snapshots are never edited after loading.
CREATE TABLE school_snapshot_enrollment (
    school_pk         INTEGER NOT NULL,
    snapshot_id       INTEGER NOT NULL,
    es_enrollment     INTEGER CHECK (es_enrollment  >= 0),   -- NULL = level not reported
    jhs_enrollment    INTEGER CHECK (jhs_enrollment >= 0),
    shs_enrollment    INTEGER CHECK (shs_enrollment >= 0),
    total_male        INTEGER NOT NULL CHECK (total_male   >= 0),
    total_female      INTEGER NOT NULL CHECK (total_female >= 0),
    total_enrollment  INTEGER GENERATED ALWAYS AS (total_male + total_female) VIRTUAL,
    PRIMARY KEY (school_pk, snapshot_id),
    FOREIGN KEY (school_pk, snapshot_id) REFERENCES school_snapshot (school_pk, snapshot_id),
    CHECK (COALESCE(es_enrollment, 0) + COALESCE(jhs_enrollment, 0) + COALESCE(shs_enrollment, 0)
           = total_male + total_female)
) WITHOUT ROWID;

-- For filtering and sizing Features by enrollment on the maps.
CREATE INDEX school_snapshot_enrollment_total ON school_snapshot_enrollment (snapshot_id, total_enrollment);

------------------------------------------------------------------------------
-- Views
------------------------------------------------------------------------------

-- Reassembles the flat Directory row. Totals come from the cache; unreported levels
-- read as 0, as in the source workbook.
CREATE VIEW directory AS
WITH offers AS (
    SELECT
        curricular_offering_id,
        MAX(school_level_id = 1) AS offers_es,
        MAX(school_level_id = 2) AS offers_jhs,
        MAX(school_level_id = 3) AS offers_shs
    FROM curricular_offering_level
    GROUP BY curricular_offering_id
)
SELECT
    ss.source_school_id                  AS school_id,
    ss.school_name,
    r.name                               AS region,
    dv.name                              AS division,
    p.name                               AS province,
    sd.name                              AS school_district,
    ld.name                              AS legislative_district,
    m.name                               AS municipality,
    b.name                               AS barangay,
    ss.street_address,
    sec.name                             AS sector,
    sm.name                              AS school_management,
    an.name                              AS annex_status,
    co.name                              AS curricular_offering,
    COALESCE(o.offers_es, 0)             AS offers_es,
    COALESCE(o.offers_jhs, 0)            AS offers_jhs,
    COALESCE(o.offers_shs, 0)            AS offers_shs,
    COALESCE(t.es_enrollment, 0)         AS es_enrollment,
    COALESCE(t.jhs_enrollment, 0)        AS jhs_enrollment,
    COALESCE(t.shs_enrollment, 0)        AS shs_enrollment,
    t.total_male,
    t.total_female,
    t.total_enrollment,
    sn.source_dataset_name               AS source_dataset,
    ds.source_url,
    sn.extraction_date
FROM school_snapshot ss
JOIN snapshot                   sn  ON sn.snapshot_id = ss.snapshot_id
JOIN dataset                    ds  ON ds.dataset_id = sn.dataset_id
JOIN municipality               m   ON m.municipality_id = ss.municipality_id
JOIN province                   p   ON p.province_id = m.province_id
JOIN region                     r   ON r.region_id = p.region_id
LEFT JOIN barangay              b   ON b.barangay_id = ss.barangay_id
JOIN legislative_district       ld  ON ld.legislative_district_id = ss.legislative_district_id
JOIN school_district            sd  ON sd.school_district_id = ss.school_district_id
JOIN division                   dv  ON dv.division_id = sd.division_id
JOIN sector                     sec ON sec.sector_id = ss.sector_id
JOIN school_management          sm  ON sm.school_management_id = ss.school_management_id
JOIN annex_status               an  ON an.annex_status_id = ss.annex_status_id
JOIN curricular_offering        co  ON co.curricular_offering_id = ss.curricular_offering_id
JOIN school_snapshot_enrollment t   ON t.school_pk = ss.school_pk AND t.snapshot_id = ss.snapshot_id
LEFT JOIN offers                o   ON o.curricular_offering_id = ss.curricular_offering_id;

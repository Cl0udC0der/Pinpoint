"""Load one DepEd enrollment workbook into a Pinpoint SQLite database as a Snapshot.

Reads the "Directory" tab for school attributes and the "Full DepEd Data" tab for
grade-by-sex enrollment, fills the school_snapshot_enrollment cache, and checks every
school's totals against the Directory tab before committing.

    python db/etl/load_deped_enrollment.py \
        Data/deped_private_basic_education_schools_sy2025-2026.xlsx \
        Data/pinpoint.sqlite --school-year "SY 2025-2026"

A new database file is created from db/schema.sql and db/seed/reference.sql.
Loading a school year that is already in the database is refused.
"""

import argparse
import sqlite3
import sys
from pathlib import Path

import openpyxl

DB_DIR = Path(__file__).resolve().parent.parent
DATASET_NAME = "Private Schools"
LEVELS = {"es": 1, "jhs": 2, "shs": 3}  # school_level_id, see seed/reference.sql
TOTAL_COLUMNS = ["es_enrollment", "jhs_enrollment", "shs_enrollment", "total_male", "total_female"]


def read_tab(workbook, name):
    rows = workbook[name].iter_rows(values_only=True)
    header = next(rows)
    return [
        {key: value.strip() if isinstance(value, str) else value for key, value in zip(header, row)}
        for row in rows
    ]


def open_database(path):
    is_new = not path.exists()
    db = sqlite3.connect(path)
    db.execute("PRAGMA foreign_keys = ON")
    if is_new:
        db.executescript((DB_DIR / "schema.sql").read_text(encoding="utf-8"))
        db.executescript((DB_DIR / "seed" / "reference.sql").read_text(encoding="utf-8"))
    return db


class Lookups:
    """Get-or-create rows in lookup and hierarchy tables, keyed by their natural key."""

    def __init__(self, db):
        self.db = db
        self.cache = {}

    def id(self, table, **key):
        cache_key = (table, tuple(key.items()))
        if cache_key not in self.cache:
            where = " AND ".join(f"{column} = ?" for column in key)
            row = self.db.execute(f"SELECT rowid FROM {table} WHERE {where}", list(key.values())).fetchone()
            if row is None:
                columns = ", ".join(key)
                marks = ", ".join("?" for _ in key)
                row = (self.db.execute(f"INSERT INTO {table} ({columns}) VALUES ({marks})", list(key.values())).lastrowid,)
            self.cache[cache_key] = row[0]
        return self.cache[cache_key]


def load(workbook_path, db_path, school_year):
    workbook = openpyxl.load_workbook(workbook_path, read_only=True)
    directory = read_tab(workbook, "Directory")
    full = {row["school_id"]: row for row in read_tab(workbook, "Full DepEd Data")}
    if set(full) != {row["school_id"] for row in directory}:
        sys.exit("Directory and Full DepEd Data tabs list different schools")

    db = open_database(db_path)
    lookups = Lookups(db)
    categories = dict(db.execute("SELECT source_prefix, enrollment_category_id FROM enrollment_category"))

    first = directory[0]
    db.execute(
        "INSERT INTO dataset (name, source_url) VALUES (?, ?) ON CONFLICT (name) DO UPDATE SET source_url = excluded.source_url",
        (DATASET_NAME, first["source_url"]),
    )
    dataset_id = db.execute("SELECT dataset_id FROM dataset WHERE name = ?", (DATASET_NAME,)).fetchone()[0]
    if db.execute("SELECT 1 FROM snapshot WHERE dataset_id = ? AND school_year = ?", (dataset_id, school_year)).fetchone():
        sys.exit(f"{school_year} is already loaded")
    snapshot_id = db.execute(
        "INSERT INTO snapshot (dataset_id, school_year, source_dataset_name, extraction_date) VALUES (?, ?, ?, ?)",
        (dataset_id, school_year, first["source_dataset"], first["extraction_date"].date().isoformat()),
    ).lastrowid

    school_pks = {}
    for row in directory:
        region_id = lookups.id("region", name=row["region"])
        province_id = lookups.id("province", region_id=region_id, name=row["province"])
        municipality_id = lookups.id("municipality", province_id=province_id, name=row["municipality"])
        barangay_id = lookups.id("barangay", municipality_id=municipality_id, name=row["barangay"]) if row["barangay"] else None
        division_id = lookups.id("division", region_id=region_id, name=row["division"])
        offering_id = lookups.id("curricular_offering", name=row["curricular_offering"])
        for level, level_id in LEVELS.items():
            if row[f"offers_{level}"] == "Yes":
                db.execute("INSERT OR IGNORE INTO curricular_offering_level VALUES (?, ?)", (offering_id, level_id))

        # ADR-0001: reuse the Feature that carried this source ID in an earlier Snapshot.
        source_school_id = int(row["school_id"])
        existing = db.execute(
            "SELECT school_pk FROM school_snapshot WHERE source_school_id = ? ORDER BY snapshot_id DESC LIMIT 1",
            (source_school_id,),
        ).fetchone()
        school_pk = existing[0] if existing else db.execute("INSERT INTO school DEFAULT VALUES").lastrowid
        school_pks[row["school_id"]] = school_pk

        db.execute(
            """INSERT INTO school_snapshot (
                   school_pk, snapshot_id, source_school_id, school_name,
                   municipality_id, barangay_id, street_address, legislative_district_id,
                   school_district_id, sector_id, school_management_id, annex_status_id, curricular_offering_id)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                school_pk, snapshot_id, source_school_id, row["school_name"],
                municipality_id, barangay_id, row["street_address"] or None,
                lookups.id("legislative_district", province_id=province_id, name=row["legislative_district"]),
                lookups.id("school_district", division_id=division_id, name=row["school_district"]),
                lookups.id("sector", name=row["sector"]),
                lookups.id("school_management", name=row["school_management"]),
                lookups.id("annex_status", name=row["annex_status"]),
                offering_id,
            ),
        )

        # Blank cells mean "not reported" and get no row; reported zeros are kept.
        for column, value in full[row["school_id"]].items():
            if not column.endswith(("_male", "_female")) or value in (None, ""):
                continue
            prefix, sex = column.rsplit("_", 1)
            learners = float(value)
            if learners != int(learners):
                sys.exit(f"School {source_school_id}: non-whole count {value!r} in {column}")
            db.execute(
                "INSERT INTO enrollment VALUES (?, ?, ?, ?, ?)",
                (school_pk, snapshot_id, categories[prefix], "M" if sex == "male" else "F", int(learners)),
            )

    db.execute(
        "INSERT INTO school_snapshot_enrollment (school_pk, snapshot_id, " + ", ".join(TOTAL_COLUMNS) + ") "
        "SELECT school_pk, snapshot_id, " + ", ".join(TOTAL_COLUMNS) + " "
        "FROM school_snapshot_enrollment_calc WHERE snapshot_id = ?",
        (snapshot_id,),
    )

    cached = {
        pk: totals
        for pk, *totals in db.execute(
            "SELECT school_pk, " + ", ".join(f"COALESCE({c}, 0)" for c in TOTAL_COLUMNS) + " "
            "FROM school_snapshot_enrollment WHERE snapshot_id = ?",
            (snapshot_id,),
        )
    }
    mismatched = [
        row["school_id"]
        for row in directory
        if cached[school_pks[row["school_id"]]] != [int(row[c]) for c in TOTAL_COLUMNS]
    ]
    if mismatched:
        db.rollback()
        sys.exit(f"Totals differ from the Directory tab for {len(mismatched)} schools, e.g. {mismatched[:5]}")
    if db.execute("PRAGMA foreign_key_check").fetchone():
        db.rollback()
        sys.exit("Foreign key violations; nothing was loaded")

    db.commit()
    enrollment_rows = db.execute("SELECT COUNT(*) FROM enrollment WHERE snapshot_id = ?", (snapshot_id,)).fetchone()[0]
    print(f"Loaded {school_year}: {len(directory)} schools, {enrollment_rows} enrollment rows into {db_path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("workbook", type=Path, help="DepEd enrollment .xlsx")
    parser.add_argument("database", type=Path, help="SQLite file; created if missing")
    parser.add_argument("--school-year", required=True, help='Snapshot label, e.g. "SY 2025-2026"')
    args = parser.parse_args()
    load(args.workbook, args.database, args.school_year)


if __name__ == "__main__":
    main()

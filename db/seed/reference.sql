-- Fixed reference rows for db/schema.sql, set by DepEd's enrollment column layout.
-- Run once, right after the schema.

INSERT INTO school_level (school_level_id, code, name, sort_order) VALUES
    (1, 'ES',  'Elementary School',  1),
    (2, 'JHS', 'Junior High School', 2),
    (3, 'SHS', 'Senior High School', 3);

INSERT INTO grade_level (grade_level_id, school_level_id, code, name, sort_order) VALUES
    ( 1, 1, 'K',     'Kindergarten',                     0),
    ( 2, 1, 'G1',    'Grade 1',                          1),
    ( 3, 1, 'G2',    'Grade 2',                          2),
    ( 4, 1, 'G3',    'Grade 3',                          3),
    ( 5, 1, 'G4',    'Grade 4',                          4),
    ( 6, 1, 'G5',    'Grade 5',                          5),
    ( 7, 1, 'G6',    'Grade 6',                          6),
    ( 8, 1, 'ESNG',  'Elementary non-graded',            7),
    ( 9, 2, 'G7',    'Grade 7',                          8),
    (10, 2, 'G8',    'Grade 8',                          9),
    (11, 2, 'G9',    'Grade 9',                         10),
    (12, 2, 'G10',   'Grade 10',                        11),
    (13, 2, 'JHSNG', 'Junior High School non-graded',   12),
    (14, 3, 'G11',   'Grade 11',                        13),
    (15, 3, 'G12',   'Grade 12',                        14);

INSERT INTO shs_strand (shs_strand_id, code, name) VALUES
    ( 1, 'ABM',          'Accountancy, Business and Management'),
    ( 2, 'ARTS',         'Arts and Design Track'),
    ( 3, 'GAS',          'General Academic Strand'),
    ( 4, 'HUMSS',        'Humanities and Social Sciences'),
    ( 5, 'MARITIME',     'Pre-Baccalaureate Maritime Strand'),
    ( 6, 'SPORTS',       'Sports Track'),
    ( 7, 'STEM',         'Science, Technology, Engineering and Mathematics'),
    ( 8, 'TVL',          'Technical-Vocational-Livelihood'),
    ( 9, 'UNIQUE',       'Other tracks unique to certain schools or localities'),
    (10, 'SSHS_ACAD',    'Strengthened SHS Academic Track'),
    (11, 'SSHS_TECHPRO', 'Strengthened SHS Technical-Professional Track');

INSERT INTO enrollment_category (enrollment_category_id, grade_level_id, shs_strand_id, source_prefix, first_school_year) VALUES
    ( 1,  1, NULL, 'kinder',            NULL),
    ( 2,  2, NULL, 'g1',                NULL),
    ( 3,  3, NULL, 'g2',                NULL),
    ( 4,  4, NULL, 'g3',                NULL),
    ( 5,  5, NULL, 'g4',                NULL),
    ( 6,  6, NULL, 'g5',                NULL),
    ( 7,  7, NULL, 'g6',                NULL),
    ( 8,  8, NULL, 'esng',              NULL),
    ( 9,  9, NULL, 'g7',                NULL),
    (10, 10, NULL, 'g8',                NULL),
    (11, 11, NULL, 'g9',                NULL),
    (12, 12, NULL, 'g10',               NULL),
    (13, 13, NULL, 'jhsng',             NULL),
    (14, 14,    1, 'g11_abm',           NULL),
    (15, 14,    2, 'g11_arts',          NULL),
    (16, 14,    3, 'g11_gas',           NULL),
    (17, 14,    4, 'g11_humss',         NULL),
    (18, 14,    5, 'g11_maritime',      NULL),
    (19, 14,    6, 'g11_sports',        NULL),
    (20, 14,    7, 'g11_stem',          NULL),
    (21, 14,    8, 'g11_tvl',           NULL),
    (22, 14,    9, 'g11_unique',        'SY 2024-2025'),
    (23, 14,   10, 'g11_sshs_acad',     'SY 2025-2026'),
    (24, 14,   11, 'g11_sshs_techpro',  'SY 2025-2026'),
    (25, 15,    1, 'g12_abm',           NULL),
    (26, 15,    2, 'g12_arts',          NULL),
    (27, 15,    3, 'g12_gas',           NULL),
    (28, 15,    4, 'g12_humss',         NULL),
    (29, 15,    5, 'g12_maritime',      NULL),
    (30, 15,    6, 'g12_sports',        NULL),
    (31, 15,    7, 'g12_stem',          NULL),
    (32, 15,    8, 'g12_tvl',           NULL),
    (33, 15,    9, 'g12_unique',        'SY 2024-2025');

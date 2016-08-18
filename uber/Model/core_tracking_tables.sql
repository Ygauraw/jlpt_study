--
-- This creates the tables needed to store the history of Core 2k/6k
-- vocabulary tests generated and (partially) completed (or retested)

drop table test_specs;
create table test_specs (
    test_id                 INTEGER PRIMARY KEY,
    time_created            INTEGER,

    core_set                TEXT NOT NULL, -- 'core2k' or 'core6k'
    test_type               TEXT NOT NULL, -- 'full', 'range' or 'chapter'
    test_mode               TEXT NOT NULL, -- challenge mode: "sound", "kanji"
    test_items              INTEGER NOT NULL, -- how many to test?
    randomise               INTEGER,	      -- whether to shuffle or not

    range_start             INTEGER,
    range_end               INTEGER,
    seed                    TEXT,          -- uses Util::RNG
    latest_sitting_id       INTEGER NOT NULL
);

-- Every time the user starts a test that is either new or has been
-- completed before, a new core_test_summary entry and several
-- core_test_details entries will be created. If they are completing a
-- test that hadn't been finished, the core_test_summary entry will
-- just be updated with the most recent results (skipping over the
-- items_tested number of items that have already been tested)

drop table test_sittings;
create table test_sittings (
    sitting_id                INTEGER PRIMARY KEY,
    test_id                   INTEGER NOT NULL, -- must match a seed
    test_start_time           INTEGER,          -- when test started
    test_end_time             INTEGER,          -- when tallies below updated

    -- items_tested/test_items (from test spec, above) = %complete:
    items_tested              INTEGER,

    -- After showing the answer for each vocab challenge, the user
    -- will be asked to answer four questions selected from below. The
    -- following tally up the "yes" answers to each question type:
    correct_voc_know   INTEGER, -- did you understand the vocab in English?
    correct_voc_read   INTEGER, -- were you able to read the vocab?
    correct_voc_write  INTEGER, -- were you able to write the vocab?
    correct_sen_know   INTEGER, -- did you understand the full sentence in English?
    correct_sen_read   INTEGER, -- were you able to read the full sentence?
    correct_sen_write  INTEGER  -- were you able to write the full sentence?

    -- Depending on the challenge modes, either the *_read/_write
    -- fields above may be ignored (both in the UI and in tallying):
    --
    -- * sound: play audio, challenge to write vocab/sentence (ignore _read)
    -- * kanji: display kanji, challenge to read vocab/sentence (ignore _write)
    --
    -- I guess I could convert _read and _write into _readwrite ...
    -- but I like the clarity that specific field names give when
    -- examined in isolation.

    -- estimate of %vocab known out of the full 2k/6k (and margin of
    -- error) can be calculated using just the above information.
);

drop table test_sitting_details;
create table test_sitting_details (
    sitting_id                TEXT,             -- not unique
    item_index                INTEGER NOT NULL, -- counting from 1

    -- detailed items corresponding to tallies above
    correct_voc_know   INTEGER, -- did you understand the vocab in English?
    correct_voc_read   INTEGER, -- were you able to read the vocab?
    correct_voc_write  INTEGER, -- were you able to write the vocab?
    correct_sen_know   INTEGER, -- did you understand the sentence in English?
    correct_sen_read   INTEGER, -- were you able to read the full sentence?
    correct_sen_write  INTEGER  -- were you able to write the full sentence?
);


-- Since I'm going to allow re-testing with previously-used seeds, I
-- don't want re-testing to skew the historical data. Therefore, the
-- first time that a test is completed it will add some raw data
-- points to the table that follows. Adding data points is up to the
-- discretion of the application; all the actual data can be retrieved
-- from the linked test/sitting records.

drop table data_points;
create table data_points (
    sitting_id  INTEGER PRIMARY KEY,
    test_id     INTEGER
    
);

-- The way I defined tests (allowing for ranges) opens up the idea of
-- using the vocab tester program as a browser or revision tool.
-- Basically the user (me) would have the option of progressing
-- through the sets in "chapter" mode. This simply involves setting a
-- default chapter size and some option for moving to the next
-- one. Each chapter will have a test_type of 'chapter' set.
--

drop table chapter_overview;
create table chapter_overview (
   default_core2k_chapter_size   INTEGER,
   default_core6k_chapter_size   INTEGER,

   core_2k_progress              INTEGER DEFAULT 0,
   core_6k_progress              INTEGER DEFAULT 0
   -- no need to store 2,000, 6,000 values; implicit
);
insert into chapter_overview values (50, 50, 0, 0);

-- no need for a table to store chapters since we have the specific
-- 'chapter' test_type that can be used to pull them out of the test
-- spec/sitting tables.


--
-- This creates the tables needed to store the history of Core 2k/6k
-- vocabulary tests generated and (partially) completed (or retested)
--
-- I will expand the database to include tests on different items so
-- I'm putting in drop table statements here to clear out just the
-- tables defined here rather than simply rm'ing the database file.

-- Generally speaking, I'll use a seed value to make a selection from
-- available vocabulary items. Re-using the same seed (and associated
-- parameters) should generate the same list later on, if needed (for
-- re-testing or other uses). Therefore, saving a seed should be the
-- same as storing an actual test list in the database.
drop table core_test_seeds;
create table core_test_seeds (
    epoch_time_created      INTEGER PRIMARY KEY,
    -- The test_?k types below are for testing. They test the first n
    -- core?k vocab items (in 1..n order) and ignore the seed
    -- completely. Since the epoch_time_created key is primary, there
    -- will only be one test set created (and reused) for a given
    -- (n,mode) tuple.  Otherwise, each core?k type generates a new
    -- random selection from the appropriate core?k lists.
    type                    TEXT,     -- core2k, core6k, test2k or test6k
    mode                    TEXT,     -- challenge mode: "sound", "kanji" or "both"

    -- The following relate to the most recent test/re-test of this seed
    -- 
    -- If a test has mode "both" then user should be able to test just
    -- the kanji side or just the sound side separately if they want
    items                   INTEGER NOT NULL,  -- how many to test?
    sound_items             INTEGER, -- of which some are sound challenges
    kanji_items             INTEGER, -- and others kanji challenges
    
    -- In order to recreate the test in the same way later, we also
    -- need the following values. The use of a predictable RNG (and
    -- selection algorithm) seeded in this way lets us avoid storing
    -- the actual selections. I could munge up all the non-computed
    -- fields in here and use that as my seed, but it's less
    -- error-prone to just create a random seed and use that every
    -- time I create a new test.
    seed                    TEXT,     -- uses Net::OnlineCode::RNG
    vocab_count             INTEGER,  -- how many vocab? (2k/6k)
    sentence_count          INTEGER   -- how many sentences? (from db)
);

-- Every time the user starts a test that is either new or has been
-- completed before, a new core_test_summary entry and several
-- core_test_details entries will be created. If they are completing a
-- test that hadn't been finished, the core_test_summary entry will
-- just be updated with the most recent results (skipping over the
-- items_tested number of items that have already been tested)

drop table core_test_summary;
create table core_test_summary (
    -- The primary key below is just a string containing the two epoch
    -- times + mode that follow. This synthetic key makes it easier to
    -- map out relationships between the summary and detail tables
    -- with Class::DBI
    id                        TEXT PRIMARY KEY,
    epoch_time_created        INTEGER NOT NULL, -- must match a seed
    epoch_time_start_test     INTEGER NOT NULL, -- when test started
    -- Whereas the main table can have "both" as a mode, this table
    -- can only have "sound" or "kanji" (separate test records for
    -- each)
    mode                      TEXT NOT NULL,
    -- end of key fields

    -- items_tested/(sound|kanji)_items (from above) = %complete:
    items_tested              INTEGER,

    -- After showing the answer for each vocab challenge, the user
    -- will be asked to answer four questions selected from below. The
    -- following tally up the "yes" answers to each question type:
    correct_voc_know   INTEGER, -- did you understand the vocab in English?
    correct_voc_read   INTEGER  -- were you able to read the vocab?
    correct_voc_write  INTEGER  -- were you able to write the vocab?
    correct_sen_know   INTEGER, -- did you understand the full sentence in English?
    correct_sen_read   INTEGER  -- were you able to read the full sentence?
    correct_sen_write  INTEGER  -- were you able to write the full sentence?

    -- Depending on the challenge modes, either the *_read/_write
    -- fields above may be ignored (both in the UI and in tallying):
    --
    -- * sound: play audio, challenge to write vocab/sentence (ignore _read)
    -- * kanji: display kanji, challenge to read vocab/sentence (ignore _write)
    -- * both: not an available mode in this table
    --
    -- I guess I could convert _read and _write into _readwrite ...
    -- but I like the clarity that specific field names give when
    -- examined in isolation.

    -- It's quite possible that the user will fail on one of the
    -- sentence-related questions due to it using some strange (to
    -- them) vocabulary that they don't understand in some way.
    -- Obviously it would be nice to store more details about why they
    -- failed (especially if they want to repeat the test after
    -- learning the failed non-key vocab items) but that sort of
    -- functionality isn't really core to what's going on here. If
    -- collating such vocab is important, the user can always search
    -- on failed items (in a detailed test report) and then copy/paste
    -- (or whatever) from that report into some other vocabulary
    -- management interface.

    -- estimate of %vocab known out of the full 2k/6k (and margin of
    -- error) can be calculated using just the above information.
);

drop table core_test_details;
create table core_test_details (
    -- synthetic foreign key id matches core_test_summary
    id                        TEXT,             -- not unique
    -- composite primary key must match _summary table
    epoch_time_created        INTEGER NOT NULL, -- foreign: match a seed 
    epoch_time_start_test     INTEGER NOT NULL, -- when test instance started
    mode                      TEXT    NOT NULL,
    -- end of key fields

    -- Note that we don't index into sentence tables or anything here.
    -- The random seed (and associated data) fully define the list of
    -- things being tested and their ordering, so we're indexing into
    -- a virtual data structure (all item_index values are sequential
    -- within a mode).

    item_index                INTEGER NOT NULL, -- counting from 1

    -- detailed items corresponding to tallies above
    correct_voc_know   INTEGER, -- did you understand the vocab in English?
    correct_voc_read   INTEGER  -- were you able to read the vocab?
    correct_voc_write  INTEGER  -- were you able to write the vocab?
    correct_sen_know   INTEGER, -- did you understand the full sentence in English?
    correct_sen_read   INTEGER  -- were you able to read the full sentence?
    correct_sen_write  INTEGER  -- were you able to write the full sentence?

);

-- Since I'm going to allow re-testing with previously-used seeds, I
-- don't want re-testing to skew the historical data. Therefore, the
-- first time that a test is completed it will add some raw data
-- points to the table that follows. This table could be rolled into
-- the seed table, but I'll keep it separate, duplicating some fields
-- but ignoring those needed to generate the test lists.

drop table data_points;
create table data_points (
    epoch_time_created      INTEGER PRIMARY KEY,
    -- duplicate some values from seed table
    type                    TEXT,     -- core2k, core6k, test2k or test6k
    mode                    TEXT,     -- challenge mode: "sound" or "kanji" only

    items                   INTEGER NOT NULL,  -- how many items tested?

    -- The following needed for statistical formula
    vocab_count             INTEGER,  -- 2k/6k
    sentence_count          INTEGER,  -- actual sentence counts at the time

    -- The following are the tallies (used with above to generate p values)
    correct_voc_know   INTEGER, -- did you understand the vocab in English?
    correct_voc_read   INTEGER  -- were you able to read the vocab?
    correct_voc_write  INTEGER  -- were you able to write the vocab?
    correct_sen_know   INTEGER, -- did you understand the full sentence in English?
    correct_sen_read   INTEGER  -- were you able to read the full sentence?
    correct_sen_write  INTEGER  -- were you able to write the full sentence?

    -- again, estimates of %known and margin of error can be computed
    -- from the above as/when needed.

);

create table series (
  series_id     INTEGER PRIMARY KEY,

  series_dir    TEXT NOT NULL,
  series_text   TEXT NOT NULL, -- human-readable version of dir

  ignore_flag   INTEGER	      -- ignore news, special offers and so on

);

create table episodes (
  episode_id   INTEGER PRIMARY KEY, -- unique across all episodes
  series_id    INTEGER NOT NULL,
  episode_num  INTEGER NOT NULL,

  -- all MP3 files are under a two-level series/episode dir structure
  episode_dir    TEXT NOT NULL,	-- just the subdir
  episode_text   TEXT NOT NULL,

  -- Unfortunately, there isn't a clear naming scheme in place across
  -- all the MP3 files. I will try to work this out in the population
  -- step so that I have at least the main audio file (however it may
  -- be named). I've ordered the non-main types below in decreasing
  -- order of frequency.
  file_main      TEXT NOT NULL, -- main audio file
  file_dialogue  TEXT,
  file_review    TEXT,
  file_grammar   TEXT,
  file_bonus     TEXT,

  file_other     TEXT 		-- a single catch-all 
);

-- These tables are for vocab (and phrases) that can be automatically
-- extracted from the vocabulary_phrases.txt files.  After a quick
-- scan of the files, I find that the given JA words/phrases don't
-- always appear with the same English/romaji. Or perhaps it's just
-- due to formatting differences in the line. In any event, it's best
-- to go with a many-to-many relationship between episodes and vocab,
-- and to break the actual vocab up into JA text in one table and
-- readings in another (one to many relationship)
create table vocab_reading (
  -- reading_id -- more trouble than it's worth
  vocab_id   INTEGER NOT NULL,	-- foreign, non-unique
  english    TEXT,
  romaji     TEXT,
  kana       TEXT		-- not sure if any entries supply this
);

create table vocab_ja (
  vocab_id   INTEGER PRIMARY KEY,
  japanese   TEXT
);

create table episode_vocab_link (
  link_id    INTEGER PRIMARY KEY,
  episode_id INTEGER NOT NULL,
  vocab_id   INTEGER NOT NULL
);

-- End of core tables

-- The following tables contain data that go into the main tables, but
-- I prefer to keep them separate in case I want to recreate the main
-- tables but avoid nuking the user data.

create table series_status (
  series_id        INTEGER PRIMARY KEY,
  difficulty       INTEGER,	-- 0 to 10, 0 means unrated
  priority         INTEGER,     -- 0 is unrated, 1 is lowest priority
  series_note      TEXT
);

create table episode_status (
  episode_id       INTEGER PRIMARY KEY,
  play_count       INTEGER,	-- main podcast only

  -- I imagine that a simple learning status field will be sufficient
  -- to track progress, eg:
  --
  -- 0  no listens
  -- 1  active listening of main EN/JA podcast
  -- 2  review (will preferably listen to just dialogue and vocab will
  --           be added to review/test list)
  -- 3  long-term review (shunt off to SRS or something)
  learn_status     INTEGER,

  short_note       TEXT,
  episode_note     TEXT
);

-- This is an extension of the episode_vocab_link table for user data
create table episode_vocab_status (
  link_id        INTEGER PRIMARY KEY,
  short_note     TEXT,		-- suitable for display in a table

  -- I'm not sure about what I'll do with challenge modes, so I'll add
  -- various fields here and decide whether/how to use them later.

  -- all learn statuses follow the same idea (0 not learning ... 3 SRS)
  learn_status   INTEGER,

  -- For various learning modes below, we have:
  -- 'j'  text as it would normally appear in Japanse (with kanJi)
  -- 'k'  text in kana
  -- 's'  sound
  -- 'e'  English meaning
  -- When combined, we get 12 possible (source, target) tuples:
  jk_status      INTEGER,
  js_status      INTEGER,
  je_status      INTEGER,
  kj_status      INTEGER,
  ks_status      INTEGER,
  ke_status      INTEGER,
  sj_status      INTEGER,
  sk_status      INTEGER,
  se_status      INTEGER,
  ej_status      INTEGER,
  ek_status      INTEGER,
  es_status      INTEGER

);


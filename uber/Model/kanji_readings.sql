--
-- schema for database created in check_vocab_readings.pl
--
--

create table summary (

  kanji        PRIMARY KEY,
  heisig6_seq  INTEGER NOT NULL,
  num_readings INTEGER,
  adj_readings INTEGER,		-- adjusted number of recognised readings
  num_vocab    INTEGER,
  num_failed   INTEGER,
  adj_failed   INTEGER          -- adjusted number of failed readings

);

-- count up each reading as it appears in vocab. Doesn't include
-- failed matches.
create table reading_tallies (

  kanji        TEXT NOT NULL,
  read_type    TEXT NOT NULL,	-- 'on' or 'kun'
  kana         TEXT NOT NULL,   -- can be hiragana (kun) or katakana (on)
  hiragana     TEXT,		-- hiragana rendering

  -- tallies can be adjusted for:
  --   出発-like sound change (+1 to adj_tally for はつ)
  --   okurigana that program didn't recognise properly (eg in 取り引き,
  --   -1 for とり, +1 for と)
  -- These adjustments should me made manually and require simultaneous
  -- additions to other fields (below)
  raw_tally    INTEGER,
  adj_tally    INTEGER

);

-- I won't create a separate table for failed readings.
-- This table will have one entry per vocab item.
create table vocab_readings (

  kanji        TEXT NOT NULL,	-- eg, 張
  vocab_kanji  TEXT NOT NULL,	-- eg, 張り切る
  vocab_kana   TEXT NOT NULL,	-- eg, はりきる

  reading_hira TEXT,		-- eg, にん or blank if failed
  reading_type TEXT,		-- 'on', 'kun' or blank if failed
  reading_kana TEXT,		-- eg, ニン, にん or blank if failed

  jlpt_grade   INTEGER,		-- 0 if not N5--N2 (N5--N1?)
  
  adj_hira     TEXT,		-- if parsing got it wrong, fill in these
  adj_type     TEXT,		-- fields. If they're populated, use them 
  adj_kana     TEXT,		-- in preference to the reading_* fields

  -- finally a flag for ignoring this vocab/reading pair set for, eg
  -- N5 大切 => たいせち (very unusual and possibly incorrect reading)
  ignore_flag  INTEGER		
);

--
-- schema for database created in check_vocab_readings.pl
--
--

-- Reworking tables based around many-to-many relationship between
-- kanji (summary table) and vocab. These two will be connected via a
-- link table.
--
-- Previously, I was explicitly going through the yomi, but now I'll
-- relegate that to being a type, used to annotate the kanji-vocab
-- links.
--
-- I'll also try to pare down the contents of the main tables, making
-- sure that they can be referred to using a single key field. Later,
-- when I want to add new data, I'll effectively create subclasses by
-- using these keys as foreign keys, and placing new data in a table
-- by itself. This should allow me to keep the core data intact while
-- I am prototyping new ideas.

-- Start with the bare minimum tables. 
create table kanji (
   kanji         TEXT PRIMARY KEY,
   rtk_frame     INTEGER,      -- frame number from latest edition of RTK
   rtk_keyword   INTEGER,      -- my RTK keyword (another table for official)
   jlpt_grade    INTEGER,      -- 0 if not N5--N2 (N5--N1?)
   jouyou_grade  INTEGER       -- grade numbering from Edict/Tagaini Jisho
);

create table kanji_vocab_link (
   kv_link_id    INTEGER PRIMARY KEY, -- for "sub-classing", easier Class::DBI
   kanji         TEXT NOT NULL,
   yomi_id       INTEGER,      -- type annotating link; 0 for "failed"
   adj_yomi_id   INTEGER,      -- allow for manual adjustment
   adj_reason    TEXT,	       -- may end up being an integer code later
   vocab_id      INTEGER NOT NULL
);

create table vocabulary (
   vocab_id      INTEGER PRIMARY KEY,
   vocab_ja      TEXT NOT NULL,	-- eg, 張り切る
   vocab_kana    TEXT NOT NULL,	-- eg, はりきる
   vocab_en      TEXT,
   jlpt_grade    INTEGER	-- 0 if not N5--N2 (N5--N1?)
);

create table yomi (
   -- Note that we don't store kanji here any more
   -- This should also make it easier to search, eg, for homonyms
   yomi_id       INTEGER PRIMARY KEY,
   yomi_type     TEXT NOT NULL,	-- on or kun
   yomi_kana     TEXT NOT NULL,	-- on-yomi represented using katakana
   yomi_hira     TEXT NOT NULL  -- 
);

--
-- The preceding should be enough to map out the core relationships
--


-- Summarise how frequently used each yomi is for a given kanji
-- (one to many kanji -> kanji_yomi_tally)
create table kanji_yomi_tally (
  kanji        TEXT,
  yomi_id      INTEGER,		-- 0 is fail, else look up yomi table
  yomi_count   INTEGER,		-- frequency count
  adj_count    INTEGER,		-- adjusted count

  -- add fields here for tagging other useful information about this
  -- reading, eg: nanori (readings used in names), rare/obsolete
  -- readings, specialised reading (eg みる is usually 見る but more
  -- specialised readings are used depending on context), sound groups
  -- (where phoneme derives from visual aspect of kanji), etc.

  exemplary_vocab_id  INTEGER
);

------------------------------------------------------------------------------
--									    --
-- Everything after here are old table definitions, which will go away	    --
--									    --
------------------------------------------------------------------------------

-- oops.. nuked this; recovering from check_vocab_readings (I need it
-- back during the transition)
create table summary (
  kanji text primary key,
  heisig6_seq integer,
  num_readings integer,
  adj_readings integer,
  num_vocab integer,
  num_failed integer,
  adj_failed integer
);

-- Adding a link table to clarify summary (kanji) -*-> yomi[_tallies]
-- relations. It shouldn't be needed, but it will help 
create table kanji_yomi_link (
  kanji       TEXT NOT NULL,
  yomi_id     INTEGER NOT NULL,

  primary key (kanji, yomi_id)
);

-- count up each reading as it appears in vocab. This does include
-- failed parsings.
-- tally_id <-> unique (kanji, yomi_id) tuples
create table yomi_tallies (

  tally_id     INTEGER PRIMARY KEY,
  kanji        TEXT    NOT NULL,
  yomi_id      INTEGER NOT NULL,

  -- Main point of this table; how many times does this yomi occur
  raw_tally    INTEGER,

  -- Single exemplary vocab. Can include one failed 当て字
  exemplar     TEXT,

  -- Roll up of the effect of all other adj_* fields
  adj_tally    INTEGER

);

-- table of unique (vocab_ja, vocab_kana) tuples. Note that some vocab
-- has the same vocab_ja, but different vocab_kana. Each such reading
-- gets a distinct entry here.
create table vocab (

  vocab_id     INTEGER PRIMARY KEY,

  vocab_ja     TEXT NOT NULL,	-- eg, 張り切る
  vocab_kana   TEXT NOT NULL,	-- eg, はりきる
  vocab_en     TEXT,

  -- the JLPT grade refers to the kana (or spoken) representation.
  -- It's too difficult (right now) to rate according to the component
  -- kanji.
  jlpt_grade   INTEGER 		-- 0 if not N5--N2 (N5--N1?)

  -- I had slated an "ignore" flag for inclusion, but as part of my
  -- reworking of the tables, I'm going to leave such non-essential
  -- attributes in external tables (to be joined on vocab_id). The
  -- idea is to focus only on core attributes that shouldn't change so
  -- that there's no need to rebuild those tables during later
  -- prototyping.
);

-- 1:1 of yomi_id <-> unique (kanji, reading_kana) tuples. Can also
-- include failed parses, in which case reading_kana is blank.
create table old_yomi (
  yomi_id      INTEGER PRIMARY KEY,

  kanji        TEXT NOT NULL,	-- eg, 人
  reading_kana TEXT,		-- eg, ニン, にん or blank

  -- the following aren't strictly necessary (can be derived)
  reading_type TEXT,		-- 'on', 'kun'
  reading_hira TEXT 		-- eg, にん or blank if failed

);  

-- kic_id <-> unique (kanji, vocab_id, yomi_id) tuples
create table kanji_in_context (

  kic_id       INTEGER PRIMARY KEY,

  kanji        TEXT    NOT NULL,
  vocab_id     INTEGER NOT NULL,
  yomi_id      INTEGER NOT NULL,

  -- adjustments can be made below if yomi_id points to a failed
  -- parse.

  adj_yomi     INTEGER,		-- "correct" on/kun yomi
  adj_kana     TEXT,            -- override values in kanji_yomi
  adj_hira     TEXT,
  adj_type     TEXT,
  reason       TEXT		-- may become a reason code later
);

-- Old, deprecated stuff. Keep around until new stuff works

-- I won't create a separate table for failed readings.
-- This table will have one entry per vocab item.
create table old_vocab_readings (

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

  -- finally, a flag for ignoring this vocab/reading pair set for, eg
  -- N5 大切 => たいせち (unusual and possibly incorrect reading)
  ignore_flag  INTEGER		
);

-- count up each reading as it appears in vocab. Doesn't include
-- failed matches.
create table reading_tallies (

  kanji        TEXT NOT NULL,
  read_type    TEXT NOT NULL,	-- 'on' or 'kun'
  kana         TEXT NOT NULL,   -- can be hiragana (kun) or katakana (on)
  hiragana     TEXT NOT NULL,	-- hiragana rendering

  exemplar     TEXT,            -- single exemplary vocab for this reading

  -- tallies can be adjusted for:
  --   出発-like sound change (+1 to adj_tally for はつ; -1 for failed はっ)
  --   okurigana that program didn't recognise properly (eg in 取り引き,
  --   -1 for とり, +1 for と)
  -- These adjustments should me made manually and require simultaneous
  -- additions to other fields (below)
  raw_tally    INTEGER,
  adj_tally    INTEGER

);


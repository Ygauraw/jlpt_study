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



-- We refer to a learnable with a class name and an ID/key within the
-- set that that class provides. Rather than have the class name
-- stored as a string everywhere, convert it into an ID

create table classes (
  class_id    INTEGER PRIMARY KEY,
  class_name  TEXT NOT NULL
);

insert into classes values (1, 'Learnable::Podcast');
insert into classes values (2, 'Learnable::ReadingText');
insert into classes values (3, 'Learnable::KanjiExemplar');
insert into classes values (4, 'Learnable::VocabWebData');
insert into classes values (5, 'Learnable::Grammar');
insert into classes values (6, 'Learnable::CoreVocab');
insert into classes values (7, 'Learnable::Core2k');
insert into classes values (8, 'Learnable::Core6k');

-- 
create table config (
  c_id       INTEGER PRIMARY KEY,
  c_name     TEXT NOT NULL,
  c_value    TEXT NOT NULL
);

insert into config values (1, 'start_of_day', 21600); -- day starts at 6AM

create table current_status (
  class_id     INTEGER NOT NULL,
  class_key    TEXT NOT NULL,
  change_time  INTEGER NOT NULL,
  status       INTEGER
);

-- This table could, in theory, be played forward/backwards
create table status_changes (
  class_id     INTEGER NOT NULL,
  class_key    TEXT NOT NULL,
  change_time  INTEGER NOT NULL,
  old_status   INTEGER,
  new_status   INTEGER
);

create table tags (
  class_id     INTEGER NOT NULL,
  class_key    TEXT NOT NULL,
  tag          TEXT NOT NULL
);

create table lists (
  list_id      INTEGER PRIMARY KEY,
  list_name    TEXT,
  list_note    TEXT,
  create_time  INTEGER,
  update_time  INTEGER
);

create table list_contents (
  list_id      INTEGER PRIMARY KEY,
  class_id     INTEGER NOT NULL,
  class_key    TEXT NOT NULL,
  added_time   INTEGER
);



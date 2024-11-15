pragma journal_mode = wal;

create table Subjects
   (subject                           integer primary key,
    task_version        text          not null,
    cookie_hash         blob          not null unique,
    prolific_pid        blob          not null,
    prolific_session    blob          not null,
    prolific_study      blob          not null
      references ProlificStudies(prolific_study),
    ip                  text          not null,
    user_agent          text          not null,
    consented_time      integer       not null,
    completed_time      integer) strict;

create table ProlificStudies
   (prolific_study      blob          primary key,
    completion_code     text          not null) strict, without rowid;

insert into ProlificStudies values (X'deadbeef', 'test study');

create table TaskData(
    subject             integer not null
        references Subjects(subject),
    k                   text not null,
    v                   blob,
      -- `v` values should be in SQLite's JSONB format.
    first_sent_time     integer not null,
    received_time       integer,
    primary key (subject, k)) strict, without rowid;

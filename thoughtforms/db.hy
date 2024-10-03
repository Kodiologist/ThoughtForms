"Interact with the database of subject information."


(import
  pathlib [Path]
  json
  sqlite3)
(setv  T True  F False)


(setv DEFAULT-SQLITE-TIMEOUT-SECONDS (* 3 60))

(defn call-with-db [path timeout f]
  (setv db (sqlite3.connect
    :isolation-level None
    :timeout timeout
    path))
  (try
    (.execute db "pragma foreign_keys = true")
    (setv db.row-factory sqlite3.Row)
    (f db)
    (finally
      (.close db))))

(defn initialize [path]
  "Erase any existing database at `path` and create a new one."
  (.unlink (Path path) :missing-ok T)
  (call-with-db path DEFAULT-SQLITE-TIMEOUT-SECONDS (fn [db]
    (.executescript db SCHEMA))))

(defn read [path]
  "Read in all the database contents as dictionaries."
  (call-with-db path DEFAULT-SQLITE-TIMEOUT-SECONDS (fn [db] (dict
    :subjects (dfor
      row (.execute db "select * from Subjects order by subject")
      (:subject row) (dfor
        k (.keys row)
        :if (!= k "subject")
        k (get row k)))
    :data (dfor
      row (.execute db "select
          subject, k, json(v) as v, first_sent_time as time1, received_time time2
          from TaskData
          order by subject, first_sent_time, k")
      #((:subject row) (:k row)) (dict
        :v (when (:v row) (json.loads (:v row)))
        :time1 (:time1 row)
        :time2 (:time2 row)))))))


(setv SCHEMA "
  pragma journal_mode = wal;

  create table Subjects
     (subject                           integer primary key,
      cookie_hash         blob          not null unique,
      prolific_pid        blob          not null unique,
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
      primary key (subject, k)) strict, without rowid;")

"Interact with the database of subject information."


(import
  pathlib [Path]
  json
  sqlite3)
(setv  T True  F False)


(setv DEFAULT-SQLITE-TIMEOUT-SECONDS (* 3 60))
(setv SCHEMA (.read-text (/ (. (Path __file__) parent) "schema.sql")))


(defn call [path f [timeout DEFAULT-SQLITE-TIMEOUT-SECONDS]]
  "Open the database, call `f` on it, and close it."
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
  (call path (fn [db]
    (.executescript db SCHEMA))))

(defn read [path]
  "Read in all the database contents as dictionaries."
  (call path (fn [db] (dict
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

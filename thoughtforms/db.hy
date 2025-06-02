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


(defn deidentified-json [db-in-path demog-in-path out-path]
  "Combine the data from a SQLite database and a demographic JSON file
  (produced by `thoughtforms.prolific.update-demographics-file`),
  deidentify it, and write out to a single JSON file."

  (setv main (read db-in-path))
  (setv demog (dfor
    d (json.loads (.read-text (Path demog-in-path)))
    (bytes.fromhex (get d "Participant id")) (dfor
      [k v] (.items d)
      (.replace (.lower k) " " "_") v)))

  (for [[subject d] (.items (:subjects main))]
    ; Add the Prolific demographic data ("pd") to each subject
    ; dictionary.
    (setv this-demog (get demog (:prolific-pid d)))
    (for [k (map hy.mangle '[
        downloaded-time total-approvals age sex
        ethnicity-simplified
        country-of-birth country-of-residence
        nationality language
        student-status employment-status])]
      (setv v (get this-demog k))
      (setv (get d (+ "pd_" k))
        (if (in v ["CONSENT_REVOKED" "DATA_EXPIRED"]) None v)))
    ; Convert `prolific_study` to a string.
    (setv (get d "prolific_study") (.hex (get d "prolific_study")))
    ; Delete personally identifying columns.
    (for [k ["cookie_hash" "ip" "prolific_pid" "prolific_session"]]
      (del (get d k))))

  ; Serialize everything to JSON. We serialize placeholders for `task`
  ; and then string-replace the placeholders to reduce excessive
  ; whitespace in the output.
  (setv out (json.dumps :indent 2 (dict
    :subjects (lfor
      [k v] (.items (:subjects main))
      {"subject" k #** v})
    :task_columns
      ["subject" "k" "v" "time1" "time2"]
    :task (lfor
      i (range (len (:data main)))
      f"!task-data-row-{i}!"))))
  (for [[i [[s k] d]] (enumerate (.items (:data main)))]
    (setv out (.replace out f"\"!task-data-row-{i}!\""
      (json.dumps [s k (:v d) (:time1 d) (:time2 d)]))))

  ; Write to `out-path`.
  (.write-text (Path out-path) out))

(defn json-to-pandas [json-path
    [include-incomplete False]
    [exclude-subjects #()]
    [to-subjects #()]]
  "Digest the output of `deidentified-json` into some `pandas`
  `DataFrame`s for analysis."

  (import pandas :as pd)

  (setv j (json.loads (.read-text (Path json-path))))
  (setv subjects (.set-index
    (pd.DataFrame (:subjects j))
    "subject"))
  (setv task-data (.set-index
    (.sort-values (pd.DataFrame (:task j) :columns (:task-columns j))
      ["subject" "time1"])
    ["subject" "k"]))

  (setv (get subjects "tv") (.map (get subjects "task_version") (dfor
    ; "tv" stands for "task version". This variable just assigns an
    ; integer to each `task_version`.
    [i v] (enumerate (.unique (get subjects "task_version")))
    v (+ i 1))))
  (when (not include-incomplete)
    (setv subjects (.copy (get subjects
      (pd.notnull (get subjects "completed_time"))))))
  (setv subjects (.drop subjects (or exclude-subjects [])))
  (setv (get subjects "total_mins") (/
    (- (get subjects "completed_time") (get subjects "consented_time"))
    60))
  (for [k ["consented_time" "completed_time" "pd_downloaded_time"]]
    (setv (get subjects k) (pd.to-datetime (get subjects k) :unit "s")))

  (setv task-data (get task-data (.isin
    (.get-level-values task-data.index "subject")
    subjects.index)))
  (for [k to-subjects]
    (setv (get subjects k) (.infer-objects
      (.reset-index :level "k" :drop True
        (get task-data.loc #(#(subjects.index k) "v"))))))

  [subjects task-data])

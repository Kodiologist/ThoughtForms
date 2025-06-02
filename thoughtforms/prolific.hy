"Interact with Prolific."


(require
  hyrule [pun])
(import
  os
  time [time]
  string
  pathlib [Path]
  random
  json
  csv)


(defn api [verb endpoint #** json-kwargs]
  (setv r (hy.I.requests.request verb
    (+ "https://api.prolific.com/api/v1/" endpoint)
    :headers (dict :Authorization (+
      "Token "
      (get os.environ "PROLIFIC_API_TOKEN")))
    #** (if json-kwargs {"json" json-kwargs} {})))
  (when (>= r.status-code 400)
    (print r.text))
  (.raise-for-status r)
  (if (.endswith endpoint "/export")
    ; This one endpoint returns CSV, rather than JSON.
    r.text
    (.json r)))


(defn first-lang-english []
  "A filter requiring the subject's first language to be English."
  (dict
    :filter-id "first-language"
    :selected-values [(next (gfor
      result (:results (api "GET" "filters"))
      :if (= (:filter-id result) "first-language")
      [k v] (.items (:choices result))
      :if (= v "English")
      k))]))


(defn make-study [
     db-path
     task-url
     project
     name internal-name description
     estimated-completion-minutes reward-cents
     [total-available-places 1]
     [completion-code-length 10]
     #** kwargs]
  "Create a draft study (not yet open to subjects) on Prolific."

  (setv code (.join "" (.choices
    (random.SystemRandom)
    string.ascii-letters
    :k completion-code-length)))

  (setv study (pun (api "POST" "studies"
    :!project :!name :!internal-name
    :!description
    :!total-available-places
    :estimated-completion-time estimated-completion-minutes
    :reward reward-cents
    :prolific-id-option "url_parameters"
    :completion-codes [{"code" code "code_type" "COMPLETED"}]
    :external-study-url (+
      task-url
      "?PROLIFIC_PID={{%PROLIFIC_PID%}}&SESSION_ID={{%SESSION_ID%}}&STUDY_ID={{%STUDY_ID%}}")
    #** kwargs)))

  (hy.I.thoughtforms/db.call db-path (fn [db]
    (.execute db
      "insert into ProlificStudies
        (prolific_study, completion_code)
        values (?, ?)"
      [(bytes.fromhex (:id study)) code])))
  (print "Created:" name))


(defn update-demographics-file [study-id json-path]
  "Update (or create) a JSON archive of Prolific demographics values
  for the given study."

  (setv json-path (Path json-path))
  (setv demog (if (.exists json-path)
    (json.loads (.read-text json-path))
    {}))
  (setv seen (sfor  d demog  (get d "Submission id")))
  (setv downloaded-time (int (time)))
  (.write-text json-path (json.dumps (+
    demog
    (lfor
      row (csv.DictReader (.split :sep "\n"
        (api "GET" f"studies/{(.hex study-id)}/export")))
      :if (not-in (get row "Submission id") seen)
      :do (.add seen (get row "Submission id"))
      (pun (dict :!downloaded-time #** (dfor
        [k v] (.items row)
        k (if (and (in k ["Age" "Total approvals"]) (.isdigit v))
          (int v)
          v)))))))))

"Interact with Prolific."


(require
  hyrule [pun])
(import
  os
  string
  random)


(defn api [verb endpoint #** json-kwargs]
  (setv r (hy.I.requests.request verb
    (+ "https://api.prolific.co/api/v1/" endpoint)
    :headers (dict :Authorization (+
      "Token "
      (get os.environ "PROLIFIC_API_TOKEN")))
    #** (if json-kwargs {"json" json-kwargs} {})))
  (when (>= r.status-code 400)
    (print (.json r)))
  (.raise-for-status r)
  (.json r))


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

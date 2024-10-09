"Try running through simple tasks."


(require
  hyrule [meth])
(import
  re
  lxml.html [document-fromstring :as as-html]
  mechanicalsoup
  werkzeug
  thoughtforms
  thoughtforms.html [E render-elem]
  pytest)


(setv ex (dict
  :page-title "Example Task"
  :language "en-GB"
  :consent-elements (E.p "This is a consent form.")
  :favicon-png-url "http://example.com/favicon.ico"
  :consent-instructions #[[If you type "I consent" below, then you consent.]]
  :completion-message "You did it! Wowie!"
  :user-ip-addr "123.123.123.123"
  :user-agent "BonziBUDDY 2024 (like Mozilla)"
  :prolific-pid "cafebabe" :prolific-study "deadbeef"
  :page-head (E.meta :name "ICBM" :content "please don't nuke me")))

(defn one-element-xpath [document query]
  (setv [x] (.xpath document query))
  x)
(defreader x
  "Apply `one-element-xpath` with the given string against the
  variable `doc`."
  `(one-element-xpath doc (+ "//" ~(.parse-one-form &reader))))


(defclass TaskFixture []

  (meth __init__ [@tmp-path]
    (setv
      @db-path (/ tmp-path "example.sqlite")
      @callback None
      @previous-output None
      @cookie-id None
      @run-args (.copy ex))
    (thoughtforms.db.initialize @db-path)
    None)

  (meth run [form-actions-f]
    (setv post-params (when (and form-actions-f @previous-output)
      (setv browser (mechanicalsoup.StatefulBrowser))
      (import warnings) (with [(warnings.catch-warnings)]
        ; https://bugs.launchpad.net/beautifulsoup/+bug/2076897
        ; This will probably be fixed in Beautiful Soup 4.13.
        (warnings.simplefilter "ignore" DeprecationWarning)
        (.open-fake-page browser @previous-output))
      (.select-form browser)
      (setv form browser.form)
      (form-actions-f form)
      (dict (:data (.get-request-kwargs browser form.form "x")))))
    (setv [cookie-id @previous-output] (thoughtforms.Task.run
       @callback
       #** @run-args
       :db-path @db-path
       :cookie-id @cookie-id
       :post-params post-params))
    (when cookie-id
      (setv @cookie-id cookie-id))
    @previous-output)

  (meth read-db []
    (thoughtforms.db.read @db-path)))
    
(defn [pytest.fixture] tasker [tmp-path]
  (TaskFixture tmp-path))

(defmacro run-task [#* form-actions-body]
  `(.run tasker ~(when form-actions-body
    `(fn [form] ~@form-actions-body))))


(defn test-minimal-task [tasker]

  (setv tasker.callback (fn [task page]
    (.consent-form task)
    (.complete task)))

  ; Get the first page of the task, which is the consent form.
  (setv output (run-task))

  ; Check that various constructor arguments are reflected in the
  ; generated page.
  (setv doc (as-html output))
  (assert (= (. doc attrib ["lang"]) (:language ex)))
  (assert (= #x"title/text()" (:page-title ex)))
  (assert (= #x"link[@rel = 'icon']/@href" (:favicon-png-url ex)))
  (assert (= #x"meta[@name = 'ICBM']/@content" "please don't nuke me"))
  (assert (in (render-elem (:consent-elements ex)) output))
  (assert (=
    #x"p[@class = 'consent-instructions']/text()"
    (:consent-instructions ex)))

  ; Try various user inputs that don't actually say "I consent".
  (setv output-was output)
  (for [statement [
      ""
      "hello world"
      "no"
      "ok"
      "yes"
      "i don't consent"
      "consent"]]
    (setv output (run-task
      (.set form "consent-statement" statement)))
    ; The task should return the same consent form.
    (assert (= output output-was))
    ; There shouldn't be a cookie yet.
    (assert (not tasker.cookie-id)))

  ; Since `Task` has never gotten consent, the database should have no
  ; data for the subject.
  (assert (= (:subjects (.read-db tasker)) {}))

  ; Indicate consent properly.
  (setv output (run-task
    (.set form "consent-statement" "i consent")))

  ; Now the database has a subject row.
  (setv [subject-info] (.values (get (.read-db tasker) "subjects")))
  (assert (= (.hex (:prolific-pid subject-info)) (:prolific-pid ex)))
  (assert (= (.hex (:prolific-study subject-info)) (:prolific-study ex)))
  (assert (= (:ip subject-info) (:user-ip-addr ex)))
  (assert (= (:user-agent subject-info) (:user-agent ex)))
  (assert (:consented-time subject-info))

  ; And we're looking at the completion form.
  (assert (!= output output-was))
  (assert tasker.cookie-id)
  (assert (:completed-time subject-info))
  (setv doc (as-html output))
  (assert (=
    #x"p[@class = 'completion-message']/text()"
    (:completion-message ex)))
  (assert (= #x"input[@name = 'cc']/@value" "test study")))
    ; This is the completion code, which is needed for submission to
    ; Prolific.


(defn test-shuffle [tasker]

  (hy.I.random.seed "shuffle")
  (setv objs "abcdefg")
  (setv shuffled-to "cadfgbe")
  (setv shuffled-to-2 "gbedfca")

  (setv tasker.callback (fn [task page]
    (.consent-form task)
    (page 'continue "cpage"
       (E.p (+ "Shuffled items: " (.join ""
         (.shuffle task "perm" objs)))))
    (.complete task)))

  ; The output to `shuffle` should be a premutation of the input.
  (run-task)
  (defn get-shuf [output]
    (.group (re.search "Shuffled items: ([a-z]+)" output) 1))
  (assert (=
    (get-shuf (run-task
      (.set form "consent-statement" "i consent")))
    shuffled-to))
  ; The stored premutation index `perm` should be an approriate integer.
  (setv perm (get (.read-db tasker) "data" #(1 "perm") "v"))
  (assert (is (type perm) int))
  (assert (<= 0 perm (- (hy.I.math.factorial (len objs)) 1)))
  ; Getting the page again should yield the same permutation.
  (assert (=
    (get-shuf (run-task))
    shuffled-to))

  ; A different subject, however, should be able to see a new
  ; permutation.
  (setv (. tasker run-args ["prolific_pid"]) "cafed00d")
  (setv tasker.cookie-id None)
  (run-task)
  (assert (=
    (get-shuf (run-task
      (.set form "consent-statement" "i consent")))
    shuffled-to-2))
  (assert (=
    (get-shuf (run-task))
    shuffled-to-2)))


(defn test-wsgi-application [tmp-path]

  (setv db-path (/ tmp-path "example.sqlite"))
  (thoughtforms.db.initialize db-path)
  (setv eb {"REMOTE_ADDR" "100.100.100.100"})

  (setv client (werkzeug.test.Client (thoughtforms.wsgi-application
    (fn [task page]
      (.consent-form task)
      (page 'enter-number "cool-number"
        (E.p "enter a number")
        :type int)
      (.complete task))
    :cookie-path "/"
    :page-title (:page-title ex)
    :language (:language ex)
    :db-path db-path
    :consent-elements (:consent-elements ex)
    :completion-message (:completion-message ex))))

  ; Get the consent form.
  (setv r (.get client :environ-base eb
    f"/?PROLIFIC_PID={(:prolific-pid ex)}&STUDY_ID={(:prolific-study ex)}"))
  (assert (= r.status-code 200))
  (assert (not-in "Set-Cookie" r.headers))
  (assert (in (render-elem (:consent-elements ex)) r.text))
  (assert (not (:subjects (thoughtforms.db.read db-path))))

  ; Provide consent.
  (setv r (.post client "/" :environ-base eb :data {
    "k" "CONSENT"
    "prolific-pid" (:prolific-pid ex)
    "prolific-study" (:prolific-study ex)
    "consent-statement" "i consent"}))
  (assert (= r.status-code 200))
  (assert (in "Set-Cookie" r.headers))
  (assert (in "enter a number" r.text))
  (assert (:subjects (thoughtforms.db.read db-path)))

  ; Enter a number on the number-entry page.
  (setv r (.post client "/" :environ-base eb :data {
    "k" (hy.mangle "cool-number")
    "integer" "-8"}))
  (assert (= r.status-code 200))
  (assert (in (:completion-message ex) r.text))
  (print (thoughtforms.db.read db-path))
  (assert (= -8 (:v (get
    (thoughtforms.db.read db-path)
    "data"
    #(1 (hy.mangle "cool-number")))))))

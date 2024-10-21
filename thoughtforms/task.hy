;; * Imports

(require
  hyrule [unless ecase meth])
(import
  builtins
  time [time]
  collections [namedtuple]
  pathlib [Path]
  re
  json
  hashlib [sha256]
  html [escape :as hesc]
  thoughtforms.html [E RawHTML ecat render-elem]
  thoughtforms.db [DEFAULT-SQLITE-TIMEOUT-SECONDS]
  thoughtforms.util [nth-permutation])
(setv  T True  F False)

;; * Utility

(setv FREE-RESPONSE ((type "FreeResponseType" #() {})))

(setv TaskDataRecord (namedtuple "TaskDataRecord" (map hy.mangle
  '[v first-sent-time received-time])))

(setv N-COOKIE-BYTES 32)
(setv COOKIE-NAME "thoughtforms-cookie-id")
(setv PROLIFIC-COMPLETION-URL "https://app.prolific.com/submissions/complete")

;; * `Task`

(defclass Task []
  "An object that represents a task as well as an individual subject's
  progress in that task."

;; ** Public

  (meth __init__ [
      @page-title @language
      @db-path
      @consent-elements
      [@favicon-png-url "data:image/png;base64,iVBORw0KGgo="]
        ; An empty PNG, to prevent requests to `favicon.ico`.
      [@consent-instructions #[[If you type "I consent" below, it means that you've read (or have had read to you) the information given in this consent form, and you'd like to be a volunteer in this study.]]]
      [@completion-message #[[Press the button to complete this session. Thank you.]]]
      [@cookie-id None]
      [@user-ip-addr None] [@user-agent ""]
      [@prolific-pid None] [@prolific-study None]
      [@post-params None]
      [@page-head #()]
      [@sqlite-timeout-seconds DEFAULT-SQLITE-TIMEOUT-SECONDS]]
    (setv
      @subject None
      @data {}
      @set-cookie? False)
    (@read-cookie))

  (meth [classmethod] run [callback #* args #** kwargs]
    "Make a new task and run it with the given callback. Other
    arguments are passed on to the constructor."
    (setv task (@, #* args #** kwargs))
    (try
      (callback task task.generate-page-by-name)
      (except [e [OutputReady]]
        (setv output (get e.args 0))
        #((when task.set-cookie? task.cookie-id) output))
      (else
        (raise (ValueError "The task callback exited with no output")))))

  (defmacro with-db [#* body]
    `(hy.I.thoughtforms/db.call-with-db
      self.db-path
      self.sqlite-timeout-seconds
      (fn [db] ~@body)))

  (meth consent-form []
    "Show the consent form. This should be called before any other
    page methods."

    (when @cookie-id
      ; The subject has already consented.
      (return))

    (setv k "CONSENT")
    (when (and
        @post-params
        (= (.get @post-params "k") k)
        (in "prolific-pid" @post-params)
        (in "prolific-study" @post-params)
        (re.match
          r"\s*i\s*consent\s*\Z"
          (.get @post-params "consent-statement" "")
          re.IGNORECASE))
      ; The subject has now consented, so we can make a database row
      ; for them and set a cookie.
      (setv @cookie-id (hy.I.secrets.token-bytes N-COOKIE-BYTES))
      (setv @set-cookie? True)
      (with-db (.execute db
        "insert into Subjects
            (prolific_pid, prolific_study, cookie_hash, ip, user_agent, consented_time)
            values (?, ?, ?, ?, ?, ?)"
        [
          (bytes.fromhex (get @post-params "prolific-pid"))
          (bytes.fromhex (get @post-params "prolific-study"))
          (.digest (sha256 @cookie-id))
          @user-ip-addr
          @user-agent
          (int (time))]))
      (@read-cookie)
      (return))

    ; The subject hasn't consented, so display the consent page.
    (@make-output k (ecat
      @consent-elements
      (E.p :class "consent-instructions"
        @consent-instructions)
      (E.input :type "hidden"
        :name "prolific-pid" :value @prolific-pid)
      (E.input :type "hidden"
        :name "prolific-study" :value @prolific-study)
      (E.input :name "consent-statement")
      (E.button :type "submit" "OK"))))

  (meth complete []
    "Show the completion page. This should be called after all other page methods."

    (setv [[completion-code]] (with-db
      (.execute db
        "update Subjects
            set completed_time = ?
            where subject = ? and completed_time isnull"
        [(int (time)) @subject])
      (list (.execute db
        "select completion_code
            from ProlificStudies
            where prolific_study =
              (select prolific_study from Subjects where subject = ?)"
        [@subject]))))
    (@make-output "completion" [
      (E.p :class "completion-message"
        @completion-message)
      (E.input :type "hidden" :name "cc"
        :value completion-code)
      (E.button :type "submit"
        :formmethod "GET" :formaction PROLIFIC-COMPLETION-URL
          ; Prolific doesn't allow POST for this, nonsensically.
        "Submit")]))

  (meth generate-page-by-name [ptype #* args #** kwargs]
    "Show a page; or if the input data has been submitted for it,
    process that; or if this page has already been completed, skip
    over it entirely."
    (@generate-page
      (getattr @, (+ "page__" (hy.mangle ptype)))
      #* args #** kwargs))

  (meth shuffle [k iterable]
    "Return a tuple giving the elements of `iterable` in a random order.
    The permutation is randomized per-subject and saved to `k`."

    (setv k (hy.mangle k))
    (setv iterable (tuple iterable))
    (unless (in k @data)
      (setv t (int (time)))
      (setv v (hy.I.random.randrange
        (hy.I.math.factorial (len iterable))))
      (setv (get @data k) (TaskDataRecord v t t))
      (with-db (.execute db
        "insert or ignore into TaskData
            (subject, k, v, first_sent_time, received_time)
            values (?, ?, jsonb(?), ?, ?)"
        [@subject k (json.dumps v :separators ",:") t t])))
    (nth-permutation iterable (len iterable) (. @data [k] v)))

;; *** Page types

  ; Page-type methods are typically called via `generate-page-by-name`.

  (meth page--continue []
    "The subject just has to click the continue button."

    (dict
      :elements
        (E.p (E.button "Continue" :name "continue" :value "yes"))
      :f (fn [ps]
        (unless (= (.get ps "continue") "yes")
          (raise InvalidInputError))
        None)))

  (meth page--choice [options]
    "The subject clicks on one of several buttons, possibly after
    filling out a free-response field."

    (setv options (list (.items options)))
    (dict
      :elements (gfor
        [i [button-value text-beside]] (enumerate options)
        (E.label
          (E.button :name "choice" :value (str i)
            (str button-value))
          (if (is text-beside FREE-RESPONSE)
            (E.input :name "free-response")
            text-beside)))
      :f (fn [ps]
        (setv [button-value text-beside] (try
          (get options (int (get ps "choice")))
          (except [[KeyError IndexError ValueError]]
            (raise InvalidInputError))))
        (if (is text-beside FREE-RESPONSE)
          (or
            (.strip (.get ps "free-response" ""))
            (raise InvalidInputError))
          button-value))))

  (meth page--checkbox [options [min 0] [max Inf]]
    "The subject checks some number of boxes, possibly after filling
    out some free-response fields."

    (setv [the-min the-max min max] [min max builtins.min builtins.max])
    (setv options (list (.items options)))
    (dict
      :elements (ecat
        (gfor
          [i [value text-beside]] (enumerate options)
          (if (is text-beside FREE-RESPONSE)
            (E.label
              ; In the free-resposne case, provide a text input
              ; instead of an actual checkbox.
              (str value)
              " "
              (E.input :name f"c{i}"))
            (E.label
              (E.input :type "checkbox" :name f"c{i}")
              " "
              text-beside)))
        (E.p (E.button :type "submit" "OK")))
      :f (fn [ps]
        (setv responses (lfor
          [i [value text-beside]] (enumerate options)
          :setv c (.strip (.get ps f"c{i}" ""))
          :if c
          (if (is text-beside FREE-RESPONSE) c value)))
        (if (<= the-min (len responses) the-max)
          responses
          (raise InvalidInputError)))))

  (meth page--enter-number [type [sign #(-1 0 1)]]
    "The subject types in a number and clicks a button."

    (setv [the-type type] [type builtins.type])
    (assert (is the-type int))
      ; Currently the only type implemented.
    (when (isinstance sign int)
      (setv sign [sign]))
    (dict
      :elements (E.p
        (E.input :name "integer")
        " "
        (E.button :type "submit" "OK"))
      :f (fn [ps]
        (try
          (setv x (int (get ps "integer")))
          (except [[KeyError ValueError]]
            (raise InvalidInputError)))
        (unless (in (hy.I.hyrule.sign x) sign)
          (raise InvalidInputError))
        x)))

  (meth page--textbox [[optional F]]
    "The subject (optionally) fills in a `textarea` and clicks a button."

    (dict
      :elements [
        (E.p (E.textarea :name "text"))
        (E.p (E.button :type "submit" "OK"))]
      :f (fn [ps]
        (when (not-in "text" ps)
          (raise InvalidInputError))
        (setv text (.strip (get ps "text")))
        (unless (or text optional)
          (raise InvalidInputError))
        text)))

;; ** Internals

  (meth read-cookie []
    "Set other attributes using the attribute `cookie-id`, if it isn't `None`."

    (when @cookie-id
      (with-db
        (setv [[@subject]] (.execute db
          "select subject from Subjects where cookie_hash = ?"
          [(.digest (sha256 @cookie-id))]))
        (setv @data (list (.execute db
          "select k, json(v) as v, first_sent_time, received_time
              from TaskData
              where subject = ?"
          [@subject]))))
      (setv @data (dfor
        [k v first-sent-time received-time] @data
        k (TaskDataRecord
          (if (is v None) None (json.loads v))
          first-sent-time
          received-time)))))

  (meth make-output [k elements]
    (raise (OutputReady f"<!DOCTYPE html>
<html lang={(hesc @language) !r}>
<head>
    <meta charset='UTF-8'>
    <title>{(hesc @page-title)}</title>
    <link rel='icon' type='image/png'
        href='{(hesc @favicon-png-url)}'>
    <style>
        .consent-instructions
          {{margin-top: 2em}}
        label
          {{display: block}}
        label > button
          {{min-width: 2em;
           margin-right: .5em;
           margin-bottom: .25em}}
    </style>
    {(render-elem @page-head)}
</head>
<body><form method='post'>

<input type='hidden' name='k' value={(hesc k) !r}>
{(render-elem elements)}

</form></body></html>\n")))

  (meth generate-page [f-page k before #* args [after #()] #** kwargs]

    (setv k (hy.mangle k))
    (if (in k @data)
      (when (. @data [k] received-time)
        ; The subject has already completed this page. Skip it.
        (return))
      (do
        ; The subject is getting this page for the first time. Save
        ; the time.
        (setv t (int (time)))
        (setv (get @data k) (TaskDataRecord None t None))
        (with-db (.execute db
          "insert or ignore into TaskData
              (subject, k, first_sent_time)
              values (?, ?, ?)"
          [@subject k t]))))

    (setv d (f-page #* args #** kwargs))
    (setv middle-elements (get d "elements"))
    (setv f-digest-input (get d "f"))
    ; If the user input is acceptable, `f-digest-input` should return
    ; a value to be JSON-encoded and saved. Otherwise, it should raise
    ; `InvalidInputError`.
    (when (and @post-params (= (.get @post-params "k") k))
      (try
        (setv v (f-digest-input @post-params))
        (except [InvalidInputError])
        (else
          ; We have a valid `v`.
          (setv t (int (time)))
          (setv (get @data k)
            (TaskDataRecord v (. @data [k] first-sent-time) t))
          (setv output
            #((json.dumps v :separators ",:") t @subject k))
          (with-db (.execute db
            "update TaskData
                set v = jsonb(?), received_time = ?
                where subject = ? and k = ? and received_time isnull"
            output))
          (return))))

    ; The subject hasn't completed this page, so display it.
    (@make-output k (ecat before middle-elements after))))

;; * `wsgi-application`

(defn wsgi-application [callback *
    [cookie-path "/"]
    #** kwargs]

  "Create a WSGI application callback via Werkzeug. `kwargs` are
  passed through to the constructor of `Task`."

  (import werkzeug)
  (werkzeug.wrappers.Request.application (fn [req]

    (setv post? (ecase req.method
      "POST" T
      "GET" F))

    (setv [cookie-id output] (Task.run callback
      :post-params (when post? (dict req.form))
      :prolific-pid (.get req.args "PROLIFIC_PID")
      :prolific-study (.get req.args "STUDY_ID")
      :cookie-id (when (setx c (.get req.cookies COOKIE-NAME))
        (bytes.fromhex c))
      :user-ip-addr req.remote-addr
      :user-agent (.headers.get req "User-Agent" "")
      #** kwargs))

    (setv resp (werkzeug.wrappers.Response
      output
      :mimetype "text/html"))
    (when cookie-id
      (.set-cookie resp
        :key COOKIE-NAME
        :value (.hex cookie-id)
        :max-age None  ; A session cookie
        :path cookie-path
        :secure T
        :httponly T
        :samesite "Strict"))
    resp)))

;; * Exceptions

(defclass InvalidInputError [Exception]
  "The subject didn't provide appropriate input for the current task page.")
(defclass OutputReady [Exception]
  "The `Task` object has some HTML to send to the subject.")

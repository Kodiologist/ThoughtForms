"Test the various page types."

(require
  hyrule [meth])
(import
  json
  lxml.html [document-fromstring :as as-html]
  thoughtforms
  thoughtforms.task [FREE-RESPONSE InvalidInputError]
  thoughtforms.html [render-elem]
  pytest)
(setv  T True  F False)


(defclass PageFixture []

  (meth define [ptype #* args #** kwargs]
    (setv d ((getattr thoughtforms.Task (+ "page__" (hy.mangle ptype)))
       None
       #* args #** kwargs))
    (setv @f (:f d))
    (setv @buttons (lfor
      e (.xpath (as-html (render-elem (:elements d))) "//button")
      (if (in "name" e.attrib)
        {(get e.attrib "name") (get e.attrib "value")}
        {}))))

  (meth submit-form [button-i fields]
    (@f {
      #** (dfor
        [k v] (.items fields)
        (.replace k "_" "-") v)
      #** (if (is button-i None) {} (get @buttons button-i))}))

  (meth good [[button-i 0] #** fields]
    (setv v (@submit-form button-i fields))
    (assert (= v (json.loads (json.dumps v))))
      ; The value should round-trip through JSON because that's how
      ; we'd store it in the database.
    v)

  (meth bad [[button-i 0] #** fields]
    (with [(pytest.raises InvalidInputError)]
      (@submit-form button-i fields))))

(defn [(pytest.fixture)] P [] (PageFixture))



(defn test-continue [P]
  (P.define 'continue)

  (assert (is (P.good) None)))


(defn test-choice [P]
  (P.define 'choice (dict
    :A "apple"
    :B "banana"
    :C "cantaloupe"
    :Other FREE-RESPONSE))

  (assert (= (P.good 0) "A"))
  (assert (= (P.good 2) "C"))
  (assert (= (P.good None :choice 2) "C"))
  (assert (= (P.good 0 :free-response "dragonfruit") "A"))
    ; The free-response box is ignored if you don't click the
    ; corresponding button.
  (assert (= (P.good 3 :free-response "dragonfruit") "dragonfruit"))
  (assert (= (P.good 3 :free-response "  dragonfruit ") "dragonfruit"))

  (P.bad None :choice 4)
  (P.bad 3)
  (P.bad 3 :free-response "")
  (P.bad 3 :free-response "   "))


(defn test-checkbox [P]
  (P.define 'checkbox :min 1 :max 2 (dict
    :A "apple"
    :B "banana"
    :C "cantaloupe"
    :Other FREE-RESPONSE))

  (assert (= (P.good :c0 "on") ["A"]))
  (assert (= (P.good :c0 "on" :c2 "on") ["A" "C"]))
  (assert (= (P.good :c0 "on" :c2 "on" :c5 "on") ["A" "C"]))
    ; Out-of-range items are ignored (like other unsought-for parameters).
  (assert (= (P.good :c0 "jim" :c2 "derrick") ["A" "C"]))
    ; The actual values (after stripping whitespace) are ignored.
  (assert (= (P.good :c0 "on" :c3 "dragonfruit") ["A" "dragonfruit"]))
  (assert (= (P.good :c0 "on" :c3 "A") ["A" "A"]))
    ; Kinda stupid, but allowed.
  (assert (= (P.good :c0 "on" :c3 "   ") ["A"]))
    ; All-whitespace (or empty) free responses are treated as missing.

  (P.bad)
    ; `:min 1` is enforced.
  (P.bad :c0 "on" :c1 "on" :c2 "on"))
    ; `:max 2` is enforced.


(defn test-enter-number [P]
  (P.define 'enter-number
    :type int
    :sign [-1 0])

  (assert (= (P.good :integer "0") 0))
  (assert (= (P.good :integer "-3") -3))
  (assert (= (P.good :integer " -3     ") -3))
  (assert (= (P.good :integer "-123456789123456789") -123456789123456789))

  (P.bad :integer "Inf")
  (P.bad :integer "-1.2")
  (P.bad :integer "-1.")
  (P.bad :integer "-1.0")
  (P.bad :integer "-1 -1")
  (P.bad :integer "3")
    ; `:sign` is enforced.
  (P.bad :integer "-1,000"))
    ; No thousands separators allowed.


(defn test-textbox [P]
  (P.define 'textbox)

  (assert (= (P.good :text "hello world") "hello world"))
  (assert (= (P.good :text "  pinkie π 🥳 ") "pinkie π 🥳"))

  (P.bad)
  (P.bad :text "")
  (P.bad :text "    "))


(defn test-textbox-optional [P]
  (P.define 'textbox :optional T)

  (assert (= (P.good :text "hello world") "hello world"))
  (assert (= (P.good :text "") ""))
  (assert (= (P.good :text "     ") ""))

  (P.bad))
    ; A web browser will send the empty string for the text box even
    ; if the user doesn't touch it. So even for this optional item, if
    ; no `text` form element is received, something is wrong.

"This is my HTML library. There are many like it, but this one is mine.
`xml.etree.ElementTree` doesn't quite have what we need, and `lxml` is
much more than we need."


(import
  collections [namedtuple]
  html [escape :as hesc])
(setv  T True  F False)


(setv VOID-TAGS (tuple (.split "area base br col embed hr img input link meta source track wbr")))

(setv RawHTML (namedtuple "RawHTML" ["string"]))

(setv Element (namedtuple "Element" (map hy.mangle
  '[tag attrs kids])))

(setv E ((type "ElementMaker" #() (dict
  :__doc__ #[[Shorthand for creating `Element`\s. `E.p("hello", id = "x")` is equivalent to `Element("p", {"id": "x"}, "hello")`, which renders as `<p id='x'>hello</p>`.]]
  :__getattr__ (fn [self tag]
    (fn [#* kids #** attrs]
      (when (and (in (.lower tag) VOID-TAGS) kids)
        (raise (ValueError f"Elements of type {tag !r} can't have children")))
      (Element tag attrs kids)))))))


(defn ecat [#* es]
  "Yield `str`s, `RawHTML`s, and `Element`s, descending into other
  iterable objects."
  (for [e es]
    (if (isinstance e #(str RawHTML Element))
      (yield e)
      (yield :from (ecat #* e)))))


(defn render-elem [x]
  "Return a string of rendered HTML, given a `str` (which is
  automatically escaped), an `Element`, a `RawHTML`, or an iterable of
  such objects."
  (cond
    (isinstance x str)
      (hesc x :quote F)
    (isinstance x RawHTML)
      x.string
    (isinstance x Element)
      (.format "<{} {}>{}{}"
        (hesc x.tag)
        (.join " " (gfor
          [k v] (.items x.attrs)
          f"{(hesc k)}='{(hesc v)}'"))
        (.join "" (map render-elem x.kids))
        (if (in (.lower x.tag) VOID-TAGS) "" f"</{(hesc x.tag)}>"))
    T
      (.join "" (map render-elem x))))

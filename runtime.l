(define-global nil? (x)
  (or (= x nil) (= x null)))

(define-global is? (x) (not (nil? x)))

(define-global no (x) (or (nil? x) (= x false)))
(define-global yes (x) (not (no x)))
(define-global either (x y) (if (is? x) x y))

(define-global has? (l k)
  (l .has-own-property k))

(define-global # (x)
  (let n (x .length)
    (if (number? n) n
    (let n -1
      (each (k v) x
        (when (and (number? k) (> k n))
          (set n k)))
      (+ n 1)))))

(define-global none? (x) (= (# x) 0))
(define-global some? (x) (> (# x) 0))
(define-global one? (x) (= (# x) 1))
(define-global two? (x) (= (# x) 2))

(define-global hd (l) (at l 0))

(define-global type (x) (typeof x))

(define-global type? (x y) (= (type x) y))

(define-global string? (x) (type? x "string"))
(define-global number? (x) (type? x "number"))
(define-global boolean? (x) (type? x "boolean"))
(define-global function? (x) (type? x "function"))
(define-global symbol? (x) (type? x "symbol"))

(define-global obj? (x)
  (and (is? x) (type? x "object")))

(define-global array? (x)
  (Array .is-array x))

(define-global atom? (x)
  (or (nil? x) (string? x) (number? x) (boolean? x) (symbol? x)))

(define-global fresh (x)
  (case (type x)
    ("object"
     (if (nil? x) nil
         (array? x) (list)
       (obj)))
    ("undefined" (list))
    ("symbol" (Symbol))
    ("string" "")
    ("number" 0)))

(define-global nan (/ 0 0))
(define-global inf (/ 1 0))
(define-global -inf (- inf))

(define-global nan? (n)
  (not (= n n)))

(define-global inf? (n)
  (or (= n inf) (= n -inf)))

(define-global clip (s from upto)
  (s .substring from upto))

(define-global cut (x from upto)
  (with l (fresh x)
    (let (j 0
          i (if (or (nil? from) (< from 0)) 0 from)
          n (# x)
          upto (if (or (nil? upto) (> upto n)) n upto))
      (while (< i upto)
        (set (at l j) (at x i))
        (inc i)
        (inc j))
      (each (k v) x
        (unless (number? k)
          (set (l [k]) v))))))

(define-global keys (x)
  (with t (obj)
    (each (k v) x
      (unless (number? k)
        (set (t [k]) v)))))

(define-global edge (x)
  (- (# x) 1))

(define-global inner (x)
  (clip x 1 (edge x)))

(define-global tl (l) (cut l 1))

(define-global char (s n)
  (s .char-at n))

(define-global code (s n)
  (s .char-code-at n))

(define-global string-literal? (x)
  (and (string? x) (= (char x 0) "\"")))

(define-global id-literal? (x)
  (and (string? x) (= (char x 0) "|")))

(define-global add (l x)
  (if (l .push)
      (l .push x)
    (set (at l (# l)) x))
  nil)

(define-global drop (l)
  (if (l .pop)
      (l (.pop))
    (let i (edge l)
      (with x (at l i)
        (wipe (at l i))))))

(define-global last (l)
  (at l (edge l)))

(define-global almost (l)
  (cut l 0 (edge l)))

(define-global reverse (l)
  (with l1 (fresh l)
    (let n (edge l)
      (each (k v) l
        (when (number? k)
          (set k (- n k)))
        (set (at l1 k) v)))))

(define-global reduce (f x)
  (if (none? x) nil
      (one? x) (hd x)
    (f (hd x) (reduce f (tl x)))))

(define-global join ls
  (with r (fresh (hd ls))
    (step l ls
      (when l
        (let n (# r)
          (each (k v) l
            (if (number? k) (inc k n))
            (set (r [k]) v)))))))

(define-global find (f t)
  (each x t
    (let y (f x)
      (if y (return y)))))

(define-global first (f l)
  (step x l
    (let y (f x)
      (if y (return y)))))

(define-global in? (x t)
  (find (fn (y) (= x y)) t))

(define-global pair (l)
  (with l1 (fresh l)
    (for i (# l)
      (add l1 (list (at l i) (at l (+ i 1))))
      (inc i))))

(define-global sort (l f)
  (l .sort (when f (fn (a b) (if (f a b) -1 1)))))

(define-global map (f x)
  (with t (fresh x)
    (step v x
      (let y (f v)
        (if (is? y)
          (add t y))))
    (each (k v) x
      (unless (number? k)
        (let y (f v)
          (when (is? y)
            (set (t [k]) y)))))))

(define-global keep (f x)
  (map (fn (v) (when (yes (f v)) v)) x))

(define-global keys? (t)
  (each (k v) t
    (unless (number? k)
      (return true)))
  false)

(define-global empty? (t)
  (each x t
    (return false))
  true)

(define-global stash (args)
  (if (args ._stash) args
      (keys? args)
      (with l (list)
        (step x args
          (add l x))
        (let p (keys args)
          (set (p ._stash) (or (p ._stash) true))
          (add l p)))
    args))

(define-global unstash (args)
  (if (none? args) (fresh args)
    (let l (last args)
      (if (and (obj? l) (l ._stash))
          (with args1 (almost args)
            (each (k v) l
              (unless (= k "_stash")
                (set (args1 [k]) v))))
        args))))

(define-global destash! (l args1)
  (if (and (obj? l) (l ._stash))
      (each (k v) l
        (unless (= k "_stash")
          (set (args1 [k]) v)))
    l))

(define-global search (s pattern start)
  (let i (s .index-of pattern start)
    (if (>= i 0) i)))

(define-global split (s sep)
  (if (or (= s "") (= sep "")) (list)
    (with l (list)
      (let n (# sep)
        (while true
          (let i (search s sep)
            (if (nil? i) (break)
              (do (add l (clip s 0 i))
                  (set s (clip s (+ i n)))))))
        (add l s)))))

(define-global cat xs
  (either (reduce (fn (a b) (cat a b)) xs) ""))

(define-global + xs
  (either (reduce (fn (a b) (+ a b)) xs) 0))

(define-global - xs
  (either (reduce (fn (b a) (- a b)) (reverse xs)) 0))

(define-global * xs
  (either (reduce (fn (a b) (* a b)) xs) 1))

(define-global / xs
  (either (reduce (fn (b a) (/ a b)) (reverse xs)) 1))

(define-global % xs
  (either (reduce (fn (b a) (% a b)) (reverse xs)) 0))

(define-global pairwise (f xs)
  (for i (edge xs)
    (let (a (at xs i)
          b (at xs (+ i 1)))
      (unless (f a b)
        (return false))))
  (return true))

(define-global < xs (pairwise (fn (a b) (< a b)) xs))
(define-global > xs (pairwise (fn (a b) (> a b)) xs))
(define-global = xs (pairwise (fn (a b) (= a b)) xs))
(define-global <= xs (pairwise (fn (a b) (<= a b)) xs))
(define-global >= xs (pairwise (fn (a b) (>= a b)) xs))

(define-global number (s)
  (let n (parseFloat s)
    (unless (isNaN n) n)))

(define-global number-code? (n)
  (and (>= n ?0) (<= n ?9)))

(define-global numeric? (s)
  (let n (# s)
    (for i n
      (unless (number-code? (code s i))
        (return false))))
  (some? s))

(define-global tostring (x)
  (x (.to-string)))

(define-global escape (s)
  (let s1 "\""
    (for i (# s)
      (let (c (char s i)
            c1 (if (= c "\n") "\\n"
                   (= c "\r") "\\r"
                   (= c "\"") "\\\""
                   (= c "\\") "\\\\"
                 c))
        (cat! s1 c1)))
    (cat s1 "\"")))

(define-global simple-id? (x)
  (and (string? x)
       (let ((ok v) (guard (read-string x)))
         (and ok (= v x)))))

(define-global str (x stack)
  (if (nil? x) "nil"
      (nan? x) "nan"
      (= x inf) "inf"
      (= x -inf) "-inf"
      (boolean? x) (if x "true" "false")
      (string-literal? x) x
      (simple-id? x) x
      (string? x) (escape x)
      (atom? x) (tostring x)
      (function? x) "function"
      (and stack (in? x stack)) "circular"
    (let (s "(" sp ""
          xs (list) ks (list)
          l (or stack (list)))
      (add l x)
      (each (k v) x
        (if (number? k)
            (set (xs [k]) (str v l))
          (do (add ks (cat (str k l) ":"))
              (add ks (str v l)))))
      (drop l)
      (each v (join xs ks)
        (cat! s sp v)
        (set sp " "))
      (cat s  ")"))))

(define-global apply (f args)
  (let args (stash args)
    (f .apply f args)))

(define-global call (f rest: args)
  (apply f args))

(define-global setenv (k rest: keys)
  (when (string? k)
    (let (frame (if (keys .toplevel)
                    (hd (_G .environment))
                  (last (_G .environment)))
          entry (or (frame [k]) (obj)))
      (each (k v) keys
        (set (entry [k]) v))
      (set (frame [k]) entry))))

(define-global print (x)
  (console .log x))

(define-global abs (Math .abs))
(define-global acos (Math .acos))
(define-global asin (Math .asin))
(define-global atan (Math .atan))
(define-global atan2 (Math .atan2))
(define-global ceil (Math .ceil))
(define-global cos (Math .cos))
(define-global floor (Math .floor))
(define-global log (Math .log))
(define-global log10 (Math .log10))
(define-global max (Math .max))
(define-global min (Math .min))
(define-global pow (Math .pow))
(define-global random (Math .random))
(define-global sin (Math .sin))
(define-global sinh (Math .sinh))
(define-global sqrt (Math .sqrt))
(define-global tan (Math .tan))
(define-global tanh (Math .tanh))
(define-global trunc (Math .floor))

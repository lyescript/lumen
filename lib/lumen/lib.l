;; -*- mode: lisp -*-

(define-module (lumen lib)
  import: (lumen)
  export: (getenv
           macro-function
           macro?
           special?
           special-form?
           statement?
           symbol-expansion
           symbol?
           variable?
           bound?
           quoted
           stash*
           bind
           bind*
           quasiexpand
           macroexpand
           indentation
           with-indent
           reserved?
           valid-id?
           id
           key
           imported
           linked
           mapo
           quote-environment
           quote-modules
           initial-environment))

(define getenv (k rest: keys)
  (when (string? k)
    (let (b (find (fn (e)
                    (get e k))
                  (reverse environment)))
      (when (table? b)
        (let (k nil)
          (each (x _) keys (set k x))
          (if k (get b k) b))))))

(define macro-function (k)
  (getenv k :macro))

(define macro? (k)
  (is? (macro-function k)))

(define special? (k)
  (is? (getenv k :special)))

(define special-form? (form)
  (and (list? form) (special? (hd form))))

(define statement? (k)
  (and (special? k) (getenv k :stmt)))

(define symbol-expansion (k)
  (getenv k :symbol))

(define symbol? (k)
  (is? (symbol-expansion k)))

(define variable? (k)
  (let (b (find (fn (frame)
                  (or (get frame k) frame._scope))
                (reverse environment)))
    (and (table? b) (is? b.variable))))

(define global? (k)
  (getenv k :global))

(define bound? (x)
  (or (macro? x)
      (special? x)
      (symbol? x)
      (variable? x)
      (global? x)))

(define escape (str)
  (let (str1 "\"" i 0)
    (while (< i (length str))
      (let (c (char str i)
            c1 (if (= c "\n") "\\n"
                   (= c "\"") "\\\""
                   (= c "\\") "\\\\"
                 c))
        (cat! str1 c1))
      (inc i))
    (cat str1 "\"")))

(define quoted (form)
  (if (string? form) (escape form)
      (atom? form) form
    `(list ,@(map quoted form))))

(define literal (s)
  (if (string-literal? s) s (quoted s)))

(define stash* (args)
  (if (keys? args)
      (let (l `(%object "_stash" true))
        (each (k v) args
          (add l (literal k))
          (add l v))
        (join args (list l)))
    args))

(define bind (lh rh)
  (if (and (composite? lh) (list? rh))
      (let (id (make-id))
	`((,id ,rh) ,@(bind lh id)))
      (atom? lh) `((,lh ,rh))
    (let (bs () r lh.rest)
      (each (x :i) lh
        (join! bs (bind x `(at ,rh ,i))))
      (if r (join! bs (bind r `(sub ,rh ,(length lh)))))
      (each (k v) lh
        (if (= v true) (set v k))
        (unless (= k 'rest)
          (join! bs (bind v `(get ,rh ',k)))))
      bs)))

(define bind* (args body)
  (let (args1 ())
    (define rest ()
      (if (= target 'js)
          `(unstash (Array.prototype.slice.call arguments ,(length args1)))
        (do (add args1 '|...|)
            '(unstash (list |...|)))))
    (if (atom? args)
        (list args1 `((let ,(list args (rest)) ,@body)))
      (let (bs ()
            r (or args.rest (and (keys? args) (make-id))))
        (each (arg) args
          (if (atom? arg) (add args1 arg)
              (or (list? arg) (keys? arg))
              (let (v (make-id))
                (add args1 v)
                (join! bs (list arg v)))))
        (if r (join! bs (list r (rest))))
        (when (keys? args)
          (join! bs (list (sub args (length args)) r)))
        (if (none? bs)
            (list args1 body)
          (list args1 `((let ,bs ,@body))))))))

(define quoting? (depth) (number? depth))
(define quasiquoting? (depth) (and (quoting? depth) (> depth 0)))
(define can-unquote? (depth) (and (quoting? depth) (= depth 1)))

(define quasisplice? (x depth)
  (and (list? x)
       (can-unquote? depth)
       (= (hd x) 'unquote-splicing)))

(define macroexpand (form)
  (if (symbol? form)
      (macroexpand (symbol-expansion form))
      (atom? form) form
    (let (x (hd form))
      (if (= x '%local)
          (let ((_ name value) form)
            `(%local ,name ,(macroexpand value)))
          (= x '%function)
          (let ((_ args rest: body) form)
            (with-bindings (args)
              `(%function ,(map macroexpand args)
                 ,@(macroexpand body))))
          (or (= x '%local-function)
              (= x '%global-function))
          (let ((_ name args rest: body) form)
            (with-bindings (args)
              `(,x ,name ,(map macroexpand args)
                 ,@(macroexpand body))))
	  (macro? x)
          (macroexpand (apply (macro-function x) (tl form)))
        (map macroexpand form)))))

(define quasiexpand)
(define quasiquote-list)

(set* quasiquote-list
  (fn (form depth)
    (let (xs (list '(list)))
      (each (k v) form
        (let (v (if (quasisplice? v depth)
                    ;; don't splice, just expand
                    (quasiexpand (at v 1))
                  (quasiexpand v depth)))
          (set (get (last xs) k) v)))
      ;; collect sibling lists
      (each (x) form
        (if (quasisplice? x depth)
            (let (x (quasiexpand (at x 1)))
              (add xs x)
              (add xs '(list)))
          (add (last xs) (quasiexpand x depth))))
      (let (pruned
            (keep (fn (x)
                    (or (> (length x) 1)
                        (not (= (hd x) 'list))
                        (keys? x)))
                  xs))
        `(join* ,@pruned)))))

(set* quasiexpand
  (fn (form depth)
    (if (quasiquoting? depth)
        (if (atom? form) (list 'quote form)
            ;; unquote
            (and (can-unquote? depth)
                 (= (hd form) 'unquote))
            (quasiexpand (at form 1))
            ;; decrease quasiquoting depth
            (or (= (hd form) 'unquote)
                (= (hd form) 'unquote-splicing))
            (quasiquote-list form (- depth 1))
            ;; increase quasiquoting depth
            (= (hd form) 'quasiquote)
            (quasiquote-list form (+ depth 1))
            (quasiquote-list form depth))
        (atom? form) form
        (= (hd form) 'quote) form
        (= (hd form) 'quasiquote)
        ;; start quasiquoting
        (quasiexpand (at form 1) 1)
      (map (fn (x) (quasiexpand x depth)) form))))

(define* indent-level 0)

(define indentation ()
  (apply cat (replicate indent-level "  ")))

(define-macro with-indent (form)
  (let (result (make-id))
    `(do (inc indent-level)
         (let (,result ,form)
           (dec indent-level)
           ,result))))

(define reserved
  (set-of "=" "==" "+" "-" "%" "*" "/" "<" ">" "<=" ">="
          ;; js
          "break" "case" "catch" "continue" "debugger"
          "default" "delete" "do" "else" "finally" "for"
          "function" "if" "in" "instanceof" "new" "return"
          "switch" "this" "throw" "try" "typeof" "var"
          "void" "with"
          ;; lua
          "and" "end" "in" "repeat" "while" "break" "false"
          "local" "return" "do" "for" "nil" "then" "else"
          "function" "not" "true" "elseif" "if" "or" "until"))

(define reserved? (x)
  (get reserved x))

(define numeric? (n)
  (and (> n 47) (< n 58)))

(define valid-code? (n)
  (or (numeric? n)             ; 0-9
      (and (> n 64) (< n 91))  ; A-Z
      (and (> n 96) (< n 123)) ; a-z
      (= n 95)))               ; _

(define valid-id? (id)
  (if (or (none? id) (special? id) (reserved? id))
      false
    (let (i 0)
      (while (< i (length id))
        (unless (valid-code? (code id i))
          (return false))
        (inc i))
      true)))

(define id (id)
  (let (id1 "" i 0)
    (while (< i (length id))
      (let (c (char id i)
            n (code c)
            c1 (if (= c "-") "_"
                   (valid-code? n) c
                   (= i 0) (cat "_" n)
                 n))
        (cat! id1 c1))
      (inc i))
    id1))

(define key (k)
  (define wrap (s)
    (if (= target 'lua) (cat "[" s "]") s))
  (let (i (inner k))
    (if (valid-id? i) i (wrap k))))

(define imported (spec :all)
  (let (m (make-id)
        k (module-key spec)
        imports ())
    (when (get nexus k)
      (each (n b) (get (module spec) 'export)
        (when (and b.variable (or all b.export))
          (add imports `(%local ,n (get ,m ',n))))))
    (when (some? imports)
      `((%local ,m (get nexus ',k)) ,@imports))))

(define linked (name form)
  (if (toplevel?)
      (let (k (module-key current-module))
        `(do ,form (set (get (get nexus ',k) ',name) ,name)))
    form))

(define quote-binding (b)
  (if (is? b.symbol)
      (extend b symbol: `',b.symbol)
      (and b.macro b.form)
      (exclude (extend b macro: b.form) :form)
      (and b.special b.form)
      (exclude (extend b special: b.form) :form)
      (is? b.variable) b
      (is? b.global) b))

(define mapo (f t)
  (let (o ())
    (each (k v) t
      (let (x (f v))
        (when (is? x)
          (add o (literal k))
          (add o x))))
    o))

(define quote-frame (t)
  `(%object ,@(mapo (fn (b) `(table ,@(quote-binding b))) t)))

(define quote-environment (env)
  `(list ,@(map quote-frame env)))

(define quote-module (m)
  `(table import: ,(quoted m.import)
          alias: ,(quoted m.alias)
          export: ,(quote-frame m.export)))

(define quote-modules ()
  `(table ,@(map quote-module modules)))

(define initial-environment ()
  (list (table define-module: (getenv 'define-module))))
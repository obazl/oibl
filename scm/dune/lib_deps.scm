(define (-fixup-progn-cmd! ws c targets deps)
  (if *mibl-debug-all*
      (format #t "~A: ~A\n" (ublue "-fixup-progn-cmd!") c))
  c)

(define (-module->filename m pkg) ;;FIXME add :signatures
  (if *mibl-debug-all*
      (format #t "~A: ~A~%" (blue "-module->filename") m))
  (let ((pkg-modules (assoc-val :modules pkg))
        (pkg-structs (assoc-val :structures pkg)))
    (if *mibl-debug-all*
        (begin
          (format #t "~A: ~A~%" (white "pkg-modules") pkg-modules)
          (format #t "~A: ~A~%" (white "pkg-structs") pkg-structs))))
  "mytest.ml")

(define (-fixup-std-dep-form ws pkg dep exports)
  (if *mibl-debug-all*
      (format #t "~A: ~A~%" (ublue "-fixup-std-dep-form") dep))
  (if (equal? (car dep) ::tools)
      dep ;; validate :pkg fld???
      (case (cdr dep)
        ((::unresolved ::opam-pkg)
         ;; (if (eq? ::import (last dep))
         (let ((exp (hash-table-ref exports
                                    (car dep))))
           (if *mibl-debug-all*
               (format #t "~A: ~A~%" (ured "XP") exp))
           (if exp
               (let* ((pkg (assoc-val :pkg exp))
                      (_ (if *mibl-debug-all* (format #t "~A: ~A~%" (ured "pkg") pkg)))
                      (tgt (assoc-val :tgt exp))
                      (_ (if *mibl-debug-all* (format #t "~A: ~A~%" (ured "tgt") tgt))))
                 (cons (car dep) exp))
               ;; else try std ocaml pkgs
               (begin
                 (if *mibl-debug-all*
                     (begin
                       (format #t "~A: ~A~%" (bgred "ocaml-std-pkgs") ocaml-std-pkgs)
                       (format #t "~A: ~A~%" (bgred "dep key") (car dep))))
                 (if-let ((x (assoc-val (car dep) ocaml-std-pkgs)))
                         ;; (format #f "@ocaml//lib/~A" (car dep))
                         (cons (car dep)
                               `((:ws . "@ocaml")
                                 (:pkg .
                                       ,(format #f "lib/~A"
                                                (keyword->symbol (car dep))))
                                 (:tgt . ,(keyword->symbol (car dep)))))
                         dep)))))
        ;; ((::fixme)
        ;;  ;; side-effect: update filegroups table
        ;;  ;; FIXME: instead, add :fg dep?
        ;;  (format #t "~A: ~A~%" (yellow "export keys")
        ;;          (hash-table-keys exports))
        ;;  (format #t "~A: ~A~%" (yellow "exports")
        ;;          exports)
        ;;  (let* ((exp (hash-table-ref exports
        ;;                              (car dep)))
        ;;         (_ (if *mibl-debug-all* (format #t "~A: ~A~%" (yellow "exp") exp)))
        ;;         (-pkg (assoc-val :pkg exp))
        ;;         (_ (if *mibl-debug-all* (format #t "~A: ~A~%" (yellow "pkg") -pkg)))
        ;;         (pkg-path (assoc-val :pkg-path pkg))
        ;;         )
        ;;    (update-filegroups-table! ;; ws pkg-path tgt pattern
        ;;     ws pkg-path ;; (car (assoc-val :name ws))
        ;;     -pkg ::all "*")
        ;;    (cons (car dep)
        ;;          (list (car exp)
        ;;                (cons :tgt "__all__")))))
        (else dep))))

(define ocaml-std-pkgs
  '((bigarray . bigarray)
    (compiler-libs . compiler-libs)
    (compiler-libs.common . compiler-libs/common)
    (compiler-libs.bytecomp . compiler-libs/bytecomp)
    (compiler-libs.toplevel . compiler-libs/toplevel)
    (dynlink . dynlink)
    (num . num/core)
    (ocamldoc . ocamldoc)
    ;; (stdlib . stdlib)
    ;; (:stdlib . stdlib)
    (str . str)
    (threads . threads)
    (unix . unix)
    ))

;;TEST
(define (glob-opam key)
  (format #t "GLOBBING~%")
  (let* ((pattern "**/**/fmt.*")
         (g (libc:glob.make)))
    (let ((old-wd (pwd)))
      ;; change to effective ws root before globbing
      (libc:chdir "/Users/gar/.opam/5.1.1/lib")
      (format #t "cwd after chdir: ~A\n" (pwd))
      (libc:glob pattern libc:GLOB_BRACE g)
      (let ((globbed (libc:glob.gl-pathv g)))
        (format #t "globbed: ~A\n" globbed)
  ))))
;; TEST
(define (test-ftw key)
  (format #t "FTW~%")
  (libc:ftw
   "/Users/gar/.opam/5.1.1/lib"
   (lambda (a b c)
     (format #t "a: ~A~%" a)
     ;; (format #t "c: ~A~%" c)
     ;;(format () "~A ~A~%" a ((libc:stat.st_size) b))
     0)
   10)
  )

;; a dep sym, e.g. (:deps (:remote bigarray parsexp sexplib0)) may be:
;; :here (current pkg), :local (other pkg in ws), :remote (other bazel ws)
;; :builtin (e.g. bigarray, num), or :opam?

;; Dune's (libraries ...) only lists pkgs, :here should not
;; occur. But we also use this routine to resolve deps in pkg-files,
;; so we must check for :here deps.

;; Support for multiple wss in one project not yet supported, so we
;; also do not check for :remote.
(define (-fixup-dep-sym ws-id dep pkg exports)
  (mibl-trace-entry "-fixup-dep-sym" dep :test *mibl-debug-deps*)
  ;; possible keys for dep 'foo:
  ;; 'foo, :foo, :lib:foo, :exe:foo, etc.
  ;; assume ref is to lib, so search for :lib:foo

  (call-with-exit
   (lambda (return)

   (if-let ((x (assoc-val dep ocaml-std-pkgs)))
           ;; builtin ocaml pkgs - distributed with but not automatically handled by compiler
          (begin
            (mibl-trace "builtin" x :test *mibl-debug-deps*)
            ;;(string->symbol (format #f "@ocaml//~A" x))
            (return `(:builtin . ,x))))

   ;; else try :here
   (if-let ((mdep (module-name->tagged-label dep pkg)))
           ;; ((mdep (module-name->tagged-label dep pkg))
           (begin
             (mibl-trace "FOUND :here dep" mdep :test *mibl-debug-deps*)
             (let* ((typ (car mdep))
                    )
               (return `(,typ (:here ,(caddr mdep))))
               ;;`(:here . ,dep)
               ;;(return mdep)))
               ;;(return `(:here ,mdep))
               )))


   ;; else try :local-module
   ;; With mibl, we can also directly express dependencies on modules
   ;; in other pkgs (directories).
   (if-let ((mdep2 (call-with-exit
                    (lambda (return)
                      (module-name->local-target return dep ws-id pkg)))))
           (begin
             (mibl-trace "Found :local dep" mdep2 :test *mibl-debug-deps*)
             (return mdep2)))
             ;; (return `(:local ,mdep2))))

   ;; else try :archive by lookup in exports tbl
   ;; requires one lookup per possible key
   ;; first lookup, :lib:foo
   ;; FIXME: this only works for dune, where exports are archives,
   ;; which may be referenced by public or private name.
   (let* ((pkg-path (assoc-val :pkg-path pkg))
          (key (string->keyword (format #f "lib:~A" dep)))
          (mibl-trace-let "trying1" key :test *mibl-debug-deps*)
          (resolved (hash-table-ref exports key)))
     (if resolved
         (let* ((pkg (assoc-val :pkg resolved))
                (mibl-trace-let "pkg" pkg :test *mibl-debug-deps*)
                (mibl-trace-let "this pkg-path" pkg-path :test *mibl-debug-deps*)
                (tgt (assoc-val :tgt resolved))
                (mibl-trace-let "tgt" tgt :test *mibl-debug-deps*))
           ;; (if (equal? pkg pkg-path)
           ;;     (string->symbol (format #f ":~A" tgt))
           ;;     (string->symbol (format #f "//~A:~A" pkg tgt)))
           (return `(:archive (:pkg . ,pkg) (:tgt . ,tgt))))

         ;; else second lookup, :foo
         (let* ((key (string->keyword
                      (format #f "~A" dep)))
                (mibl-trace-let "trying2" key :test *mibl-debug-deps*)
                ;; (_ (if *mibl-debug-deps* (format #t "~A: ~A~%" (bgblue "exports") exports)))
                ;; (_ (mibl-debug-print-exports-table ws-id))
                (resolved (hash-table-ref exports key)))
           (if resolved
               (let* ((pkg (assoc-val :pkg resolved))
                      (_ (if *mibl-debug-deps* (format #t "~A: ~A~%" (ured "pkg") pkg)))
                      (tgt (assoc-val :tgt resolved))
                      (_ (if *mibl-debug-deps* (format #t "~A: ~A~%" (ured "tgt") tgt))))
                 ;; (if (equal? pkg pkg-path)
                 ;;     (string->symbol (format #f ":~A" tgt))
                 ;;     (string->symbol (format #f "//~A:~A" pkg tgt)))
                 (return `(:local (:pkg . ,pkg) (:tgt . ,tgt))))
               ;; else third lookup, 'foo
               (let* ((key (string->symbol
                            (format #f "~A" dep)))
                      (_ (if *mibl-debug-deps* (format #t "~A: ~A~%" (uwhite "trying3") key)))
                      (resolved (hash-table-ref exports key)))
                 (if resolved
                     (let* ((pkg (assoc-val :pkg resolved))
                            (_ (if *mibl-debug-deps* (format #t "~A: ~A~%" (ured "pkg") pkg)))
                            (tgt (assoc-val :tgt resolved))
                            (_ (if *mibl-debug-deps* (format #t "~A: ~A~%" (ured "tgt") tgt))))
                       ;; (cons dep resolved)
                       (return `(:local (:pkg . ,pkg) (:tgt . ,tgt))))
                     ;; else not in exports tbl
                     (begin
                       (if *mibl-debug-deps* (format #t "~A: ~A~%" (uwhite "trying opam") key))
                       (let ((segs (string-split (format #f "~A" key) ".")))
                         ;; (glob-opam key) ;; TEST
                         ;; (test-ftw key) ;; TEST
                         (if-let ((dep (opam-fts key)))
                                 (if (empty? dep)
                                     (return `(:unresolved ,key))
                                     (return `(:opam . ,dep))
                                     ;; (let* ((opams (fold (lambda (d accum)
                                     ;;                       ;; (format #t "dep: ~A~%" (car d))
                                     ;;                       ;; (format #t "accum: ~A~%" accum)
                                     ;;                       (if (eq? :opam (car d))
                                     ;;                           (cons (cdr d) accum)
                                     ;;                           accum))
                                     ;;                     '() (cdr deps)))
                                     ;;        (opams (remove-duplicates opams))
                                     ;;        (non-opams (fold (lambda (d accum)
                                     ;;                           ;; (format #t "dep: ~A~%" (car d))
                                     ;;                           ;; (format #t "accum: ~A~%" accum)
                                     ;;                           (if (not (eq? :opam (car d)))
                                     ;;                               (cons d accum)
                                     ;;                               accum))
                                     ;;                         '() (cdr deps))))
                                     ;;   ;; (format #t "opams: ~A~%" opams)
                                     ;;   ;; (format #t "non-opams: ~A~%" non-opams)
                                     ;;   (if (truthy? opams)
                                     ;;       (set-cdr! deps `((:opam ,@opams) ,@non-opams))
                                     ;;       (set-cdr! deps non-opams)))
                                     )
                                 ;; should not happen?
                                 (begin
                                   (if *mibl-debug-deps*
                                       (format #t "~A: ~A~%" (red "unresolved; assume opam") key))
                                   (return `(:opam? . ,key))))
                         ;; (if (= 1 (length segs))
                         ;;     (string->symbol (format #f "@~A//lib/~A" dep dep))
                         ;;     (string->symbol (format #f "@~A//lib/~{~A~^/~}" (car segs) (cdr segs))))
                         )))))))))))

(define (-fixup-conditionals! ws pkg stanza)
  (if *mibl-debug-all*
      (format #t "~A: ~A\n" (ublue "-fixup-conditionals!") stanza))
  (if (not (member (car stanza) '(:diff :menhir)))
      (if-let ((conditionals (if-let ((dc
                                       (assoc-in '(:deps :conditionals)
                                                 (cdr stanza))))
                                     dc #f)))
              (if (truthy? conditionals)
                  (begin
                    (if *mibl-debug-all*
                        (format #t "~A: ~A~%" (blue "conditionals") (cdr conditionals)))
                    (for-each (lambda (conditional)
                                (if *mibl-debug-all*
                                    (format #t "~A: ~A~%" (bgblue "conditional")
                                            conditional))

                                ;;FIXME: selectors are always external pkgs (i.e. with '@')?
                                ;; even for proj libs?
                                (for-each (lambda (selector)
                                            (if *mibl-debug-all*
                                                (format #t "~A: ~A~%" (bgblue "selector")
                                                        selector))
                                            (let ((resolution (find-in-exports ws (car selector))))
                                              (if *mibl-debug-all*
                                                  (format #t "~A: ~A~%" (bgblue "selector resolution") resolution))
                                              (set-cdr! selector
                                                        (list
                                                         (cdr selector)
                                                         (if resolution
                                                             (string-append
                                                              (format #f "//~A"
                                                                      (assoc-val :pkg resolution))
                                                              ":"
                                                              (format #f "~A"
                                                                      (assoc-val :tgt resolution)))
                                                             (string->symbol
                                                              (format #f "@~A//lib/~A"
                                                                      (car selector) (car selector)))))))
                                            ;; (set-car! selector (format #f "//bzl/import:~A" (car selector)))
                                            )
                                          (assoc-val :selectors conditional)))
                              (cdr conditionals))))
              )))

;; FIXME: rename
(define (-fixup-stanza! ws-id pkg stanza)
  (mibl-trace-entry "-fixup-stanza!" stanza)
  (case (car stanza)
    ((:install) (values))
    (else (let* ((ws (assoc-val ws-id *mibl-project*))
                 (exports (car (assoc-val :exports ws)))
                 (pkg-path (assoc-val :pkg-path pkg))
                 (stanza-alist (cdr stanza)))
            ;; (mibl-debug-print-exports-table ws-id)

            (-fixup-conditionals! ws-id pkg stanza)
            (mibl-trace "XXXXXXXXXXXXXXXX" (car stanza))
            (case (car stanza)

              ((:executable :test)
               (if *mibl-debug-all*
                   (format #t "~A: ~A~%" (ublue "x fixup") (car stanza)))
               ;; FIXME: also handle :dynamic
               (let* (;; (modules (assoc-in '(:compile :manifest :modules) stanza-alist))
                     (compile-deps (assoc-in '(:deps :remote) stanza-alist))
                     (stanza-deps (assoc-in '(:deps :remote) stanza-alist))

                      (ppx (if-let ((ppx (assoc-val :ppx stanza-alist)))
                                   ppx #f))
                      (ppxex (if-let ((ppxes (assoc-val :ppxes stanza-alist)))
                                     ppxes #f))
                      (_ (if *mibl-debug-all* (format #t "~A: ~A~%" (ublue "ppx") ppx)))
                      (ppx-codeps (if-let ((ppx-codeps (assoc
                                                        :ppx-codeps stanza-alist)))
                                          ppx-codeps #f))
                     )
                 ;; (format #t "x compile modules: ~A~%" modules)
                 (if *mibl-debug-all*
                     (begin
                       (format #t "x compile deps: ~A~%" compile-deps)
                       (format #t "x stanza deps: ~A~%" stanza-deps)))
                 (if compile-deps ;; (not (null? compile-deps))
                     (begin
                       (if *mibl-debug-all*
                           (format #t "~A: ~A~%" (ured "resolving dep labels 1") compile-deps))
                       (let* ((exports (car (assoc-val :exports ws)))
                              (ppx (if-let ((ppx (assoc-val :ppx stanza-alist)))
                                           ppx #f))
                              (_ (if *mibl-debug-all* (format #t "~A: ~A~%" (ublue "ppx") ppx)))
                              (fixdeps
                               (map (lambda (dep)
                                      (if *mibl-debug-all*
                                          (format #t "~A: ~A~%" (uwhite "fixup dep A") dep))
                                      (cond
                                       ((list? dep)
                                        ;; std dep form: (:foo (:pkg...)(:tgt...))
                                        (-fixup-std-dep-form ws-id pkg dep exports))
                                       ((symbol? dep)
                                        (-fixup-dep-sym ws-id dep pkg exports))
                                       (else (error 'fixme
                                                    (format #f "~A: ~A~%" (bgred "unrecognized :archive dep type") dep)))))
                                    (cdr compile-deps))))
                         (if *mibl-debug-all*
                             (format #t "~A: ~A~%" (ured "fixed-up compile-deps") fixdeps))
                         (set-cdr! compile-deps fixdeps)
                         (set-car! compile-deps :Resolved)))

                     ;; else no compile-deps
                     )

                 (if ppx
                     (begin
                       (if *mibl-debug-all*
                           (format #t "~A: ~A~%" (ured "resolving ppx") ppx))
                       (let* ((exports (car (assoc-val :exports ws)))
                              (ppx-deps (assoc :manifest ppx))
                              (_ (if *mibl-debug-all* (format #t "~A: ~A~%" (bgred "ppx-deps") ppx-deps)))
                              (fixppx
                               (map (lambda (dep)
                                      (if *mibl-debug-all*
                                          (format #t "~A: ~A~%" (uwhite "fixup ppx-dep") dep))
                                      (cond
                                       ((list? dep)
                                        ;; std dep form: (:foo (:pkg...)(:tgt...))
                                        (-fixup-std-dep-form ws pkg dep exports))
                                       ((symbol? dep)
                                        (-fixup-dep-sym ws-id dep pkg exports))
                                       (else (error 'fixme
                                                    (format #f "~A: ~A~%" (bgred "unrecognized ppx-dep type") dep)))))
                                    (cdr ppx-deps))))
                         (if *mibl-debug-all*
                             (format #t "~A: ~A~%" (ured "fixed-up ppx-deps") fixppx))
                         (set-cdr! ppx-deps fixppx)
                         ;; (set-car! ppx-deps :resolved)
                         ;; (error 'STOP "stop ppx")
                         )))
                     ;; (let ((new (map (lambda (dep)
                     ;;                   ;; (format #t "~A: ~A\n" (uyellow "dep") dep)
                     ;;                   (let ((exp (hash-table-ref exports dep)))
                     ;;                     ;; (format #t "~A: ~A\n" (uyellow "ht val") exp)
                     ;;                     (if exp
                     ;;                         (string->symbol (format #f "//~A:~A" exp dep))
                     ;;                         ;; assume opam label:
                     ;;                         (string->symbol (format #f "@~A//:~A" dep dep)))))
                     ;;                 (cdr deps))))
                     ;;   (set-cdr! deps new)
                     ;;   (set-car! deps :resolved))
                 ;; (if modules
                 ;;     (let ((new (map (lambda (m)
                 ;;                       (format #t "module: ~A\n" m)
                 ;;                       (let ((exp (hash-table-ref exports m)))
                 ;;                         (format #t "importing: ~A\n" exp)
                 ;;                         (if exp
                 ;;                             (format #f "//~A:~A" exp m)
                 ;;                             (-resolve-module-deps m stanza pkg))))
                 ;;                     (cdr modules))))
                 ;;       (set-cdr! modules new)))
                 ;; (error 'fixme "STOP labels")
                 ))

              ;; ((:diff)
              ;;  (error 'FIXME
              ;;         (format #f "unhandled labels :diff" )))

              ((:rule :rulex
                      :diff :node :ocamlc
                      :bindiff-test :diff-test
                      :write-file)
               (if *mibl-debug-all*
                   (format #t "~A: ~A, ~A~%" (ublue "fixup") (car stanza) stanza-alist))
               (let* ((targets (assoc-val ::outputs stanza-alist))
                      (_ (if *mibl-debug-all* (format #t "targets: ~A~%" targets)))
                      (deps (if-let ((deps (assoc :deps stanza-alist)))
                                    ;; (if (null? deps) '() (car deps))
                                    deps
                                    #f))
                      (_ (if *mibl-debug-all* (format #t "deps: ~A~%" deps)))
                      (action (if-let ((action (assoc-val :cmd stanza-alist))) ;; (assoc-val :actions stanza-alist)))
                                      action
                                      (if-let ((action
                                                (assoc-val :progn stanza-alist)))
                                              action
                                              (error 'bad-action
                                                     (format #t "unexpected action in rule: ~A\n" stanza-alist)))))
                      (_ (if *mibl-debug-all* (format #t "action: ~A~%" action)))
                      (tool (assoc-in '(:cmd :tool) stanza-alist)))
                 (if *mibl-debug-all*
                     (begin
                       (format #t "Tool: ~A~%" tool)
                       (format #t "Action: ~A~%" action)
                       (format #t "stanza-alist: ~A~%" stanza-alist)))

                 ;; fixup-deps
                 ;; (if-let ((deps (if-let ((deps (assoc :deps stanza-alist)))
                 ;;                     ;; (if (null? deps) '() (car deps))
                 ;;                     deps #f)))
                 (if deps
                     (begin
                       (if *mibl-debug-all*
                           (format #t "~A: ~A~%" (ured "resolving dep labels 2") deps))
                       (let ((exports (car (assoc-val :exports ws)))
                             (fixdeps
                              (map (lambda (dep)
                                     (if *mibl-debug-all*
                                         (format #t "~A: ~A~%" (uwhite "fixup dep B") dep))
                                     (if (eq? (car dep) ::tools)
                                         (begin
                                           (if *mibl-debug-all*
                                               (format #t "~A: ~A~%" (bgred "::TOOLS") (caadr dep)))
                                           (cond
                                            ((eq? ::unresolved (cdadr dep))
                                             (let* ((t (format #f "~A" (caadr dep)))
                                                    (t (if (string-prefix? ":exe:" t)
                                                           (string->symbol (string-append ":bin:" (string-drop t 5)))
                                                           (caadr dep))))
                                               (if *mibl-debug-all*
                                                   (begin
                                                     (format #t "~A~%" (bgred "IMPORT TOOL"))
                                                     (format #t "~A~%" (red "export keys"))))
                                               ;; if tool = :exe:..., replace exe with bin before lookup
                                               ;; (for-each (lambda (k)
                                               ;;             (format #t "~A: ~A~%" (ured "key") k))
                                               ;;           (sort! (hash-table-keys exports) sym<?))
                                               (if-let ((import (hash-table-ref exports t)))
                                                       (begin
                                                         (if *mibl-debug-all*
                                                             (format #t "~A: ~A~%" (bgred "importing") import))
                                                         (list ::tools
                                                               (cons (caadr dep) ;; use original :exe:, :bin: just for lookup
                                                                           (list (assoc :pkg import)
                                                                                 (assoc :tgt import))
                                                                           ;; (format #f "//~A:~A"
                                                                           ;;         (assoc-val :pkg import)
                                                                           ;;         (assoc-val :tgt import))
                                                                           ))
                                                         )
                                                       (begin
                                                         (if *mibl-debug-all*
                                                             (format #t "~A: ~A~%" (red "no import for tool") t))
                                                         ;; (error 'STOP "STOP no import")
                                                         ;; assume (rashly) that form is e.g. ::tools/version/gen/gen.exe
                                                         (let* ((kw t) ;; (caadr dep))
                                                                (t (keyword->symbol kw))
                                                                (path (dirname t)))
                                                           `(::tools
                                                             (,kw
                                                              ,(cons :pkg (if (string=? "./" path)
                                                                              pkg-path path
                                                                              ;; (if (string=? "::wsroot" path)
                                                                              ;;     pkg-path
                                                                              ;;     path)
                                                                              ))
                                                              ;; ,(cons :pkg (if (string=? "./" path)
                                                              ;;                 pkg-path path))
                                                              ,(cons :tgt (basename t))))
                                                           )))))
                                            ((eq? ::unresolved (cdadr dep))
                                             ;;FIXME
                                             )
                                           ;; else treat it just like a std dep
                                           (else (-fixup-std-dep-form ws-id pkg dep exports))))
                                         ;; else std dep form: (:foo (:pkg...)(:tgt...))
                                         (-fixup-std-dep-form ws-id pkg dep exports)))
                                   (cdr deps))))
                             (if *mibl-debug-all*
                                 (format #t "~A: ~A~%" (ured "fixed-up deps") fixdeps))
                         (set-cdr! deps fixdeps))))
                 ;; (format #t "~A: ~A~%" (ured "reset deps") deps)

                 ;; :actions is always a list of cmd; for progn, more than one
                 (if (assoc :cmd stanza-alist) ;; :actions stanza-alist)
                     (begin
                       (for-each (lambda (c)
                                   (if *mibl-debug-all*
                                       (format #t "PROGN cmd: ~A~%" c))
                                   (-fixup-progn-cmd! ws c targets deps))
                                 action))
                     ;; else? actions always have a :cmd?
                     (begin
                       (if *mibl-debug-all*
                           (begin
                             (format #t "rule action: ~A~%" action)
                             (format #t "rule tool: ~A~%" tool)
                             (format #t "rule targets: ~A~%" targets)
                             (format #t "rule deps: ~A~%" deps)
                             (error 'unhandled action "unhandled action")
                             ))
                       ;; (if-let ((tool-label (hash-table-ref exports (cadr tool))))
                       ;;         (let* ((_ (if *mibl-debug-all* (format #t "tool-label: ~A~%" tool-label)))
                       ;;                (pkg (car (assoc-val :pkg tool-label)))
                       ;;                (tgt (car (assoc-val :tgt tool-label)))
                       ;;                (label (format #f "//~A:~A" pkg tgt))
                       ;;                (_ (if *mibl-debug-all* (format #t "tool-label: ~A\n" tool-label))))
                       ;;           (set-cdr! tool (list label)))
                       ;;         ;; FIXME: handle deps
                       ;;         '())
                       ))))

              ((:archive :ns-archive :library :ns-library)

               (if *mibl-debug-all*
                   (format #t "~A: ~A~%" (blue "aggregate fixup") (car stanza)))
               ;; (let ((deps (assoc-val :deps stanza-alist)))
               ;;   (format #t "archive deps: ~A~%" deps)))
               (let* ((deps (if-let ((deps (assoc-in '(:deps :remote) stanza-alist)))
                                    deps #f))
                      (_ (if *mibl-debug-all* (format #t "~A: ~A~%" (blue "deps") deps)))
                      (ppx (if-let ((ppx (assoc-val :ppx stanza-alist)))
                                   ppx #f))
                      (ppxex (if-let ((ppxes (assoc-val :ppxes stanza-alist)))
                                     ppxes #f))
                      (_ (if *mibl-debug-all* (format #t "~A: ~A~%" (ublue "ppx") ppx)))
                      (ppx-codeps (if-let ((ppx-codeps (assoc
                                                        :ppx-codeps stanza-alist)))
                                          ppx-codeps #f))
                      )
                 (if deps
                     (begin
                       (if *mibl-debug-all*
                           (format #t "~A: ~A~%" (ugreen "resolving libdeps 3") deps))
                       (let ((exports (car (assoc-val :exports ws)))
                             (fixdeps
                              (map (lambda (dep)
                                     (if *mibl-debug-all*
                                         (format #t "~A: ~A~%" (green "resolving dep") dep))
                                     (cond
                                      ((list? dep) ;; std dep form: (:foo (:pkg...)(:tgt...))
                                       (-fixup-std-dep-form ws pkg dep exports))
                                      ((symbol? dep) ;; e.g. (:deps (:remote bigarray parsexp sexplib0))
                                       (-fixup-dep-sym ws-id dep pkg exports))
                                      (else (error 'fixme
                                                   (format #f "~A: ~A~%" (bgred "unrecognized :archive dep type") dep)))))
                                   (cdr deps))))
                         (if *mibl-debug-all*
                             (format #t "~A: ~A~%" (ured "fixed-up deps") fixdeps))
                         (set-cdr! deps fixdeps)
                         (set-car! deps :resolved))))
                 (if ppx
                     (begin
                       (if *mibl-debug-all*
                           (format #t "~A: ~A~%" (ured "resolving ppx") ppx))
                       (let* ((exports (car (assoc-val :exports ws)))
                              (ppx-deps (assoc :manifest ppx))
                              (_ (if *mibl-debug-all* (format #t "~A: ~A~%" (bgred "ppx-deps") ppx-deps)))
                              (fixppx
                               (map (lambda (dep)
                                      (if *mibl-debug-all*
                                          (format #t "~A: ~A~%" (uwhite "fixup ppx-dep") dep))
                                      (cond
                                       ((list? dep)
                                        ;; std dep form: (:foo (:pkg...)(:tgt...))
                                        (-fixup-std-dep-form ws pkg dep exports))
                                       ((symbol? dep)
                                        (-fixup-dep-sym ws-id dep pkg exports))
                                       (else (error 'fixme
                                                    (format #f "~A: ~A~%" (bgred "unrecognized ppx-dep type") dep)))))
                                    (cdr ppx-deps))))
                         (if *mibl-debug-all*
                             (format #t "~A: ~A~%" (ured "fixed-up ppx-deps") fixppx))
                         (set-cdr! ppx-deps fixppx)
                         ;; (set-car! ppx-deps :resolved)
                         ;; (error 'STOP "stop ppx")
                         )))
                 (if ppx-codeps
                     (begin
                       (if *mibl-debug-all*
                           (format #t "~A: ~A~%" (ured "resolving ppx-codeps") ppx-codeps))
                       (let* ((exports (car (assoc-val :exports ws)))
                              ;; (ppx-deps (assoc :manifest ppx))
                              ;; (_ (if *mibl-debug-all* (format #t "~A: ~A~%" (bgred "ppx-deps") ppx-deps)))
                              (fixppx
                               (map (lambda (dep)
                                      (if *mibl-debug-all*
                                          (format #t "~A: ~A~%" (uwhite "fixup ppx-dep") dep))
                                      (cond
                                       ((list? dep)
                                        ;; std dep form: (:foo (:pkg...)(:tgt...))
                                        (-fixup-std-dep-form ws pkg dep exports))
                                       ((symbol? dep)
                                        (-fixup-dep-sym ws-id dep pkg exports))
                                       (else (error 'fixme
                                                    (format #f "~A: ~A~%" (bgred "unrecognized ppx-dep type") dep)))))
                                    (cdr ppx-codeps))))
                         (if *mibl-debug-all*
                             (format #t "~A: ~A~%" (ured "fixed-up ppx-codeps") fixppx))
                         (set-cdr! ppx-codeps fixppx)
                         ;; (set-car! ppx-deps :resolved)
                         ;; (error 'STOP "stop ppx")
                         )))
                 ))

              ((:cppo)
               (let ((deps (assoc :deps (cdr stanza))))
                 (if *mibl-debug-all*
                     (format #t "~A: ~A~%" (red "deps") deps))
                 (set-cdr! deps (dissoc '(::tools) (cdr deps)))
                 (if *mibl-debug-all*
                     (format #t "~A: ~A~%" (red "deps after") deps)))
               )

              ;; ((:library)
              ;;  (format #t "~A~%" (ublue "fixup :library"))
              ;;  (let* ((deps (if-let ((deps (assoc-in '(:deps :remote) stanza-alist)))
              ;;                       deps #f))
              ;;         (_ (if *mibl-debug-all* (format #t "deps: ~A~%" deps)))
              ;;         )
              ;;    (if deps
              ;;        (begin
              ;;          (format #t "~A: ~A~%" (ured "resolving dep labels") deps)
              ;;          (let ((exports (car (assoc-val :exports ws)))
              ;;                (fixdeps
              ;;                 (map (lambda (dep)
              ;;                        (format #t "~A: ~A~%" (uwhite "fixup dep") dep)
              ;;                        (cond
              ;;                         ((list? dep)
              ;;                          ;; std dep form: (:foo (:pkg...)(:tgt...))
              ;;                          (-fixup-std-dep-form ws pkg dep exports))
              ;;                         ((symbol? dep)
              ;;                          (-fixup-dep-sym ws-id dep pkg exports))
              ;;                         (else (error 'fixme
              ;;                                      (format #f "~A: ~A~%" (bgred "unrecognized :archive dep type") dep)))))
              ;;                      (cdr deps))))
              ;;            (format #t "~A: ~A~%" (ured "fixed-up deps") fixdeps)
              ;;            (set-cdr! deps fixdeps)
              ;;            (set-car! deps :resolved))))))

              ;;  (format #t "~A~%" (magenta "fixup :library"))
              ;;  (let ((manifest (assoc-val :manifest stanza-alist))
              ;;        (deps (assoc-val :deps stanza-alist)))
              ;;    (format #t "library deps: ~A~%" deps)))

              ((:lex :yacc :menhir :env
                          :prologues :testsuite :tuareg :alias)
               (values))

              ((:shell :tool :stdout :cmd :cmd-lines) (values))

              ((:test-action) (values)) ;; testing

              (else
               (error 'fixme
                      (format #t "~A: ~A~%" (bgred "UNhandled fixup stanza") (car stanza)))))))))

(define (-fixup-module-deps! ws pkg module-spec)
  ;; module-spec: (A (ml: a.ml ...) (:mli a.mli ...))
  ;; (or :ml_, :mli_)
  (mibl-trace-entry "-fixup-module-deps!" module-spec :test *mibl-debug-deps*)
  (let* ((exports (car (assoc-val :exports ws)))
         (ml-deps (if-let ((mldeps (assoc-val :ml (cdr module-spec))))
                          mldeps
                          (assoc-val :ml_ (cdr module-spec))))
         (mli-deps (if-let ((mldeps (assoc-val :mli (cdr module-spec))))
                           mldeps
                           (assoc-val :mli_ (cdr module-spec))))
         )
    (mibl-trace "ml-deps" ml-deps :test *mibl-debug-deps*)
    (if (list? ml-deps)
        (let ((newdeps (map (lambda (dep)
                              (-fixup-dep-sym :@ dep pkg exports))
                            (cdr ml-deps))))
          (mibl-trace "new ml-dep" newdeps :test *mibl-debug-deps*)
          (if (truthy? newdeps)
              (set-cdr! ml-deps `((:deps ,@newdeps))))))

    (mibl-trace "mli-deps" mli-deps :test *mibl-debug-deps*)
    (if (list? mli-deps)
        (let ((newdeps (map (lambda (dep)
                              (-fixup-dep-sym :@ dep pkg exports))
                            (cdr mli-deps))))
          (mibl-trace "new mli-dep" newdeps :test *mibl-debug-deps*)
          (if (truthy? newdeps)
              (set-cdr! mli-deps `((:deps ,@newdeps))))))
    ))

(define (-fixup-struct-deps! ws pkg struct-spec)
  (mibl-trace-entry "-fixup-struct-deps!" struct-spec :test *mibl-debug-deps*)
  ;; struct-spec: (:structures (:static (a.ml ...)) (:dynamic (b.ml ...)))
  (let* ((exports (car (assoc-val :exports ws)))
         (statics (if-let ((deps (assoc-val :static (cdr struct-spec))))
                       deps '()))
         (dynamics (if-let ((deps (assoc-val :dynamic (cdr struct-spec))))
                       deps '())))
    (mibl-trace "struct statics" statics :test *mibl-debug-deps*)
    (for-each (lambda (struct) ;; (Foo foo.ml ...)
                (mibl-trace "struct" struct :test *mibl-debug-deps*)
                (let* ((s-deps (cdr struct)))
                  ;; s-deps:  (foo.ml Dep1 Dep2 ...)
                  ;; we will set-cdr! on this
                  (mibl-trace "sdeps" s-deps :test *mibl-debug-deps*)
                  (if (list? s-deps)
                      (let ((newdeps (map (lambda (dep)
                                             (mibl-trace "Fixing" dep :test *mibl-debug-deps*)
                                             (-fixup-dep-sym :@ dep pkg exports))
                                           (cdr s-deps))))
                        (mibl-trace "sstruct newdeps" newdeps :test *mibl-debug-deps*)
                        (if (truthy? newdeps)
                            (set-cdr! s-deps `((:deps ,@newdeps))))))))
              statics)
    (mibl-trace "struct dynamics" dynamics :test *mibl-debug-deps*)
    (for-each (lambda (struct) ;; (Foo foo.ml ...)
                (mibl-trace "struct" struct :test *mibl-debug-deps*)
                (let* ((s-deps (cdr struct)))
                  ;; s-deps:  (foo.ml Dep1 Dep2 ...)
                  ;; we will set-cdr! on this
                  (mibl-trace "sdeps" s-deps :test *mibl-debug-deps*)
                  (if (list? s-deps)
                      (let ((newdeps (map (lambda (dep)
                                             (mibl-trace "Fixing" dep :test *mibl-debug-deps*)
                                             (-fixup-dep-sym :@ dep pkg exports))
                                           (cdr s-deps))))
                        (mibl-trace "dstruce newdeps" newdeps :test *mibl-debug-deps*)
                        (set-cdr! s-deps `((:struct-deps ,@newdeps)))))))
              dynamics)
    ))

(define (-fixup-sig-deps! ws pkg sig-spec)
  (if *mibl-debug-all*
      (format #t "~A: ~A\n" (ublue "-fixup-sig-deps!") sig-spec))
  ;; sig-spec: (:signatures: (:static (a.mli ...)) (:dynamic (b.mli ...)))
  (let* ((exports (car (assoc-val :exports ws)))
         (statics (if-let ((deps (assoc-val :static (cdr sig-spec))))
                       deps '()))
         (dynamics (if-let ((deps (assoc-val :dynamic (cdr sig-spec))))
                       deps '())))
    (mibl-trace "fixup sig statics" statics)
    (mibl-trace "fixup sig dynamics" dynamics)
    ;; first statics
    (for-each (lambda (sig) ;; (:static (Foo foo.mli ...))
                (mibl-trace "fixup static sig" sig)
                (let* ((s-deps (cdr sig)))
                  ;; s-deps:  (foo.mli Dep1 Dep2 ...)
                  ;; we will set-cdr! on this
                  ;;(_ (format #t "~A: ~A\n" (ublue "sdeps") s-deps))
                  (if (list? s-deps)
                      (let ((newdeps (map (lambda (dep)
                                            (mibl-trace "fixing" dep)
                                            ;;(format #t "~A: ~A\n" (ublue "fixing") dep)
                                      (-fixup-dep-sym :@ dep pkg exports))
                                    (cdr s-deps))))
                        (mibl-trace "new static-sig dep" newdeps)
                        (if (truthy? newdeps)
                            (set-cdr! s-deps `((:deps ,@newdeps))))))))
              statics)
        (for-each (lambda (sig) ;; (:static (Foo foo.mli ...))
                (mibl-trace "fixup dyn sig" sig)
                (let* ((s-deps (cdr sig)))
                  ;; s-deps:  (foo.mli Dep1 Dep2 ...)
                  ;; we will set-cdr! on this
                  ;;(_ (format #t "~A: ~A\n" (ublue "sdeps") s-deps))
                  (if (list? s-deps)
                      (let ((newdeps (map (lambda (dep)
                                            (mibl-trace "fixing" dep)
                                            ;;(format #t "~A: ~A\n" (ublue "fixing") dep)
                                      (-fixup-dep-sym :@ dep pkg exports))
                                    (cdr s-deps))))
                        (mibl-trace "new dynsig dep" newdeps)
                        (set-cdr! s-deps `((:sig-deps ,@newdeps)))))))
              dynamics)))

;; updates stanzas/pkg files. initial conditions:
;; * :deps derived from (libraries) fld of (library) stanza
;; * module deps listed in :modules, :structures, :signatures
;; result:
;;     :deps - module names replaced by bazel labels
;;     pkg file deps: opam pkg modules removed
;; e.g. sexplib0 =>  @sexplib0//lib/sexplib0
;; method: try to resolve each module locally
;; if that fails, assume it is an opam pkg
(define normalize-lib-deps!
  (let ((+documentation+ "Map dune target references to bazel labels using exports table.")
        (+signature+ '(normalize-lib-deps! workspace-id)))
    (lambda (ws-id)
      (let ((ws (assoc-val ws-id *mibl-project*)))
        (if *mibl-debug-all*
            (format #t "~%~A for ws: ~A\n"
                (bgred "normalize-lib-deps!") ws)) ;;(assoc :name ws)))
        ;; (assoc-val 'name ws))
        (let* ((pkgs (car (assoc-val :pkgs ws)))
               ;; (_ (if *mibl-debug-all* (format #t "PKGS: ~A\n" pkgs)))
               (exports (car (assoc-val :exports ws))))
          ;; (format #t "resolving labels for pkgs: ~A\n" (hash-table-keys pkgs))
          ;; (format #t "exports: ~A\n" exports)
          (for-each (lambda (pkg-kv)
                      (if *mibl-debug-all*
                          (format #t "~A: ~A~%" (ublue "resolving pkg") pkg-kv))
                      ;; (format #t "pkg: ~A~%" (cdr pkg-kv))
                      (let ((pkg (cdr pkg-kv)))
                        (if-let ((stanzas (assoc-val :mibl (cdr pkg-kv))))
                                (for-each (lambda (stanza)
                                            (-fixup-stanza! ws-id pkg stanza)
                                            (if *mibl-debug-all*
                                                (format #t "stanza: ~A~%" stanza)))
                                          stanzas))
                        (if-let ((modules (assoc-val :modules (cdr pkg-kv))))
                                (for-each (lambda (module)
                                            (-fixup-module-deps! ws pkg module))
                                          modules))
                        (if-let ((structs (assoc :structures (cdr pkg-kv))))
                                (-fixup-struct-deps! ws pkg structs)
                                ;; (for-each (lambda (struct)
                                ;;             (-fixup-struct-deps! ws pkg struct))
                                ;;           structs)
                                )
                        (if-let ((sigs (assoc :signatures (cdr pkg-kv))))
                                (-fixup-sig-deps! ws pkg sigs)
                                ;; (for-each (lambda (sig)
                                ;;             (-fixup-sig-deps! ws pkg sig))
                                ;;           sigs)
                                )
                        )
                      )
                    pkgs)
          )))))

(define (merge-mod-deps! deps)
  ;; (format #t "merge-mod-deps! ~A~%" deps)
  (let* ((mod-deps (fold (lambda (d accum)
                          ;; (format #t "dep: ~A~%" (car d))
                          ;; (format #t "accum: ~A~%" accum)
                          (if (eq? :mod (car d))
                              (if (eq? :here (caadr d))
                                  (cons (cadr d) accum)
                                  (cons (cdr d) accum))
                              accum))
                        '() (cdr deps)))
           ;; (mod-deps (remove-duplicates mod-deps))
           (non-mod-deps (fold (lambda (d accum)
                              ;; (format #t "dep: ~A~%" (car d))
                              ;; (format #t "accum: ~A~%" accum)
                              (if (not (eq? :mod (car d)))
                                  (cons d accum)
                                  accum))
                            '() (cdr deps))))
      ;; (format #t "mod-deps: ~A~%" mod-deps)
      ;; (format #t "non-mod-deps: ~A~%" non-mod-deps)
      (if (truthy? mod-deps)
          (set-cdr! deps `((:modules ,@mod-deps) ,@non-mod-deps))
          (set-cdr! deps non-mod-deps))))

(define (merge-struct-deps! deps)
  ;; (format #t "merge-struct-deps! ~A~%" deps)
  (let* ((mod-deps (fold (lambda (d accum)
                          ;; (format #t "dep: ~A~%" (car d))
                          ;; (format #t "accum: ~A~%" accum)
                          (if (eq? :struct (car d))
                              (if (eq? :here (caadr d))
                                  (cons (cadr d) accum)
                                  (cons (cdr d) accum))
                              accum))
                        '() (cdr deps)))
           ;; (mod-deps (remove-duplicates mod-deps))
           (non-mod-deps (fold (lambda (d accum)
                              ;; (format #t "dep: ~A~%" (car d))
                              ;; (format #t "accum: ~A~%" accum)
                              (if (not (eq? :struct (car d)))
                                  (cons d accum)
                                  accum))
                            '() (cdr deps))))
      ;; (format #t "mod-deps: ~A~%" mod-deps)
      ;; (format #t "non-mod-deps: ~A~%" non-mod-deps)
      (if (truthy? mod-deps)
          (set-cdr! deps `((:structs ,@mod-deps) ,@non-mod-deps))
          (set-cdr! deps non-mod-deps))))

(define (merge-sig-deps! deps)
  ;; (format #t "merge-sig-deps! ~A~%" deps)
  (let* ((mod-deps (fold (lambda (d accum)
                          ;; (format #t "dep: ~A~%" (car d))
                          ;; (format #t "accum: ~A~%" accum)
                          (if (eq? :sig (car d))
                              (if (eq? :here (caadr d))
                                  (cons (cadr d) accum)
                                  (cons (cdr d) accum))
                              accum))
                        '() (cdr deps)))
           ;; (mod-deps (remove-duplicates mod-deps))
           (non-mod-deps (fold (lambda (d accum)
                              ;; (format #t "dep: ~A~%" (car d))
                              ;; (format #t "accum: ~A~%" accum)
                              (if (not (eq? :sig (car d)))
                                  (cons d accum)
                                  accum))
                            '() (cdr deps))))
      ;; (format #t "mod-deps: ~A~%" mod-deps)
      ;; (format #t "non-mod-deps: ~A~%" non-mod-deps)
      (if (truthy? mod-deps)
          (set-cdr! deps `((:sigs ,@mod-deps) ,@non-mod-deps))
          (set-cdr! deps non-mod-deps))))

(define (merge-opams! deps)
  ;; (format #t "merge-opams! ~A~%" deps)
  (let* ((opams (fold (lambda (d accum)
                        ;; (format #t "dep: ~A~%" (car d))
                        ;; (format #t "accum: ~A~%" accum)
                        (if (eq? :opam (car d))
                            (cons (cdr d) accum)
                            accum))
                      '() (cdr deps)))
         (opams (remove-duplicates opams))
         (non-opams (fold (lambda (d accum)
                            ;; (format #t "dep: ~A~%" (car d))
                            ;; (format #t "accum: ~A~%" accum)
                            (if (not (eq? :opam (car d)))
                                (cons d accum)
                                accum))
                          '() (cdr deps))))
    ;; (format #t "opams: ~A~%" opams)
    ;; (format #t "non-opams: ~A~%" non-opams)
    (if (truthy? opams)
        (set-cdr! deps `((:opam ,@opams) ,@non-opams))
        (set-cdr! deps non-opams))))

(define merge-file-deps!
(let ((+documentation+ "Merge :deps in :modules, :structures, :signatures.")
      (+signature+ '(merge-file-deps! ws-id)))
  (lambda (ws-id)
    (mibl-trace-entry "merge-file-deps!" ws-id :test *mibl-debug-deps*)
    (let* ((ws (assoc-val ws-id *mibl-project*))
           (pkgs (car (assoc-val :pkgs ws))))
      (for-each (lambda (pkg-kv)
                  ;; (format #t "pkg: ~A~%" (car pkg-kv))
                  (if-let ((modules (assoc-val :modules (cdr pkg-kv))))
                          (for-each (lambda (m)
                                      ;; (format #t "module: ~A~%" m)
                                      (let* ((ml (assoc-val :ml (cdr m)))
                                             (mli (assoc-val :mli (cdr m))))
                                        ;; (format #t "ml: ~A~%" ml)
                                        ;; (format #t "mli: ~A~%" mli)
                                        (if (list? ml)
                                            (begin
                                              (if-let ((deps (assoc :deps (cdr ml))))
                                                      (begin
                                                        (merge-opams! deps)
                                                        (merge-mod-deps! deps)
                                                        (merge-struct-deps! deps)
                                                        (merge-sig-deps! deps)
                                                        )))
                                            )
                                        (if (list? mli)
                                            (if-let ((deps (assoc :deps (cdr mli))))
                                                    (begin
                                                        (merge-opams! deps)
                                                        (merge-mod-deps! deps)
                                                        (merge-struct-deps! deps)
                                                        (merge-sig-deps! deps))))
                                                ))
                                        modules))
                      (if-let ((structs (assoc-val :structures (cdr pkg-kv))))
                              (let* ((statics (if-let ((deps (assoc-val :static structs)))
                                                      deps '()))
                                     (dynamics (if-let ((deps (assoc-val :dynamic structs)))
                                                       deps '())))
                                (for-each (lambda (struct)
                                            ;; (format #t "static struct: ~A~%" struct)
                                            (if (list? (cdr struct))
                                                (if-let ((deps (assoc :deps (cddr struct))))
                                                        (merge-opams! deps))))
                                          statics)
                                (for-each (lambda (struct)
                                            (error 'unimplemented
                                                   (format #t "dyn struct: ~A~%" struct)
                                                   ))
                                          dynamics)))
                      (if-let ((sigs (assoc-val :signatures (cdr pkg-kv))))
                              (let* ((statics (if-let ((deps (assoc-val :static sigs)))
                                                      deps '()))
                                     (dynamics (if-let ((deps (assoc-val :dynamic sigs)))
                                                       deps '())))
                                (for-each (lambda (sig)
                                            ;; (format #t "static sig: ~A~%" sig)
                                            (if (list? (cdr sig))
                                                (if-let ((deps (assoc :deps (cddr sig))))
                                                        (merge-opams! deps))))
                                          statics)
                                (for-each (lambda (sig)
                                            (error 'unimplemented
                                                   (format #t "dyn sig: ~A~%" sig)))
                                          dynamics)))
                      )
                    pkgs))
      (values)
      )))

(define (debug-print-exports-table ws)
  (format #t "~A: ~A~%" (ublue "debug-print-exports-table") ws)
  (let* ((@ws (assoc-val ws -mibl-ws-table))
         (exports (car (assoc-val :exports @ws)))
         (keys (sort! (hash-table-keys exports) sym<?)))
    (format #t "~A:~%" (ured "exports table"))
    (for-each (lambda (k)
                (format #t " ~A => ~A~%" k (exports k)))
              keys)))
;; (format #t "~A: ~A~%" (red "exports keys") (hash-table-keys exports))
;; (format #t "~A: ~A~%" (red "exports table") exports)))

(define (debug-print-filegroups ws)
  (format #t "~A: ~A~%" (ublue "debug-print-filegroups") ws)
  (let* ((@ws (assoc-val ws -mibl-ws-table))
         (filegroups (car (assoc-val :filegroups @ws)))
         (keys (sort! (hash-table-keys filegroups) string<?)))
    ;; (format #t "~A:~%" (red "filegroups table"))
    (for-each (lambda (k)
                (format #t " ~A => ~A~%" k (filegroups k)))
              keys)))

(define (debug-print-pkgs ws)
  (format #t "~A~%" (bgred "PKG DUMP"))
  (let* ((@ws (assoc-val ws -mibl-ws-table))
         (pkgs (car (assoc-val :pkgs @ws)))
         )
    (format #t "~A: ~A ~A~%" (bggreen "workspace") (assoc :name @ws) (assoc :path @ws))
    (for-each (lambda (k)
                (let ((pkg (hash-table-ref pkgs k)))
                  (format #t "~%~A: ~A~%" (bggreen "Package") (green k)) ;; (assoc-val :pkg-path pkg))
                  ;; (format #t "~A: ~A~%" (green "pkg") pkg) ;; (assoc-val :pkg-path pkg))
                  ;; (for-each (lambda (fld)
                  ;;             (format #t "~A: ~A~%" (ugreen "fld") (car fld)))
                  ;;           pkg)
                  (if-let ((dune (assoc-val 'dune pkg)))
                          (format #t "~A: ~A~%" (ugreen "dune") dune))
                  (if-let ((opams (assoc-val :opam pkg)))
                          (begin
                            (format #t "~A:~%" (ugreen "opams"))
                            (for-each (lambda (opam)
                                        (format #t "  ~A~%" opam))
                                      opams)))
                  (if-let ((ms (assoc-val :modules pkg)))
                          (for-each (lambda (m)
                                      (format #t "~A: ~A~%" (ugreen "pkg-module") m))
                                    ms)
                          (format #t "~A: ~A~%" (ugreen "pkg-modules") ms))
                  (format #t "~A:~%" (ugreen "pkg-structures") )
                  (if-let ((ss (assoc-in '(:structures :static) pkg)))
                          (begin
                            (format #t "  raw: ~A~%" ss)
                            (for-each (lambda (s)
                                        (format #t "  ~A: ~A~%" (ugreen "static") s))
                                      (cdr ss)))
                          (format #t "  ~A: ~A~%" (ugreen "statics") ss))
                  (if-let ((ss (assoc-in '(:structures :dynamic) pkg)))
                          (for-each (lambda (s)
                                      (format #t "  ~A: ~A~%" (ugreen "dynamic") s))
                                    (cdr ss))
                          (format #t "  ~A: ~A~%" (ugreen "dynamics") ss))
                  ;; (format #t "~A: ~A~%" (ugreen "pkg-structures") (assoc-val :structures pkg))
                  (format #t "~A: ~A~%" (ugreen "pkg-signatures") (assoc-val :signatures pkg))
                  (format #t "~A: ~A~%" (ugreen "pkg-ocamllex") (assoc-val :ocamllex pkg))
                  (format #t "~A: ~A~%" (ugreen "pkg-ocamlyacc") (assoc-val :ocamlyacc pkg))
                  (format #t "~A: ~A~%" (ugreen "pkg-cc") (assoc-val :cc pkg))
                  (format #t "~A: ~A~%" (ugreen "pkg-ppx") (assoc-val :shared-ppx pkg))
                  (format #t "~A: ~A~%" (ugreen "pkg-files") (assoc-val :files pkg))
                  (if-let ((dune (assoc :dune pkg)))
                          (for-each (lambda (stanza)
                                      (format #t "~A: ~A~%" (ucyan "stanza") stanza))
                                    (cdr dune)))))
              (sort! (hash-table-keys pkgs) string<?))
    pkgs))


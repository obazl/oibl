;; module is from :modules or :structures
;; search pkg :prologues for it;
;; if found, find executable for prologue
;; derive ns from executable
(define (derive-exe-ns pkg module)
  (if (or *mibl-debug-prologues* *mibl-debug-s7*)
      (format #t "~A: ~A\n" (ublue "-derive-exe-ns") module))
  (let* ((prologues (assoc-in '(:mibl :prologues) pkg))
         (plog (find-if (lambda (prologue)
                          (format #t "testing plog: ~A\n" prologue)
                          (let ((p-modules (assoc-val :modules (cdr prologue))))
                            (member (car module) p-modules)))
                        (cdr prologues))))
    (if plog
        (let* ((serial (car plog))
               (_ (format #t "plog serial ~A\n" serial))
               (exe (find-then (lambda (stanza)
                               (case (car stanza)
                                 ((:executable)
                                  (format #t "checking exe stanza ~A\n" stanza)
                                  (let ((prologue-id (assoc-val :prologue (cdr stanza))))
                                    (if (equal? prologue-id serial)
                                        (assoc-val :main (cdr stanza))
                                        #f)))
                                  (else #f)))
                             (assoc-val :mibl pkg))))
          (format #t "exe: ~A\n" exe)
          (if exe
              (format #f "~S_ns" exe))))
    ))

(define (emit-prologue outp pkg serial)
  (if (or *mibl-debug-prologues* *mibl-debugging*)
      (format #t "~A: ~A~%" (ublue "emit-prologue") serial))
  (let* ((prologues (assoc-in '(:mibl :prologues) pkg))
         (this-prologue (assoc-val serial (cdr prologues)))
         (p-modules (assoc-val :modules this-prologue)))
    (format outp "ocaml_library(\n")
    (format outp "    name     = \"libPrologue_~A\",\n" serial)
    (format outp "    manifest = [\n")
    (format outp "~{        \":~A\"~^,~%~}\n" p-modules)
    (format outp "    ]\n")
    (format outp ")\n")
    (newline outp)))


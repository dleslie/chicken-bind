; *** This file starts with a copy of the file multilex.scm ***
; Copyright (C) 1997 Danny Dube', Universite' de Montre'al.
; All rights reserved.
; SILex 1.0.

;
; Gestion des Input Systems
; Fonctions a utiliser par l'usager:
;   lexer-make-IS, lexer-get-func-getc, lexer-get-func-ungetc,
;   lexer-get-func-line, lexer-get-func-column et lexer-get-func-offset
;

; Taille initiale par defaut du buffer d'entree
(define lexer-init-buffer-len 1024)

; Numero du caractere newline
(define lexer-integer-newline (char->integer #\newline))

; Constructeur d'IS brut
(define lexer-raw-IS-maker
  (lambda (buffer read-ptr input-f counters)
    (let ((input-f          input-f)                ; Entree reelle
	  (buffer           buffer)                 ; Buffer
	  (buflen           (string-length buffer))
	  (read-ptr         read-ptr)
	  (start-ptr        1)                      ; Marque de debut de lexeme
	  (start-line       1)
	  (start-column     1)
	  (start-offset     0)
	  (end-ptr          1)                      ; Marque de fin de lexeme
	  (point-ptr        1)                      ; Le point
	  (user-ptr         1)                      ; Marque de l'usager
	  (user-line        1)
	  (user-column      1)
	  (user-offset      0)
	  (user-up-to-date? #t))                    ; Concerne la colonne seul.
      (letrec
	  ((start-go-to-end-none         ; Fonctions de depl. des marques
	    (lambda ()
	      (set! start-ptr end-ptr)))
	   (start-go-to-end-line
	    (lambda ()
	      (let loop ((ptr start-ptr) (line start-line))
		(if (= ptr end-ptr)
		    (begin
		      (set! start-ptr ptr)
		      (set! start-line line))
		    (if (char=? (string-ref buffer ptr) #\newline)
			(loop (+ ptr 1) (+ line 1))
			(loop (+ ptr 1) line))))))
	   (start-go-to-end-all
	    (lambda ()
	      (set! start-offset (+ start-offset (- end-ptr start-ptr)))
	      (let loop ((ptr start-ptr)
			 (line start-line)
			 (column start-column))
		(if (= ptr end-ptr)
		    (begin
		      (set! start-ptr ptr)
		      (set! start-line line)
		      (set! start-column column))
		    (if (char=? (string-ref buffer ptr) #\newline)
			(loop (+ ptr 1) (+ line 1) 1)
			(loop (+ ptr 1) line (+ column 1)))))))
	   (start-go-to-user-none
	    (lambda ()
	      (set! start-ptr user-ptr)))
	   (start-go-to-user-line
	    (lambda ()
	      (set! start-ptr user-ptr)
	      (set! start-line user-line)))
	   (start-go-to-user-all
	    (lambda ()
	      (set! start-line user-line)
	      (set! start-offset user-offset)
	      (if user-up-to-date?
		  (begin
		    (set! start-ptr user-ptr)
		    (set! start-column user-column))
		  (let loop ((ptr start-ptr) (column start-column))
		    (if (= ptr user-ptr)
			(begin
			  (set! start-ptr ptr)
			  (set! start-column column))
			(if (char=? (string-ref buffer ptr) #\newline)
			    (loop (+ ptr 1) 1)
			    (loop (+ ptr 1) (+ column 1))))))))
	   (end-go-to-point
	    (lambda ()
	      (set! end-ptr point-ptr)))
	   (point-go-to-start
	    (lambda ()
	      (set! point-ptr start-ptr)))
	   (user-go-to-start-none
	    (lambda ()
	      (set! user-ptr start-ptr)))
	   (user-go-to-start-line
	    (lambda ()
	      (set! user-ptr start-ptr)
	      (set! user-line start-line)))
	   (user-go-to-start-all
	    (lambda ()
	      (set! user-ptr start-ptr)
	      (set! user-line start-line)
	      (set! user-column start-column)
	      (set! user-offset start-offset)
	      (set! user-up-to-date? #t)))
	   (init-lexeme-none             ; Debute un nouveau lexeme
	    (lambda ()
	      (if (< start-ptr user-ptr)
		  (start-go-to-user-none))
	      (point-go-to-start)))
	   (init-lexeme-line
	    (lambda ()
	      (if (< start-ptr user-ptr)
		  (start-go-to-user-line))
	      (point-go-to-start)))
	   (init-lexeme-all
	    (lambda ()
	      (if (< start-ptr user-ptr)
		  (start-go-to-user-all))
	      (point-go-to-start)))
	   (get-start-line               ; Obtention des stats du debut du lxm
	    (lambda ()
	      start-line))
	   (get-start-column
	    (lambda ()
	      start-column))
	   (get-start-offset
	    (lambda ()
	      start-offset))
	   (peek-left-context            ; Obtention de caracteres (#f si EOF)
	    (lambda ()
	      (char->integer (string-ref buffer (- start-ptr 1)))))
	   (peek-char
	    (lambda ()
	      (if (< point-ptr read-ptr)
		  (char->integer (string-ref buffer point-ptr))
		  (let ((c (input-f)))
		    (if (char? c)
			(begin
			  (if (= read-ptr buflen)
			      (reorganize-buffer))
			  (string-set! buffer point-ptr c)
			  (set! read-ptr (+ point-ptr 1))
			  (char->integer c))
			(begin
			  (set! input-f (lambda () 'eof))
			  #f))))))
	   (read-char
	    (lambda ()
	      (if (< point-ptr read-ptr)
		  (let ((c (string-ref buffer point-ptr)))
		    (set! point-ptr (+ point-ptr 1))
		    (char->integer c))
		  (let ((c (input-f)))
		    (if (char? c)
			(begin
			  (if (= read-ptr buflen)
			      (reorganize-buffer))
			  (string-set! buffer point-ptr c)
			  (set! read-ptr (+ point-ptr 1))
			  (set! point-ptr read-ptr)
			  (char->integer c))
			(begin
			  (set! input-f (lambda () 'eof))
			  #f))))))
	   (get-start-end-text           ; Obtention du lexeme
	    (lambda ()
	      (substring buffer start-ptr end-ptr)))
	   (get-user-line-line           ; Fonctions pour l'usager
	    (lambda ()
	      (if (< user-ptr start-ptr)
		  (user-go-to-start-line))
	      user-line))
	   (get-user-line-all
	    (lambda ()
	      (if (< user-ptr start-ptr)
		  (user-go-to-start-all))
	      user-line))
	   (get-user-column-all
	    (lambda ()
	      (cond ((< user-ptr start-ptr)
		     (user-go-to-start-all)
		     user-column)
		    (user-up-to-date?
		     user-column)
		    (else
		     (let loop ((ptr start-ptr) (column start-column))
		       (if (= ptr user-ptr)
			   (begin
			     (set! user-column column)
			     (set! user-up-to-date? #t)
			     column)
			   (if (char=? (string-ref buffer ptr) #\newline)
			       (loop (+ ptr 1) 1)
			       (loop (+ ptr 1) (+ column 1)))))))))
	   (get-user-offset-all
	    (lambda ()
	      (if (< user-ptr start-ptr)
		  (user-go-to-start-all))
	      user-offset))
	   (user-getc-none
	    (lambda ()
	      (if (< user-ptr start-ptr)
		  (user-go-to-start-none))
	      (if (< user-ptr read-ptr)
		  (let ((c (string-ref buffer user-ptr)))
		    (set! user-ptr (+ user-ptr 1))
		    c)
		  (let ((c (input-f)))
		    (if (char? c)
			(begin
			  (if (= read-ptr buflen)
			      (reorganize-buffer))
			  (string-set! buffer user-ptr c)
			  (set! read-ptr (+ read-ptr 1))
			  (set! user-ptr read-ptr)
			  c)
			(begin
			  (set! input-f (lambda () 'eof))
			  'eof))))))
	   (user-getc-line
	    (lambda ()
	      (if (< user-ptr start-ptr)
		  (user-go-to-start-line))
	      (if (< user-ptr read-ptr)
		  (let ((c (string-ref buffer user-ptr)))
		    (set! user-ptr (+ user-ptr 1))
		    (if (char=? c #\newline)
			(set! user-line (+ user-line 1)))
		    c)
		  (let ((c (input-f)))
		    (if (char? c)
			(begin
			  (if (= read-ptr buflen)
			      (reorganize-buffer))
			  (string-set! buffer user-ptr c)
			  (set! read-ptr (+ read-ptr 1))
			  (set! user-ptr read-ptr)
			  (if (char=? c #\newline)
			      (set! user-line (+ user-line 1)))
			  c)
			(begin
			  (set! input-f (lambda () 'eof))
			  'eof))))))
	   (user-getc-all
	    (lambda ()
	      (if (< user-ptr start-ptr)
		  (user-go-to-start-all))
	      (if (< user-ptr read-ptr)
		  (let ((c (string-ref buffer user-ptr)))
		    (set! user-ptr (+ user-ptr 1))
		    (if (char=? c #\newline)
			(begin
			  (set! user-line (+ user-line 1))
			  (set! user-column 1))
			(set! user-column (+ user-column 1)))
		    (set! user-offset (+ user-offset 1))
		    c)
		  (let ((c (input-f)))
		    (if (char? c)
			(begin
			  (if (= read-ptr buflen)
			      (reorganize-buffer))
			  (string-set! buffer user-ptr c)
			  (set! read-ptr (+ read-ptr 1))
			  (set! user-ptr read-ptr)
			  (if (char=? c #\newline)
			      (begin
				(set! user-line (+ user-line 1))
				(set! user-column 1))
			      (set! user-column (+ user-column 1)))
			  (set! user-offset (+ user-offset 1))
			  c)
			(begin
			  (set! input-f (lambda () 'eof))
			  'eof))))))
	   (user-ungetc-none
	    (lambda ()
	      (if (> user-ptr start-ptr)
		  (set! user-ptr (- user-ptr 1)))))
	   (user-ungetc-line
	    (lambda ()
	      (if (> user-ptr start-ptr)
		  (begin
		    (set! user-ptr (- user-ptr 1))
		    (let ((c (string-ref buffer user-ptr)))
		      (if (char=? c #\newline)
			  (set! user-line (- user-line 1))))))))
	   (user-ungetc-all
	    (lambda ()
	      (if (> user-ptr start-ptr)
		  (begin
		    (set! user-ptr (- user-ptr 1))
		    (let ((c (string-ref buffer user-ptr)))
		      (if (char=? c #\newline)
			  (begin
			    (set! user-line (- user-line 1))
			    (set! user-up-to-date? #f))
			  (set! user-column (- user-column 1)))
		      (set! user-offset (- user-offset 1)))))))
	   (reorganize-buffer            ; Decaler ou agrandir le buffer
	    (lambda ()
	      (if (< (* 2 start-ptr) buflen)
		  (let* ((newlen (* 2 buflen))
			 (newbuf (make-string newlen))
			 (delta (- start-ptr 1)))
		    (let loop ((from (- start-ptr 1)))
		      (if (< from buflen)
			  (begin
			    (string-set! newbuf
					 (- from delta)
					 (string-ref buffer from))
			    (loop (+ from 1)))))
		    (set! buffer    newbuf)
		    (set! buflen    newlen)
		    (set! read-ptr  (- read-ptr delta))
		    (set! start-ptr (- start-ptr delta))
		    (set! end-ptr   (- end-ptr delta))
		    (set! point-ptr (- point-ptr delta))
		    (set! user-ptr  (- user-ptr delta)))
		  (let ((delta (- start-ptr 1)))
		    (let loop ((from (- start-ptr 1)))
		      (if (< from buflen)
			  (begin
			    (string-set! buffer
					 (- from delta)
					 (string-ref buffer from))
			    (loop (+ from 1)))))
		    (set! read-ptr  (- read-ptr delta))
		    (set! start-ptr (- start-ptr delta))
		    (set! end-ptr   (- end-ptr delta))
		    (set! point-ptr (- point-ptr delta))
		    (set! user-ptr  (- user-ptr delta)))))))
	(list (cons 'start-go-to-end
		    (cond ((eq? counters 'none) start-go-to-end-none)
			  ((eq? counters 'line) start-go-to-end-line)
			  ((eq? counters 'all ) start-go-to-end-all)))
	      (cons 'end-go-to-point
		    end-go-to-point)
	      (cons 'init-lexeme
		    (cond ((eq? counters 'none) init-lexeme-none)
			  ((eq? counters 'line) init-lexeme-line)
			  ((eq? counters 'all ) init-lexeme-all)))
	      (cons 'get-start-line
		    get-start-line)
	      (cons 'get-start-column
		    get-start-column)
	      (cons 'get-start-offset
		    get-start-offset)
	      (cons 'peek-left-context
		    peek-left-context)
	      (cons 'peek-char
		    peek-char)
	      (cons 'read-char
		    read-char)
	      (cons 'get-start-end-text
		    get-start-end-text)
	      (cons 'get-user-line
		    (cond ((eq? counters 'none) #f)
			  ((eq? counters 'line) get-user-line-line)
			  ((eq? counters 'all ) get-user-line-all)))
	      (cons 'get-user-column
		    (cond ((eq? counters 'none) #f)
			  ((eq? counters 'line) #f)
			  ((eq? counters 'all ) get-user-column-all)))
	      (cons 'get-user-offset
		    (cond ((eq? counters 'none) #f)
			  ((eq? counters 'line) #f)
			  ((eq? counters 'all ) get-user-offset-all)))
	      (cons 'user-getc
		    (cond ((eq? counters 'none) user-getc-none)
			  ((eq? counters 'line) user-getc-line)
			  ((eq? counters 'all ) user-getc-all)))
	      (cons 'user-ungetc
		    (cond ((eq? counters 'none) user-ungetc-none)
			  ((eq? counters 'line) user-ungetc-line)
			  ((eq? counters 'all ) user-ungetc-all))))))))

; Construit un Input System
; Le premier parametre doit etre parmi "port", "procedure" ou "string"
; Prend un parametre facultatif qui doit etre parmi
; "none", "line" ou "all"
(define lexer-make-IS
  (lambda (input-type input . largs)
    (let ((counters-type (cond ((null? largs)
				'line)
			       ((memq (car largs) '(none line all))
				(car largs))
			       (else
				'line))))
      (cond ((and (eq? input-type 'port) (input-port? input))
	     (let* ((buffer   (make-string lexer-init-buffer-len #\newline))
		    (read-ptr 1)
		    (input-f  (lambda () (read-char input))))
	       (lexer-raw-IS-maker buffer read-ptr input-f counters-type)))
	    ((and (eq? input-type 'procedure) (procedure? input))
	     (let* ((buffer   (make-string lexer-init-buffer-len #\newline))
		    (read-ptr 1)
		    (input-f  input))
	       (lexer-raw-IS-maker buffer read-ptr input-f counters-type)))
	    ((and (eq? input-type 'string) (string? input))
	     (let* ((buffer   (string-append (string #\newline) input))
		    (read-ptr (string-length buffer))
		    (input-f  (lambda () 'eof)))
	       (lexer-raw-IS-maker buffer read-ptr input-f counters-type)))
	    (else
	     (let* ((buffer   (string #\newline))
		    (read-ptr 1)
		    (input-f  (lambda () 'eof)))
	       (lexer-raw-IS-maker buffer read-ptr input-f counters-type)))))))

; Les fonctions:
;   lexer-get-func-getc, lexer-get-func-ungetc,
;   lexer-get-func-line, lexer-get-func-column et lexer-get-func-offset
(define lexer-get-func-getc
  (lambda (IS) (cdr (assq 'user-getc IS))))
(define lexer-get-func-ungetc
  (lambda (IS) (cdr (assq 'user-ungetc IS))))
(define lexer-get-func-line
  (lambda (IS) (cdr (assq 'get-user-line IS))))
(define lexer-get-func-column
  (lambda (IS) (cdr (assq 'get-user-column IS))))
(define lexer-get-func-offset
  (lambda (IS) (cdr (assq 'get-user-offset IS))))

;
; Gestion des lexers
;

; Fabrication de lexer a partir d'arbres de decision
(define lexer-make-tree-lexer
  (lambda (tables IS)
    (letrec
	(; Contenu de la table
	 (counters-type        (vector-ref tables 0))
	 (<<EOF>>-pre-action   (vector-ref tables 1))
	 (<<ERROR>>-pre-action (vector-ref tables 2))
	 (rules-pre-actions    (vector-ref tables 3))
	 (table-nl-start       (vector-ref tables 5))
	 (table-no-nl-start    (vector-ref tables 6))
	 (trees-v              (vector-ref tables 7))
	 (acc-v                (vector-ref tables 8))

	 ; Contenu du IS
	 (IS-start-go-to-end    (cdr (assq 'start-go-to-end IS)))
	 (IS-end-go-to-point    (cdr (assq 'end-go-to-point IS)))
	 (IS-init-lexeme        (cdr (assq 'init-lexeme IS)))
	 (IS-get-start-line     (cdr (assq 'get-start-line IS)))
	 (IS-get-start-column   (cdr (assq 'get-start-column IS)))
	 (IS-get-start-offset   (cdr (assq 'get-start-offset IS)))
	 (IS-peek-left-context  (cdr (assq 'peek-left-context IS)))
	 (IS-peek-char          (cdr (assq 'peek-char IS)))
	 (IS-read-char          (cdr (assq 'read-char IS)))
	 (IS-get-start-end-text (cdr (assq 'get-start-end-text IS)))
	 (IS-get-user-line      (cdr (assq 'get-user-line IS)))
	 (IS-get-user-column    (cdr (assq 'get-user-column IS)))
	 (IS-get-user-offset    (cdr (assq 'get-user-offset IS)))
	 (IS-user-getc          (cdr (assq 'user-getc IS)))
	 (IS-user-ungetc        (cdr (assq 'user-ungetc IS)))

	 ; Resultats
	 (<<EOF>>-action   #f)
	 (<<ERROR>>-action #f)
	 (rules-actions    #f)
	 (states           #f)
	 (final-lexer      #f)

	 ; Gestion des hooks
	 (hook-list '())
	 (add-hook
	  (lambda (thunk)
	    (set! hook-list (cons thunk hook-list))))
	 (apply-hooks
	  (lambda ()
	    (let loop ((l hook-list))
	      (if (pair? l)
		  (begin
		    ((car l))
		    (loop (cdr l)))))))

	 ; Preparation des actions
	 (set-action-statics
	  (lambda (pre-action)
	    (pre-action final-lexer IS-user-getc IS-user-ungetc)))
	 (prepare-special-action-none
	  (lambda (pre-action)
	    (let ((action #f))
	      (let ((result
		     (lambda ()
		       (action "")))
		    (hook
		     (lambda ()
		       (set! action (set-action-statics pre-action)))))
		(add-hook hook)
		result))))
	 (prepare-special-action-line
	  (lambda (pre-action)
	    (let ((action #f))
	      (let ((result
		     (lambda (yyline)
		       (action "" yyline)))
		    (hook
		     (lambda ()
		       (set! action (set-action-statics pre-action)))))
		(add-hook hook)
		result))))
	 (prepare-special-action-all
	  (lambda (pre-action)
	    (let ((action #f))
	      (let ((result
		     (lambda (yyline yycolumn yyoffset)
		       (action "" yyline yycolumn yyoffset)))
		    (hook
		     (lambda ()
		       (set! action (set-action-statics pre-action)))))
		(add-hook hook)
		result))))
	 (prepare-special-action
	  (lambda (pre-action)
	    (cond ((eq? counters-type 'none)
		   (prepare-special-action-none pre-action))
		  ((eq? counters-type 'line)
		   (prepare-special-action-line pre-action))
		  ((eq? counters-type 'all)
		   (prepare-special-action-all  pre-action)))))
	 (prepare-action-yytext-none
	  (lambda (pre-action)
	    (let ((get-start-end-text IS-get-start-end-text)
		  (start-go-to-end    IS-start-go-to-end)
		  (action             #f))
	      (let ((result
		     (lambda ()
		       (let ((yytext (get-start-end-text)))
			 (start-go-to-end)
			 (action yytext))))
		    (hook
		     (lambda ()
		       (set! action (set-action-statics pre-action)))))
		(add-hook hook)
		result))))
	 (prepare-action-yytext-line
	  (lambda (pre-action)
	    (let ((get-start-end-text IS-get-start-end-text)
		  (start-go-to-end    IS-start-go-to-end)
		  (action             #f))
	      (let ((result
		     (lambda (yyline)
		       (let ((yytext (get-start-end-text)))
			 (start-go-to-end)
			 (action yytext yyline))))
		    (hook
		     (lambda ()
		       (set! action (set-action-statics pre-action)))))
		(add-hook hook)
		result))))
	 (prepare-action-yytext-all
	  (lambda (pre-action)
	    (let ((get-start-end-text IS-get-start-end-text)
		  (start-go-to-end    IS-start-go-to-end)
		  (action             #f))
	      (let ((result
		     (lambda (yyline yycolumn yyoffset)
		       (let ((yytext (get-start-end-text)))
			 (start-go-to-end)
			 (action yytext yyline yycolumn yyoffset))))
		    (hook
		     (lambda ()
		       (set! action (set-action-statics pre-action)))))
		(add-hook hook)
		result))))
	 (prepare-action-yytext
	  (lambda (pre-action)
	    (cond ((eq? counters-type 'none)
		   (prepare-action-yytext-none pre-action))
		  ((eq? counters-type 'line)
		   (prepare-action-yytext-line pre-action))
		  ((eq? counters-type 'all)
		   (prepare-action-yytext-all  pre-action)))))
	 (prepare-action-no-yytext-none
	  (lambda (pre-action)
	    (let ((start-go-to-end    IS-start-go-to-end)
		  (action             #f))
	      (let ((result
		     (lambda ()
		       (start-go-to-end)
		       (action)))
		    (hook
		     (lambda ()
		       (set! action (set-action-statics pre-action)))))
		(add-hook hook)
		result))))
	 (prepare-action-no-yytext-line
	  (lambda (pre-action)
	    (let ((start-go-to-end    IS-start-go-to-end)
		  (action             #f))
	      (let ((result
		     (lambda (yyline)
		       (start-go-to-end)
		       (action yyline)))
		    (hook
		     (lambda ()
		       (set! action (set-action-statics pre-action)))))
		(add-hook hook)
		result))))
	 (prepare-action-no-yytext-all
	  (lambda (pre-action)
	    (let ((start-go-to-end    IS-start-go-to-end)
		  (action             #f))
	      (let ((result
		     (lambda (yyline yycolumn yyoffset)
		       (start-go-to-end)
		       (action yyline yycolumn yyoffset)))
		    (hook
		     (lambda ()
		       (set! action (set-action-statics pre-action)))))
		(add-hook hook)
		result))))
	 (prepare-action-no-yytext
	  (lambda (pre-action)
	    (cond ((eq? counters-type 'none)
		   (prepare-action-no-yytext-none pre-action))
		  ((eq? counters-type 'line)
		   (prepare-action-no-yytext-line pre-action))
		  ((eq? counters-type 'all)
		   (prepare-action-no-yytext-all  pre-action)))))

	 ; Fabrique les fonctions de dispatch
	 (prepare-dispatch-err
	  (lambda (leaf)
	    (lambda (c)
	      #f)))
	 (prepare-dispatch-number
	  (lambda (leaf)
	    (let ((state-function #f))
	      (let ((result
		     (lambda (c)
		       state-function))
		    (hook
		     (lambda ()
		       (set! state-function (vector-ref states leaf)))))
		(add-hook hook)
		result))))
	 (prepare-dispatch-leaf
	  (lambda (leaf)
	    (if (eq? leaf 'err)
		(prepare-dispatch-err leaf)
		(prepare-dispatch-number leaf))))
	 (prepare-dispatch-<
	  (lambda (tree)
	    (let ((left-tree  (list-ref tree 1))
		  (right-tree (list-ref tree 2)))
	      (let ((bound      (list-ref tree 0))
		    (left-func  (prepare-dispatch-tree left-tree))
		    (right-func (prepare-dispatch-tree right-tree)))
		(lambda (c)
		  (if (< c bound)
		      (left-func c)
		      (right-func c)))))))
	 (prepare-dispatch-=
	  (lambda (tree)
	    (let ((left-tree  (list-ref tree 2))
		  (right-tree (list-ref tree 3)))
	      (let ((bound      (list-ref tree 1))
		    (left-func  (prepare-dispatch-tree left-tree))
		    (right-func (prepare-dispatch-tree right-tree)))
		(lambda (c)
		  (if (= c bound)
		      (left-func c)
		      (right-func c)))))))
	 (prepare-dispatch-tree
	  (lambda (tree)
	    (cond ((not (pair? tree))
		   (prepare-dispatch-leaf tree))
		  ((eq? (car tree) '=)
		   (prepare-dispatch-= tree))
		  (else
		   (prepare-dispatch-< tree)))))
	 (prepare-dispatch
	  (lambda (tree)
	    (let ((dicho-func (prepare-dispatch-tree tree)))
	      (lambda (c)
		(and c (dicho-func c))))))

	 ; Fabrique les fonctions de transition (read & go) et (abort)
	 (prepare-read-n-go
	  (lambda (tree)
	    (let ((dispatch-func (prepare-dispatch tree))
		  (read-char     IS-read-char))
	      (lambda ()
		(dispatch-func (read-char))))))
	 (prepare-abort
	  (lambda (tree)
	    (lambda ()
	      #f)))
	 (prepare-transition
	  (lambda (tree)
	    (if (eq? tree 'err)
		(prepare-abort     tree)
		(prepare-read-n-go tree))))

	 ; Fabrique les fonctions d'etats ([set-end] & trans)
	 (prepare-state-no-acc
	   (lambda (s r1 r2)
	     (let ((trans-func (prepare-transition (vector-ref trees-v s))))
	       (lambda (action)
		 (let ((next-state (trans-func)))
		   (if next-state
		       (next-state action)
		       action))))))
	 (prepare-state-yes-no
	  (lambda (s r1 r2)
	    (let ((peek-char       IS-peek-char)
		  (end-go-to-point IS-end-go-to-point)
		  (new-action1     #f)
		  (trans-func (prepare-transition (vector-ref trees-v s))))
	      (let ((result
		     (lambda (action)
		       (let* ((c (peek-char))
			      (new-action
			       (if (or (not c) (= c lexer-integer-newline))
				   (begin
				     (end-go-to-point)
				     new-action1)
				   action))
			      (next-state (trans-func)))
			 (if next-state
			     (next-state new-action)
			     new-action))))
		    (hook
		     (lambda ()
		       (set! new-action1 (vector-ref rules-actions r1)))))
		(add-hook hook)
		result))))
	 (prepare-state-diff-acc
	  (lambda (s r1 r2)
	    (let ((end-go-to-point IS-end-go-to-point)
		  (peek-char       IS-peek-char)
		  (new-action1     #f)
		  (new-action2     #f)
		  (trans-func (prepare-transition (vector-ref trees-v s))))
	      (let ((result
		     (lambda (action)
		       (end-go-to-point)
		       (let* ((c (peek-char))
			      (new-action
			       (if (or (not c) (= c lexer-integer-newline))
				   new-action1
				   new-action2))
			      (next-state (trans-func)))
			 (if next-state
			     (next-state new-action)
			     new-action))))
		    (hook
		     (lambda ()
		       (set! new-action1 (vector-ref rules-actions r1))
		       (set! new-action2 (vector-ref rules-actions r2)))))
		(add-hook hook)
		result))))
	 (prepare-state-same-acc
	  (lambda (s r1 r2)
	    (let ((end-go-to-point IS-end-go-to-point)
		  (trans-func (prepare-transition (vector-ref trees-v s)))
		  (new-action #f))
	      (let ((result
		     (lambda (action)
		       (end-go-to-point)
		       (let ((next-state (trans-func)))
			 (if next-state
			     (next-state new-action)
			     new-action))))
		    (hook
		     (lambda ()
		       (set! new-action (vector-ref rules-actions r1)))))
		(add-hook hook)
		result))))
	 (prepare-state
	  (lambda (s)
	    (let* ((acc (vector-ref acc-v s))
		   (r1 (car acc))
		   (r2 (cdr acc)))
	      (cond ((not r1)  (prepare-state-no-acc   s r1 r2))
		    ((not r2)  (prepare-state-yes-no   s r1 r2))
		    ((< r1 r2) (prepare-state-diff-acc s r1 r2))
		    (else      (prepare-state-same-acc s r1 r2))))))

	 ; Fabrique la fonction de lancement du lexage a l'etat de depart
	 (prepare-start-same
	  (lambda (s1 s2)
	    (let ((peek-char    IS-peek-char)
		  (eof-action   #f)
		  (start-state  #f)
		  (error-action #f))
	      (let ((result
		     (lambda ()
		       (if (not (peek-char))
			   eof-action
			   (start-state error-action))))
		    (hook
		     (lambda ()
		       (set! eof-action   <<EOF>>-action)
		       (set! start-state  (vector-ref states s1))
		       (set! error-action <<ERROR>>-action))))
		(add-hook hook)
		result))))
	 (prepare-start-diff
	  (lambda (s1 s2)
	    (let ((peek-char         IS-peek-char)
		  (eof-action        #f)
		  (peek-left-context IS-peek-left-context)
		  (start-state1      #f)
		  (start-state2      #f)
		  (error-action      #f))
	      (let ((result
		     (lambda ()
		       (cond ((not (peek-char))
			      eof-action)
			     ((= (peek-left-context) lexer-integer-newline)
			      (start-state1 error-action))
			     (else
			      (start-state2 error-action)))))
		    (hook
		     (lambda ()
		       (set! eof-action <<EOF>>-action)
		       (set! start-state1 (vector-ref states s1))
		       (set! start-state2 (vector-ref states s2))
		       (set! error-action <<ERROR>>-action))))
		(add-hook hook)
		result))))
	 (prepare-start
	  (lambda ()
	    (let ((s1 table-nl-start)
		  (s2 table-no-nl-start))
	      (if (= s1 s2)
		  (prepare-start-same s1 s2)
		  (prepare-start-diff s1 s2)))))

	 ; Fabrique la fonction principale
	 (prepare-lexer-none
	  (lambda ()
	    (let ((init-lexeme IS-init-lexeme)
		  (start-func  (prepare-start)))
	      (lambda ()
		(init-lexeme)
		((start-func))))))
	 (prepare-lexer-line
	  (lambda ()
	    (let ((init-lexeme    IS-init-lexeme)
		  (get-start-line IS-get-start-line)
		  (start-func     (prepare-start)))
	      (lambda ()
		(init-lexeme)
		(let ((yyline (get-start-line)))
		  ((start-func) yyline))))))
	 (prepare-lexer-all
	  (lambda ()
	    (let ((init-lexeme      IS-init-lexeme)
		  (get-start-line   IS-get-start-line)
		  (get-start-column IS-get-start-column)
		  (get-start-offset IS-get-start-offset)
		  (start-func       (prepare-start)))
	      (lambda ()
		(init-lexeme)
		(let ((yyline   (get-start-line))
		      (yycolumn (get-start-column))
		      (yyoffset (get-start-offset)))
		  ((start-func) yyline yycolumn yyoffset))))))
	 (prepare-lexer
	  (lambda ()
	    (cond ((eq? counters-type 'none) (prepare-lexer-none))
		  ((eq? counters-type 'line) (prepare-lexer-line))
		  ((eq? counters-type 'all)  (prepare-lexer-all))))))

      ; Calculer la valeur de <<EOF>>-action et de <<ERROR>>-action
      (set! <<EOF>>-action   (prepare-special-action <<EOF>>-pre-action))
      (set! <<ERROR>>-action (prepare-special-action <<ERROR>>-pre-action))

      ; Calculer la valeur de rules-actions
      (let* ((len (quotient (vector-length rules-pre-actions) 2))
	     (v (make-vector len)))
	(let loop ((r (- len 1)))
	  (if (< r 0)
	      (set! rules-actions v)
	      (let* ((yytext? (vector-ref rules-pre-actions (* 2 r)))
		     (pre-action (vector-ref rules-pre-actions (+ (* 2 r) 1)))
		     (action (if yytext?
				 (prepare-action-yytext    pre-action)
				 (prepare-action-no-yytext pre-action))))
		(vector-set! v r action)
		(loop (- r 1))))))

      ; Calculer la valeur de states
      (let* ((len (vector-length trees-v))
	     (v (make-vector len)))
	(let loop ((s (- len 1)))
	  (if (< s 0)
	      (set! states v)
	      (begin
		(vector-set! v s (prepare-state s))
		(loop (- s 1))))))

      ; Calculer la valeur de final-lexer
      (set! final-lexer (prepare-lexer))

      ; Executer les hooks
      (apply-hooks)

      ; Resultat
      final-lexer)))

; Fabrication de lexer a partir de listes de caracteres taggees
(define lexer-make-char-lexer
  (let* ((char->class
	  (lambda (c)
	    (let ((n (char->integer c)))
	      (list (cons n n)))))
	 (merge-sort
	  (lambda (l combine zero-elt)
	    (if (null? l)
		zero-elt
		(let loop1 ((l l))
		  (if (null? (cdr l))
		      (car l)
		      (loop1
		       (let loop2 ((l l))
			 (cond ((null? l)
				l)
			       ((null? (cdr l))
				l)
			       (else
				(cons (combine (car l) (cadr l))
				      (loop2 (cddr l))))))))))))
	 (finite-class-union
	  (lambda (c1 c2)
	    (let loop ((c1 c1) (c2 c2) (u '()))
	      (if (null? c1)
		  (if (null? c2)
		      (reverse u)
		      (loop c1 (cdr c2) (cons (car c2) u)))
		  (if (null? c2)
		      (loop (cdr c1) c2 (cons (car c1) u))
		      (let* ((r1 (car c1))
			     (r2 (car c2))
			     (r1start (car r1))
			     (r1end (cdr r1))
			     (r2start (car r2))
			     (r2end (cdr r2)))
			(if (<= r1start r2start)
			    (cond ((< (+ r1end 1) r2start)
				   (loop (cdr c1) c2 (cons r1 u)))
				  ((<= r1end r2end)
				   (loop (cdr c1)
					 (cons (cons r1start r2end) (cdr c2))
					 u))
				  (else
				   (loop c1 (cdr c2) u)))
			    (cond ((> r1start (+ r2end 1))
				   (loop c1 (cdr c2) (cons r2 u)))
				  ((>= r1end r2end)
				   (loop (cons (cons r2start r1end) (cdr c1))
					 (cdr c2)
					 u))
				  (else
				   (loop (cdr c1) c2 u))))))))))
	 (char-list->class
	  (lambda (cl)
	    (let ((classes (map char->class cl)))
	      (merge-sort classes finite-class-union '()))))
	 (class-<
	  (lambda (b1 b2)
	    (cond ((eq? b1 'inf+) #f)
		  ((eq? b2 'inf-) #f)
		  ((eq? b1 'inf-) #t)
		  ((eq? b2 'inf+) #t)
		  (else (< b1 b2)))))
	 (finite-class-compl
	  (lambda (c)
	    (let loop ((c c) (start 'inf-))
	      (if (null? c)
		  (list (cons start 'inf+))
		  (let* ((r (car c))
			 (rstart (car r))
			 (rend (cdr r)))
		    (if (class-< start rstart)
			(cons (cons start (- rstart 1))
			      (loop c rstart))
			(loop (cdr c) (+ rend 1))))))))
	 (tagged-chars->class
	  (lambda (tcl)
	    (let* ((inverse? (car tcl))
		   (cl (cdr tcl))
		   (class-tmp (char-list->class cl)))
	      (if inverse? (finite-class-compl class-tmp) class-tmp))))
	 (charc->arc
	  (lambda (charc)
	    (let* ((tcl (car charc))
		   (dest (cdr charc))
		   (class (tagged-chars->class tcl)))
	      (cons class dest))))
	 (arc->sharcs
	  (lambda (arc)
	    (let* ((range-l (car arc))
		   (dest (cdr arc))
		   (op (lambda (range) (cons range dest))))
	      (map op range-l))))
	 (class-<=
	  (lambda (b1 b2)
	    (cond ((eq? b1 'inf-) #t)
		  ((eq? b2 'inf+) #t)
		  ((eq? b1 'inf+) #f)
		  ((eq? b2 'inf-) #f)
		  (else (<= b1 b2)))))
	 (sharc-<=
	  (lambda (sharc1 sharc2)
	    (class-<= (caar sharc1) (caar sharc2))))
	 (merge-sharcs
	  (lambda (l1 l2)
	    (let loop ((l1 l1) (l2 l2))
	      (cond ((null? l1)
		     l2)
		    ((null? l2)
		     l1)
		    (else
		     (let ((sharc1 (car l1))
			   (sharc2 (car l2)))
		       (if (sharc-<= sharc1 sharc2)
			   (cons sharc1 (loop (cdr l1) l2))
			   (cons sharc2 (loop l1 (cdr l2))))))))))
	 (class-= eqv?)
	 (fill-error
	  (lambda (sharcs)
	    (let loop ((sharcs sharcs) (start 'inf-))
	      (cond ((class-= start 'inf+)
		     '())
		    ((null? sharcs)
		     (cons (cons (cons start 'inf+) 'err)
			   (loop sharcs 'inf+)))
		    (else
		     (let* ((sharc (car sharcs))
			    (h (caar sharc))
			    (t (cdar sharc)))
		       (if (class-< start h)
			   (cons (cons (cons start (- h 1)) 'err)
				 (loop sharcs h))
			   (cons sharc (loop (cdr sharcs)
					     (if (class-= t 'inf+)
						 'inf+
						 (+ t 1)))))))))))
	 (charcs->tree
	  (lambda (charcs)
	    (let* ((op (lambda (charc) (arc->sharcs (charc->arc charc))))
		   (sharcs-l (map op charcs))
		   (sorted-sharcs (merge-sort sharcs-l merge-sharcs '()))
		   (full-sharcs (fill-error sorted-sharcs))
		   (op (lambda (sharc) (cons (caar sharc) (cdr sharc))))
		   (table (list->vector (map op full-sharcs))))
	      (let loop ((left 0) (right (- (vector-length table) 1)))
		(if (= left right)
		    (cdr (vector-ref table left))
		    (let ((mid (quotient (+ left right 1) 2)))
		      (if (and (= (+ left 2) right)
			       (= (+ (car (vector-ref table mid)) 1)
				  (car (vector-ref table right)))
			       (eqv? (cdr (vector-ref table left))
				     (cdr (vector-ref table right))))
			  (list '=
				(car (vector-ref table mid))
				(cdr (vector-ref table mid))
				(cdr (vector-ref table left)))
			  (list (car (vector-ref table mid))
				(loop left (- mid 1))
				(loop mid right))))))))))
    (lambda (tables IS)
      (let ((counters         (vector-ref tables 0))
	    (<<EOF>>-action   (vector-ref tables 1))
	    (<<ERROR>>-action (vector-ref tables 2))
	    (rules-actions    (vector-ref tables 3))
	    (nl-start         (vector-ref tables 5))
	    (no-nl-start      (vector-ref tables 6))
	    (charcs-v         (vector-ref tables 7))
	    (acc-v            (vector-ref tables 8)))
	(let* ((len (vector-length charcs-v))
	       (v (make-vector len)))
	  (let loop ((i (- len 1)))
	    (if (>= i 0)
		(begin
		  (vector-set! v i (charcs->tree (vector-ref charcs-v i)))
		  (loop (- i 1)))
		(lexer-make-tree-lexer
		 (vector counters
			 <<EOF>>-action
			 <<ERROR>>-action
			 rules-actions
			 'decision-trees
			 nl-start
			 no-nl-start
			 v
			 acc-v)
		 IS))))))))

; Fabrication d'un lexer a partir de code pre-genere
(define lexer-make-code-lexer
  (lambda (tables IS)
    (let ((<<EOF>>-pre-action   (vector-ref tables 1))
	  (<<ERROR>>-pre-action (vector-ref tables 2))
	  (rules-pre-action     (vector-ref tables 3))
	  (code                 (vector-ref tables 5)))
      (code <<EOF>>-pre-action <<ERROR>>-pre-action rules-pre-action IS))))

(define lexer-make-lexer
  (lambda (tables IS)
    (let ((automaton-type (vector-ref tables 4)))
      (cond ((eq? automaton-type 'decision-trees)
	     (lexer-make-tree-lexer tables IS))
	    ((eq? automaton-type 'tagged-chars-lists)
	     (lexer-make-char-lexer tables IS))
	    ((eq? automaton-type 'code)
	     (lexer-make-code-lexer tables IS))))))

;
; Table generated from the file c.l by SILex 1.0
;

(define lexer-default-table
  (vector
   'line
   (lambda (yycontinue yygetc yyungetc)
     (lambda (yytext yyline)
                                   (begin (set! pp-mode #f) (tok 'stop))
       ))
   (lambda (yycontinue yygetc yyungetc)
     (lambda (yytext yyline)
                                   (lexer-error (yygetc))
       ))
   (vector
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (yycontinue)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
         	                   (if pp-mode
				       (begin 
					 (set! pp-mode #f) (tok 'pp-end))
				       (yycontinue) )
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (yycontinue)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (yycontinue)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (yycontinue)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (yycontinue)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (let loop ()
				     (let ([c (yygetc)])
				       (if (or (eq? 'eof c) (char=? #\newline c))
					   (begin
					     (if pp-mode
						 (begin
						   (set! pp-mode #f)
						   (tok 'pp-end))
						 (yycontinue) ) )
					   (loop) ) ) )
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (let loop ([c (yygetc)])
				     (cond [(eq? 'eof c) (parsing-error "unexpected end of comment")]
					   [(char=? #\newline c) (loop (yygetc))]
					   [(char=? c #\*)
					    (let ([c2 (yygetc)])
					      (if (eq? #\/ c2)
						  (yycontinue)
						  (loop c2) ) ) ]
					   [else (loop (yygetc))] ) )
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'enum)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'typedef)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'extern)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'static)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                    (tok 'fixnum)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                    (tok 'number)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                    (tok 'symbol)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                    (tok 'bool)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                     (tok 'pointer-vector)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'pointer)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'u32)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 's32)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'u64)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 's64)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 's64)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 's64)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 's32)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 's32)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'u64)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'u32)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'bool)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                    (tok 'callback)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                    (tok 'scheme-value)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                    (tok 'scheme-pointer)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                    (tok 'byte-vector) ; DEPRECATED
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                    (tok 'blob)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                    (tok 'scheme-value)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                    (tok 'abstract)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                    (tok 'specialize)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                    (tok 'byte)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                    (tok 'discard)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'in)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'out)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'inout)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'mutable)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'length)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'size_t)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'int)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'unsigned)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'signed)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'float)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'double)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'short)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'long)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'char)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'void)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'struct)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'union)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'const)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'class)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'public)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'protected)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'private)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'volatile)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'namespace)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'virtual)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'explicit)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'inline)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'using)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'interface)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'implementation)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'end)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'objc-class)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'protocol)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'objc-public)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'objc-protected)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'objc-private)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok (list 'id "@encode"))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok (list 'id "@defs"))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok (list 'id "@selector"))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'dots)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                          (begin (set! pp-mode #t) (tok 'pp-define))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                          (begin (set! pp-mode 'include) (tok 'pp-include))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                          (begin (set! pp-mode 'import) (tok 'pp-import))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                          (begin (set! pp-mode #t) (tok 'pp-ifdef))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                          (begin (set! pp-mode #t) (tok 'pp-ifndef))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                          (begin (set! pp-mode #t) (tok 'pp-elif))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                          (begin (set! pp-mode #t) (tok 'pp-if))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                          (begin (set! pp-mode #t) (tok 'pp-else))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                          (begin (set! pp-mode #t) (tok 'pp-pragma))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                          (begin (set! pp-mode #t) (tok 'pp-endif))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                          (begin (set! pp-mode #t) (tok 'pp-error))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                          (begin (set! pp-mode #t) (tok 'pp-undef))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok '(op "#"))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'if)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'else)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (let loop ([cs '()])
				     (let ([c (yygetc)])
				       (cond [(eq? 'eof c)
					      (parsing-error "unexpected end of string constant")]
					     [(char=? c #\\) (loop (cons (yygetc) cs))]
					     [(char=? c #\")
					      (tok (list 'string (reverse-list->string cs)) )]
					     [else (loop (cons c cs))] ) ) )
        ))
    #t
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yytext yyline)
                                   (tok (list 'char (string->number (substring yytext 2 5) 8)))
        ))
    #t
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yytext yyline)
                                   (tok (list 'char (string->number (substring yytext 3 (- (string-length yytext) 1)) 16)))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok '(char #\nul))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok '(char #\alarm))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok '(char #\backspace))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok '(char #\page))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok '(char #\newline))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok '(char #\return))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok '(char #\tab))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok '(char #\vtab))
        ))
    #t
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yytext yyline)
                                   (tok (list 'char (string-ref yytext 2)))
        ))
    #t
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yytext yyline)
                                   (tok (list 'char (string-ref yytext 1)))
        ))
    #t
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yytext yyline)
                                   (tok (list 'id yytext))
        ))
    #t
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yytext yyline)
                                   (tok (list 'num (string->number (substring yytext 2 (string-length yytext)) 16)))
        ))
    #t
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yytext yyline)
                                   (tok (list 'num (string->number (substring yytext 1 (string-length yytext)) 8)))
        ))
    #t
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yytext yyline)
                                     (tok (list 'num (string->number yytext)))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (if (eq? pp-mode 'include)
				       (let loop ([s '()])
					 (let ([c (yygetc)])
					   (cond [(eq? 'eof c) (parsing-error "unexpected end of include file name")]
						 [(char=? #\> c)
						  (set! pp-mode #f)
						  (tok `(i-string ,(reverse-list->string s)) )]
						 [else (loop (cons c s))] ) ) ) 
				       (tok `(op "<") ))
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'open-paren)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'close-paren)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'open-bracket)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'close-bracket)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'open-curly)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'close-curly)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'comma)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'semicolon)
        ))
    #f
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yyline)
                                   (tok 'star)
        ))
    #t
    (lambda (yycontinue yygetc yyungetc)
      (lambda (yytext yyline)
                                     (tok (list 'op yytext))
        )))
   'decision-trees
   0
   1
   '#((67 (41 (33 (12 (10 (9 err 48) (11 50 err)) (14 (13 47 51) (32 err
    49))) (37 (35 (34 2 27) (36 28 err)) (39 (38 9 8) (40 26 19)))) (49 (45
    (43 (42 18 11) (44 23 13)) (47 (46 22 29) (48 46 24))) (61 (59 (58 21
    4) (60 12 20)) (63 (62 3 6) (64 10 (65 30 25)))))) (106 (97 (93 (91 (68
    38 25) (92 17 52)) (95 (94 16 5) (96 42 err))) (101 (99 (98 25 39) (100
    34 36)) (103 (102 45 37) (105 25 41)))) (116 (111 (109 (108 25 35) (110
    25 31)) (113 (112 25 32) (115 25 43))) (123 (118 (117 44 40) (119 33
    25)) (125 (124 15 7) (126 14 (127 10 err))))))) (67 (41 (33 (12 (10 (9
    err 48) (11 50 err)) (14 (13 47 51) (32 err 55))) (37 (35 (34 2 27) (36
    53 err)) (39 (38 9 8) (40 26 19)))) (49 (45 (43 (42 18 11) (44 23 13))
    (47 (46 22 29) (48 46 24))) (61 (59 (58 21 4) (60 12 20)) (63 (62 3 6)
    (64 10 (65 30 25)))))) (106 (97 (93 (91 (68 38 25) (92 17 52)) (95 (94
    16 5) (96 42 err))) (101 (99 (98 25 39) (100 34 36)) (103 (102 45 37)
    (105 25 41)))) (116 (111 (109 (108 25 35) (110 25 31)) (113 (112 25 32)
    (115 25 43))) (123 (118 (117 54 40) (119 33 25)) (125 (124 15 7) (126
    14 (127 10 err))))))) (= 61 10 err) (= 61 10 err) (= 58 10 err) (= 61
    10 err) (62 (61 err 10) (63 56 err)) (62 (61 err 10) (= 124 10 err))
    (39 (38 err 10) (= 61 10 err)) (= 61 10 err) err (= 61 10 err) err err
    err err err err err err (61 (60 err 57) (62 10 err)) (58 (47 (46 err
    59) (48 err 21)) (70 (69 err 58) (= 101 58 err))) (58 (48 err 21) (= 61
    10 err)) (58 (48 err 21) (= 61 10 err)) (70 (48 (= 46 59 err) (58 (56
    60 21) (69 err 58))) (101 (= 88 61 err) (120 (102 58 err) (121 61
    err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123
    25 err)))) (11 (10 62 err) (= 92 63 62)) err (105 (100 (= 32 68 err)
    (101 69 (102 66 err))) (113 (106 67 (112 err 65)) (= 117 64 err))) (=
    46 70 err) (102 (99 (= 34 27 err) (100 74 (101 72 75))) (112 (= 105 76
    err) (115 (113 73 err) (116 71 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (97 (96 25 err) (98 77 (123 25 err)))) (96 (65 (48 err (58 25
    err)) (91 25 (95 err 25))) (115 (97 err (114 25 78)) (118 (117 25 79)
    (123 25 err)))) (96 (65 (48 err (58 25 err)) (91 25 (95 err 25))) (106
    (97 err (105 25 80)) (112 (111 25 81) (123 25 err)))) (97 (65 (48 err
    (58 25 err)) (95 (91 25 err) (96 25 err))) (109 (105 (104 25 84) (108
    25 82)) (112 (111 25 83) (123 25 err)))) (95 (58 (48 err 25) (65 err
    (91 25 err))) (111 (= 96 err 25) (112 85 (123 25 err)))) (95 (58 (48
    err 25) (65 err (91 25 err))) (111 (= 96 err 25) (112 86 (123 25
    err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (108 (= 96 err 25)
    (109 87 (123 25 err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err
    88) (97 err (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err)))
    (111 (= 96 err 25) (112 89 (123 25 err)))) (97 (65 (48 err (58 25 err))
    (95 (91 25 err) (96 25 err))) (111 (106 (105 25 92) (110 25 91)) (116
    (115 25 90) (123 25 err)))) (96 (65 (48 err (58 25 err)) (91 25 (95 err
    25))) (103 (97 err (102 25 93)) (111 (110 25 94) (123 25 err)))) (91
    (58 (48 err 25) (65 err 25)) (96 (95 err 95) (97 err (123 25 err))))
    (97 (65 (48 err (58 25 err)) (95 (91 25 err) (96 25 err))) (106 (104 25
    (105 96 97)) (117 (116 25 98) (123 25 err)))) (91 (36 (33 (32 err 100)
    (35 err 68)) (58 (48 err 25) (65 err 25))) (116 (96 (95 err 25) (97 err
    25)) (121 (117 99 25) (122 101 (123 25 err))))) (97 (65 (48 err (58 25
    err)) (95 (91 25 err) (96 25 err))) (111 (109 (108 25 102) (110 25
    104)) (121 (120 25 103) (123 25 err)))) (47 (= 42 105 err) (61 (48 106
    err) (62 10 err))) (= 12 47 err) (= 9 48 err) (35 (= 32 49 err) (116
    (36 68 err) (117 100 err))) err (11 (10 err 50) (= 13 107 err)) (13 (=
    10 50 err) (32 (14 108 err) (33 109 err))) err (95 (58 (48 err 25) (65
    err (91 25 err))) (121 (= 96 err 25) (122 101 (123 25 err)))) (= 32 55
    err) (= 61 10 err) (= 61 10 err) (45 (= 43 111 err) (48 (46 111 err)
    (58 110 err))) (69 (48 err (58 59 err)) (101 (70 58 err) (102 58 err)))
    (58 (47 (46 err 59) (48 err (56 60 21))) (70 (69 err 58) (= 101 58
    err))) (65 (48 err (58 112 err)) (97 (71 112 err) (103 112 err))) (= 39
    113 err) (102 (48 (11 (10 115 err) (= 39 114 115)) (97 (49 125 (58 124
    115)) (98 122 (99 121 115)))) (116 (111 (103 120 (110 115 119)) (= 114
    118 115)) (119 (117 117 (118 115 116)) (= 120 123 115)))) (= 110 126
    err) (= 114 127 err) (110 (= 108 130 err) (114 (111 129 err) (115 128
    err))) (109 (= 102 131 err) (110 132 (111 133 err))) (105 (100 (= 32 68
    err) (101 69 (102 66 err))) (113 (106 67 (112 err 65)) (= 117 64 err)))
    (= 101 134 err) (= 46 135 err) (= 101 136 err) (= 101 137 err) (115
    (114 err 139) (= 117 138 err)) (= 108 140 err) (= 110 141 err) (110
    (109 err 142) (111 143 err)) (95 (58 (48 err 25) (65 err (91 25 err)))
    (109 (= 96 err 25) (110 144 (123 25 err)))) (96 (65 (48 err (58 25
    err)) (91 25 (95 err 25))) (106 (97 err (105 25 145)) (112 (111 25 146)
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (98 (= 96 err
    25) (99 147 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err)))
    (114 (= 96 err 25) (115 148 (123 25 err)))) (96 (65 (48 err (58 25
    err)) (91 25 (95 err 25))) (106 (97 err (105 25 150)) (109 (108 25 149)
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (97 (96 25
    err) (98 151 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err)))
    (110 (= 96 err 25) (111 152 (123 25 err)))) (95 (58 (48 err 25) (65 err
    (91 25 err))) (97 (96 25 err) (98 153 (123 25 err)))) (95 (58 (48 err
    25) (65 err (91 25 err))) (110 (= 96 err 25) (111 154 (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (117 (= 96 err 25) (118 155
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (111 (= 96
    err 25) (112 156 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (119 (= 96 err 25) (120 157 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (111 (= 96 err 25) (112 158 (123 25 err)))) (95
    (58 (48 err 25) (65 err (91 25 err))) (105 (= 96 err 25) (106 159 (123
    25 err)))) (96 (65 (48 err (58 25 err)) (91 25 (95 err 25))) (106 (97
    err (105 25 160)) (116 (115 25 161) (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (110 (= 96 err 25) (111 162 (123 25 err)))) (91
    (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err))))
    (96 (65 (48 err (58 25 err)) (91 25 (95 err 25))) (109 (97 err (108 25
    163)) (117 (116 25 164) (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (105 (96 166 (97 err 25)) (106 165 (123 25 err)))) (95 (58
    (48 err 25) (65 err (91 25 err))) (111 (= 96 err 25) (112 167 (123 25
    err)))) (96 (65 (48 err (58 25 err)) (91 25 (95 err 25))) (104 (97 err
    (103 25 168)) (122 25 (123 169 err)))) (96 (65 (48 err (58 25 err)) (91
    25 (95 err 25))) (114 (97 err (98 171 25)) (115 170 (123 25 err)))) (65
    (35 (= 32 100 err) (48 (36 68 err) (58 25 err))) (97 (95 (91 25 err)
    (96 25 err)) (117 (116 25 99) (123 25 err)))) (35 (= 32 100 err) (116
    (36 68 err) (117 100 err))) (95 (58 (48 err 25) (65 err (91 25 err)))
    (112 (= 96 err 25) (113 172 (123 25 err)))) (95 (58 (48 err 25) (65 err
    (91 25 err))) (115 (= 96 err 25) (116 173 (123 25 err)))) (96 (65 (48
    err (58 25 err)) (91 25 (95 err 25))) (113 (97 err (112 25 174)) (117
    (116 25 175) (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err)))
    (117 (= 96 err 25) (118 176 (123 25 err)))) err err (= 13 107 err) (=
    10 50 err) err (48 err (58 110 err)) (48 err (58 110 err)) (65 (48 err
    (58 112 err)) (97 (71 112 err) (103 112 err))) err (= 39 177 err) (= 39
    177 err) (= 39 178 err) (= 39 179 err) (= 39 180 err) (= 39 181 err) (=
    39 182 err) (= 39 183 err) (= 39 184 err) (58 (40 (39 err 177) (48 err
    185)) (71 (65 err 185) (97 err (103 185 err)))) (40 (39 err 177) (48
    err (58 186 err))) (40 (39 err 187) (48 err (58 186 err))) (= 100 188
    err) (= 97 189 err) (= 114 190 err) (= 100 191 err) (106 (105 err 193)
    (= 115 192 err)) (101 (100 err 195) (= 110 194 err)) (= 112 196 err) (=
    99 197 err) (= 102 198 err) err (= 108 199 err) (= 102 200 err) (= 98
    201 err) (106 (105 err 202) (= 111 203 err)) (= 97 204 err) (100 (99
    err 205) (101 206 err)) (= 112 207 err) (= 116 208 err) (95 (58 (48 err
    25) (65 err (91 25 err))) (101 (= 96 err 25) (102 209 (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (118 (= 96 err 25) (119 210
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (116 (= 96
    err 25) (117 211 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (108 (= 96 err 25) (109 212 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (116 (= 96 err 25) (117 213 (123 25 err)))) (95
    (58 (48 err 25) (65 err (91 25 err))) (97 (96 25 err) (98 214 (123 25
    err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (100 (= 96 err 25)
    (101 215 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (115
    (= 96 err 25) (116 216 (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (115 (= 96 err 25) (116 217 (123 25 err)))) (95 (58 (48 err
    25) (65 err (91 25 err))) (114 (= 96 err 25) (115 218 (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (103 (= 96 err 25) (104 219
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (98 (= 96 err
    25) (99 220 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err)))
    (97 (96 25 err) (98 221 (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (111 (= 96 err 25) (112 222 (123 25 err)))) (95 (58 (48 err
    25) (65 err (91 25 err))) (108 (= 96 err 25) (109 223 (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (110 (= 96 err 25) (111 224
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (111 (= 96
    err 25) (112 225 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (105 (= 96 err 25) (106 226 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (116 (= 96 err 25) (117 227 (123 25 err)))) (95
    (58 (48 err 25) (65 err (91 25 err))) (105 (= 96 err 25) (106 228 (123
    25 err)))) (58 (52 (48 err (51 25 229)) (= 54 230 25)) (95 (65 err (91
    25 err)) (97 (96 25 err) (123 25 err)))) (95 (58 (48 err 25) (65 err
    (91 25 err))) (110 (= 96 err 25) (111 231 (123 25 err)))) (103 (96 (65
    (48 err (58 25 err)) (91 25 (95 err 25))) (99 (97 err (98 237 240))
    (101 (100 25 236) (102 25 243)))) (112 (108 (= 105 235 25) (110 (109
    232 233) (111 242 234))) (116 (113 239 (115 25 241)) (118 (117 25 238)
    (123 25 err))))) (95 (58 (48 err 25) (65 err (91 25 err))) (114 (= 96
    err 25) (115 244 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (110 (= 96 err 25) (111 245 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (101 (= 96 err 25) (102 246 (123 25 err)))) (95
    (58 (48 err 25) (65 err (91 25 err))) (117 (= 96 err 25) (118 247 (123
    25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (116 (= 96 err 25)
    (117 248 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (101
    (= 96 err 25) (102 249 (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (101 (= 96 err 25) (102 250 (123 25 err)))) (95 (58 (48 err
    25) (65 err (91 25 err))) (108 (= 96 err 25) (109 251 (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (101 (= 96 err 25) (102 252
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (109 (= 96
    err 25) (110 253 (123 25 err)))) err err err err err err err err (58
    (40 (39 err 254) (48 err 185)) (71 (65 err 185) (97 err (103 185
    err)))) (48 err (58 255 err)) err (= 101 256 err) (= 103 257 err) (=
    111 258 err) (= 105 259 err) (= 101 260 err) (= 102 261 err) (= 100 262
    err) (= 101 263 err) (= 111 264 err) (= 108 265 err) (= 105 266 err) (=
    101 267 err) (= 115 268 err) (= 108 269 err) (= 118 270 err) (= 116 271
    err) (= 115 272 err) (= 111 273 err) err (= 108 274 err) (= 101 275
    err) (95 (58 (48 err 25) (65 err (91 25 err))) (115 (= 96 err 25) (116
    276 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (97 (96
    25 err) (98 277 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (101 (= 96 err 25) (102 278 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (105 (= 96 err 25) (106 279 (123 25 err)))) (95
    (58 (48 err 25) (65 err (91 25 err))) (117 (= 96 err 25) (118 280 (123
    25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (116 (= 96 err 25)
    (117 281 (123 25 err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err
    25) (97 err (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err)))
    (115 (= 96 err 25) (116 282 (123 25 err)))) (95 (58 (48 err 25) (65 err
    (91 25 err))) (116 (= 96 err 25) (117 283 (123 25 err)))) (91 (58 (48
    err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err)))) (91 (58
    (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err)))) (95
    (58 (48 err 25) (65 err (91 25 err))) (108 (= 96 err 25) (109 284 (123
    25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (116 (= 96 err 25)
    (117 285 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (114
    (= 96 err 25) (115 286 (123 25 err)))) (91 (58 (48 err 25) (65 err 25))
    (96 (95 err 25) (97 err (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (103 (= 96 err 25) (104 287 (123 25 err)))) (95 (58 (48 err
    25) (65 err (91 25 err))) (110 (= 96 err 25) (111 288 (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (103 (= 96 err 25) (104 289
    (123 25 err)))) (58 (52 (48 err (51 25 290)) (= 54 291 25)) (95 (65 err
    (91 25 err)) (97 (96 25 err) (123 25 err)))) (95 (58 (48 err 25) (65
    err (91 25 err))) (110 (= 96 err 25) (111 292 (123 25 err)))) (65 (50
    (48 err 25) (51 293 (58 25 err))) (96 (91 25 (95 err 25)) (97 err (123
    25 err)))) (65 (52 (48 err 25) (53 294 (58 25 err))) (96 (91 25 (95 err
    25)) (97 err (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err)))
    (116 (= 96 err 25) (117 295 (123 25 err)))) (95 (58 (48 err 25) (65 err
    (91 25 err))) (101 (= 96 err 25) (102 296 (123 25 err)))) (95 (58 (48
    err 25) (65 err (91 25 err))) (117 (= 96 err 25) (118 297 (123 25
    err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (117 (= 96 err 25)
    (118 298 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (110
    (= 96 err 25) (111 299 (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (105 (= 96 err 25) (106 300 (123 25 err)))) (95 (58 (48 err
    25) (65 err (91 25 err))) (98 (= 96 err 25) (99 301 (123 25 err)))) (58
    (52 (48 err (51 25 303)) (= 54 302 25)) (95 (65 err (91 25 err)) (97
    (96 25 err) (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err)))
    (111 (= 96 err 25) (112 304 (123 25 err)))) (97 (65 (48 err (58 25
    err)) (95 (91 25 err) (96 25 err))) (112 (109 (108 25 305) (111 25
    307)) (122 (121 25 306) (123 25 err)))) (96 (55 (51 (48 err 25) (52 312
    (54 25 311))) (65 (58 25 err) (91 25 (95 err 25)))) (112 (98 (97 err
    310) (= 99 309 25)) (121 (113 308 25) (122 313 (123 25 err))))) (95 (58
    (48 err 25) (65 err (91 25 err))) (117 (= 96 err 25) (118 314 (123 25
    err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (105 (= 96 err 25)
    (106 315 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (116
    (= 96 err 25) (117 316 (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (101 (= 96 err 25) (102 317 (123 25 err)))) (91 (58 (48 err
    25) (65 err 25)) (96 (95 err 318) (97 err (123 25 err)))) (95 (58 (48
    err 25) (65 err (91 25 err))) (99 (= 96 err 25) (100 319 (123 25
    err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (105 (= 96 err 25)
    (106 320 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (100
    (= 96 err 25) (101 321 (123 25 err)))) (91 (58 (48 err 25) (65 err 25))
    (96 (95 err 25) (97 err (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (105 (= 96 err 25) (106 322 (123 25 err)))) (95 (58 (48 err
    25) (65 err (91 25 err))) (114 (= 96 err 25) (115 323 (123 25 err))))
    (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25
    err)))) err (= 39 324 err) (= 102 325 err) (= 109 326 err) (= 114 327
    err) (= 102 328 err) err err (= 101 329 err) (= 102 330 err) (= 114 331
    err) (= 117 332 err) (= 110 333 err) (= 99 334 err) err (= 105 335 err)
    (= 97 336 err) (102 (101 err 337) (= 111 338 err)) (= 115 339 err) (=
    100 340 err) (= 101 341 err) (= 114 342 err) (95 (58 (48 err 25) (65
    err (91 25 err))) (112 (= 96 err 25) (113 343 (123 25 err)))) (95 (58
    (48 err 25) (65 err (91 25 err))) (116 (= 96 err 25) (117 344 (123 25
    err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (99 (= 96 err 25)
    (100 345 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (99
    (= 96 err 25) (100 346 (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (97 (96 25 err) (98 347 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (105 (= 96 err 25) (106 348 (123 25 err)))) (91
    (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err))))
    (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25
    err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (101 (= 96 err 25)
    (102 349 (123 25 err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err
    25) (97 err (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err)))
    (100 (= 96 err 25) (101 350 (123 25 err)))) (91 (58 (48 err 25) (65 err
    25)) (96 (95 err 25) (97 err (123 25 err)))) (91 (58 (48 err 25) (65
    err 25)) (96 (95 err 25) (97 err (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (110 (= 96 err 25) (111 351 (123 25 err)))) (65
    (50 (48 err 25) (51 352 (58 25 err))) (96 (91 25 (95 err 25)) (97 err
    (123 25 err)))) (65 (52 (48 err 25) (53 353 (58 25 err))) (96 (91 25
    (95 err 25)) (97 err (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (101 (= 96 err 25) (102 354 (123 25 err)))) (91 (58 (48 err 25)
    (65 err 25)) (96 (95 err 355) (97 err (123 25 err)))) (91 (58 (48 err
    25) (65 err 25)) (96 (95 err 356) (97 err (123 25 err)))) (58 (52 (48
    err (51 25 357)) (= 54 358 25)) (95 (65 err (91 25 err)) (97 (96 25
    err) (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (110 (=
    96 err 25) (111 359 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (116 (= 96 err 25) (117 360 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (116 (= 96 err 25) (117 361 (123 25 err)))) (95
    (58 (48 err 25) (65 err (91 25 err))) (111 (= 96 err 25) (112 362 (123
    25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (115 (= 96 err 25)
    (116 363 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (115
    (= 96 err 25) (116 364 (123 25 err)))) (65 (52 (48 err 25) (53 365 (58
    25 err))) (96 (91 25 (95 err 25)) (97 err (123 25 err)))) (65 (50 (48
    err 25) (51 366 (58 25 err))) (96 (91 25 (95 err 25)) (97 err (123 25
    err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (105 (= 96 err 25)
    (106 367 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (111
    (= 96 err 25) (112 368 (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (116 (= 96 err 25) (117 369 (123 25 err)))) (95 (58 (48 err
    25) (65 err (91 25 err))) (111 (= 96 err 25) (112 370 (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (101 (= 96 err 25) (102 371
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (104 (= 96
    err 25) (105 372 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (102 (= 96 err 25) (103 373 (123 25 err)))) (65 (52 (48 err 25)
    (53 374 (58 25 err))) (96 (91 25 (95 err 25)) (97 err (123 25 err))))
    (65 (50 (48 err 25) (51 375 (58 25 err))) (96 (91 25 (95 err 25)) (97
    err (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (109 (=
    96 err 25) (110 376 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (109 (= 96 err 25) (110 377 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (120 (= 96 err 25) (121 378 (123 25 err)))) (91
    (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (100 (= 96 err 25) (101 379
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (116 (= 96
    err 25) (117 380 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (116 (= 96 err 25) (117 381 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (99 (= 96 err 25) (100 382 (123 25 err)))) (95
    (58 (48 err 25) (65 err (91 25 err))) (101 (= 96 err 25) (102 383 (123
    25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (99 (= 96 err 25)
    (100 384 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (110
    (= 96 err 25) (111 385 (123 25 err)))) err err (= 97 386 err) err err
    (= 102 387 err) err (= 116 388 err) (= 100 389 err) (= 101 390 err) (=
    116 391 err) (= 99 392 err) (= 116 393 err) (= 99 394 err) (= 99 395
    err) err (= 101 396 err) (= 109 397 err) (= 102 398 err) (95 (58 (48
    err 25) (65 err (91 25 err))) (97 (96 25 err) (98 399 (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (101 (= 96 err 25) (102 400
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (116 (= 96
    err 25) (117 401 (123 25 err)))) (91 (58 (48 err 25) (65 err 25)) (96
    (95 err 25) (97 err (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (108 (= 96 err 25) (109 402 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (108 (= 96 err 25) (109 403 (123 25 err)))) (91
    (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err))))
    (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25
    err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (101 (= 96 err 25)
    (102 404 (123 25 err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err
    405) (97 err (123 25 err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95
    err 406) (97 err (123 25 err)))) (91 (58 (48 err 25) (65 err 25)) (96
    (95 err 25) (97 err (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (116 (= 96 err 25) (117 407 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (116 (= 96 err 25) (117 408 (123 25 err)))) (65
    (50 (48 err 25) (51 409 (58 25 err))) (96 (91 25 (95 err 25)) (97 err
    (123 25 err)))) (65 (52 (48 err 25) (53 410 (58 25 err))) (96 (91 25
    (95 err 25)) (97 err (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (103 (= 96 err 25) (104 411 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (97 (96 25 err) (98 412 (123 25 err)))) (91 (58
    (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err)))) (95
    (58 (48 err 25) (65 err (91 25 err))) (117 (= 96 err 25) (118 413 (123
    25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (99 (= 96 err 25)
    (100 414 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (116
    (= 96 err 25) (117 415 (123 25 err)))) (91 (58 (48 err 25) (65 err 25))
    (96 (95 err 25) (97 err (123 25 err)))) (91 (58 (48 err 25) (65 err
    25)) (96 (95 err 25) (97 err (123 25 err)))) (95 (58 (48 err 25) (65
    err (91 25 err))) (110 (= 96 err 25) (111 416 (123 25 err)))) (95 (58
    (48 err 25) (65 err (91 25 err))) (98 (= 96 err 25) (99 417 (123 25
    err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (101 (= 96 err 25)
    (102 418 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (108
    (= 96 err 25) (109 419 (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (99 (= 96 err 25) (100 420 (123 25 err)))) (95 (58 (48 err
    25) (65 err (91 25 err))) (101 (= 96 err 25) (102 421 (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (101 (= 96 err 25) (102 422
    (123 25 err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97
    err (123 25 err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25)
    (97 err (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (98
    (= 96 err 25) (99 423 (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (98 (= 96 err 25) (99 424 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (110 (= 96 err 25) (111 425 (123 25 err)))) (91
    (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err))))
    (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25
    err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123
    25 err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (102 (= 96
    err 25) (103 426 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (105 (= 96 err 25) (106 427 (123 25 err)))) (91 (58 (48 err 25)
    (65 err 25)) (96 (95 err 25) (97 err (123 25 err)))) err err err (= 101
    428 err) err (= 111 429 err) err (= 101 430 err) (= 116 431 err) (= 111
    432 err) err (= 101 433 err) (= 97 434 err) (95 (58 (48 err 25) (65 err
    (91 25 err))) (99 (= 96 err 25) (100 435 (123 25 err)))) (91 (58 (48
    err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err)))) (95 (58
    (48 err 25) (65 err (91 25 err))) (101 (= 96 err 25) (102 436 (123 25
    err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123
    25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (101 (= 96 err 25)
    (102 437 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (100
    (= 96 err 25) (101 438 (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (116 (= 96 err 25) (117 439 (123 25 err)))) (95 (58 (48 err
    25) (65 err (91 25 err))) (116 (= 96 err 25) (117 440 (123 25 err))))
    (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25
    err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123
    25 err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err
    (123 25 err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97
    err (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (116 (=
    96 err 25) (117 441 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (98 (= 96 err 25) (99 442 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (116 (= 96 err 25) (117 443 (123 25 err)))) (95
    (58 (48 err 25) (65 err (91 25 err))) (97 (96 25 err) (98 444 (123 25
    err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (114 (= 96 err 25)
    (115 445 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (116
    (= 96 err 25) (117 446 (123 25 err)))) (91 (58 (48 err 25) (65 err 25))
    (96 (95 err 25) (97 err (123 25 err)))) (91 (58 (48 err 25) (65 err
    25)) (96 (95 err 447) (97 err (123 25 err)))) (91 (58 (48 err 25) (65
    err 25)) (96 (95 err 25) (97 err (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (105 (= 96 err 25) (106 448 (123 25 err)))) (95
    (58 (48 err 25) (65 err (91 25 err))) (109 (= 96 err 25) (110 449 (123
    25 err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (111 (= 96
    err 25) (112 450 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (101 (= 96 err 25) (102 451 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (117 (= 96 err 25) (118 452 (123 25 err)))) (91
    (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (116 (= 96 err 25) (117 453
    (123 25 err)))) err (= 114 454 err) err (= 101 455 err) (= 108 456 err)
    (= 110 457 err) (= 99 458 err) (95 (58 (48 err 25) (65 err (91 25
    err))) (101 (= 96 err 25) (102 459 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (100 (= 96 err 25) (101 460 (123 25 err)))) (91
    (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err))))
    (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25
    err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123
    25 err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (104 (= 96
    err 25) (105 461 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (108 (= 96 err 25) (109 462 (123 25 err)))) (91 (58 (48 err 25)
    (65 err 25)) (96 (95 err 25) (97 err (123 25 err)))) (95 (58 (48 err
    25) (65 err (91 25 err))) (114 (= 96 err 25) (115 463 (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (97 (96 25 err) (98 464 (123
    25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (101 (= 96 err 25)
    (102 465 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (118
    (= 96 err 25) (119 466 (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (97 (96 25 err) (98 467 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (101 (= 96 err 25) (102 468 (123 25 err)))) (95
    (58 (48 err 25) (65 err (91 25 err))) (108 (= 96 err 25) (109 469 (123
    25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (114 (= 96 err 25)
    (115 470 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (109
    (= 96 err 25) (110 471 (123 25 err)))) (91 (58 (48 err 25) (65 err 25))
    (96 (95 err 25) (97 err (123 25 err)))) err (= 100 472 err) err (= 116
    473 err) (= 101 474 err) (91 (58 (48 err 25) (65 err 25)) (96 (95 err
    25) (97 err (123 25 err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95
    err 25) (97 err (123 25 err)))) (91 (58 (48 err 25) (65 err 25)) (96
    (95 err 25) (97 err (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (101 (= 96 err 25) (102 475 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (100 (= 96 err 25) (101 476 (123 25 err)))) (95
    (58 (48 err 25) (65 err (91 25 err))) (99 (= 96 err 25) (100 477 (123
    25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (114 (= 96 err 25)
    (115 478 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (101
    (= 96 err 25) (102 479 (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (108 (= 96 err 25) (109 480 (123 25 err)))) (91 (58 (48 err
    25) (65 err 25)) (96 (95 err 481) (97 err (123 25 err)))) (91 (58 (48
    err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err)))) (91 (58
    (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err)))) (91
    (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err))))
    err (= 97 482 err) err (91 (58 (48 err 25) (65 err 25)) (96 (95 err 25)
    (97 err (123 25 err)))) (91 (58 (48 err 25) (65 err 25)) (96 (95 err
    25) (97 err (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err)))
    (116 (= 96 err 25) (117 483 (123 25 err)))) (91 (58 (48 err 25) (65 err
    25)) (96 (95 err 484) (97 err (123 25 err)))) (95 (58 (48 err 25) (65
    err (91 25 err))) (99 (= 96 err 25) (100 485 (123 25 err)))) (95 (58
    (48 err 25) (65 err (91 25 err))) (105 (= 96 err 25) (106 486 (123 25
    err)))) (96 (65 (48 err (58 25 err)) (91 25 (95 err 25))) (113 (97 err
    (112 25 487)) (119 (118 25 488) (123 25 err)))) (= 116 489 err) (91 (58
    (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err)))) (95
    (58 (48 err 25) (65 err (91 25 err))) (118 (= 96 err 25) (119 490 (123
    25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (116 (= 96 err 25)
    (117 491 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (97
    (96 25 err) (122 25 (123 492 err)))) (95 (58 (48 err 25) (65 err (91 25
    err))) (111 (= 96 err 25) (112 493 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (97 (96 25 err) (98 494 (123 25 err)))) (= 105
    495 err) (95 (58 (48 err 25) (65 err (91 25 err))) (101 (= 96 err 25)
    (102 496 (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (111
    (= 96 err 25) (112 497 (123 25 err)))) (95 (58 (48 err 25) (65 err (91
    25 err))) (101 (= 96 err 25) (102 498 (123 25 err)))) (95 (58 (48 err
    25) (65 err (91 25 err))) (105 (= 96 err 25) (106 499 (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (108 (= 96 err 25) (109 500
    (123 25 err)))) (= 111 501 err) (95 (58 (48 err 25) (65 err (91 25
    err))) (99 (= 96 err 25) (100 502 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (114 (= 96 err 25) (115 503 (123 25 err)))) (91
    (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (110 (= 96 err 25) (111 504
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (117 (= 96
    err 25) (118 505 (123 25 err)))) (= 110 506 err) (95 (58 (48 err 25)
    (65 err (91 25 err))) (116 (= 96 err 25) (117 507 (123 25 err)))) (91
    (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (116 (= 96 err 25) (117 508
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (101 (= 96
    err 25) (102 509 (123 25 err)))) err (95 (58 (48 err 25) (65 err (91 25
    err))) (111 (= 96 err 25) (112 510 (123 25 err)))) (95 (58 (48 err 25)
    (65 err (91 25 err))) (101 (= 96 err 25) (102 511 (123 25 err)))) (91
    (58 (48 err 25) (65 err 25)) (96 (95 err 25) (97 err (123 25 err))))
    (95 (58 (48 err 25) (65 err (91 25 err))) (114 (= 96 err 25) (115 512
    (123 25 err)))) (95 (58 (48 err 25) (65 err (91 25 err))) (114 (= 96
    err 25) (115 513 (123 25 err)))) (91 (58 (48 err 25) (65 err 25)) (96
    (95 err 25) (97 err (123 25 err)))) (91 (58 (48 err 25) (65 err 25))
    (96 (95 err 25) (97 err (123 25 err)))))
   '#((#f . #f) (#f . #f) (121 . 121) (121 . 121) (121 . 121) (121 . 121)
    (121 . 121) (121 . 121) (121 . 121) (121 . 121) (121 . 121) (120 . 120)
    (119 . 119) (118 . 118) (117 . 117) (116 . 116) (115 . 115) (114 . 114)
    (113 . 113) (112 . 112) (111 . 111) (110 . 110) (121 . 121) (121 . 121)
    (110 . 110) (107 . 107) (#f . #f) (94 . 94) (91 . 91) (121 . 121) (#f .
    #f) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (121 . 121) (5 . 5) (3 . 3) (2
    . 2) (1 . 1) (4 . 4) (#f . #f) (91 . 91) (107 . 107) (2 . 2) (121 .
    121) (121 . 121) (#f . #f) (110 . 110) (109 . 109) (#f . #f) (#f . #f)
    (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f)
    (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f)
    (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107)
    (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107)
    (107 . 107) (107 . 107) (107 . 107) (107 . 107) (92 . 92) (107 . 107)
    (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (#f . #f)
    (107 . 107) (107 . 107) (107 . 107) (107 . 107) (7 . 7) (6 . 6) (4 . 4)
    (#f . #f) (0 . 0) (110 . 110) (#f . #f) (108 . 108) (106 . 106) (106 .
    106) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f .
    #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f .
    #f) (#f . #f) (#f . #f) (85 . 85) (#f . #f) (#f . #f) (#f . #f) (78 .
    78) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f .
    #f) (#f . #f) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (45 . 45) (107 . 107) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (105 . 105) (104 .
    104) (103 . 103) (102 . 102) (101 . 101) (100 . 100) (99 . 99) (98 .
    98) (#f . #f) (#f . #f) (97 . 97) (#f . #f) (#f . #f) (#f . #f) (#f .
    #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f .
    #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f .
    #f) (69 . 69) (#f . #f) (#f . #f) (107 . 107) (107 . 107) (107 . 107)
    (107 . 107) (107 . 107) (107 . 107) (53 . 53) (107 . 107) (107 . 107)
    (52 . 52) (51 . 51) (107 . 107) (107 . 107) (107 . 107) (28 . 28) (107
    . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107
    . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107
    . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107
    . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107
    . 107) (107 . 107) (93 . 93) (107 . 107) (107 . 107) (8 . 8) (96 . 96)
    (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (86 . 86) (84 . 84)
    (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (76 . 76)
    (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f)
    (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107)
    (57 . 57) (56 . 56) (107 . 107) (48 . 48) (107 . 107) (66 . 66) (55 .
    55) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (39 . 39) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (50 . 50) (107 . 107) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (95 .
    95) (90 . 90) (#f . #f) (89 . 89) (88 . 88) (#f . #f) (82 . 82) (#f .
    #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f . #f) (#f .
    #f) (70 . 70) (#f . #f) (#f . #f) (#f . #f) (107 . 107) (107 . 107)
    (107 . 107) (58 . 58) (107 . 107) (107 . 107) (49 . 49) (34 . 34) (107
    . 107) (107 . 107) (107 . 107) (65 . 65) (107 . 107) (107 . 107) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (40 . 40) (107 . 107) (107 .
    107) (107 . 107) (20 . 20) (18 . 18) (107 . 107) (107 . 107) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (21 . 21) (19 .
    19) (107 . 107) (107 . 107) (107 . 107) (47 . 47) (44 . 44) (54 . 54)
    (11 . 11) (107 . 107) (107 . 107) (10 . 10) (87 . 87) (83 . 83) (81 .
    81) (#f . #f) (79 . 79) (#f . #f) (72 . 72) (#f . #f) (#f . #f) (#f .
    #f) (75 . 75) (#f . #f) (#f . #f) (107 . 107) (60 . 60) (107 . 107) (63
    . 63) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (24 . 24) (22 .
    22) (25 . 25) (23 . 23) (107 . 107) (107 . 107) (107 . 107) (107 . 107)
    (107 . 107) (107 . 107) (33 . 33) (37 . 37) (15 . 15) (107 . 107) (107
    . 107) (29 . 29) (107 . 107) (107 . 107) (107 . 107) (9 . 9) (107 .
    107) (80 . 80) (#f . #f) (74 . 74) (#f . #f) (#f . #f) (#f . #f) (#f .
    #f) (107 . 107) (107 . 107) (61 . 61) (46 . 46) (27 . 27) (26 . 26)
    (107 . 107) (107 . 107) (41 . 41) (107 . 107) (107 . 107) (107 . 107)
    (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107) (107 . 107)
    (64 . 64) (77 . 77) (#f . #f) (71 . 71) (#f . #f) (#f . #f) (62 . 62)
    (59 . 59) (43 . 43) (107 . 107) (107 . 107) (107 . 107) (107 . 107)
    (107 . 107) (107 . 107) (107 . 107) (14 . 14) (13 . 13) (12 . 12) (73 .
    73) (#f . #f) (67 . 67) (42 . 42) (38 . 38) (107 . 107) (17 . 17) (107
    . 107) (107 . 107) (107 . 107) (#f . #f) (35 . 35) (107 . 107) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (#f . #f) (107 . 107) (107 .
    107) (107 . 107) (107 . 107) (107 . 107) (#f . #f) (107 . 107) (107 .
    107) (36 . 36) (107 . 107) (107 . 107) (#f . #f) (107 . 107) (32 . 32)
    (107 . 107) (107 . 107) (68 . 68) (107 . 107) (107 . 107) (30 . 30)
    (107 . 107) (107 . 107) (16 . 16) (31 . 31))))

;
; User functions
;

(define lexer #f)

(define lexer-get-line   #f)
(define lexer-getc       #f)
(define lexer-ungetc     #f)

(define lexer-init
  (lambda (input-type input)
    (let ((IS (lexer-make-IS input-type input 'line)))
      (set! lexer (lexer-make-lexer lexer-default-table IS))
      (set! lexer-get-line   (lexer-get-func-line IS))
      (set! lexer-getc       (lexer-get-func-getc IS))
      (set! lexer-ungetc     (lexer-get-func-ungetc IS)))))

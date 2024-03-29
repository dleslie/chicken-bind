;;;; bind-translator.import.scm - GENERATED BY CHICKEN 4.8.0.3 -*- Scheme -*-

(eval '(import
         scheme
         chicken
         extras
         data-structures
         files
         ports
         silex
         srfi-13
         srfi-1
         utils
         regex
         matchable
         matchable))
(##sys#register-compiled-module
  'bind-translator
  (list)
  '((parse-easy-ffi . bind-translator#parse-easy-ffi)
    (register-ffi-macro . bind-translator#register-ffi-macro)
    (ffi-include-path-list . bind-translator#ffi-include-path-list)
    (ffi-dont-include . bind-translator#ffi-dont-include)
    (foreign-type-declaration . bind-translator#foreign-type-declaration)
    (parse-type-declaration . bind-translator#parse-type-declaration)
    (parse-opaque-type-declaration
      .
      bind-translator#parse-opaque-type-declaration)
    (check-c-syntax . bind-translator#check-c-syntax)
    (set-bind-options . bind-translator#set-bind-options)
    (set-renaming . bind-translator#set-renaming)
    (no-c-syntax-checks . bind-translator#no-c-syntax-checks)
    (bind-foreign-lambda* . bind-translator#bind-foreign-lambda*))
  (list)
  (list))

;; END OF FILE

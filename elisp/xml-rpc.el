;; xml-rpc.el -- An elisp implementation of clientside XML-RPC
;; $Id: xml-rpc.el 3068 2005-12-22 03:41:13Z v_thunder $

;; Copyright (C) 2001 CodeFactory AB.
;; Copyright (C) 2001 Daniel Lundin.
;; Parts Copyright (C) 2002 Mark A. Hershberger

;; Author: Daniel Lundin <daniel@codefactory.se>
;; Maintainer: Daniel Lundin <daniel@codefactory.se>
;; Version: 1.0
;; Created: May 13 2001
;; Keywords: xml rpc network
;; URL: http://www.codefactory.se/~daniel/emacs/

;; This file is NOT (yet) part of GNU Emacs.

;; This is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This software is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.


;;; Commentary:

;; This is an XML-RPC client implementation in elisp, capable of both
;; synchronous and asynchronous method calls (using the url package's async
;; retrieval functionality).
;; XML-RPC is remote procedure calls over HTTP using XML to describe the
;; function call and return values.

;; xml-rpc.el represents XML-RPC datatypes as lisp values, automatically
;; converting to and from the XML datastructures as needed, both for method
;; parameters and return values, making using XML-RPC methods fairly
;; transparent to the lisp code.

;; Requirements
;; ------------

;; xml-rpc.el uses the url package for http handling and xml.el for XML
;; parsing. url is a part of the W3 browser package (but now as a separate
;; module in the CVS repository).
;; xml.el is a part of GNU Emacs 21, but can also be downloaded from
;; here: <URL:ftp://ftp.codefactory.se/pub/people/daniel/elisp/xml.el>


;; XML-RPC datatypes are represented as follows
;; --------------------------------------------

;;          int:  42
;; float/double:  42.0
;;       string:  "foo"
;;        array:  '(1 2 3 4)   '(1 2 3 (4.1 4.2))
;;       struct:  '(("name" . "daniel") ("height" . 6.1))


;; Examples
;; ========
;; Here follows some examples demonstrating the use of xml-rpc.el

;; Normal synchronous operation
;; ----------------------------

;; (xml-rpc-method-call "http://localhost:80/RPC" 'foo-method foo bar zoo)

;; Asynchronous example (cb-foo will be called when the methods returns)
;; ---------------------------------------------------------------------

;; (defun cb-foo (foo)
;;   (print (format "%s" foo)))

;; (xml-rpc-method-call-async 'cb-foo "http://localhost:80/RPC"
;;                            'foo-method foo bar zoo)


;; Some real world working examples for fun and play
;; -------------------------------------------------

;; Check the temperature (celsius) outside jonas@codefactory.se's apartment

;; (xml-rpc-method-call
;;      "http://flint.bengburken.net:80/xmlrpc/onewire_temp.php"
;;      'onewire.getTemp)


;; Fetch the latest NetBSD news the past 5 days from O'reillynet

;; (xml-rpc-method-call "http://www.oreillynet.com/meerkat/xml-rpc/server.php"
;;  		     'meerkat.getItems
;;  		     '(("channel" . 1024)
;;  		       ("search" . "/NetBSD/")
;;  		       ("time_period" . "5DAY")
;;  		       ("ids" . 0)
;;  		       ("descriptions" . 200)
;;  		       ("categories" . 0)
;;  		       ("channels" . 0)
;;  		       ("dates" . 0)
;;  		       ("num_items" . 5)))


;;; History:

;; 1.1 - Added support for boolean types.  If the type of a
;;       returned value is not specified, string is assumed

;; 1.0 - First version


;;; Bugs/Todo:

;; * Base64 datatype is not implemented [should use base64.el]

;;; Code:

(require 'custom)
(require 'xml)
(require 'url)
(require 'w3)

(defcustom xml-rpc-load-hook nil
  "*Hook run after loading xml-rpc."
  :type 'hook :group 'xml-rpc)

(defvar xml-rpc-char-subst-table '(("&" . "&amp;")
				   ("<" . "&lt;")
				   (">" . "&gt;")
				   ("\"" . "&quot;"))
  "Alist of strings to convert before sending over xml-rpc.")

;;
;; Value type handling functions
;;

(defun xml-rpc-value-intp (value)
  "Return t if VALUE is an integer."
  (integerp value))

(defun xml-rpc-value-doublep (value)
  "Return t if VALUE is a double precision number."
  (floatp value))

(defun xml-rpc-value-stringp (value)
  "Return t if VALUE is a string."
  (stringp value))

(defun xml-rpc-value-booleanp (value)
  "Return t if VALUE is a boolean"
  (or (eq value nil)
      (eq value t)))

(defun string-to-boolean (value)
  "Return t if VALUE is a boolean"
  (or (string-equal value "true") (string-equal value "1")))

;; An XML-RPC struct is a list where every car is a list of length 1 or 2 and
;; has a string for car.
(defsubst xml-rpc-value-structp (value)
  "Return t if VALUE is an XML-RPC struct."
  (and (listp value)
       (let ((vals value)
	     (result t)
	     curval)
	 (while (and vals result)
	   (setq result (and
			 (setq curval (car-safe vals))
			 (cdr-safe curval)
;			 (memq (safe-length curval) '(1 2))
			 (stringp (car-safe curval))))
	   (setq vals (cdr-safe vals)))
	 result)))

;; A somewhat lazy predicate for arrays
(defsubst xml-rpc-value-arrayp (value)
  "Return t if VALUE is an XML-RPC struct."
  (and (listp value)
       (not (xml-rpc-value-structp value))))


(defun xml-rpc-xml-list-to-value (xml-list)
  "Convert an XML-RPC structure in an xml.el style XML-LIST to an elisp list, \
interpreting and simplifying it while retaining its structure."
  (cond 
   ((listp (caddar xml-list))
	  (setq valtype (car (caddar xml-list))
		valvalue (caddr (caddar xml-list)))
	  (cond
	   ;; Base64 not implemented yet
	   ((eq valtype 'base64)
	    (error "Base64 handling not implemented yet"))
	   ;; Boolean
	   ((eq valtype 'boolean)
	    (string-to-boolean valvalue))
	   ;; String
	   ((eq valtype 'string)
	    valvalue)
	   ;; Integer
	   ((eq valtype 'int)
	    (string-to-int valvalue))
	   ;; Double/float
	   ((eq valtype 'double)
	    (string-to-number valvalue))
	   ;; Struct
	   ((eq valtype 'struct)
	    (mapcar (lambda (member)
		      (let ((membername (cadr (cdaddr member)))
			    (membervalue (xml-rpc-xml-list-to-value (cdddr member))))
			(cons membername membervalue)))
		    (cddr (caddar xml-list))))
	   ;; Array
	   ((eq valtype 'array)
	    (mapcar (lambda (arrval)
		      (xml-rpc-xml-list-to-value (list arrval)))
		    (cddr valvalue)))))
   ((caddar xml-list))))

(defun boolean-to-string (value)
  "Convert a boolean value to a string"
  (if value
      "1"
    "0"))

(defun xml-rpc-escape-string (string)
  "Replace characters invalid in xml-rpc with escaped equivalents."
  (with-temp-buffer
    (insert string)
    (let ((alist xml-rpc-char-subst-table))
      (while (setq subst (pop alist))
	(goto-char (point-min))
	(while (search-forward (car subst) nil t)
	  (replace-match (cdr subst) nil t))))
    (buffer-substring-no-properties (point-min) (point-max))))

(defun xml-rpc-value-to-xml-list (value)
  "Return XML representation of VALUE properly formatted for use with the  \
functions in xml.el."
  (cond
;   ((not value)
;    nil)
   ((xml-rpc-value-booleanp value)
    `((value nil (boolean nil ,(boolean-to-string value)))))
   ((listp value)
    (let ((result nil)
	  (xmlval nil))
      (if (xml-rpc-value-structp value)
	  ;; Value is a struct
	  (progn
	    (while (setq xmlval `((member nil (name nil ,(caar value))
					  ,(car (xml-rpc-value-to-xml-list
						 (cdar value)))))
			 result (if t (append result xmlval) (car xmlval))
			 value (cdr value)))
	    `((value nil ,(append '(struct nil) result))))
	;; Value is an array
	(while (setq xmlval (xml-rpc-value-to-xml-list (car value))
		     result (if result (append result xmlval)
			      xmlval)
		     value (cdr value)))
	`((value nil (array nil ,(append '(data nil) result)))))))
   ;; Value is a scalar
   ((xml-rpc-value-intp value)
    `((value nil (int nil ,(int-to-string value)))))
   ((xml-rpc-value-stringp value)
    `((value nil (string nil ,(xml-rpc-escape-string value)))))
   ((xml-rpc-value-doublep value)
    `((value nil (double nil ,(number-to-string value)))))))

(defun xml-rpc-xml-to-string (xml)
  "Return a string representation of the XML tree as valid XML markup."
  (let ((tree (xml-node-children xml))
	(result (concat "<" (symbol-name (xml-node-name xml)) ">")))
    (while tree
      (cond
       ((listp (car tree))
	(setq result (concat result (xml-rpc-xml-to-string (car tree)))))
       ((stringp (car tree))
	(setq result (concat result (car tree))))
       (t
	(error "Invalid XML tree")))
      (setq tree (cdr tree)))
    (setq result (concat result "</" (symbol-name (xml-node-name xml)) ">"))
    result))




;;
;; Response handling
;;

(defsubst xml-rpc-response-errorp (response)
  "An 'xml-rpc-method-call'  result value is always a list, where the first \
element in RESPONSE is either nil or if an error occured, a cons pair \
according to (errnum .  \"Error string\"),"
 (let ((first (car-safe response)))
   (and first (listp first) (eq (car first) 'fault))))


(defsubst xml-rpc-response-error-code (response)
  "Return the error code from RESPONSE."
  (and (xml-rpc-response-errorp response)
       (caar response)))
  
(defsubst xml-rpc-response-error-string (response)
  "Return the error code from RESPONSE."
  (and (xml-rpc-response-errorp response)
       (cdar response)))

(defun xml-rpc-xml-to-response (xml)
  "Convert an XML list to a method response list.
The return value is always a list with two elements, (error payload).
Error is either nil or a cons pair consisting of and integer errorcode and
error description string.  The errorcode is nil if XML is not a valid xml list.
Payload is an rpc-xml-value."
  ;; Check if we have a methodResponse
  (cond
   ((not (eq (car-safe (car-safe xml)) 'methodResponse))
    '((nil . "Not a valid XML-RPC  methodResponse.")))

   ;; Did we get a fault response
   ((eq (caaddr (car xml)) 'fault)
    ;; Dig deep in the XML list for some useful information
    (let ((errstruct  (cddar (cddadr (cdaddr (car xml)))))
	  errnum errstr)
      (setq errnum (string-to-number (caddr (caddar (cdddar errstruct))))
	    errstr (caddar (cddadr (cddadr errstruct))))
      (list (cons errnum errstr) nil)))
 
   ;; Interpret the XML list and produce a more useful data structure
   (t
    (let ((valpart (cdr (cdaddr (caddar xml)))))
      (xml-rpc-xml-list-to-value valpart)))))


;;
;; Misc
;;

(defun xml-rpc-get-temp-buffer-name ()
  "Get a working buffer name such as ` *XML-RPC-<i>*' without a live process \
and empty it"
  (let ((num 1)
	name buf)
    (while (progn (setq name (format " *XML-RPC-%d*" num)
			buf (get-buffer name))
		  (and buf (or (get-buffer-process buf)
			       (save-excursion (set-buffer buf)
					       (> (point-max) 1)))))
      (setq num (1+ num)))
    name))



;;
;; Method handling
;;

(defun xml-rpc-request (server-url xml &optional async-callback-function)
  "Perform http post request to SERVER-URL using XML.

If ASYNC-CALLBACK-FUNCTION is non-nil, the request will be performed
asynchronously and ASYNC-CALLBACK-FUNCTION should be a callback function to
be called when the reuest is finished.  ASYNC-CALLBACK-FUNCTION is called with
a single argument being an xml.el style XML list.

It returns an XML list containing the method response from the XML-RPC server,
or nil if called with ASYNC-CALLBACK-FUNCTION."
  (unwind-protect
      (save-excursion
	(let ((url-working-buffer (get-buffer-create
				   (xml-rpc-get-temp-buffer-name)))
	      (url-request-method "POST")
	      (url-package-name "Lispmeralda-Emacs")
	      (url-package-version "1.0")
	      (url-request-data (concat "<?xml version=\"1.0\"?>\n"
					(xml-rpc-xml-to-string (car xml))))
	      (url-request-extra-headers (cons
					  (cons  "Content-Type" "text/xml")
					  url-request-extra-headers)))
;	  (print url-request-data (create-file-buffer "request-data"))
	  (set-buffer url-working-buffer)

	  (cond ((boundp 'url-be-asynchronous) ; Sniff for w3 lib capability
		 (if async-callback-function
		     (setq url-be-asynchronous t
			   url-current-callback-data (list
						      async-callback-function
						      (current-buffer))
			   url-current-callback-func 'xml-rpc-request-callback-handler)
		   (setq url-be-asynchronous nil))
		 (url-retrieve server-url t)

		 (if url-be-asynchronous
		     nil
		   (let ((result (xml-rpc-request-process-buffer
				  url-working-buffer)))
 ;	      (print result (create-file-buffer "result-data"))
 ;	      (kill-buffer (current-buffer))
		     result)))
		(t			; Post emacs20 w3-el
		 (if async-callback-function
		     (url-retrieve server-url async-callback-function)
		   (let* ((buffer (url-retrieve-synchronously server-url))
			  (result (xml-rpc-request-process-buffer buffer)))
;		     (kill-buffer buffer)
		     result))))))))

(defun xml-rpc-clean-string (s)
  (let ((new-string (replace-regexp-in-string "^[ \t\n]+" "" s)))
    (if (string-equal "" new-string)
	nil
      new-string)))

(defun xml-rpc-clean (l)
  (cond
   ((listp l)
    (let ((remain l)
	  elem
	  (result nil))
      (while l
	; iterate
	(setq elem (car l)
	      l (cdr l))
	; test the head
	(cond
	 ; a string, so clean it.
	 ((stringp elem)
	  (let ((tmp (xml-rpc-clean-string elem)))
	    (if tmp
		(setq result (append result (list tmp))))))

	  ; a list, so recurse.
	  ((listp elem)
	   (setq result (append result (list (xml-rpc-clean elem)))))

	  ; everthing else, as is.
	  (t
	   (setq result (append result (list elem))))))
      result))

   ((stringp l) ; will returning nil be acceptable ?
    (xml-rpc-clean-string elem))

   (t
    l)))

(defun xml-rpc-request-process-buffer (xml-buffer)
  "Process buffer XML-BUFFER."
  (unwind-protect
      (save-excursion
	(set-buffer xml-buffer)
	(goto-char (point-min))
	(while (re-search-forward "" nil t)
	  (replace-match "" nil nil))
	(goto-char (point-min))
	(if (string-match "Exp" url-version)
	    (xml-rpc-clean (xml-parse-region (search-forward-regexp "<\\?xml") (point-max)))
	  ;; Gather the results
	  (let* ((status (cdr (assoc "status" url-current-mime-headers)))
		 (result (cond
			  ;; No HTTP status returned
			  ((not status)
			   (let ((errstart
				  (search-forward "\n---- Error was: ----\n")))
			     (and errstart
				  (buffer-substring errstart (point-max)))))
		      
			  ;; A probable XML response
			  ((looking-at "<\\?xml *version=.*\\??>")
			   (xml-parse-region 0 (point-max)))
			  
			  ;; Valid HTTP status
			  (t
			   (int-to-string status)))))
	    result)))))


(defun xml-rpc-request-callback-handler (callback-fun xml-buffer)
  "Marshall a callback function request to CALLBACK-FUN with the results \
handled from XML-BUFFER."
  (let ((xml-response (xml-rpc-request-process-buffer xml-buffer)))
;    (kill-buffer xml-buffer)
    (funcall callback-fun (xml-rpc-xml-to-response xml-response))))
  

(defun xml-rpc-method-call-async (async-callback-func server-url method
							     &rest params)
  "Call an XML-RPC method asynchronously at SERVER-URL named METHOD with \
PARAMS as parameters. When the method returns, ASYNC-CALLBACK-FUNC will be \
called with the result as parameter."
  (let* ((m-name (if (stringp method)
		     method
		   (symbol-name method)))
	 (m-params (mapcar '(lambda (p)
			      `(param nil ,(car (xml-rpc-value-to-xml-list
						 p))))
			   (if async-callback-func
			       params
			     (car-safe params))))
	 (m-func-call `((methodCall nil (methodName nil ,m-name)
				    ,(append '(params nil) m-params)))))
;    (print m-func-call (create-file-buffer "func-call"))
    (xml-rpc-request server-url m-func-call async-callback-func)))



(defun xml-rpc-method-call (server-url method &rest params)
  "Call an XML-RPC method at SERVER-URL named METHOD with PARAMS as \
parameters."
  (let ((response
	 (xml-rpc-method-call-async nil server-url method params)))
    (if (stringp response)
	(list (cons nil (concat "URL/HTTP Error: " response)))
      (xml-rpc-xml-to-response response))))


(provide 'xml-rpc)
(run-hooks 'xml-rpc-load-hook)
;;; xml-rpc.el ends here




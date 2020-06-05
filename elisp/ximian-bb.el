;;; -*-Emacs-Lisp-*-
;; ximian-bb.el - Functions for dealing with ximian-build.conf files

;; Copyright 2003 Ximian, Inc.
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License, version 2,
;; as published by the Free Software Foundation.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.

;; Author: Dan Mills <thunder@ximian.com>
;; Date: Fall 2002

;; This file is NOT (yet) part of GNU Emacs.

;;; Commentary:

;; This are some functions to do a couple of things with
;; ximian-build.conf files:
;;
;; * Rename the buffer visiting them, so that instead of
;;   "ximian-build.conf<NN>" you get the name of the module, with
;;   ".conf" appended.
;;
;; * Make it very easy to submit any conf file to the Ximian BB master
;;   server for building.

;; Requirements:
;; -------------
;;
;; You will need to have installed:
;;
;; * W3
;; * xml-rpc.el + ximian patches (available on synapse)

;; Usage
;; -----
;;
;; You can load this file at startup by placing it in your load-path
;; and adding this to your ~/.emacs:
;;
;; (require 'ximian-bb)
;;
;; To use the rename function, use the sgml-settings.el file available
;; on synapse.  If you'd rather not do that, you can just add the
;; following to your emacs startup files:
;;
;; (if (fboundp 'ximian-conf-rename)
;;    (add-hook 'sgml-mode-hook 'ximian-conf-rename))
;;
;; To build conf files through the daemon, you must have a valid
;; login/password for the bb master.  By default, your current
;; username is used as the login, and an empty string as your
;; password.  If this is not correct, set these variables:
;;
;; (setq ximian-daemon-user "fred")
;; (setq ximian-daemon-password "barney")
;;
;; Then to build a conf file, type "M-x ximian-conf-build RET" in the
;; buffer visiting it.
;;
;; Enjoy!
;;

;;; Code:

(require 'xml-rpc)
(require 'w3)

(defvar ximian-daemon-user (user-login-name)
  "Owner for jobs submitted to the Ximian BB daemon")
(defvar ximian-daemon-password ""
  "Password for the owner specified in ximian-bb-daemon-user.")

(defvar ximian-bb-config-file "/usr/share/ximian-build-system/conf/bb.conf"
  "Location where the bb.conf file can be found.  This file is
distributed with Ximian BB, in the ximian-build-system package.")
(defvar ximian-bb-config nil
  "The parsed bb.conf xml tree.  It will not be loaded if
ximian-bb-config-file is nil.")

;; Compatibility functions for xemacs / older emacsen.

(unless (fboundp 'completing-read-multiple)
  (defun completing-read-multiple (prompt table &optional predicate require-match
					  initial-contents history default)
    "Beware, this is not a real implementation of
completing-read-multiple as emacs has it.  It is just completing-read,
but it returns a list instead.  Useful for compatibility purposes."
    (list (completing-read prompt table predicate require-match initial-contents history default))))

(unless (fboundp 'pop)
  (defmacro pop (place)
    "Remove and return the head of the list stored in PLACE.
Analogous to (prog1 (car PLACE) (setf PLACE (cdr PLACE))),
though more
careful about evaluating each argument only once and in the
right order.
PLACE may be a symbol, or any generalized variable allowed by
`setf'."
    (if (symbolp place)
	(list 'car (list 'prog1 place (list 'setq place (list
							 'cdr place))))
      (cl-do-pop place))))

;; Handy functions for dealing with xml data

(defun ximian-xml-get-value (name xml)
  "Assuming a list of xml nodes in the form of: (name args value1
value2 ..), then return all the values of the named node as a list.
If there is only one value, then return it by itself."
  (let ((ret (assoc name xml)))
    (if (> (length ret) 3)
	(cddr ret)
      (caddr ret))))

(defun ximian-bb-config-get (name)
  "Shorthand function for calling ximian-xml-get-value on
ximian-bb-conf, the parsed bb.conf xml tree."
  (ximian-xml-get-value name ximian-bb-config))

(defun ximian-get-targets-alist ()
  "Contact the build master and retrieve a list of all the available
targets that can be used to build on."
  (let* ((master (ximian-xml-get-value 'master (ximian-bb-config-get 'daemon)))
	 (raw-tgts (xml-rpc-method-call (concat "http://" master ":8080/RPC2") 'targets))
	 targets)
    (while raw-tgts
      (setq targets (append targets `((,(pop raw-tgts))))))
    targets))

;; Goodness below

(defun ximian-conf-build (&optional targets owner password)
  "Build packages from the ximian-build.conf file the current buffer
is visiting."
  (interactive)

  (and ximian-bb-config-file
       (setq ximian-bb-config (or ximian-bb-config
				  (cddar (xml-parse-file ximian-bb-config-file)))))

  (let ((targets   (or targets
		       (completing-read-multiple "Target: " (ximian-get-targets-alist))))
	(owner    (or owner    ximian-daemon-user))
	(password (or password ximian-daemon-password))
	(master   (ximian-xml-get-value 'master (ximian-bb-config-get 'daemon)))
	ret)
    (while targets
      (push (xml-rpc-method-call (concat "http://" master ":8080/RPC2") 'build_simple
				 owner password `(("target" . ,(pop targets))
						  ("modules" (("name" . ,(buffer-name))
							      ("conf" . ,(buffer-string))))))
	    ret))))

(defun ximian-conf-rename ()
  "To be used when opening a ximian-build.conf file.
Search for a <name> tag, and uniquely rename the buffer using it."
  (goto-char (point-min))
  (if (re-search-forward "<!DOCTYPE module SYSTEM \"helix-build.dtd\">")
      (if (not (re-search-forward "<name>" nil 't))
	  (rename-buffer "ximian-build.conf" 'unique)
	(let ((pt (point))
	      endpt)
	  (re-search-forward "</" nil 't)
	  (setq endpt (- (point) 2))
	  (rename-buffer (concat (buffer-substring pt endpt) ".conf") 'unique)))))

(provide 'ximian-bb)

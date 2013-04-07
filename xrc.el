;;; xrc.el --- Syntax sugar and other goodies for working with xml-rpc.el

;; Copyright (C) 2013 Andrew Kirkpatrick

;; Author:     Andrew Kirkpatrick <ubermonk@gmail.com>
;; Maintainer: Andrew Kirkpatrick <ubermonk@gmail.com>
;; URL:        https://github.com/spacebat/xrc
;; Created:    07 Apr 2013
;; Keywords:   convenience, lisp
;; Version:    0.1

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You may have received a copy of the GNU General Public License
;; along with this program.  If not, see:
;; <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Using xml-rpc is prone to code like:

;; (setq myurl "http://hostname:port/path")
;; (xml-rpc-method-call myurl 'method "arg")
;; (xml-rpc-method-call myurl 'other-method "other-arg")

;; This library lets us instead write:

;; (xrc-defcaller caller :url "http://hostname:port/path")
;; (caller 'method "arg")
;; (caller 'other-method "other-arg")

;; Its syntactical sugar that makes a difference for exploratory
;; programming, but could also provide benefits such as sanity checks
;; on method names an arguments for XML-RPC services.

;; Append :checked-p t to the end of the xrc-defcaller line to have an
;; error raised immediately by the library if a method is called that
;; is not supported by the endpoint.

;; To install, once xrc.el is located somewhere in your
;; load-path, you can add this to your initialization file:

;; (require 'xrc)

;; TODO: implement with-xrc-endpoint macro for that extra caramel malt
;; topping. You know, maltose has a glycaemic index of around 110

;; Local Variables:
;; lexical-binding: t
;; End:

;;; Code:

(require 'xml-rpc)

;; represent an xml-rpc endpoint
(defstruct (xrc-endpoint (:constructor xrc-make-endpoint))
  ;; the URL to pass to xml-rpc-method-call
  url
  ;; a docstring describing this endpoint
  documentation
  ;; a lazily calculated hash of methods applicable by this endpoint
  %method-table%)

(defun xrc-endpoint-get-methods (endpoint &optional obarray)
  "Obtain the methods available on ENDPOINT as reported by
system.listMethods, as a list of symbols"
  (mapcar (lambda (name)
            (intern name obarray))
          (xml-rpc-method-call (xrc-endpoint-url endpoint) 'system.listMethods)))

(defun xrc-endpoint-method-table (endpoint &optional refresh)
  "Obtain the methods available on ENDPOINT as a hash table. The
methods are fetched the first time this is called and then
cached, unless REFRESH is true."
  (or (and (not refresh)
           (xrc-endpoint-%method-table% endpoint))
      (let ((table (make-hash-table)))
        (dolist (method (xrc-endpoint-get-methods endpoint))
          (puthash method t table))
        (setf (xrc-endpoint-%method-table% endpoint) table))))

(defun xrc-endpoint-method-p (endpoint method)
  "Predicate that indicates if METHOD is among the methods
reported to be available on ENDPOINT"
  (gethash method (xrc-endpoint-method-table endpoint)))

(defun* xrc-caller (endpoint &key checked-p)
  "Create a closure that wraps an xrc-endpoint. The name of a
method to call on the endpoint is provided as a symbol as for
`xml-rpc-method-call'. If the keyword argument :checked-p is
provided and non-nil, calls will be checked against those
reported by the endpoint. If the method is :xrc-endpoint, the
wrapped endpoint struct is returned. If the method is :checked-p,
the value passed in for checking is returned."
  (unless lexical-binding
    (error "The special variable lexical-binding must be non-nil for xrc-caller to work"))
  (lambda (method &rest args)
    (case method
      (:xrc-endpoint endpoint)
      (:checked-p checked-p)
      (t
       (when checked-p
         (unless (xrc-endpoint-method-p endpoint method)
           (error "The method '%s' is not supported on the xrc-endpoint")))
       (apply 'xml-rpc-method-call (xrc-endpoint-url endpoint) method args)))))

(defmacro xrc-defcaller (name &rest args)
  "Accept or create a closure as produced by `xrc-caller' and
bind it to the function cell of the symbol NAME"
  (let* ((endpoint (pcase args
                     (`(,(pred xrc-endpoint-p) ,tail)
                      (car args))
                     (t
                      (apply 'xrc-make-endpoint args))))
         (caller (xrc-caller endpoint)))

    `(defalias ',name ',caller)))

(provide 'xrc)

;;; org-srs-item-card.el --- The flashcard item type -*- lexical-binding:t -*-

;; Copyright (C) 2024 Bohong Huang

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package implements flashcard review items in Org-srs, supporting
;; multiple representations for the front and back.

;;; Code:

(require 'cl-lib)
(require 'cl-generic)

(require 'org)

(require 'org-srs-item)
(require 'org-srs-review)

(cl-defmethod org-srs-item-review ((_type null) &rest args)
  (apply #'org-srs-item-review 'card args))

(defun org-srs-item-card-regions ()
  (cl-flet ((org-entry-end-position (&aux (position (org-entry-end-position)))
              (if (= position (point-max)) (1+ position) position)))
    (let ((initalp t) (front nil) (back nil))
      (org-map-entries
       (lambda ()
         (unless (cl-shiftf initalp nil)
           (let ((heading (cl-fifth (org-heading-components))))
             (cond
              ((string-equal-ignore-case heading "Front")
               (setf front (cons (point) (1- (org-entry-end-position)))))
              ((string-equal-ignore-case heading "Back")
               (setf back (cons (point) (1- (org-entry-end-position)))))))))
       nil 'tree)
      (let ((heading (save-excursion
                       (org-back-to-heading)
                       (cons (point) (pos-eol))))
            (content (cons
                      (save-excursion
                        (org-end-of-meta-data t)
                        (point))
                      (1- (org-entry-end-position)))))
        (if front
            (if back
                (cl-values front back)
              (error "Unable to determine the back of the card"))
          (if back
              (cl-values content back)
            (cl-values heading content)))))))

(defun org-srs-item-card-put-ellipsis-overlay (start end)
  (let ((overlay (make-overlay start end nil 'front-advance)))
    (overlay-put overlay 'category 'org-srs-item-card)
    (overlay-put overlay 'display "...")))

(cl-defun org-srs-item-card-remove-ellipsis-overlays (&optional (start (point-min)) (end (point-max)))
  (remove-overlays start (1+ end) 'org-srs-item-card))

(defun org-srs-item-card-show ()
  (org-fold-show-subtree)
  (org-srs-item-card-remove-ellipsis-overlays
   (save-excursion (org-end-of-meta-data t) (point))
   (save-excursion (org-end-of-subtree) (point))))

(cl-defun org-srs-item-card-hide (&optional (side :back))
  (org-srs-item-card-show)
  (cl-ecase side
    (:front
     (cl-destructuring-bind (beg . end) (cl-nth-value 0 (org-srs-item-card-regions))
       (cond
        ((= (save-excursion (org-back-to-heading) (point)) beg)
         (save-excursion
           (goto-char beg)
           (re-search-forward org-outline-regexp-bol)
           (org-srs-item-card-put-ellipsis-overlay (point) end)))
        ((save-excursion (goto-char beg) (org-at-heading-p))
         (save-excursion (goto-char beg) (org-fold-hide-entry)))
        (t (org-srs-item-card-put-ellipsis-overlay beg end)))))
    (:back
     (cl-destructuring-bind (beg . end) (cl-nth-value 1 (org-srs-item-card-regions))
       (if (save-excursion (goto-char beg) (org-at-heading-p))
           (save-excursion (goto-char beg) (org-fold-hide-entry))
         (org-srs-item-card-put-ellipsis-overlay beg end))))))

(cl-defmethod org-srs-item-review ((type (eql 'card)) &rest args)
  (org-srs-item-narrow)
  (org-srs-item-card-hide)
  (org-srs-review-add-hook-once 'org-srs-item-after-confirm-hook #'org-srs-item-card-show)
  (apply (org-srs-item-confirmation) type args))

(cl-defmethod org-srs-item-new ((_type (eql 'card)) &rest args)
  (apply #'org-srs-item-new nil args))

(provide 'org-srs-item-card)
;;; org-srs-item-card.el ends here

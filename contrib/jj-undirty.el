;; This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

;; == jj-undirty ==
;; Update JJ repo after saving a buffer
(defun jj-undirty()
  "Execute `jj status` to snapshot the current repository.
This function checks if the current buffer resides in a JJ repository,
and if so executes `jj status` while logging the command output to
the '*jj-undirty*' buffer.
This function is most useful as hook, to frequently snapshot the
workgin copy and update the JJ op log after files have been modified:
  (add-hook 'after-save-hook 'jj-undirty)"
  (interactive)
  (when (locate-dominating-file "." ".jj")	; detect JJ repo
    (progn
      (let ((absfile (buffer-file-name))
	    (buffer (get-buffer-create "*jj-undirty*"))
 	    (process-connection-type nil))	; use a pipe instead of a pty
	(with-current-buffer buffer
	  (goto-char (point-max))		; append to end of buffer
	  (insert "\n# jj-undirty: after-save-hook: " absfile "\njj status\n")
	  (start-process "jj status" buffer	; asynchronous snapshotting
 			 "jj" "--no-pager" "status" "--color=never")
	  ))))
  )

;; Detect JJ repo and snapshot on every save
(add-hook 'after-save-hook 'jj-undirty)
;; (remove-hook 'after-save-hook 'jj-undirty)

;; This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

;; == suspend-with-shell ==
;; Wrap `(suspend-emacs)` so that a subshell is executed with $SHELL pointing
;; to a script that will run `COMMAND`. This way, emacs can be suspended
;; to run another terminal process on the same tty, without using
;; `ioctl(TIOCSTI)` - which `(suspend-emacs)` relies on but is not available
;; in recent kernel versions.
(defun suspend-with-shell (COMMAND)
  "Call (suspend-emacs) with $SHELL assigned to a script that will run COMMAND"
  (interactive)
  (let ((oldshell (getenv "SHELL"))
        (tfile (make-temp-file "emacssubshell"))
        (script (concat "#!/usr/bin/env bash\nset -Eeu #-x\n" COMMAND "\n"))
        (cannot-suspend 't)) ; force suspend-emacs to use sys_subshell
    (with-temp-file tfile
      (insert script))
    (set-file-modes tfile #o700 'nofollow)
    ;; see sys_subshell() in https://github.com/emacs-mirror/emacs/blob/master/src/keyboard.c
    (setenv "SHELL" tfile)
    (suspend-emacs)     ; this calls system($SHELL)
    (setenv "SHELL" oldshell)
    (delete-file tfile)
    )
  )

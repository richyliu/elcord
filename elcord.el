;;; elcord.el --- Allows you to integrate Rich Presence from Discord

;;; Copyright 2017 heatingdevice

;;; Version: 0.0.1
;;; Author: heatingdevice
;;; URL: https://github.com/mstrodl/elcord

;;; Code:

(provide 'elcord)
(setq debug-on-error t)

;;; Commentary:
;; elcord allows you to show off your buffer with all your Discord friends via the new rich presence feature

(require 'json)
(eval-when-compile (require 'cl))
(require 'bindat)

(message "Opening Discord IPC socket...")

(defvar elcord-client_id "373861544456486913")
(defun elcord-on-connect (&rest args)
  "Debug function used to log packets recieved."
  ; (message "New msg %s" ARGS)
  )

(defvar elcord-jsonstr "")
(defvar elcord-datalen 0)
(defvar elcord-message-spec '())
(defvar elcord-packet '())

(defun elcord-send-packet (opcode obj)
  "Packs and sends a packet to the IPC server.
Argument OPCODE OP code to send.
Argument OBJ The data to send to the IPC server."
  (setf elcord-jsonstr (json-encode obj))
  (setf elcord-datalen (length elcord-jsonstr))
  (setf elcord-message-spec
    `((:op u32r)
      (:len u32r)
      (:data str ,elcord-datalen)))
  (setf elcord-packet (bindat-pack
                  elcord-message-spec
                  `((:op . ,opcode)
                    (:len . ,elcord-datalen)
                    (:data . ,elcord-jsonstr))))
  (process-send-string elcord-sock elcord-packet)
  )

(defvar elcord-activity '())
(defvar elcord-nonce "")
(defvar elcord-presence '())
(defvar elcord-pid (emacs-pid))

(defun elcord-setpresence (filename line-num line-count)
  "Set presence.
Argument FILENAME Name of current buffer.
Argument LINE-NUM Line number the pointer is located at.
Argument LINE-COUNT Total number of lines in buffer."
  (setf elcord-activity `(
                   ("assets" . (
                                ("large_image" . "emacs_icon")
                                ("large_text" . "Use this!")
                                ("small_image" . "vim_small")
                                ("small_text" . "Not this!")
                                ))
                   ("details" . ,(concat "Editing " filename))
                   ("state" . ,(concat "Line " (number-to-string line-num)))
                   ("party" . (
                               ("id" . "theonlyeditor")
                               ("size" . [,line-num ,line-count])
                               ))
                   ("secrets" . (
                                 ("join" . "yesuseemacswithmepls")
                                 ("match" . "emacsisbest")
                                 ("spectate" . "stupidvimuseruseemacs")
                                 ))
                   ))
  (setf elcord-nonce (format-time-string "%s"))
  (setf elcord-presence `(
                   ("cmd" . "SET_ACTIVITY")
                   ("args" . (("activity" . ,elcord-activity)
                              ("pid" . ,elcord-pid)))
                   ("nonce" . ,elcord-nonce)
                   ))
  (elcord-send-packet 1 elcord-presence)
  )

(defvar elcord-discord-socket (concat (or (getenv "XDG_RUNTIME_DIR") (getenv "TMPDIR") (getenv "TMP") (getenv "TEMP") "/tmp") "/discord-ipc-0"))

(if (eq system-type "windows-nt")
    (setf elcord-discord-socket "\\\\?\\pipe\\discord-ipc-0"))

(defvar elcord-sock (make-network-process :name "elcord-sock"
                      :remote elcord-discord-socket
                      :sentinel 'elcord-on-connect
                      :filter 'elcord-on-connect))
(set-process-query-on-exit-flag elcord-sock nil)
(message "Sending Discord IPC handshake...")
(elcord-send-packet 0 `(("v" . 1) ("client_id" . ,elcord-client_id)))
(defun elcord-command-hook ()
  "Check if we changed our current line..."
  (if (or (eq 'next-line this-command)
          (eq 'evil-ret this-command)
          (eq 'previous-line this-command)
          (eq 'newline this-command)
          (eq 'scroll-up-command this-command)
          (eq 'scroll-down-command this-command))
      ; We get ratelimited.... really... really... REALLY hard.... *Good thing that the client makes sure we don't hit the rate limit and doesn't queue presences!*
      (elcord-setpresence (buffer-name) (count-lines 1 (point)) (count-lines (point-min) (point-max))))
  )
; We have this hook which is called whenever like anything at all happens and we check if it changed the line#...
(add-hook 'post-command-hook 'elcord-command-hook)

;;; elcord.el ends here
(require 'ert)
(require 'flx)


;; for "every" function
(require 'cl)

(ert-deftest flx-test-sanity ()
  "sanity check."
  (should (= 1 1)))

(ert-deftest flx-get-hash-for-string ()
  (let ((h (flx-get-hash-for-string "aab" 'flx-get-heatmap-str))
        (count 0))
    (should (equal '(0 1) (gethash ?a h) ))
    (should (equal '(2) (gethash ?b h)))
    (maphash (lambda (k v)
               (incf count))
             h)
    (should (= 3 count))))

(ert-deftest flx-is-boundary ()
  (should (flx-is-boundary ?/ ?a))
  (should (flx-is-boundary nil ?a))
  (should-not (flx-is-boundary ?a ?/))
  (should (flx-is-boundary ?/ ?A))
  (should (flx-is-boundary ?a ?A)))

(ert-deftest flx-is-capital ()
  (should (flx-is-capital ?A))
  (should (flx-is-capital ?Z))
  (should-not (flx-is-capital ?_))
  (should-not (flx-is-capital ?a)))

(ert-deftest flx-is-word ()
  (should (flx-is-word ?a))
  (should (flx-is-word ?A))
  (should-not (flx-is-word ?_)))

(ert-deftest flx-inc-vec ()
  "roll and unroll should be bring back original score"
  (let ((vec (vector 1 2 3)))
    (should (equal (vector 2 3 4) (flx-inc-vec vec)))))

(ert-deftest flx-matches-basic ()
  (let* ((str "aggg")
         (h (flx-get-hash-for-string str 'flx-get-heatmap-str))
         (res (flx-get-matches h "g")))
    (should (equal res '((1) (2) (3))))))


(ert-deftest flx-matches-more ()
  (let* ((str "ab-gh-ab")
         (h (flx-get-hash-for-string str 'flx-get-heatmap-str))
         (res (flx-get-matches h "ab")))
    (should (equal res '((0 1)
                         (0 7)
                         (6 7))))))

(ert-deftest flx-get-heatmap-vector-basic ()
  "see worksheet for derivation"
  (let ((res (flx-get-heatmap-file "__abcab")))
    (should (equal res [84 81 78 -8 -9 -10 -10])))
  (let ((res (flx-get-heatmap-file "ab_cde-fghi")))
    (should (equal res [82 -4 -5 79 -7 -8 -9 76 -10 -11 -11])))
  (let ((res (flx-get-heatmap-file "xyz/ab_cde-fghi")))
    (should (equal res [43 -43 -44 -45 78 -8 -9 75 -11 -12 -13 72 -14 -15 -15])))
  (let ((res (flx-get-heatmap-file "ab_cde-fghi/x")))
    (should (equal res [43 -43 -44 40 -46 -47 -48 37 -49 -50 -51 -52 81])))
  (let ((res (flx-get-heatmap-file "1/ab_cde-fghi/x")))
    (should (equal res [41 -45 39 -47 -48 36 -50 -51 -52 33 -53 -54 -55 -56 80])))
  (let ((res (flx-get-heatmap-file "ab_cd/ef/g_h/i")))
    (should (equal res [39 -47 -48 36 -50 -51 37 -49 -50 38 -48 35 -51 79])))
  (let ((res (flx-get-heatmap-file "a/b/c/d/e/f/g/h/i/j/k")))
    (should (equal res [25 -61 23 -63 24 -62 25 -61 26 -60 27 -59 28 -58 29 -57 30 -56 31 -55 72])))
  (let ((res (flx-get-heatmap-file "a/cd.ef")))
    (should (equal res [43 -43 79 -7 -8 31 -9]))))


(ert-deftest flx-score-basic ()
  "basic scoring -- matches get number, non-matches get nil"
  ;; matches
  (mapc (lambda (str)
          (should (flx-score str "a" (flx-make-filename-cache))))
        '("a"
          "ba"
          "ab"
          ".a"
          "aaaa"
          "foo.bra"
          "a/foo"
          "b/a/foo"
          "b/.a/foo"
          "b/.a./foo"))
  ;; empty string should not match anything
  (mapc (lambda (str)
          (should-not (flx-score str "" (flx-make-filename-cache))))
        '(""
          "zz"
          "."))
  ;; non-matches
  (mapc (lambda (str)
          (should-not (flx-score str "a" (flx-make-filename-cache))))
        '(""
          "zz"
          ".")))


(ert-deftest flx-score-string ()
  "score as string"
  (let ((string-as-path-score (flx-score "a/b" "a" (flx-make-string-cache)))
        (string-score (flx-score "a_b" "a" (flx-make-string-cache))))
    (should (= (car string-as-path-score)
               (car string-score)))))


(ert-deftest flx-basename-entire ()
  "whole match is preferred"
  (let* ((query "a")
         (higher (flx-score "a" query (flx-make-filename-cache)))
         (lower (flx-score "ab" query (flx-make-filename-cache))))
    (should (> (car higher) (car lower)))))

(ert-deftest flx-basename-order ()
  "index of match matters"
  (let* ((query "a")
         (higher (flx-score "a_b_c" query (flx-make-filename-cache)))
         (lower (flx-score "b_a_c" query (flx-make-filename-cache))))
    (should (> (car higher) (car lower)))))

(ert-deftest flx-basename-lead-separators ()
  "leading word separators should be penalized"
  (let* ((query "a")
         (higher (flx-score "ab" query (flx-make-filename-cache)))
         (lower (flx-score "_ab" query (flx-make-filename-cache))))
    (should (> (car higher) (car lower)))))


;;;;;;;;;;;;;;
;; advanced ;;
;;;;;;;;;;;;;;

(ert-deftest flx-filename-non-anchored-substring-yields-better ()
  "Preferring to match beginning-of-word can lead to wrong answers.

In this case, the match with more contiguous characters is better."
  (let* ((query "abcd")
         (higher (flx-score "f a fbcd/fabcd/z" query (flx-make-filename-cache)))
         (lower (flx-score "f a fbcd/z" query (flx-make-filename-cache))))
    (should (> (car higher) (car lower)))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; imported from Command-t tests ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(ert-deftest flx-imported-prioritizes-matches-with-more-matching-characters ()
  (let* ((str "foobar")
         (higher (flx-score str "fbar" (flx-make-filename-cache)))
         (lower (flx-score str "fb" (flx-make-filename-cache))))
    (should (> (car higher) (car lower)))))

(ert-deftest flx-imported-prioritizes-shorter-paths-over-longer-ones ()
  (let* ((query "art")
         (higher (flx-score "articles.rb" query (flx-make-filename-cache)))
         (lower (flx-score "articles_controller_spec.rb" query (flx-make-filename-cache))))
    (should (> (car higher) (car lower)))))


;;; I've had to modify these test heavily, every assertion Command-t
;;; makes, we've gone the opposite way.  :)
;;;
;;; We strongly prefer basename matches, where as they do not.
(ert-deftest flx-imported-prioritizes-matches-after-/ ()
  (let ((query "b"))
    (let ((higher (flx-score "foo/bar" query (flx-make-filename-cache)))
          (lower (flx-score "foobar" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))
    (let ((higher (flx-score "foo/bar" query (flx-make-filename-cache)))
          (lower (flx-score "foo9bar" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))
    (let ((higher (flx-score "foo/bar" query (flx-make-filename-cache)))
          (lower (flx-score "foo.bar" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))))



(ert-deftest flx-imported-prioritizes-matches-after-- ()
  (let ((query "b"))
    (let ((higher (flx-score "foo-bar" query (flx-make-filename-cache)))
          (lower (flx-score "foobar" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))
    (let ((higher (flx-score "foo-bar" query (flx-make-filename-cache)))
          (lower (flx-score "foo.bar" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))))

(ert-deftest flx-imported-prioritizes-matches-after-_ ()
  (let ((query "b"))
    (let ((higher (flx-score "foo_bar" query (flx-make-filename-cache)))
          (lower (flx-score "foobar" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))
    (let ((higher (flx-score "foo_bar" query (flx-make-filename-cache)))
          (lower (flx-score "foo.bar" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))))

(ert-deftest flx-imported-prioritizes-matches-after-space ()
  (let ((query "b"))
    (let ((higher (flx-score "foo bar" query (flx-make-filename-cache)))
          (lower (flx-score "foobar" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))
    (let ((higher (flx-score "foo bar" query (flx-make-filename-cache)))
          (lower (flx-score "foo.bar" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))))

(ert-deftest flx-imported-prioritizes-matches-after-periods ()
  (let ((query "b"))
    (let ((higher (flx-score "foo.bar" query (flx-make-filename-cache)))
          (lower (flx-score "foobar" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))))

(ert-deftest flx-imported-prioritizes-matching-capitals-following-lowercase ()
  (let ((query "b"))
    (let ((higher (flx-score "fooBar" query (flx-make-filename-cache)))
          (lower (flx-score "foobar" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))))

(ert-deftest prioritizes-matches-earlier-in-the-string ()
  (let ((query "b"))
    (let ((higher (flx-score "**b*****" query (flx-make-filename-cache)))
          (lower (flx-score "******b*" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))))


(ert-deftest flx-imported-prioritizes-matches-closer-to-previous-matches ()
  (let ((query "bc"))
    (let ((higher (flx-score "**bc****" query (flx-make-filename-cache)))
          (lower (flx-score "**b***c*" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))))


(ert-deftest flx-imported-scores-alternative-matches-of-same-path-differently ()
  (let ((query "artcon"))
    (let ((higher (flx-score "***/***********/art*****_con*******.**" query (flx-make-filename-cache)))
          (lower (flx-score "a**/****r******/**t*c***_*on*******.**" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))))

(ert-deftest flx-imported-provides-intuitive-results-for-artcon-and-articles_controller ()
  (let ((query "artcon"))
    (let ((higher (flx-score "app/controllers/articles_controller.rb" query (flx-make-filename-cache)))
          (lower (flx-score "app/controllers/heartbeat_controller.rb" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))))

(ert-deftest flx-imported-provides-intuitive-results-for-aca-and-a/c/articles_controller ()
  (let ((query "aca"))
    (let ((lower (flx-score "app/controllers/heartbeat_controller.rb" query (flx-make-filename-cache)))
          (higher (flx-score "app/controllers/articles_controller.rb" query (flx-make-filename-cache)))
          (best   (flx-score "a**/c**********/a******************.**" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower)))
      ;; our best is a higher score than higher because we penalize higher for
      ;; having one more word.
      (should (> (car best) (car higher))))))


(ert-deftest flx-imported-provides-intuitive-results-for-d-and-doc/command-t.txt ()
  (let ((query "d"))
    (let ((higher (flx-score "TODO" query (flx-make-filename-cache)))
          (lower (flx-score "doc/command-t.txt" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))))

(ert-deftest flx-imported-provides-intuitive-results-for-do-and-doc/command-t.txt ()
  (let ((query "do"))
    ;; This test is flipped around, because we consider capitals to always be
    ;; word starters, and we very heavily favor basepath matches.
    (let ((higher (flx-score "TODO" query (flx-make-filename-cache)))
          (lower (flx-score "doc/command-t.txt" query (flx-make-filename-cache))))
      (should (> (car higher) (car lower))))))


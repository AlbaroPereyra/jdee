;;; Package --- Tests of jdee in-house parsing
;;; Commentary:
;;; Code:

(require 'ert)
(require 'jdee-parse)
(require 'load-relative)

;; TODO: Refactor the framework into a separate file to be required.
(defconst jdee-test-project-1-dir (relative-expand-file-name "../../jdee-test/project-1/")
  "Directory for project-1 test code")
(defconst jdee-test-this-dir (relative-expand-file-name "./")
  "Directory containing this test code")

(defmacro jdee-test-with-jdee-buffer (content directory &rest body)
  "Evaluate BODY in a temporary buffer with CONTENT.
If DIRECTORY is non-nil, it used as the current directory for the test."
  (declare (debug t)
           (indent 2))
  `(with-temp-buffer
     (insert ,content)
     (let ((jdee-mode-hook nil)
           (java-mode-hook nil)
           (c-mode-common-hook nil)
           (prog-mode-hook nil)
           (buffer-file-name (concat
                              (if ,directory
                                  (concat ,directory "/")
                                jdee-test-this-dir)
                              "Temp.java")))
       (jdee-mode)
       (goto-char (point-min))
       ,@body)))

(defmacro jdee-test-with-existing-class (class &rest body)
  "Fake CLASS being defined and run BODY"
  (declare (debug t)
           (indent 1))
  `(let ((advice-name (concat "class-exists-" ,class)))
     (unwind-protect
       (progn
        ;; Add advice to make the class be defined
        (advice-add
         'jdee-parse-class-exists
          :before-until
          (lambda (name)
            (string-equal name ,class))
          '((name . advice-name)))
        ,@body)
       ;; When done, remove the advice
       (advice-remove #'jdee-parse-class-exists advice-name))))

(ert-deftest jdee-parse-find-decl-same-name ()
  "Test that `jdee-parse-find-declaration-of' works when the variable and the
class have the same name, but different spellings."

  (jdee-test-with-jdee-buffer
      ;; Insert a basic class
      "class Testing {
 private String string;
}"
      nil

    ;; Check that we find it, looking forward and backwards
    (dolist (spot (list (point-max) (point-min)))
      (goto-char spot)

      (let ((start (jdee-parse-find-declaration-of "string")))
        (should start)
        (goto-char start)
        (message "Declaration: %s" (buffer-substring-no-properties start (point-max)))
        (should (looking-at "String string"))))))



(ert-deftest jdee-complete-on-newline ()
  "Test that `jdee-complete' works when there is a newline between the previous text and the point."

  (jdee-test-with-jdee-buffer

    ;; Insert a basic class
   "class Testing {

     public String someString() { return \"some\"; }

     public String foo() {
         someString().

         // Point on previous line

     }

}"
      nil

    ;; Goto to line after text
    (goto-char (point-min))
    (search-forward "previous line")
    (forward-line -1)

    ;; Find the variable we are completing
    (let ((pair (jdee-parse-java-variable-at-point)))
      (should (equal '("someString" "") pair)))))


(ert-deftest jdee-parse-partial-value ()
  "Parsing of partly written method call"

  (jdee-test-with-jdee-buffer
      "class Testing {
  void foo() {
     String s = null;
     s.get

}
}"
      nil
    (goto-char (point-min))
    (search-forward "s.get")
    (goto-char (match-end 0))
    (let ((pair (jdee-parse-java-variable-at-point)))
      (should (equal '("s" "get") pair))
      (goto-char jdee-parse-current-beginning)
      (should (looking-at "get"))
      (should (= (+ jdee-parse-current-beginning 3) jdee-parse-current-end)))))


(ert-deftest jdee-parse-method-from-class ()
  "Completion of 'static_method().'"

  (message "running jdee-parse-method-from-class")
  (jdee-test-with-jdee-buffer
      "class Testing {
private static String hello() { return \"Hello\"; }


}"
      nil

    (jdee-test-with-existing-class "Testing"
      ;; Put the class-info into the cache
      (let ((jdee-complete-classinfo-cache
             '(("Testing"
                ;; Public
                ((nil
                  (("Testing" nil)) ;; Constructors
                  (("hello" "java.lang.String" nil)) ;; Methods
                  nil)
                 (nil nil nil nil) ;; Protected
                 (nil nil nil nil) ;; Package
                 (nil nil nil nil) ;; Private
                )))))
        (search-forward "hello") ;; Parse only checks classes that the point is inside
        (should (equal (jdee-parse-eval-type-of "hello().") "java.lang.String"))))))

(ert-deftest jdee-parse-split-line-style ()
  "Parsing of an expression split over multiple lines:
    foo().
    bar().
    b"

  (message "Running jdee-parse-split-line-style")

  (jdee-test-with-jdee-buffer
      "class Testing {
             Testing() {
               foo().
               bar().
               b
      }"
      nil

    (goto-char (point-min))
    (search-forward-regexp "b$")
    (end-of-line)

    (let ((pair (jdee-parse-java-variable-at-point)))
      (should (string-equal (car pair) "foo().bar"))
      (should (string-equal (cadr pair) "b")))))

(ert-deftest jdee-parse-modifiers ()
  "Parsing of single line expression declaring a variable"
  (message "Running jdee-parse-modifiers")

  (jdee-test-with-jdee-buffer
   "class Testing {
       private final String foo;
    }"


   (message "Figure out how this fails and write the test")))

(ert-deftest jdee-parse-inner-enum ()
  "Parsing of a nested enum"

  (message "Runnign jdee-parse-inner-enum")

  (jdee-test-with-jdee-buffer
      "class Testing {
       private final String foo;
    }"
      jdee-test-project-1-dir

    (let ((qual  (jdee-parse-get-qualified-name "InnerEnum" 'import)))
     (should (string-equal qual "uk.org.russet.Outer.InnerEnum")))))

(ert-deftest jdee-complete-inner-enum ()
  "Class lookup of an inner enum"

  (message "Running jdee-complete-inner-enum")

  (jdee-test-with-jdee-buffer
      "class Testing {
       private final String foo;
    }"
      jdee-test-project-1-dir

    (let ((info  (jdee-complete-get-classinfo "uk.org.russet.Outer.InnerEnum")))
      (message "Info %s" info)
      (should info))))


(provide 'jdee-parse-test)
;;; jdee-parse-test.el ends here


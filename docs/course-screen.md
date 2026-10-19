# The course screen

`CourseController.j` builds it: a `CPSplitView` with the left column (revision header and problem tree) and the problem on the right.

## Loading

`GET /courses/<id>` gives the section tree, which becomes a `CourseTree`; `GET /courses/<id>/progress` gives what is solved. Then `-showProblemId:revisionMode:` shows the problem the URL names. Without a problem in the URL, it replaces the URL with the first problem not solved in the round shown, and the router comes back.

A problem is fetched when it is shown (`GET .../problems/<pid>`, with `?round=N` in a revision). Answers to requests for a problem or round the learner has already left are ignored.

## The tree

`SidebarController` drives a `CPOutlineView` from `CourseTree`:

- Sections are rows that open and close when clicked; they cannot be selected. Top-level sections start open, and the sections around the current problem are opened.
- A problem's row is `CourseTreeProblemLabel(title, solved, timesSolved, revisionMode)`: a tick (✓) or circle (○) for the round being shown, then "×N", the number of rounds it has been solved in. The count shows from two on; in revision mode also at one, which marks what was solved before.
- Selecting a row changes the URL; the controller then selects it programmatically, guarded so that this does not loop.

`CourseTree` orders problems as the backend does: a section's own problems before its subsections'.

## The problem

`ProblemView` stacks, top to bottom: the title (green with a ✓ when solved in this round), previous and next buttons (titled with those problems' names), the body, the question, a radio button per choice, "Check answer", and feedback. It lays itself out in `-layoutSubviews`, measures wrapped text with `sizeWithFont:inWidth:`, keeps text at most 760 pixels wide, and grows so that its scroll view can scroll.

Problem text is plain, written in YAML with line breaks wherever the author wrapped. `TextFormatBlocks` (TextFormat.j) splits it into prose and code:

- Prose: the lines of a paragraph are joined. A line starting a list item (`- `, `* `, `1. `) keeps its own line, and indented lines after it, indented no deeper than the item's text, continue it.
- Code: any other indented line. Neighbouring code lines, and code paragraphs separated only by blank lines, make one block, with their common indentation removed.

`RichTextView` shows the prose in labels and each code block in a `CodeBlockView`: CodeMirror, read-only, highlighted as the problem's `language` (for multiple choice, the course's), selectable and copyable, and as tall as its content. Until the editor script has loaded, a block shows the code plain in the same font and line height, so nothing moves when it is replaced. The body, the question and the feedback (with the explanation after a correct answer) are all `RichTextView`s; `CourseController` passes the explanation unformatted.

The wheel is not stopped over a code block, unlike over an editor, so the page scrolls with the pointer on one.

Answering a multiple choice question posts `{choice, round}`. A correct answer returns the new progress, which redraws the tree and the header. When the answer completes the round, the feedback adds "Course complete!" or "Revision complete!" and the number of times completed.

## Code problems

For `type: "code"`, `ProblemView` shows a `CodeEditor` holding the problem's `starter_code` instead of radio buttons, then **Run** and **Check answer**, then the output in a grey box. How programs run is in runtimes.md.

- **Run** runs the program and shows what it printed, and any error, in full: for a compiled language, everything the compiler said. While a runtime downloads or compiles, the output box shows what it is doing ("Downloading the Zig compiler…", "Compiling…"). Nothing is sent to the backend.
- **Check answer** runs it too, and if it ran to the end posts `{output, round}` with its stdout. A program that failed is not sent: the learner is told to fix the error. A timeout is shown as such.
- While a program runs, both buttons are disabled. Showing another problem abandons the run.
- The question is reflowed like the body, so an indented line in it (the exact text to print) keeps its own line.
- What the learner typed is lost when they go to another problem or reload; the editor starts from `starter_code` each time.

### Run on the learner's computer

A code problem with `run: "local"` is for a language the browser cannot run (Rust). There is no Run button: the code is shown to read, with **Copy code** (the clipboard API; if the browser refuses, the learner is told to select and copy it), then a box headed "What your program printed:" for the output pasted back, then **Check answer**, which posts `{output, round}` with what was pasted. The code editor is only as tall as the code, up to the usual height. The paste box is a plain `CodeEditor` (`-initWithFrame:plain:`): no line numbers or highlighting.

Learners may paste a whole terminal; the backend leaves out what Cargo printed before the program's output.

The editor is CodeMirror 6 (runtimes.md): Ruby highlighting, line numbers, bracket matching and closing, undo, and indentation as you type (Return indents inside a block, typing `end` takes it back out). Tab indents; Escape then Tab leaves the editor, which is CodeMirror's way of not trapping keyboard users.

## Revision mode

Above the tree, a header with:

- **Revision mode**, a checkbox. It does not change anything itself: it navigates between `#/courses/...` and `#/revise/...`, and the controller then sets the checkbox to match. Revision mode without a revision (the first time, or a hand-typed URL) starts one with `POST /courses/<id>/revisions`.
- **?**, which opens a `CPPopover` explaining revision mode. The text is `REVISION_HELP` at the top of `CourseController.j`.
- A status line: "Completed 2 times" or "Not completed yet"; in revision mode, "Revision 1: 3 / 6 solved". Revision numbers shown to the learner start at 1 (the backend's round 2).
- **Start over**, in revision mode: after a confirmation, starts the next revision. An unfinished one is left behind.

In a revision, the backend returns the choices shuffled, in an order fixed for that revision; the app needs nothing special for that.

The course menu and My progress show, per course, "x / y solved · completed N times", and while a revision is running its progress and a "Continue revision of <course>" button.

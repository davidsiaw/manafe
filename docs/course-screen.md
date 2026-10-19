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

Problem text is plain, written in YAML with line breaks wherever the author wrapped. `TextFormatReflow` joins the lines of a paragraph, and keeps lines that are indented (code) or start a list item on their own. The explanation after a correct answer is reflowed the same way.

Answering posts `{choice, round}`. A correct answer returns the new progress, which redraws the tree and the header. When the answer completes the round, the feedback adds "Course complete!" or "Revision complete!" and the number of times completed.

## Revision mode

Above the tree, a header with:

- **Revision mode**, a checkbox. It does not change anything itself: it navigates between `#/courses/...` and `#/revise/...`, and the controller then sets the checkbox to match. Revision mode without a revision (the first time, or a hand-typed URL) starts one with `POST /courses/<id>/revisions`.
- **?**, which opens a `CPPopover` explaining revision mode. The text is `REVISION_HELP` at the top of `CourseController.j`.
- A status line: "Completed 2 times" or "Not completed yet"; in revision mode, "Revision 1: 3 / 6 solved". Revision numbers shown to the learner start at 1 (the backend's round 2).
- **Start over**, in revision mode: after a confirmation, starts the next revision. An unfinished one is left behind.

In a revision, the backend returns the choices shuffled, in an order fixed for that revision; the app needs nothing special for that.

The course menu and My progress show, per course, "x / y solved · completed N times", and while a revision is running its progress and a "Continue revision of <course>" button.

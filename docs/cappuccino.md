# Cappuccino: what has surprised us

AppKit in Cappuccino behaves like Cocoa most of the time. These are the places where it did not do what we expected. Objective-J basics and the toolchain are in chino.md.

- **Redraw after asynchronous callbacks.** AppKit only updates the screen inside its run loop. Code called from `XMLHttpRequest`, a promise or `hashchange` must end with `[[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode]`, or changes appear late, on the next mouse movement. `ApiClient`, `Passkeys.j` and the hash listener do this.
- **Radio buttons need a shared action to be exclusive.** When a `CPRadio` is added to a view, it is grouped with the radios in that view that have the same action; a radio without an action gets a group of its own, so several can be on at once. Passing a group to `initWithFrame:radioGroup:` does not prevent the regrouping, and passing nil creates no group at all. Give every radio of a question the same target and action (`ProblemView` uses `-choiceChanged:`).
- **Hidden is not removed.** A hidden view keeps its subviews attached, and they still answer to view walks. Check `isHiddenOrHasHiddenAncestor`.
- **Lay out children from the parent's `bounds`.** `[view center]` is in the superview's coordinates: it works the first time and breaks on the next relayout.
- **Views that grow with their content** (`ProblemView`, `PageView`) set their own height at the end of `-layoutSubviews`, only when it changed, or they lay out forever. Measure wrapped text with `[string sizeWithFont:font inWidth:width]`, and allow 8 pixels for `CPTextField`'s padding.
- **CPOutlineView needs a column width.** A column created without one is narrow, and titles are cut off. Set the width and an autoresizing mask.
- **Programmatic selection calls the delegate.** `selectRowIndexes:` triggers `outlineViewSelectionDidChange:`; guard it (`_selectingProgrammatically`) if the delegate navigates.
- **Checkboxes and the spec helpers.** `click_cappuccino_button` sends the action without changing the checkbox's state, unlike a real click. Do not read `[sender state]` in the action; decide from the app's own state (see `-toggleRevisionMode:`).
- **CPAlert** has `runModalWithDidEndBlock:`; the return code is the index of the button pressed, starting at 0.
- **CPPopover**: give it a `CPViewController` whose view has a fixed size, `CPPopoverBehaviorTransient` to close on outside clicks, and show it with `showRelativeToRect:nil ofView:button preferredEdge:CPMaxXEdge`.
- **Storing context on a control.** The code sets plain JavaScript properties on controls (`button._course = summary`) to know which item was clicked. Objective-J objects are JavaScript objects, so this works; prefix such properties with an underscore.

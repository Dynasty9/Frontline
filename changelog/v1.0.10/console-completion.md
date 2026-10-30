+++
title = "Find console commands as you type"
summary = "Find console commands and their arguments through suggestions that narrow as you type."
kind = "improved"


[[screenshots]]
file = "after.jpg"
caption = "Browse the full command list without leaving the console."

[layout_comparison]
before = "layout-before.jpg"
after = "layout-after.jpg"
caption = "Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it."
+++

A scrollable command dropdown lists every command, then narrows to fuzzy matches and argument suggestions as you type.

- An empty prompt shows every command with its description in a scrollable dropdown.
- Typing finds close matches, including partial spellings and small typos. Arguments get suggestions too.
- Use Up/Down to choose, then Tab or Enter to insert; you can also click a suggestion. Inserting never executes it.
- Ctrl+Up/Down browses your command history. Esc dismisses suggestions before closing the console.
- Completing in the middle of a line keeps the arguments that follow it.

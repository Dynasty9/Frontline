+++
title = "Keep large interfaces within reach"
summary = "Keep menus, controls and multiplayer rosters reachable in small windows and at large interface scales."
kind = "fixed"


[[screenshots]]
file = "lobby-after.jpg"
caption = "After: the roster scrolls while Start and Close stay clearly in view."

[[screenshots]]
file = "lobby-before.jpg"
caption = "Before: a full co-op roster pushes the lobby actions into the bottom edge."


[[screenshots]]
file = "controls-before.jpg"
caption = "Before: maximum interface scale pushes the Controls dialog beyond the window."

[[screenshots]]
file = "controls-after.jpg"
caption = "After: the dialog fits the window and its contents can be scrolled."

[layout_comparison]
before = "layout-before.jpg"
after = "layout-after.jpg"
caption = "Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it."
+++

Pause menus, controls, lobby rosters and the server browser stay usable at maximum interface scale and in small windows.

- Pause and controls dialogs scroll when their contents cannot fit, with focused buttons brought into view.
- Full eight-player lobby rosters scroll without pushing Join, Ready, Start or Leave out of reach.
- Server-browser filters and direct-connect fields wrap instead of forcing the screen wider than the window.
- Repeatedly opening a dialog no longer shifts its resting position. Resizing during its opening animation keeps it centered.

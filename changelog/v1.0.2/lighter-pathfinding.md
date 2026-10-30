+++
title = "Battles use less memory"
summary = "Battles use less memory for route planning while units follow the same routes."
kind = "improved"

[layout_comparison]
before = "layout-before.jpg"
after = "layout-after.jpg"
caption = "Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it."
+++

Route planning keeps much less of the map in memory at once, so a battle needs about 120 MB less. Units find exactly the same routes as before.

- A battle now takes about 120 MB less memory, which matters most in the browser, where a page can't use more than
  2 GB.
- Units take exactly the same routes as before.

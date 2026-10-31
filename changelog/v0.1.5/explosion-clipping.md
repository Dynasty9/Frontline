+++
title = "No more distortion when shells land together"
summary = "Overlapping explosions no longer overload the sound output and distort."
kind = "fixed"

[layout_comparison]
before = "layout-before.jpg"
after = "layout-after.jpg"
caption = "Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it."
+++

When several explosions went off at once the sound could clip. A limiter on the master volume now holds it just under the top, and everyday levels are unchanged.



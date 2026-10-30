+++
title = "Website links work again after an uninstall"
summary = "Starting Frontline restores its website links if another uninstall or system cleanup removed them."
kind = "fixed"
+++

If the links from the website were taken away (uninstalling another copy of Frontline, or a registry cleaner), the game never claimed them back, so Join, Find Match and signing in on the website did nothing. Starting the game sets them up again now.

- Each time it starts, the game checks that your system still opens website links with it, and sets them up again
  if not.
- With more than one copy of the game, links open the one you started last.

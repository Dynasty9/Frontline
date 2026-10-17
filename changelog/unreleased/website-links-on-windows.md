+++
title = "The website opens the game on Windows, and signing in says what's happening"
summary = "On Windows the website's Launch, Join and Find Match buttons, and its sign-in for the game, never reached the game: it couldn't set itself up to take them. Now it can, and signing in from the game shows each step as it goes."
kind = "fixed"

[[screenshots]]
file = "game-sign-in.jpg"
caption = "Signing in from the game: the steps, and the one you're on"
+++

- **Fixed:** on Windows, the game never managed to set itself up to open the website's links, so Launch Frontline,
  Join, Find Match and the sign-in handed back from the website did nothing. Start the game once after it updates
  and they all work.
- **Signing in from the game** lists the steps (sign in with GitHub on the website, let your browser open
  Frontline, the game signs in) and shows which one you're on, with a line that keeps moving while it waits for the
  website. When the website hands the sign-in back it says it's signing in; if something went wrong it says what,
  with a Try again button.
- **On the website**, after you sign in for the game it shows the two steps, and whether your browser opened the
  game. If it didn't, it says what to do, with a button to open it again.

+++
title = "No network error when more players join"
summary = "Additional players can join a multiplayer battle without triggering network errors for everyone else."
kind = "fixed"
+++

In a battle with three or more players, everyone else's game reported a network error each time another player joined. It no longer does.

- **More players:** a third or later player joining no longer sets off an error on the other players' games.
- **Long map builds:** every player's connection to the host still waits patiently while the host lays out the map,
  so nobody is dropped before the battle starts.

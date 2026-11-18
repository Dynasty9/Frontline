+++
title = "No more stutter when parked cars and wrecks come into view"
summary = "Panning across a town froze the picture for a tenth to a quarter of a second each time a parked car or a burnt-out tank came into view. Now a car is put together over a few frames, and wrecks and cars that look alike are copied."
kind = "improved"
+++

- A car coming into view costs at most a few hundredths of a second spread over a few frames, where it used to cost 100-290 ms in one. It appears a fraction of a second later instead.
- Burnt-out tanks are all the same hulk, so every one after the first is copied in about 5 ms instead of built in about 190. Cars of the same model and paint are copied the same way.
- Battles load a little faster too: the map's hulks used to take nearly two seconds of the load.
- Cars and wrecks look exactly as before.

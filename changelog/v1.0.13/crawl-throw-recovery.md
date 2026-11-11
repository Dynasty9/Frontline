+++
title = "Crawl, throw and crouch recovery fixes"
summary = "Reach forward while crawling, keep grenade throws grounded, and settle crouched feet without inverted toes."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Before: the crawl fallback folds the hands behind the shoulders."

[[screenshots]]
file = "after.jpg"
caption = "After: forward-reaching crawl arms with palms facing the ground."

[[videos]]
file = "recovery.mp4"
poster = "after.jpg"
caption = "Controlled shared-renderer sequence: crawl, recover, throw, crouch walk and stop."
+++

The optional imported rifleman now reaches forward with alternating crawl arms and ground-facing palms. Crawling remains procedural; it is not a new captured animation.

Grenade throws use the installed Mixamo toss with the current stance underneath it, and the grenade follows the throwing hand until release. Crouch stops settle the toes and keep knees bending forward. Getting up releases old prone foot anchors.

The video uses fixed-step capture in a controlled preview with actual character translation. It demonstrates these transitions, not full battle performance or every terrain combination.

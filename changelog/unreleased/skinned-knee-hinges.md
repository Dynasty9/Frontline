+++
title = "Ragdoll knees follow the captured leg bend"
summary = "Skinned knee constraints now align to the character's actual leg pose at death."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Before: standing bullet collapse with fixed knee frames."

[[screenshots]]
file = "after.jpg"
caption = "After: the same impact with knees aligned to the captured bend plane."
+++

The knee hinge is calibrated from the thigh and shin directions at handoff, retaining its existing flexion and sideways limits. Nearly straight legs retain the rest-frame fallback. Standing, crouching, captured prone, and the older character's standing fixture retain the existing collision and skin checks. Early physics separation remains unfinished.

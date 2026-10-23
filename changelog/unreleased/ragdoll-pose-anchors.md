+++
title = "Ragdoll attachments match the animated pose"
summary = "Prototype skinned ragdolls place their joint attachments from the pose at death."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Previous prone-transition impact with bind-pose attachment offsets."

[[screenshots]]
file = "after.jpg"
caption = "The same impact with attachment positions taken from the captured pose."
+++

Shoulder and spine bones between simulated body parts can move the arm attachment away from its bind-pose location. Ragdoll joints now use captured attachment positions while retaining their existing anatomical rotation reference and limits. The final prone pose previously started with a 12 cm shoulder-anchor mismatch; the corrected configuration starts within 1 mm. First-tick dynamic separation remains under investigation and is reported separately from settled-body checks. Position-solver iterations increase from six to eight to retain settled collision stability; velocity iterations and joint limits are unchanged.

+++
title = "Remove hidden duplicate soldier meshes"
summary = "Skinned riflemen discard the invisible geometry replaced by their character mesh."
kind = "improved"
+++

Successfully loaded skinned riflemen now release unused procedural mesh leaves. Their pose joints and attachment pivots remain available for gameplay animation, and ordinary procedural units retain their geometry.

Motion sampling also reuses normalized orientations when calculating ragdoll momentum, avoiding repeated normalization of the previous pose.

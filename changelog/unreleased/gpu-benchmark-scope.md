+++
title = "Make the GPU benchmark clear about Time passes"
summary = "The stationary GPU benchmark now marks Time passes as unmeasured instead of implying that it can price a moving sky while the battle clock is held."
kind = "fixed"
+++

The report still compares the other graphics settings and restores every setting without saving. Time passes is listed separately, with an explanation that its sky relighting, terrain-shadow rebakes and reflection recaptures need an advancing battle clock. This fixes the benchmark's Cinematic coverage check without claiming a zero cost or a new performance measurement.

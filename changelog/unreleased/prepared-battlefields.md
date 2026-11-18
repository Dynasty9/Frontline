+++
title = "Choose your battlefield"
summary = "Pick Alder Valley, Stonebridge or Highland Junction before deploying. Desktop builds reuse prepared ground and routes to reduce work at loading time."
kind = "new"

[[videos]]
file = "deployment.webm"
poster = "deployment.jpg"
caption = "Select Stonebridge, then Highland Junction, deploy, and arrive at the FOB. Real Compatibility-renderer capture using generated fallback terrain; loading is shown at 45x, selection and arrival at normal speed. This is not a loading-time comparison."

[[videos]]
file = "prepared-entry.webm"
poster = "prepared-entry.jpg"
caption = "Highland Junction entry using a locally validated prepared package. Real software-rendered selection and arrival at 1x; loading at 30x. The host restoration path was checked separately in the capture log. This footage makes no loading-speed or gameplay-performance claim."

[[screenshots]]
file = "battlefields.jpg"
caption = "Alder Valley, Stonebridge and Highland Junction: coastal, river-crossing and dry foothill layouts."

[[screenshots]]
file = "selection.jpg"
caption = "Choose a battlefield before deploying; shown at 960x600 with reduced motion."
+++

- **Alder Valley:** a coastal flank, western river and central town.
- **Stonebridge:** an inland river, with bridges and fords linking the villages.
- **Highland Junction:** dry foothills and country roads, without river crossings.

Choose a map for solo play or when hosting; the host can change it in the lobby.
Every commander joins the same ground. Starting forces belong to the current
players, while campaign missions keep their own layouts.
The browser offers the same layouts, generated on demand to keep its initial
download smaller.

Loading uses more of each frame to prepare scenery and soldier poses before
revealing the battle. The loading bar now tracks that preparation instead of
staying on the completed cover stage. The private simulation skips artwork that
only the player's view needs.
Solo combat starts once the loading screen has faded, including the final
shader warm-up.

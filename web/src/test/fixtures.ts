// Made-up answers from the matchmaker, and a made-up release's changelog, for
// stories and tests. Each lobby is one of the cases the battle list draws
// differently.

import type { Health, Lobby } from "@/lib/matchmaker"
import type { Release } from "@/lib/changelog"

const lobby = (l: Partial<Lobby> & Pick<Lobby, "id" | "name" | "host">): Lobby => ({
  verified: false,
  players: 1,
  max_players: 8,
  in_game: false,
  drop_in: true,
  nat: "cone",
  version: "v0.1.9",
  age: 60,
  ...l,
})

/** Waiting in the lobby, hosted from a signed-in account. */
export const lobbyOpen = lobby({
  id: "a1f0c2d3e4b5",
  name: "Bridgehead at dawn",
  host: "Raven",
  verified: true,
  players: 3,
})

/** Already fighting, but players may drop in. */
export const lobbyDropIn = lobby({
  id: "b2e1d3c4f5a6",
  name: "Armour on the river road",
  host: "Kestrel",
  players: 5,
  in_game: true,
  nat: "open",
  age: 900,
})

/** Behind a router that can't be punched through. */
export const lobbyStrict = lobby({
  id: "c3d2e4f5a6b7",
  name: "Night raid",
  host: "Mole",
  players: 1,
  max_players: 4,
  nat: "strict",
})

/** Fighting, and not letting anyone else in. */
export const lobbyClosed = lobby({
  id: "d4c3f5a6b7c8",
  name: "Kingpin",
  host: "Badger",
  players: 2,
  max_players: 4,
  in_game: true,
  drop_in: false,
  age: 1500,
})

/** No seats left. */
export const lobbyFull = lobby({
  id: "e5b4a6b7c8d9",
  name: "Full house",
  host: "Heron",
  verified: true,
  players: 8,
})

// in the matchmaker's order: fullest first
export const lobbies: Lobby[] = [lobbyFull, lobbyDropIn, lobbyOpen, lobbyClosed, lobbyStrict]

export const health: Health = {
  ok: true,
  accounts: "supabase",
  lobbies: lobbies.length,
  players: lobbies.reduce((n, l) => n + l.players, 0),
}

export const healthQuiet: Health = { ok: true, accounts: "supabase", lobbies: 0, players: 0 }

/** A release with one change of each kind: pictures, a markdown body, and neither. */
export const release: Release = {
  version: "0.2.0",
  tag: "v0.2.0",
  name: "River crossings",
  date: "2026-10-20",
  summary: "Engineers bridge rivers under fire, and boats ferry squads across.",
  url: "https://github.com/Dynasty9/Frontline/releases/tag/v0.2.0",
  pull_requests: [21, 22, 23],
  entries: [
    {
      slug: "bridging",
      title: "Engineers lay bridges",
      kind: "new",
      summary: "Order an engineer squad to a riverbank and it lays a pontoon bridge, a section at a time.",
      body: `- **Under fire** the work stops and the engineers take cover.
- **Tanks** wait for the last section.`,
      screenshots: [
        { url: "/shots/river_bridge.jpg", caption: "A pontoon bridge going out under smoke" },
        { url: "/shots/battle.jpg", caption: "The far bank, taken" },
      ],
    },
    {
      slug: "ferries",
      title: "Boats ferry squads",
      kind: "improved",
      summary: "A patrol boat can carry a squad across and land it on the far bank.",
      body: "",
      screenshots: [],
    },
    {
      slug: "ford-pathing",
      title: "Soldiers find the ford",
      kind: "fixed",
      summary: "Squads no longer wade into deep water looking for the shallow crossing.",
      body: "",
      screenshots: [],
    },
  ],
}

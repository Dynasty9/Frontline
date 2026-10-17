// Made-up answers from the matchmaker, and a made-up release's changelog, for
// stories and tests. Each lobby is one of the cases the battle list draws
// differently.

import type { User } from "@/lib/account"
import { RANKS } from "@/lib/insignia"
import type { Health, Lobby } from "@/lib/matchmaker"
import type { Battle, BattleHead, Board, BoardRow, Career, Figures, PublicPlayer } from "@/lib/players"
import type { Release } from "@/lib/changelog"
import { type Asset, type Build, latest } from "@/lib/releases"

/** A signed-in player a few ranks up: Corporal I, 1,350 XP, wearing the rank 4 patch (Night Watch). */
export const player: User = {
  id: "5f0c1a2b-3c4d-4e5f-8a9b-0c1d2e3f4a5b",
  email: "raven@example.test",
  callsign: "Raven",
  icon: "r04",
  xp: 1350,
  rank: 6,
  rank_xp: 1200,
  next_xp: 1470,
  battles: 23,
  wins: 14,
  avatar: "insignia",
  github_avatar: null,
  hide_history: false,
  joined: "2026-10-02T18:30:00Z",
}

/** The same player signed in with GitHub, their GitHub picture to choose. */
export const githubPlayer: User = {
  ...player,
  github_avatar: "/insignia/s02.svg",
}

/** Raven's public page, as anyone sees it. */
export const ravenPublic: PublicPlayer = {
  callsign: "Raven",
  icon: "r04",
  avatar: null,
  xp: 1350,
  rank: 6,
  rank_xp: 1200,
  next_xp: 1470,
  battles: 23,
  wins: 14,
  joined: "2026-10-02T18:30:00Z",
  history: true,
  position: 4,
  last_seen: new Date(Date.now() - 3 * 3600_000).toISOString(),
}

const row = (
  position: number,
  callsign: string,
  icon: string,
  xp: number,
  battles: number,
  wins: number
): BoardRow => ({
  position,
  callsign,
  icon,
  avatar: null,
  rank: rankOf(xp),
  xp,
  score: xp,
  battles,
  wins,
})

// the XP each rank starts at, as the site's table has it
const rankOf = (xp: number) => {
  let r = 0
  for (const k of RANKS) if (k.xp <= xp) r = k.rank
  return r
}

/** The all-time board: a podium, players level on XP sharing a place, and Raven fourth. */
export const board: Board = {
  board: "xp",
  period: "all",
  page: 1,
  pages: 3,
  per_page: 50,
  total: 128,
  rows: [
    row(1, "Kestrel", "r12", 9_840, 210, 131),
    row(2, "Harrier", "r09", 6_120, 140, 70),
    row(2, "Merlin", "s05", 6_120, 151, 64),
    row(4, "Raven", "r04", 1_350, 23, 14),
    row(5, "Gyr", "s03", 640, 11, 3),
  ],
  me: null,
}

/** The weekly board, with the signed-in player further down it than this page reaches. */
export const weekBoard: Board = {
  ...board,
  period: "week",
  pages: 1,
  total: 61,
  rows: board.rows.slice(0, 3).map((r) => ({ ...r, score: Math.round(r.score / 9) })),
  me: { ...row(57, "Osprey", "s01", 300, 1, 1), score: 45 },
}

const battleHead = (over: Partial<BattleHead> & Pick<BattleHead, "id" | "title">): BattleHead => ({
  played_at: new Date(Date.now() - 86_400_000).toISOString(),
  game_version: "1.0.4",
  mode: "skirmish",
  mission: "",
  side: 0,
  result: "victory",
  duration_s: 1460,
  rating: 71.3,
  score: 640,
  kills: 12,
  lost: 4,
  veh_kills: 2,
  veh_lost: 0,
  shots: 900,
  hits: 120,
  ...over,
})

/** Raven's battles, newest first. */
export const ravenBattles: BattleHead[] = [
  battleHead({
    id: "6c0f4e9a-0000-4000-8000-000000000003",
    title: "Bridgehead",
    mode: "mission",
    mission: "bridgehead",
    result: "defeat",
    rating: 38.2,
    kills: 4,
    lost: 9,
  }),
  battleHead({
    id: "6c0f4e9a-0000-4000-8000-000000000002",
    title: "Co-op vs the AI",
    mode: "coop",
    side: 1,
    rating: 88,
    kills: 20,
    lost: 2,
  }),
  battleHead({
    id: "6c0f4e9a-0000-4000-8000-000000000001",
    title: "Battle vs the AI",
    played_at: new Date(Date.now() - 9 * 86_400_000).toISOString(),
  }),
]

const figures = (f: Figures): Figures => ({ shots: 0, hits: 0, val_killed: 0, val_lost: 0, ...f })

/** The newest battle in full: its after-action report as Raven's game kept it. */
export const ravenBattle: Battle = {
  ...ravenBattles[1],
  me: {
    name: "Raven",
    kills: 20,
    downs: 6,
    lost: 2,
    captured: 0,
    veh_kills: 3,
    veh_lost: 1,
    bld_kills: 2,
    built: 9,
    shots: 1400,
    hits: 190,
    val_killed: 1460,
    spent: 2100,
    support: 2,
    captures: 1,
    towns: 1,
    prisoners: 3,
    revived: 4,
    rating: 88,
    score: 1712,
  },
  report: {
    t: 1460,
    winner: 1,
    me: 7,
    me_team: 1,
    players: [
      {
        id: 7,
        name: "Raven",
        team: 1,
        ...figures({
          kills: 20,
          lost: 2,
          veh_kills: 3,
          veh_lost: 1,
          shots: 1400,
          hits: 190,
          val_killed: 1460,
          val_lost: 300,
          captures: 1,
          towns: 1,
        }),
      },
      {
        id: 9,
        name: "Kite",
        team: 1,
        ...figures({ kills: 9, lost: 5, shots: 800, hits: 70, val_killed: 520, val_lost: 600 }),
      },
      {
        id: -1,
        name: "Coalition AI",
        team: 0,
        ai: true,
        ...figures({
          kills: 7,
          lost: 29,
          veh_kills: 1,
          veh_lost: 3,
          shots: 2600,
          hits: 210,
          val_killed: 900,
          val_lost: 1980,
        }),
      },
    ],
    sides: [
      figures({
        kills: 7,
        downs: 3,
        lost: 29,
        captured: 4,
        veh_kills: 1,
        veh_lost: 3,
        shots: 2600,
        hits: 210,
        val_killed: 900,
        val_lost: 1980,
        spent: 2600,
        squads: 9,
        vehicles: 4,
      }),
      figures({
        kills: 29,
        downs: 11,
        lost: 7,
        captured: 0,
        veh_kills: 3,
        veh_lost: 1,
        shots: 2200,
        hits: 260,
        val_killed: 1980,
        val_lost: 900,
        spent: 3100,
        squads: 11,
        vehicles: 3,
        captures: 1,
        towns: 1,
      }),
    ],
  },
}

/** Raven's career, totalled from those battles. */
export const ravenCareer: Career = {
  battles: 3,
  victories: 2,
  defeats: 1,
  kills: 36,
  lost: 15,
  veh_kills: 6,
  veh_lost: 0,
  shots: 2700,
  hits: 360,
  seconds: 4380,
  score: 1920,
  rating: 65.8,
  best: { id: ravenBattles[1].id, rating: 88, title: "Co-op vs the AI", played_at: ravenBattles[1].played_at },
  sides: [2, 1],
  modes: { skirmish: 1, coop: 1, mission: 1 },
  first: ravenBattles[2].played_at,
  last: ravenBattles[0].played_at,
}

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

/** Waiting in the lobby, hosted from a signed-in account: a mission, played co-op. */
export const lobbyOpen = lobby({
  id: "a1f0c2d3e4b5",
  name: "Bridgehead at dawn",
  host: "Raven",
  verified: true,
  players: 3,
  mode: "mission",
  mission: "Bridgehead",
  side: 0,
  teams: [3, 0],
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
  mode: "versus",
  side: -1,
  teams: [3, 2],
})

/** Behind a router that can't be punched through, and wanting a password. */
export const lobbyStrict = lobby({
  id: "c3d2e4f5a6b7",
  name: "Night raid",
  host: "Mole",
  players: 1,
  max_players: 4,
  nat: "strict",
  mode: "coop",
  side: 1,
  teams: [0, 1],
  locked: true,
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

/** The latest release as it would be with a Mac build, which releases from before it don't have. */
export const buildWithMac: Build = {
  ...latest,
  assets: {
    ...latest.assets,
    macos: {
      name: "Frontline-macos.zip",
      url: latest.assets.windows.url.replace("Frontline-windows.zip", "Frontline-macos.zip"),
      size: 96_000_000,
      sha256: "0".repeat(64),
    },
  },
}

const download = (name: string, size: number): Asset => ({
  name,
  url: latest.assets.windows.url.replace("Frontline-windows.zip", name),
  size,
  sha256: "0".repeat(64),
})

/** The latest release as it would be with installers for Windows and the Mac. */
export const buildWithInstallers: Build = {
  ...buildWithMac,
  installers: {
    windows: download("Frontline-windows-setup.exe", 42_000_000),
    macos: download("Frontline-macos.dmg", 66_000_000),
  },
}

/** The latest release as releases from before the installers were: just the zips. */
export const buildWithoutInstallers: Build = { ...buildWithMac, installers: undefined }

// Made-up answers from the matchmaker and GitHub, for stories and tests. Each
// lobby is one of the cases the battle list draws differently.

import type { Health, Lobby } from "@/lib/matchmaker"
import type { Build, GhAsset, GhRelease } from "@/lib/releases"

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

const RELEASES = "https://github.com/Dynasty9/Frontline/releases"

export const stableBuild: Build = {
  tag: "v0.1.9",
  name: "v0.1.9",
  url: `${RELEASES}/tag/v0.1.9`,
  published: "2026-10-14T18:22:00Z",
  prerelease: false,
  assets: {
    windows: { url: `${RELEASES}/download/v0.1.9/Frontline-windows.zip`, size: 91_400_000 },
    linux: { url: `${RELEASES}/download/v0.1.9/Frontline-linux.zip`, size: 88_700_000 },
  },
}

export const nightlyBuild: Build = {
  tag: "nightly",
  name: "Nightly",
  url: `${RELEASES}/tag/nightly`,
  published: "2026-10-15T03:10:00Z",
  prerelease: true,
  assets: {
    windows: { url: `${RELEASES}/download/nightly/Frontline-windows.zip`, size: 91_600_000 },
    linux: { url: `${RELEASES}/download/nightly/Frontline-linux.zip`, size: 88_900_000 },
  },
}

/** A release whose Linux build didn't make it. */
export const windowsOnlyBuild: Build = {
  ...stableBuild,
  assets: { windows: stableBuild.assets.windows },
}

// What GitHub's releases API answers for the builds above, newest first: a
// draft and a release still uploading its zips come before them and are
// passed over.
const ghAsset = (tag: string, file: string, size: number): GhAsset => ({
  name: file,
  browser_download_url: `${RELEASES}/download/${tag}/${file}`,
  size,
})

export const ghReleases: GhRelease[] = [
  {
    tag_name: "v0.2.0",
    name: "v0.2.0",
    html_url: `${RELEASES}/tag/v0.2.0`,
    published_at: "2026-10-15T20:00:00Z",
    prerelease: false,
    draft: true,
    assets: [ghAsset("v0.2.0", "Frontline-windows.zip", 92_000_000)],
  },
  {
    tag_name: "v0.1.10",
    name: "v0.1.10",
    html_url: `${RELEASES}/tag/v0.1.10`,
    published_at: "2026-10-15T09:00:00Z",
    prerelease: false,
    draft: false,
    assets: [],
  },
  {
    tag_name: "nightly",
    name: "Nightly",
    html_url: nightlyBuild.url,
    published_at: nightlyBuild.published,
    prerelease: true,
    draft: false,
    assets: [
      ghAsset("nightly", "Frontline-windows.zip", 91_600_000),
      ghAsset("nightly", "Frontline-linux.zip", 88_900_000),
    ],
  },
  {
    tag_name: "v0.1.9",
    name: "v0.1.9",
    html_url: stableBuild.url,
    published_at: stableBuild.published,
    prerelease: false,
    draft: false,
    assets: [
      ghAsset("v0.1.9", "Frontline-windows.zip", 91_400_000),
      ghAsset("v0.1.9", "Frontline-linux.zip", 88_700_000),
      ghAsset("v0.1.9", "SHA256SUMS.txt", 180),
    ],
  },
]

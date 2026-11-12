import definitions from "../../../scripts/autoload/defs.gd?raw"
import roster from "../../../scripts/game/vehicle_roster.gd?raw"

// The Field Manual, as the website shows it: every soldier, squad, weapon,
// vehicle, building, fire mission and upgrade in the game, read when the site
// is built from the game's own tables (scripts/autoload/defs.gd and
// scripts/game/vehicle_roster.gd), so its figures are always the game's. The
// game's Field Manual (scripts/ui/field_manual.gd) works the same figures out
// for its pages; the labels here are its labels. The site's 3D viewer opens
// any of these by its key (the browser build's ?manual=<key>), as the game's
// manual does.
//
// shortcut: this reads the tables' literal format; update the reader if those
// tables become computed (manual.test.ts checks every entry is here).

export type Fact = {
  label: string
  value: string
  /** how it compares with the rest of its kind, as the game's counted bars: a share of the biggest */
  frac?: number
}

export type Entry = {
  /** the game's key: the 3D viewer opens it */
  id: string
  name: string
  /** whose it is: 0 the Coalition, 1 the Rebels, -1 both or neither */
  team: number
  /** whose it is, in words: a side, or a vehicle's faction (NATO, CSAT...) */
  side: string
  /** the filter it's listed under on its page */
  group: string
  /** what it is, in a few words */
  kind: string
  description: string
  facts: Fact[]
  /** where it comes from and what it goes with */
  notes: string[]
  /** the viewer has a model of it (upgrades have none) */
  model: boolean
  /** an armed support flight the viewer can fly over its range */
  support?: { id: string; shape: string }
  /** a vehicle's availability: built (and at which tier), called in, automatic, or reference only */
  status?: string
}

export type SectionKey = "infantry" | "vehicles" | "buildings" | "support" | "research"

export type Section = {
  key: SectionKey
  title: string
  /** the page's headline, two lines: the second in the accent */
  headline: [string, string]
  summary: string
  groups: string[]
  entries: Entry[]
  /** what one entry is called, in the counts ("vehicle", "vehicles") */
  noun: [string, string]
}

// ---------------------------------------------------------------- reading the tables

const STRING = '"(?:[^"\\\\]|\\\\.)*"'
const decode = (value: string) => JSON.parse(value) as string

function text(body: string, key: string) {
  const value = body.match(new RegExp(`"${key}":\\s*(${STRING})`))?.[1]
  return value ? decode(value) : ""
}
function num(body: string, key: string) {
  const value = body.match(new RegExp(`"${key}":\\s*(-?[\\d.]+)`))?.[1]
  return value === undefined ? undefined : Number(value)
}
const flag = (body: string, key: string) => new RegExp(`"${key}":\\s*true`).test(body)
function strings(items: string) {
  return [...items.matchAll(new RegExp(STRING, "g"))].map((m) => decode(m[0]))
}
function list(body: string, key: string) {
  const value = body.match(new RegExp(`"${key}":\\s*\\[([^\\]]*)\\]`))?.[1]
  return value === undefined ? [] : strings(value)
}
function numbers(body: string, key: string) {
  const value = body.match(new RegExp(`"${key}":\\s*\\[([^\\]]*)\\]`))?.[1]
  return value === undefined ? [] : value.split(",").map(Number)
}
/** A table in defs.gd: each entry's key and the text of its dictionary. */
function table(name: string) {
  const body = definitions.split(`var ${name} := {`)[1]?.split("\n}")[0]
  if (!body) throw new Error(`Missing game table: ${name}`)
  return [...body.matchAll(/\t"([^"]+)": \{([\s\S]*?)(?=\n\t"|$)/g)].map(([, id, entry]) => ({ id, body: entry }))
}
function constant(name: string) {
  const value = definitions.match(new RegExp(`const ${name} := (.+?)(?:\\s+#.*)?\\n`))?.[1]
  if (value === undefined) throw new Error(`Missing game constant: ${name}`)
  return value.startsWith("[") ? value.slice(1, -1).split(",").map(Number) : [Number(value)]
}

const SIDES = ["Coalition", "Rebels"]
const sideName = (team: number) => SIDES[team] ?? "Both sides"
const teamOf = (teams: number[]) => (teams.length === 1 ? teams[0] : -1)
const round = (n: number) => Math.round(n)
const plural = (n: number, one: string, many = `${one}s`) => `${n} ${n === 1 ? one : many}`
const share = (value: number, max: number) => (max > 0 ? Math.max(0, Math.min(1, value / max)) : undefined)
const sentence = (s: string) => (s ? s[0].toUpperCase() + s.slice(1) : s)

/** The game's start-of-battle and supply figures, for the manual's overview. */
export const LOGISTICS = {
  startSupply: constant("START_SUPPLY")[0],
  capPerFob: constant("CAP_PER_FOB")[0],
  baseCap: constant("BASE_CAP")[0],
  truckLoad: constant("SUPPLY_PER_TRUCK"),
  townYield: constant("TOWN_YIELD"),
}

// ---------------------------------------------------------------- the raw tables

const WEAPONS = table("WEAPONS").map(({ id, body }) => ({
  id,
  name: text(body, "name"),
  dmg: num(body, "dmg") ?? 0,
  range: num(body, "range") ?? 0,
  interval: num(body, "interval") ?? 1,
  acc: num(body, "acc") ?? 0,
  mag: num(body, "mag") ?? 0,
  ammo: num(body, "ammo") ?? 0,
  reload: num(body, "reload") ?? 0,
  supp: num(body, "supp") ?? 0,
  burst: (body.match(/"burst": Vector2i\((\d+), (\d+)\)/)?.slice(1) ?? ["1", "1"]).map(Number),
  ap: flag(body, "ap"),
  he: num(body, "he"),
  airburst: flag(body, "airburst"),
  aa: flag(body, "aa"),
}))
const weapon = new Map(WEAPONS.map((w) => [w.id, w]))

const UNITS = table("UNITS").map(({ id, body }) => ({
  id,
  name: text(body, "name"),
  team: num(body, "team") ?? -1,
  weapon: text(body, "weapon"),
  hp: num(body, "hp") ?? 0,
  frags: num(body, "frags") ?? 0,
  smokes: num(body, "smokes") ?? 0,
  rockets: num(body, "rockets") ?? 0,
  mortar: num(body, "mortar") ?? 0,
  drones: num(body, "drones") ?? 0,
  build: num(body, "build") ?? 1,
  heal: num(body, "heal") ?? 1,
  medic: flag(body, "medic"),
  engineer: flag(body, "engineer"),
  crew: flag(body, "crew"),
  bearer: flag(body, "bearer"),
}))
const unit = new Map(UNITS.map((u) => [u.id, u]))

const SQUADS = table("SQUADS").map(({ id, body }) => ({
  id,
  name: text(body, "name"),
  team: num(body, "team") ?? -1,
  cost: num(body, "cost") ?? 0,
  time: num(body, "time") ?? 0,
  members: list(body, "members"),
  desc: text(body, "desc"),
}))
const squad = new Map(SQUADS.map((s) => [s.id, s]))

const BUILDINGS = table("BUILDINGS").map(({ id, body }) => {
  const produces = body.match(new RegExp(`"produces": \\[\\[([^\\]]*)\\], \\[([^\\]]*)\\]\\]`))
  const size = body.match(/"size": Vector2\(([\d.]+), ([\d.]+)\)/)
  return {
    id,
    name: text(body, "name"),
    cost: num(body, "cost") ?? 0,
    time: num(body, "time") ?? 0,
    hp: num(body, "hp") ?? 0,
    size: size ? [Number(size[1]), Number(size[2])] : [0, 0],
    teams: numbers(body, "teams"),
    desc: text(body, "desc"),
    produces: produces ? [strings(produces[1]), strings(produces[2])] : undefined,
  }
})

const SUPPORT = table("SUPPORT").map(({ id, body }) => ({
  id,
  name: text(body, "name"),
  team: num(body, "team") ?? -1,
  cost: num(body, "cost") ?? 0,
  cooldown: num(body, "cooldown") ?? 0,
  from: num(body, "from") ?? 300,
  shape: text(body, "shape"),
  r: num(body, "r") ?? 0,
  fly: text(body, "fly"),
  model: text(body, "model"),
  recon: flag(body, "recon"),
  pattern: text(body, "pattern"),
  desc: text(body, "desc"),
}))

const UPGRADES = table("UPGRADES").map(({ id, body }) => ({
  id,
  name: text(body, "name"),
  cost: num(body, "cost") ?? 0,
  time: num(body, "time") ?? 0,
  teams: numbers(body, "teams"),
  tier: num(body, "tier"),
  requires: text(body, "requires"),
  desc: text(body, "desc"),
}))

/** A vehicle as the game's tables have it: the original ones in defs.gd, then the roster's. */
type RawVehicle = {
  id: string
  name: string
  team: number
  tier: number
  faction?: string
  role?: string
  pattern?: string
  cost: number
  time: number
  hp: number
  armor: number
  speed: number
  base: string
  body: string
  /** where it's built (the Helipad, the Boat Dock or the Factory), if it's built */
  at?: string
}

const RAW_VEHICLES: RawVehicle[] = table("VEHICLES").map(({ id, body }) => ({
  id,
  name: text(body, "name"),
  team: num(body, "team") ?? -1,
  tier: num(body, "tier") ?? 1,
  cost: num(body, "cost") ?? 0,
  time: num(body, "time") ?? 0,
  hp: num(body, "hp") ?? 0,
  armor: num(body, "armor") ?? 0,
  speed: num(body, "speed") ?? 0,
  base: text(body, "base"),
  body,
}))
// the base buildings' own lists, before the roster joins them (Defs._init)
for (const b of BUILDINGS)
  for (const side of b.produces ?? [])
    for (const id of side) {
      const v = RAW_VEHICLES.find((x) => x.id === id)
      if (v) v.at = `the ${b.name}`
    }
const entry = new RegExp(
  `t\\[(${STRING})\\] = _v\\((${STRING}), (-?\\d+), (\\d+), (${STRING}), (${STRING}), (${STRING}), (${STRING}), (\\d+), ([\\d.]+), ([\\d.]+), (\\d+), ([\\d.]+), ([\\d.]+), (${STRING}),([\\s\\S]*?)(?=\\n\\tt\\[|\\n\\treturn t)`,
  "g"
)
for (const m of roster.matchAll(entry)) {
  const [, key, name, team, tier, , faction, role, pattern, cost, time, hp, armor, speed, , base, body] = m
  const t = Number(team)
  RAW_VEHICLES.push({
    id: decode(key),
    name: decode(name),
    team: t,
    tier: Number(tier),
    faction: decode(faction),
    role: decode(role),
    pattern: decode(pattern),
    cost: Number(cost),
    time: Number(time),
    hp: Number(hp),
    armor: Number(armor),
    speed: Number(speed),
    base: decode(base),
    body,
    // as Defs._init sends them: air to the Helipad, boats to the Dock, the rest to the Factory
    at:
      t < 0 || t > 1
        ? undefined
        : flag(body, "air")
          ? "the Helipad"
          : decode(base) === "boat"
            ? "the Boat Dock"
            : "the Factory",
  })
}
const rawVehicle = new Map(RAW_VEHICLES.map((v) => [v.id, v]))

/** The rest of the garage (aircraft, boats, civilian vehicles): reference models in the Field Manual. */
const GARAGE = roster
  .split("\n")
  .filter((line) => /^\s*\["/.test(line))
  .map((line) => {
    const [id, name, cat, faction, role, pattern, crew, speed, armament, description] = JSON.parse(
      line.trim().replace(/,$/, "")
    ) as [string, string, string, string, string, string, string, number, string, string]
    return { id, name, cat, faction, role, pattern, crew, speed, armament, description }
  })

// who carries each weapon, and on which side (as the game's manual counts them)
const carriers = new Map<string, { names: string[]; teams: Set<number> }>()
const carry = (w: string, name: string, team: number) => {
  if (!w) return
  const c = carriers.get(w) ?? { names: [], teams: new Set<number>() }
  if (!c.names.includes(name)) c.names.push(name)
  if (team >= 0) c.teams.add(team)
  carriers.set(w, c)
}
for (const u of UNITS) carry(u.weapon, u.name, u.team)
for (const v of RAW_VEHICLES) if (!v.faction) carry(text(v.body, "mg"), v.name, v.team)
carry("mmg", "MG Nest", -1)
carry("m2", ".50 Cal Nest", -1)

// ---------------------------------------------------------------- infantry

const squadsOf = (u: string) => SQUADS.filter((s) => s.members.includes(u)).map((s) => s.name)
const max = <T>(items: T[], f: (x: T) => number) => Math.max(0, ...items.map(f))

/** Damage per second over a long fight: bursts with the pauses between them, times the chance a round hits (FieldManual._dps). */
function dps(w: (typeof WEAPONS)[number]) {
  const burst = (w.burst[0] + w.burst[1]) * 0.5
  return (w.dmg * w.acc * burst) / (burst * w.interval + 0.85)
}

function unitRole(u: (typeof UNITS)[number]) {
  if (u.crew) return "vehicle crew"
  if (u.medic) return "medic"
  if (u.engineer) return "engineer"
  if (u.rockets > 0) return "anti-tank"
  if (u.mortar > 0) return "indirect fire"
  if (u.drones > 0) return "drone operator"
  if (u.weapon === "lmg") return "automatic rifleman"
  if (u.bearer) return "casualty evacuation"
  return "rifleman"
}

/** What he does, as the game's manual says it (FieldManual._unit_desc). */
function unitDescription(u: (typeof UNITS)[number]) {
  if (u.medic) return "Patches up the wounded under fire, drags them to cover and calls the stretcher bearers."
  if (u.engineer)
    return `Builds bases and defences, digs trenches${u.team === 1 ? " and tunnels" : ""} and repairs tracks.`
  if (u.rockets > 0) return "Hunts vehicles and bunkers with rockets; pops up from cover to fire."
  if (u.mortar > 0) return "Carries a light mortar and drops bombs on anything his side has spotted, behind cover too."
  if (u.drones > 0) return "Flies kamikaze FPV drones into infantry and armour from behind cover."
  if (u.bearer) return "Carries the wounded and the dead back to the medic tent."
  if (u.weapon === "lmg")
    return "The squad's automatic weapon: pins the enemy down so the riflemen can move. Crews MG nests."
  return "The backbone of the squad: fights from cover, throws grenades, moves by bounds."
}

const hpMax = max(UNITS, (u) => u.hp)
const soldiers: Entry[] = UNITS.map((u) => {
  const w = weapon.get(u.weapon)
  const kit = [
    u.frags > 0 && plural(u.frags, "frag grenade"),
    u.smokes > 0 && `${u.smokes} smoke`,
    u.rockets > 0 && `${u.rockets} ${u.team === 1 ? "RPG-7 rockets" : "AT rockets"}`,
    u.mortar > 0 && `${u.mortar} mortar bombs`,
    u.drones > 0 && `${u.drones} FPV drones`,
  ].filter(Boolean)
  const facts: Fact[] = [
    { label: "Health", value: `${round(u.hp)}`, frac: share(u.hp, hpMax) },
    { label: "Weapon", value: w ? `${w.name} (${round(w.dmg)} dmg, ${round(w.range)} m)` : "unarmed" },
    { label: "Kit", value: kit.length ? kit.join(", ") : "-" },
  ]
  if (u.heal > 1) facts.push({ label: "First aid", value: `x${u.heal.toFixed(1)} faster` })
  if (u.build > 1) facts.push({ label: "Building / digging", value: `x${u.build.toFixed(1)} faster` })
  const inSquads = squadsOf(u.id)
  return {
    id: u.id,
    name: u.name,
    team: u.team,
    side: sideName(u.team),
    group: "Soldiers",
    kind: unitRole(u),
    description: unitDescription(u),
    facts,
    notes: inSquads.length ? [`In: ${inSquads.join(", ")}`] : [],
    model: true,
  }
})

/** A squad's firepower: every man's sustained damage, together (FieldManual._squad_fire). */
const squadFire = (s: (typeof SQUADS)[number]) =>
  s.members.reduce((sum, m) => {
    const w = weapon.get(unit.get(m)?.weapon ?? "")
    return sum + (w ? dps(w) : 0)
  }, 0)
const fireMax = max(SQUADS, squadFire)
const squadCostMax = max(SQUADS, (s) => s.cost)
const squads: Entry[] = SQUADS.map((s) => {
  const free = s.cost === 0
  const counts = new Map<string, number>()
  for (const m of s.members) counts.set(unit.get(m)?.name ?? m, (counts.get(unit.get(m)?.name ?? m) ?? 0) + 1)
  const members = [...counts].map(([n, c]) => (c > 1 ? `${c} × ${n}` : n)).join(", ")
  return {
    id: s.id,
    name: s.name,
    team: s.team,
    side: sideName(s.team),
    group: "Squads",
    kind: free ? `${s.members.length} men · comes with its vehicle` : `${s.members.length} men · ${s.cost} supply`,
    description: s.desc,
    facts: [
      { label: "Men", value: `${s.members.length}`, frac: share(s.members.length, 6) },
      { label: "Firepower", value: `${round(squadFire(s))} damage / s`, frac: share(squadFire(s), fireMax) },
      { label: "Cost", value: free ? "-" : `${s.cost} supply`, frac: free ? undefined : share(s.cost, squadCostMax) },
      { label: "Training time", value: free ? "-" : `${round(s.time)} s` },
      { label: "Members", value: members },
    ],
    notes: [`Trained at: ${!free ? "the Barracks" : s.team === 0 ? "an IFV (Factory)" : "a BTR (Factory)"}`],
    model: true,
  }
})

const smallArms = new Set(["rifle", "ak", "smg", "lmg", "pistol"])
const carried = WEAPONS.filter((w) => carriers.has(w.id))
const wMax = {
  dmg: max(carried, (w) => w.dmg),
  range: max(carried, (w) => w.range),
  rpm: max(carried, (w) => 60 / w.interval),
  acc: max(carried, (w) => w.acc),
  dps: max(carried, dps),
  supp: max(carried, (w) => w.supp),
}
const weapons: Entry[] = carried.map((w) => {
  const users = carriers.get(w.id)!
  const crew = w.id === "mmg" || w.id === "m2"
  const flags = [
    w.ap && "armour-piercing",
    w.he !== undefined && `high-explosive (${w.he.toFixed(1)} m)`,
    w.airburst && "airburst over trenches",
    w.aa && "anti-aircraft",
  ].filter(Boolean)
  const rpm = 60 / w.interval
  return {
    id: w.id,
    name: w.name,
    team: crew ? -1 : teamOf([...users.teams]),
    side: crew ? "Both sides" : sideName(teamOf([...users.teams])),
    group: "Weapons",
    kind: crew ? "crew-served" : smallArms.has(w.id) ? "small arm" : "vehicle weapon",
    description: flags.length ? `${sentence(flags.join(", "))}.` : `Bursts of ${w.burst[0]}-${w.burst[1]} rounds.`,
    facts: [
      { label: "Damage per hit", value: `${round(w.dmg)}`, frac: share(w.dmg, wMax.dmg) },
      { label: "Effective range", value: `${round(w.range)} m`, frac: share(w.range, wMax.range) },
      { label: "Rate of fire", value: `${Math.trunc(rpm)} rounds / min`, frac: share(rpm, wMax.rpm) },
      { label: "Accuracy", value: `${Math.trunc(w.acc * 100)}%`, frac: share(w.acc, wMax.acc) },
      { label: "Sustained damage", value: `${round(dps(w))} / s`, frac: share(dps(w), wMax.dps) },
      { label: "Suppression", value: `${round(w.supp)} per burst round`, frac: share(w.supp, wMax.supp) },
      { label: "Magazine / belt", value: `${w.mag}${w.ammo >= 9000 ? "" : `  (${w.ammo} carried)`}` },
      { label: "Reload", value: `${w.reload.toFixed(1)} s` },
    ],
    notes: [`Used by: ${users.names.join(", ")}`],
    model: true,
  }
})

// ---------------------------------------------------------------- vehicles

const ARMOUR = ["none (soft-skinned)", "light (stops rifle fire)", "heavy (small arms bounce off)"]
const upgradeFor = (tier: number, team: number) =>
  UPGRADES.find((u) => u.tier === tier && u.teams.includes(team))?.name ?? "research"
const built = RAW_VEHICLES.filter((v) => v.team >= 0 || v.cost > 0)
const vMax = {
  hp: max(RAW_VEHICLES, (v) => v.hp),
  speed: max(RAW_VEHICLES, (v) => v.speed),
  cost: max(built, (v) => v.cost),
}

function vehicleFacts(v: RawVehicle): Fact[] {
  const mg = text(v.body, "mg")
  const atgm = numbers(v.body, "atgm")[0]
  const sam = numbers(v.body, "sam")[0]
  const art = v.body.match(/"art": \{"shell": "(\w+)", "min": ([\d.]+), "max": ([\d.]+)/)
  const guns = [
    flag(v.body, "cannon") && "main gun",
    mg && weapon.get(mg)?.name,
    atgm && `${atgm} anti-tank missiles`,
    sam && `${sam} anti-aircraft missiles`,
    (num(v.body, "rockets") ?? 0) > 0 && v.base === "attack_heli" && "rocket pods",
    art &&
      `${art[1] === "grad" ? "rocket artillery" : "howitzer"}, ${round(Number(art[2]))}-${round(Number(art[3]))} m`,
  ].filter(Boolean)
  const facts: Fact[] = [
    { label: "Hit points", value: `${round(v.hp)}`, frac: share(v.hp, vMax.hp) },
    { label: "Armour", value: ARMOUR[Math.max(0, Math.min(2, v.armor))], frac: v.armor / 2 },
    { label: "Top speed", value: `${Math.trunc(v.speed * 3.6)} km/h`, frac: share(v.speed, vMax.speed) },
    { label: "Armament", value: guns.length ? guns.join(", ") : "unarmed" },
    {
      label: "Cost",
      value: v.cost > 0 ? `${v.cost} supply` : "-",
      frac: v.cost > 0 ? share(v.cost, vMax.cost) : undefined,
    },
    { label: "Build time", value: v.time > 0 ? `${round(v.time)} s` : "-" },
  ]
  const carries = squad.get(text(v.body, "carry"))
  if (carries) facts.push({ label: "Carries", value: `${carries.name} (${carries.members.length} men)` })
  const service = text(v.body, "service")
  if (service)
    facts.push({
      label: "Service",
      value:
        {
          repair: "repairs vehicles within 13 m",
          ammo: "rearms men and vehicles within 13 m",
          medical: "treats the wounded within 11 m",
        }[service] ?? service,
    })
  const sight = num(v.body, "sight")
  if (sight) facts.push({ label: "Sees", value: `${round(sight)} m` })
  if (v.tier > 1) facts.push({ label: "Unlocked by", value: `${upgradeFor(v.tier, v.team)} (tier ${v.tier})` })
  if (v.pattern) facts.push({ label: "Based on", value: v.pattern })
  return facts
}

const vehicles = new Map<string, Entry>()
for (const v of RAW_VEHICLES) {
  const fromRoster = !!v.faction
  const auto = v.team < 0
  vehicles.set(v.id, {
    id: v.id,
    name: v.name,
    team: v.team >= 0 && v.team <= 1 ? v.team : -1,
    side: v.faction ?? (v.team === 0 ? "Coalition" : v.team === 1 ? "Rebels" : "Shared"),
    group: auto ? "Automatic supply" : "Buildable",
    kind: v.role ?? v.base.replaceAll("_", " "),
    description: text(v.body, "desc"),
    facts: vehicleFacts(v),
    notes: [
      v.cost > 0 ? `Built at ${v.at ?? "the Factory"}` : "Drives supply from your depot to the FOBs",
      ...(fromRoster ? [`${v.faction} - ${v.role}`] : []),
    ],
    model: true,
    status: auto ? "Automatic supply" : fromRoster ? `Buildable · Tier ${v.tier}` : "Buildable",
  })
}
for (const g of GARAGE) {
  if (vehicles.has(g.id)) continue
  const team = /^(NATO|AAF)/.test(g.faction) ? 0 : /^(CSAT|FIA|Syndikat)/.test(g.faction) ? 1 : -1
  vehicles.set(g.id, {
    id: g.id,
    name: g.name,
    team,
    side: g.faction,
    group: "Field Manual only",
    kind: g.role,
    description: g.description,
    facts: [
      { label: "Role", value: g.role },
      { label: "Crew / passengers", value: g.crew },
      { label: "Top speed", value: `${g.speed} km/h`, frac: share(g.speed, 1500) },
      { label: "Armament", value: g.armament },
      { label: "Based on", value: g.pattern },
    ],
    notes: [`Faction: ${g.faction}`],
    model: true,
    status: "Field Manual only",
  })
}
// the aircraft the fire support flies: the same model, with its sortie to watch
for (const s of SUPPORT) {
  if (!s.model) continue
  const support = ["a10", "jet", "orbit"].includes(s.fly) ? { id: s.id, shape: s.shape } : undefined
  const existing = vehicles.get(s.model)
  if (existing) {
    if (existing.group === "Field Manual only") {
      existing.group = "Air support"
      existing.status = "Air support"
      existing.notes.push(`Called in: ${s.name}`)
    }
    if (support && !existing.support) existing.support = support
    continue
  }
  vehicles.set(s.model, {
    id: s.model,
    name: s.name,
    team: s.team,
    side: s.team === 0 ? "Coalition" : "Rebels",
    group: "Air support",
    kind: "Support aircraft",
    description: s.desc,
    facts: [
      { label: "Cost", value: `${s.cost} supply` },
      { label: "Cooldown", value: `${round(s.cooldown)} s` },
      ...(s.pattern ? [{ label: "Based on", value: s.pattern }] : []),
    ],
    notes: [`Called in: ${s.name}`],
    model: true,
    status: "Air support",
    ...(support ? { support } : {}),
  })
}

// ---------------------------------------------------------------- buildings

// the base itself (FieldManual.BASES); everything else is a field defence
const BASES = new Set(["fob", "barracks", "factory", "helipad", "dock", "medic_tent", "research", "tunnel"])
const bMax = { hp: max(BUILDINGS, (b) => b.hp), cost: max(BUILDINGS, (b) => b.cost) }
const nameOf = (id: string) => squad.get(id)?.name ?? rawVehicle.get(id)?.name ?? id
const buildings: Entry[] = BUILDINGS.map((b) => {
  const produced = [0, 1].map((team) => [
    ...(b.produces?.[team] ?? []),
    ...RAW_VEHICLES.filter((v) => v.faction && v.team === team && v.at === `the ${b.name}`).map((v) => v.id),
  ])
  const notes = produced.flatMap((ids, team) => (ids.length ? [`${SIDES[team]}: ${ids.map(nameOf).join(", ")}`] : []))
  if (b.id === "research") notes.push(`Researches: ${UPGRADES.map((u) => u.name).join(", ")}`)
  const facts: Fact[] = [
    { label: "Hit points", value: `${round(b.hp)}`, frac: share(b.hp, bMax.hp) },
    { label: "Cost", value: `${b.cost} supply`, frac: share(b.cost, bMax.cost) },
    { label: "Build time", value: `${round(b.time)} s (one engineer)` },
    { label: "Footprint", value: `${b.size[0].toFixed(1)} x ${b.size[1].toFixed(1)} m` },
  ]
  const nest = { mg_nest: "mmg", hmg_nest: "m2" }[b.id]
  const gun = nest ? weapon.get(nest) : undefined
  if (gun)
    facts.unshift({
      label: "Crewed weapon",
      value: `${gun.name === "GPMG" ? "GPMG" : ".50 cal"}: ${round(gun.dmg)} dmg, ${round(gun.range)} m${gun.ap ? ", armour-piercing" : ""}`,
    })
  const team = teamOf(b.teams)
  return {
    id: b.id,
    name: b.name,
    team,
    side: sideName(team),
    group: BASES.has(b.id) ? "Base buildings" : "Field defences",
    kind: `${b.cost} supply · ${round(b.hp)} hp`,
    description: b.desc,
    facts,
    notes,
    model: true,
  }
})

// ---------------------------------------------------------------- fire support

const AIMED: Record<string, string> = {
  line: "a line, dragged to set the run-in",
  strafe: "a strafing line, dragged",
  orbit: "an orbit over a circle",
  circle: "a circle",
  sweep: "a line it flies along, dragged",
  watch: "an orbit over a circle",
}
const MINUTES = ["one", "two", "three", "four", "five", "six"]
const called = SUPPORT.filter((s) => s.team >= 0)
const sMax = {
  cost: max(called, (s) => s.cost),
  cooldown: max(called, (s) => s.cooldown),
  r: max(called, (s) => (s.recon ? 0 : s.r)),
}
const supportGroup = (s: (typeof SUPPORT)[number]) =>
  s.recon
    ? "Reconnaissance"
    : s.fly === "a10"
      ? "Strafing runs"
      : s.fly === "jet"
        ? "Air strikes"
        : s.fly === "orbit"
          ? "Gunships & drones"
          : "Artillery & mortars"
const support: Entry[] = called.map((s) => {
  const fromMinute = Math.trunc(s.from / 60)
  const demo = ["a10", "jet", "orbit"].includes(s.fly)
  return {
    id: s.id,
    name: s.name,
    team: s.team,
    side: sideName(s.team),
    group: supportGroup(s),
    kind: `${s.cost} supply · every ${round(s.cooldown)} s`,
    description: s.desc,
    facts: [
      { label: "Cost", value: `${s.cost} supply`, frac: share(s.cost, sMax.cost) },
      { label: "Cooldown", value: `${round(s.cooldown)} s`, frac: share(s.cooldown, sMax.cooldown) },
      {
        label: s.recon ? "Sees" : "Area",
        value: `${round(s.r)} m ${s.shape === "sweep" ? "either side" : "radius"}`,
        frac: s.recon ? undefined : share(s.r, sMax.r),
      },
      { label: "Aimed as", value: AIMED[s.shape] ?? s.shape },
      ...(s.pattern ? [{ label: "Aircraft", value: s.pattern }] : []),
    ],
    notes: [`Called from the support panel or Z, from minute ${MINUTES[Math.max(0, Math.min(5, fromMinute - 1))]}`],
    model: true,
    ...(demo ? { support: { id: s.id, shape: s.shape } } : {}),
  }
})

// ---------------------------------------------------------------- research

const research: Entry[] = UPGRADES.map((u) => {
  const team = teamOf(u.teams)
  const requires = UPGRADES.find((x) => x.id === u.requires)
  return {
    id: u.id,
    name: u.name,
    team,
    side: sideName(team),
    group: u.tier ? "Vehicle tiers" : "Upgrades",
    kind: `${u.cost} supply · ${round(u.time)} s`,
    description: u.desc,
    facts: [
      { label: "Cost", value: `${u.cost} supply` },
      { label: "Research time", value: `${round(u.time)} s` },
      ...(u.tier ? [{ label: "Unlocks", value: `tier ${u.tier} vehicles` }] : []),
      ...(requires ? [{ label: "Needs", value: requires.name }] : []),
    ],
    notes: ["Researched at the Research Post"],
    model: false,
  }
})

// ---------------------------------------------------------------- the manual's pages

export const VEHICLES = [...vehicles.values()].toSorted((a, b) => a.name.localeCompare(b.name))

export const SECTIONS: Section[] = [
  {
    key: "infantry",
    title: "Infantry",
    headline: ["Every man", "thinks for himself."],
    summary:
      "The squads you train, the soldiers in them and the weapons they carry. Each man takes cover, keeps his head down and works the drill.",
    groups: ["Squads", "Soldiers", "Weapons"],
    entries: [...squads, ...soldiers, ...weapons],
    noun: ["entry", "entries"],
  },
  {
    key: "vehicles",
    title: "Vehicles",
    headline: ["Know your", "motor pool."],
    summary:
      "From the first scout car to the heaviest armour. Explore the roster, turn each vehicle over and find its place in your force.",
    groups: ["Buildable", "Air support", "Automatic supply", "Field Manual only"],
    entries: VEHICLES,
    noun: ["vehicle", "vehicles"],
  },
  {
    key: "buildings",
    title: "Buildings",
    headline: ["Build it.", "Dig in. Hold it."],
    summary:
      "What your engineers put up: the base that trains and builds your force, and the defences that hold the ground it takes.",
    groups: ["Base buildings", "Field defences"],
    entries: buildings,
    noun: ["building", "buildings"],
  },
  {
    key: "support",
    title: "Fire support",
    headline: ["Call it in.", "Danger close."],
    summary:
      "Off-map support, called on a spot from the support panel: strike jets, gun runs, orbiting gunships, artillery and the recon flights that find their targets.",
    groups: ["Air strikes", "Strafing runs", "Gunships & drones", "Artillery & mortars", "Reconnaissance"],
    entries: support,
    noun: ["fire mission", "fire missions"],
  },
  {
    key: "research",
    title: "Research",
    headline: ["Train harder.", "Field heavier."],
    summary:
      "What the Research Post unlocks: better kit for every soldier, and the doctrines that bring heavier vehicles to the Factory and the Helipad.",
    groups: ["Upgrades", "Vehicle tiers"],
    entries: research,
    noun: ["upgrade", "upgrades"],
  },
]

export const section = (key: string | undefined) => SECTIONS.find((s) => s.key === key)

/** The figures the overview quotes: counted from the tables, so they stay true. */
export const TALLY = {
  squads: SQUADS.filter((s) => s.cost > 0).length,
  soldiers: UNITS.length,
  weapons: weapons.length,
  vehicles: VEHICLES.length,
  buildable: VEHICLES.filter((v) => v.group === "Buildable").length,
  bases: buildings.filter((b) => b.group === "Base buildings").length,
  defences: buildings.filter((b) => b.group === "Field defences").length,
  support: support.length,
  upgrades: research.length,
  perSide: [0, 1].map((team) => ({
    squads: SQUADS.filter((s) => s.cost > 0 && s.team === team).length,
    vehicles: VEHICLES.filter((v) => v.group === "Buildable" && v.team === team).length,
    support: support.filter((s) => s.team === team).length,
    buildings: buildings.filter((b) => b.team === team || b.team === -1).length,
  })),
}

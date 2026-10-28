import definitions from "../../../scripts/autoload/defs.gd?raw"
import roster from "../../../scripts/game/vehicle_roster.gd?raw"

export type Vehicle = {
  id: string
  name: string
  faction: string
  role: string
  description: string
  availability: string
}

// shortcut: reads the roster's literal data format; update this reader if those tables become computed.
const string = '"(?:[^"\\\\]|\\\\.)*"'
const decode = (value: string) => JSON.parse(value) as string
function field(body: string, key: string) {
  const value = body.match(new RegExp(`"${key}":\\s*(${string})`))?.[1]
  return value ? decode(value) : ""
}
function table(name: string) {
  const body = definitions.split(`var ${name} := {`)[1]?.split("\n}")[0]
  if (!body) throw new Error(`Missing game table: ${name}`)
  return [...body.matchAll(/\t"([^"]+)": \{([\s\S]*?)(?=\n\t"|$)/g)]
}

const vehicles = new Map<string, Vehicle>()
for (const [, id, body] of table("VEHICLES")) {
  const team = Number(body.match(/"team": (-?\d+)/)?.[1])
  vehicles.set(id, {
    id,
    name: field(body, "name"),
    faction: team === 0 ? "Coalition" : team === 1 ? "Rebels" : "Shared",
    role: field(body, "base").replaceAll("_", " "),
    description: field(body, "desc"),
    availability: team < 0 ? "Automatic supply" : "Buildable",
  })
}
const entry = new RegExp(
  `t\\[(${string})\\] = _v\\((${string}), (\\d+), (\\d+), (${string}), (${string}), (${string}), (${string}),([\\s\\S]*?)(?=\\n\\tt\\[|\\n\\treturn t)`,
  "g"
)
for (const [, key, name, , tier, , faction, role, , body] of roster.matchAll(entry)) {
  const id = decode(key)
  vehicles.set(id, {
    id,
    name: decode(name),
    faction: decode(faction),
    role: decode(role),
    description: field(body, "desc"),
    availability: `Buildable · Tier ${tier}`,
  })
}
for (const line of roster.split("\n")) {
  if (!/^\s*\["/.test(line)) continue
  const [id, name, , faction, role, , , , , description] = JSON.parse(line.trim().replace(/,$/, "")) as [
    string,
    string,
    string,
    string,
    string,
    string,
    string,
    number,
    string,
    string,
  ]
  if (!vehicles.has(id)) vehicles.set(id, { id, name, faction, role, description, availability: "Field Manual only" })
}
for (const [, , body] of table("SUPPORT")) {
  const id = field(body, "model")
  if (!id) continue
  const existing = vehicles.get(id)
  if (existing) {
    if (existing.availability === "Field Manual only") existing.availability = "Air support"
    continue
  }
  const team = Number(body.match(/"team": (-?\d+)/)?.[1])
  vehicles.set(id, {
    id,
    name: field(body, "name"),
    faction: team === 0 ? "Coalition" : "Rebels",
    role: "Support aircraft",
    description: field(body, "desc"),
    availability: "Air support",
  })
}

export const VEHICLES = [...vehicles.values()].toSorted((a, b) => a.name.localeCompare(b.name))

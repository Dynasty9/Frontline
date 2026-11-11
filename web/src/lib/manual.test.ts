import { describe, expect, it } from "vitest"
import definitions from "../../../scripts/autoload/defs.gd?raw"
import roster from "../../../scripts/game/vehicle_roster.gd?raw"
import { LOGISTICS, SECTIONS, TALLY, VEHICLES, section } from "./manual"

const keys = (name: string) =>
  [
    ...definitions
      .split(`var ${name} := {`)[1]
      .split("\n}")[0]
      .matchAll(/^\t"([^"]+)": \{/gm),
  ].map((m) => m[1])
const vehicle = (id: string) => VEHICLES.find((v) => v.id === id)
const find = (key: string, id: string) => section(key)!.entries.find((e) => e.id === id)
const fact = (key: string, id: string, label: string) => find(key, id)?.facts.find((f) => f.label === label)?.value
const ids = (key: string, group?: string) =>
  section(key)!
    .entries.filter((e) => !group || e.group === group)
    .map((e) => e.id)

describe("the Field Manual's vehicles", () => {
  it("includes every base, roster and garage entry once", () => {
    const table = [
      ...keys("VEHICLES"),
      ...[...roster.matchAll(/t\["([^"]+)"\] =/g)].map((m) => m[1]),
      ...[...roster.matchAll(/^\s*\["([^"]+)",/gm)].map((m) => m[1]),
    ]
    expect(table.filter((id) => !vehicle(id))).toEqual([])
    expect(new Set(VEHICLES.map((v) => v.id)).size).toBe(VEHICLES.length)
    const blanks = VEHICLES.flatMap((v) =>
      (["id", "name", "side", "kind", "description", "status"] as const).filter((k) => !v[k]).map((k) => `${v.id}.${k}`)
    )
    expect(blanks).toEqual([])
  })
  it("distinguishes units, support aircraft and manual-only vehicles", () => {
    expect(vehicle("hunter")).toMatchObject({ name: "Hunter", side: "NATO", status: "Buildable · Tier 1" })
    expect(vehicle("tank")?.status).toBe("Buildable")
    expect(vehicle("truck")?.status).toBe("Automatic supply")
    expect(vehicle("blackwasp")?.status).toBe("Air support")
    expect(vehicle("ac130")?.status).toBe("Air support")
    expect(vehicle("hatchback")?.status).toBe("Field Manual only")
  })
  it("maps demonstrations to real armed support commands", () => {
    expect(vehicle("wipeout")?.support).toEqual({ id: "wipeout", shape: "strafe" })
    expect(vehicle("blackwasp")?.support).toEqual({ id: "airstrike", shape: "line" })
    expect(vehicle("ac130")?.support).toEqual({ id: "ac130", shape: "orbit" })
    expect(vehicle("hunter")?.support).toBeUndefined()
  })
  it("reads their figures from the tables", () => {
    expect(fact("vehicles", "tank", "Hit points")).toBe("1400")
    expect(fact("vehicles", "tank", "Top speed")).toBe("23 km/h")
    expect(fact("vehicles", "tank", "Armament")).toBe("main gun, Coax MG")
    expect(fact("vehicles", "ifv", "Carries")).toBe("Mech Infantry (4 men)")
    expect(find("vehicles", "tank")?.notes).toContain("Built at the Factory")
    expect(find("vehicles", "heli")?.notes).toContain("Built at the Helipad")
    expect(find("vehicles", "rhib")?.notes).toContain("Built at the Boat Dock")
  })
})

describe("the rest of the Field Manual", () => {
  it("has every soldier, squad, building, called-in support and upgrade", () => {
    expect(ids("infantry", "Soldiers")).toEqual(keys("UNITS"))
    expect(ids("infantry", "Squads")).toEqual(keys("SQUADS"))
    expect(ids("buildings")).toEqual(keys("BUILDINGS"))
    expect(ids("research")).toEqual(keys("UPGRADES"))
    // the observers' smoke screen isn't called by either side
    expect(ids("support")).toEqual(keys("SUPPORT").filter((k) => k !== "smoke"))
  })
  it("lists only the weapons something carries", () => {
    const weapons = section("infantry")!.entries.filter((e) => e.group === "Weapons")
    expect(weapons.map((w) => w.id)).toContain("rifle")
    expect(weapons.map((w) => w.id)).toContain("m2")
    for (const w of weapons) expect(w.notes[0]).toMatch(/^Used by: \S/)
  })
  it("files every entry under one of its page's groups, and every page's keys are the viewer's own", () => {
    const astray = SECTIONS.flatMap((s) => s.entries.filter((e) => !s.groups.includes(e.group)).map((e) => e.id))
    expect(astray).toEqual([])
    for (const s of SECTIONS) expect(new Set(s.entries.map((e) => e.id)).size).toBe(s.entries.length)
    const bars = SECTIONS.flatMap((s) => s.entries.flatMap((e) => e.facts.flatMap((f) => f.frac ?? [])))
    expect(bars.every((frac) => frac >= 0 && frac <= 1)).toBe(true)
  })
  it("reads their figures from the tables", () => {
    expect(fact("infantry", "rifle_squad", "Cost")).toBe("100 supply")
    expect(fact("infantry", "rifle_squad", "Members")).toBe("4 × Rifleman, Medic")
    expect(fact("infantry", "engineer", "Building / digging")).toBe("x2.0 faster")
    expect(fact("infantry", "rifle", "Rate of fire")).toBe("500 rounds / min")
    expect(fact("buildings", "fob", "Footprint")).toBe("14.0 x 14.0 m")
    expect(find("buildings", "fob")?.group).toBe("Base buildings")
    expect(find("buildings", "sandbags")?.group).toBe("Field defences")
    expect(find("buildings", "factory")?.notes[0]).toMatch(/^Coalition: Battle Tank, IFV, Humvee, .*Hunter/)
    expect(find("support", "a10")).toMatchObject({ group: "Strafing runs", support: { id: "a10", shape: "strafe" } })
    expect(find("support", "artillery")?.group).toBe("Artillery & mortars")
    expect(find("support", "artillery")?.support).toBeUndefined()
    expect(find("support", "gryphon_recon")?.group).toBe("Reconnaissance")
    expect(fact("research", "combined_arms", "Needs")).toBe("Armoured Warfare")
    expect(find("research", "armor")?.model).toBe(false)
  })
  it("counts what the overview quotes", () => {
    expect(TALLY.vehicles).toBe(VEHICLES.length)
    expect(TALLY.squads).toBeGreaterThan(5)
    expect(LOGISTICS.startSupply).toBe(Number(definitions.match(/const START_SUPPLY := (\d+)/)![1]))
    expect(LOGISTICS.townYield).toHaveLength(2)
  })
})

import { describe, expect, it } from "vitest"
import definitions from "../../../scripts/autoload/defs.gd?raw"
import roster from "../../../scripts/game/vehicle_roster.gd?raw"
import { VEHICLES } from "./vehicles"

const vehicle = (id: string) => VEHICLES.find((v) => v.id === id)

describe("game vehicle roster", () => {
  it("includes every base, roster and garage entry once", () => {
    const base = definitions.split("var VEHICLES := {")[1].split("\n}")[0]
    const ids = [
      ...base.matchAll(/\t"([^"]+)": \{/g),
      ...roster.matchAll(/t\["([^"]+)"\] =/g),
      ...roster.matchAll(/^\s*\["([^"]+)",/gm),
    ].map((m) => m[1])
    for (const id of ids) expect(VEHICLES.some((v) => v.id === id)).toBe(true)
    expect(new Set(VEHICLES.map((v) => v.id)).size).toBe(VEHICLES.length)
    for (const v of VEHICLES) for (const value of Object.values(v)) expect(value).toBeTruthy()
  })
  it("distinguishes units, support aircraft and manual-only vehicles", () => {
    expect(vehicle("hunter")).toMatchObject({ name: "Hunter", faction: "NATO", availability: "Buildable · Tier 1" })
    expect(vehicle("tank")?.availability).toBe("Buildable")
    expect(vehicle("truck")?.availability).toBe("Automatic supply")
    expect(vehicle("blackwasp")?.availability).toBe("Air support")
    expect(vehicle("ac130")?.availability).toBe("Air support")
    expect(vehicle("hatchback")?.availability).toBe("Field Manual only")
  })
})

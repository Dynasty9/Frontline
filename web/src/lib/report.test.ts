import { describe, expect, it } from "vitest"
import { accuracy, rating, ratingWord, score } from "@/lib/report"

// The same numbers as the game's BattleStats (scripts/game/battle_stats.gd).
describe("rating", () => {
  it("sits in the middle for a commander who has hardly fought", () => {
    expect(rating({}, {})).toBe(50)
  })

  it("is mostly the exchange: 4:1 by value is as good as it gets", () => {
    // destroyed 4x what they lost, no shooting to speak of, all of their side's kills
    const r = rating({ val_killed: 4 * 60 + 180, val_lost: 0 + 45, shots: 10 }, { val_killed: 420 })
    expect(r).toBeCloseTo(100 * (0.6 * 1 + 0.2 * 0.5 + 0.2 * 1), 5)
  })

  it("counts marksmanship once they've fired enough: one hit in seven is full marks", () => {
    expect(rating({ shots: 700, hits: 100 }, {})).toBeCloseTo(
      100 * (0.6 * 0.5 + 0.2 * (100 / 700 / 0.15) + 0.2 * 0.5),
      5
    )
    expect(rating({ shots: 100, hits: 50 }, {})).toBeCloseTo(100 * (0.6 * 0.5 + 0.2 * 1 + 0.2 * 0.5), 5)
  })

  it("has a word for every band", () => {
    expect([90, 75, 60, 45, 30, 10].map(ratingWord)).toEqual([
      "Outstanding",
      "Effective",
      "Capable",
      "Mixed",
      "Costly",
      "Ineffective",
    ])
  })
})

describe("score", () => {
  it("is what was destroyed, plus ground, prisoners, the saved and the built", () => {
    expect(score({ val_killed: 640, captures: 1, towns: 2, prisoners: 3, revived: 4, built: 5 })).toBe(
      640 + 100 + 100 + 45 + 20 + 10
    )
  })
})

describe("accuracy", () => {
  it("is hits for shots, or nothing with no shots", () => {
    expect(accuracy({ shots: 200, hits: 30 })).toBe(15)
    expect(accuracy({})).toBeNull()
  })
})

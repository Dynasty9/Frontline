// What an after-action report's numbers mean, as the game's stats screen says
// it: the same formulas as BattleStats in scripts/game/battle_stats.gd (keep
// the two in step), so the report on the website rates every commander the way
// the game did at the end of the battle.

import type { Figures } from "@/lib/players"

const n = (r: Figures, k: keyof Figures) => Number(r[k] ?? 0) || 0
const clamp = (v: number) => Math.min(1, Math.max(0, v))

/**
 * How well a commander fought, 0-100: mostly what they destroyed against what
 * they lost (by supply value: 4:1 is as good as it gets, 1:4 as bad), then how
 * well their men shot and their share of their side's fight.
 */
export function rating(r: Figures, side: Figures): number {
  const vk = n(r, "val_killed")
  const ex = (vk + 60) / (n(r, "val_lost") + 60)
  const exchange = clamp(0.5 + (0.25 * Math.log(ex)) / Math.log(2))
  const shots = n(r, "shots")
  // most rounds are fired to keep heads down: one in seven finding its target is already good shooting
  const acc = shots >= 30 ? clamp(n(r, "hits") / shots / 0.15) : 0.5
  const sk = n(side, "val_killed")
  const share = sk > 0 ? clamp(vk / sk) : 0.5
  return 100 * (0.6 * exchange + 0.2 * acc + 0.2 * share)
}

export function ratingWord(v: number): string {
  if (v >= 85) return "Outstanding"
  if (v >= 70) return "Effective"
  if (v >= 55) return "Capable"
  if (v >= 40) return "Mixed"
  if (v >= 25) return "Costly"
  return "Ineffective"
}

/** Points: what they destroyed, plus ground taken, prisoners, saving men and building (a little). */
export function score(r: Figures): number {
  return Math.round(
    n(r, "val_killed") +
      100 * n(r, "captures") +
      50 * n(r, "towns") +
      15 * n(r, "prisoners") +
      5 * n(r, "revived") +
      2 * n(r, "built")
  )
}

/** Hits for shots fired, as a percentage (null when they hardly fired). */
export const accuracy = (r: Figures) => (n(r, "shots") > 0 ? (100 * n(r, "hits")) / n(r, "shots") : null)

/** A figure the report shows: from the record, or worked out from it (accuracy, units fielded). */
export type Measure = keyof Figures | "acc" | "fielded"

/**
 * The head-to-head rows of the game's summary (stats_panel.gd _Summary.ROWS):
 * [figure, label, which way is better (1 more, -1 fewer, 0 neither), what it counts].
 */
export const SUMMARY: [Measure, string, 1 | -1 | 0, string][] = [
  ["kills", "Enemy killed", 1, "Enemy soldiers killed."],
  ["downs", "Enemy wounded", 1, "Times an enemy soldier was put down wounded (some were saved, some bled out)."],
  ["lost", "Men lost", -1, "Own soldiers killed."],
  ["captured", "Men captured", -1, "Own soldiers taken prisoner."],
  ["veh_kills", "Vehicles destroyed", 1, "Enemy vehicles knocked out."],
  ["veh_lost", "Vehicles lost", -1, "Own vehicles knocked out."],
  ["bld_kills", "Buildings destroyed", 1, "Enemy buildings and defences knocked down (wrecked FOBs too)."],
  ["val_killed", "Value destroyed", 1, "What everything destroyed or captured cost the enemy, in supply."],
  ["acc", "Accuracy", 1, "Rounds that hit what they were aimed at."],
  ["prisoners", "Prisoners taken", 1, "Enemy soldiers who surrendered and were taken."],
  ["captures", "FOBs captured", 1, "Enemy FOBs taken over."],
  ["towns", "Towns taken", 1, "Towns and villages taken (each one's supply dump and trucks come with it)."],
  ["revived", "Wounded saved", 1, "Times a medic or a medevac brought a wounded man back."],
  ["delivered", "Supply delivered", 1, "Supply the trucks and helicopters brought to the FOBs."],
  ["spent", "Supply spent", 0, "Supply spent on troops, vehicles, buildings, research and fire support."],
  ["fielded", "Units fielded", 0, "Squads and vehicles trained or built."],
  ["built", "Structures built", 0, "Buildings and defences completed."],
  ["support", "Fire missions", 0, "Air and artillery support called in."],
]

/** A measure's value, as the summary shows it ("12", "14%"; "-" for no accuracy to speak of). */
export function measure(r: Figures, m: Measure): string {
  if (m === "acc") {
    const a = accuracy(r)
    return a === null ? "-" : `${Math.round(a)}%`
  }
  const v = m === "fielded" ? n(r, "squads") + n(r, "vehicles") : n(r, m)
  return Math.round(v).toLocaleString()
}

/** The number behind a measure, for comparing two sides. */
export const measureValue = (r: Figures, m: Measure) =>
  m === "acc" ? (accuracy(r) ?? 0) : m === "fielded" ? n(r, "squads") + n(r, "vehicles") : n(r, m)

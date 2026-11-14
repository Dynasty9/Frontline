// --gpu-bench: what each graphics setting costs the graphics card
// (scripts/test/gpu_bench.gd). Headless there is no GPU time to read, so this
// checks the run itself: it holds the battle, prices every setting the
// Cinematic preset turns on, writes its report, puts every setting back, and
// never saves the player's settings.
import test from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { ROOT } from "./lib/game.mjs";

// where Godot keeps user:// for this project on each system
const userDir = () => {
  if (process.platform === "win32") return path.join(process.env.APPDATA ?? "", "Godot", "app_userdata", "Frontline");
  if (process.platform === "darwin") return path.join(os.homedir(), "Library", "Application Support", "Godot", "app_userdata", "Frontline");
  return path.join(process.env.XDG_DATA_HOME ?? path.join(os.homedir(), ".local", "share"), "godot", "app_userdata", "Frontline");
};

test("the GPU benchmark prices every Cinematic setting and puts the settings back", async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "gpu-bench-"));
  const out = path.join(dir, "report.json");
  const settings = path.join(userDir(), "settings.cfg");
  const before = fs.existsSync(settings) ? fs.statSync(settings).mtimeMs : null;
  try {
    const { stdout, stderr } = await promisify(execFile)(
      process.env.GODOT || "godot",
      ["--headless", "--fixed-fps", "30", "--path", ROOT, "--", "--scenario=attack", "--seed=1", "--preset=cinematic",
        `--gpu-bench=${out}`, "--gpu-bench-at=1", "--gpu-bench-frames=2", "--gpu-bench-cycles=2"],
      { timeout: 120_000, maxBuffer: 16 * 1024 * 1024 },
    );
    assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error/);
    assert.match(stdout, /GPUBENCH done/);
    const report = JSON.parse(fs.readFileSync(out, "utf8"));
    const priced = new Set(report.settings.map((s) => s.key));
    for (const key of [...report.cinematic_keys, "cloud_shadows", "scale"]) {
      assert.ok(priced.has(key), `${key} was priced`);
    }
    for (const s of report.settings) {
      assert.equal(s.pairs.length, 2, `${s.key} was switched off and on twice`);
    }
    assert.equal(report.restored, true, "every setting is back as it was");
    assert.equal(report.no_save, true, "a test run never saves settings");
    const after = fs.existsSync(settings) ? fs.statSync(settings).mtimeMs : null;
    assert.equal(after, before, "the player's settings file wasn't written");
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

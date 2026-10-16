// Drives the game through its test port (scripts/test/test_port.gd): starts a
// headless copy with --test-port=0, reads the port it took from its output,
// connects, and sends one JSON command per line. Game time moves only on step(),
// in exact 1/30 s ticks, so a seed replays the same battle every time.
//
//   const game = await Game.start();
//   await game.load({ scenario: "attack", seed: 3 });
//   await game.step(30);
//   const { squads } = await game.query("squads", { team: 1 });
//   await game.close();
//
// GODOT names the Godot 4.7 executable (on Windows, the _console.exe build).

import { spawn } from "node:child_process";
import net from "node:net";
import path from "node:path";

export const ROOT = path.resolve(import.meta.dirname, "..", "..");
const READY = /TESTPORT listening 127\.0\.0\.1:(\d+)/;

/** A position for an order: [x, z] on the ground. */
export const v3 = (x, z) => ({ v3: [x, z] });

export class Game {
  /** Starts a headless game and connects to its test port. `args` go after the `--`. */
  static async start({ args = [], godot = process.env.GODOT || "godot", timeout = 120_000 } = {}) {
    const proc = spawn(godot, ["--headless", "--fixed-fps", "30", "--path", ROOT, "--", "--test-port=0", ...args], {
      stdio: ["ignore", "pipe", "pipe"],
    });
    const game = new Game(proc);
    const port = await game.#waitForPort(timeout);
    await game.#connect(port);
    return game;
  }

  #proc;
  #sock = null;
  #inbuf = "";
  #pending = []; // [resolve, reject, timer, cmd] in the order sent: replies come back in order
  #exit;
  #nextId = 1;
  /** The game's output so far (the last few hundred lines), for failure messages. */
  output = [];
  /** Script errors the game has counted since it started (every reply carries it). */
  errors = 0;

  constructor(proc) {
    this.#proc = proc;
    this.#exit = new Promise((resolve) => proc.on("exit", (code) => resolve(code)));
    const keep = (chunk) => {
      for (const line of chunk.toString().split(/\r?\n/)) {
        if (line === "") continue;
        this.output.push(line);
        if (process.env.FL_TEST_VERBOSE) console.log(`[game] ${line}`);
      }
      if (this.output.length > 400) this.output.splice(0, this.output.length - 400);
    };
    proc.stdout.on("data", keep);
    proc.stderr.on("data", keep);
  }

  #waitForPort(timeout) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => fail(new Error("the game never opened its test port")), timeout);
      const fail = (err) => {
        clearTimeout(timer);
        this.#proc.kill();
        reject(this.#withOutput(err));
      };
      const look = (chunk) => {
        const m = READY.exec(chunk.toString());
        if (m) {
          clearTimeout(timer);
          this.#proc.stdout.off("data", look);
          resolve(Number(m[1]));
        }
      };
      this.#proc.stdout.on("data", look);
      this.#proc.on("error", (err) => fail(err));
      this.#exit.then((code) => fail(new Error(`the game quit (exit code ${code}) before opening its test port`)));
    });
  }

  #connect(port) {
    return new Promise((resolve, reject) => {
      this.#sock = net.createConnection({ host: "127.0.0.1", port }, resolve);
      this.#sock.setNoDelay(true);
      this.#sock.on("error", reject);
      this.#sock.on("data", (chunk) => this.#onData(chunk));
      this.#sock.on("close", () => {
        for (const [, reject, timer, cmd] of this.#pending.splice(0)) {
          clearTimeout(timer);
          reject(this.#withOutput(new Error(`the game hung up during "${cmd}"`)));
        }
      });
    });
  }

  #onData(chunk) {
    this.#inbuf += chunk.toString();
    let nl;
    while ((nl = this.#inbuf.indexOf("\n")) >= 0) {
      const line = this.#inbuf.slice(0, nl);
      this.#inbuf = this.#inbuf.slice(nl + 1);
      const p = this.#pending.shift();
      if (!p) continue;
      const [resolve, reject, timer, cmd] = p;
      clearTimeout(timer);
      const reply = JSON.parse(line);
      this.errors = reply.errors ?? this.errors;
      if (reply.ok) resolve(reply);
      else reject(new Error(`${cmd}: ${reply.error}`));
    }
  }

  #withOutput(err) {
    err.message += `\n--- the game's last output ---\n${this.output.slice(-40).join("\n")}`;
    return err;
  }

  /**
   * Sends a command and waits for its reply (rejecting if the game says it
   * failed). A long step on a big map takes a while: `timeout` is in real ms.
   */
  send(cmd, fields = {}, { timeout = 600_000 } = {}) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(this.#withOutput(new Error(`no reply to "${cmd}" in ${timeout} ms`))), timeout);
      this.#pending.push([resolve, reject, timer, cmd]);
      this.#sock.write(JSON.stringify({ cmd, id: this.#nextId++, ...fields }) + "\n");
    });
  }

  hello() {
    return this.send("hello");
  }

  /** A fresh battle: { scenario } | { mission } | { battle: true } (AI against AI), with seed, play, static... */
  load(what) {
    return this.send("load", what);
  }

  /** Runs the game on: `seconds` of game time (or { ticks }). */
  step(seconds) {
    return this.send("step", typeof seconds === "object" ? seconds : { seconds });
  }

  /** Gives an order as team 0's or team 1's commander: order(0, "move", { squads: [1], pos: v3(10, 40) }). */
  order(team, t, fields = {}) {
    return this.send("order", { team, t, ...fields });
  }

  /** What's on the field: "world", "squads", "soldiers", "vehicles" or "structures", with { team, kind, ids }. */
  query(what, filters = {}) {
    return this.send("query", { what, ...filters });
  }

  /** The behaviour counters (world.stat) and the after-action summary. */
  stats() {
    return this.send("stats");
  }

  /** A fingerprint of the whole simulation: two runs from one seed agree on it tick for tick. */
  async hash() {
    return (await this.send("hash")).hash;
  }

  /** Script errors counted so far, and the last few of them. */
  scriptErrors() {
    return this.send("errors");
  }

  /** Quits the game and returns its exit code (0: no script errors, no failed checks). */
  async close() {
    if (this.#sock && !this.#sock.destroyed) {
      await this.send("quit", {}, { timeout: 30_000 }).catch(() => {});
      this.#sock.end();
    }
    const killer = setTimeout(() => this.#proc.kill(), 30_000);
    const code = await this.#exit;
    clearTimeout(killer);
    return code;
  }
}

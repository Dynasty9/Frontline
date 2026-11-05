// A worker owns the same Rust ticks and recording format as the desktop process.
let api, ready = false, loaded = false, replay = false, stopped = false;
let speed = 1, previous = performance.now(), accumulated = 0, outstanding = false;
const decoder = new TextDecoder();

function run(operation, argument = 0, bytes = new Uint8Array()) {
  const pointer = api.input_resize(bytes.byteLength);
  if (!pointer && bytes.byteLength) throw new Error('Simulation input exceeds its limit.');
  new Uint8Array(api.memory.buffer, pointer, bytes.byteLength).set(bytes);
  const failed = api.run(operation, argument);
  const output = new Uint8Array(api.memory.buffer, api.output_pointer(), api.output_length()).slice();
  if (failed) throw new Error(decoder.decode(output));
  return output;
}

function drain() {
  if (outstanding || !ready) return;
  const bytes = run(5);
  if (bytes.length) {
    outstanding = true;
    postMessage({kind: 'packets', bytes}, [bytes.buffer]);
  }
}

function fail(error) {
  stopped = true;
  postMessage({kind: 'error', message: String(error?.message || error)});
}

function pump() {
  if (stopped) return;
  try {
    const now = performance.now();
    if (loaded) {
      // A suspended browser tab resumes the battle without a burst of catch-up ticks.
      accumulated = Math.min(4, accumulated + (now - previous) * speed * 0.06);
      const count = Math.floor(accumulated);
      if (count) { run(2, count); accumulated -= count; }
    }
    previous = now;
    drain();
    setTimeout(pump, 4);
  } catch (error) { fail(error); }
}

self.onmessage = async ({data}) => {
  try {
    switch (data.kind) {
      case 'start': {
        if (api) throw new Error('Simulation already started.');
        const response = await fetch(new URL('frontline_browser.wasm', self.location.href));
        if (!response.ok) throw new Error('Could not load the simulation.');
        api = (await WebAssembly.instantiate(await response.arrayBuffer(), {})).instance.exports;
        replay = data.replay;
        speed = replay ? 0 : 1;
        let metadata = JSON.parse(decoder.decode(run(replay ? 7 : 0, 0, data.bytes)));
        if (replay) metadata = JSON.parse(decoder.decode(run(8, data.seek)));
        ready = true;
        postMessage({kind: 'ready', metadata});
        previous = performance.now();
        pump();
        break;
      }
      case 'open': run(4); drain(); break;
      case 'packet':
        run(3, 0, data.bytes);
        if (data.bytes[6] === 2) { loaded = true; previous = performance.now(); }
        drain();
        break;
      case 'consumed': outstanding = false; drain(); break;
      case 'speed':
        if (!Number.isFinite(data.value) || data.value < 0 || data.value > 4) throw new Error('Invalid playback speed.');
        speed = data.value; previous = performance.now(); accumulated = 0;
        break;
      case 'stop': {
        stopped = true;
        const bytes = replay ? new Uint8Array() : run(6);
        postMessage({kind: 'finished', bytes}, [bytes.buffer]);
        close();
        break;
      }
      default: throw new Error('Unknown simulation worker message.');
    }
  } catch (error) { fail(error); }
};

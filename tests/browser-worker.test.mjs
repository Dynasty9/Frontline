import assert from 'node:assert/strict';
import { readFile, access } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { Worker } from 'node:worker_threads';
import { test } from 'node:test';
import vm from 'node:vm';

const root = resolve(import.meta.dirname, '..');
const wasm = resolve(root, 'native/target/wasm32-unknown-unknown/release/frontline_browser.wasm');
const contract = process.env.FL_BROWSER_CONTRACT;
const bridgeSource = await readFile(resolve(root, 'tools/web/simulation-bridge.js'), 'utf8');

test('browser bridge bounds handoffs and only acknowledges consumed packet bundles', () => {
  const sent = [];
  const context = vm.createContext({Uint8Array, DataView, URL, atob, document: {baseURI:'https://example.test/game/'}, Worker: class {
    postMessage(message) { sent.push(message); }
    terminate() {}
  }});
  vm.runInContext(bridgeSource, context);
  const bridge = new context.FrontlineSimulation();
  assert.equal(bridge.allocate(513 * 1024 * 1024), false);
  assert.equal(bridge.allocate(3), true);
  bridge.append('AQI=');
  assert.throws(() => bridge.start(false, 0), /Incomplete/);
  bridge.append('Aw==');
  assert.throws(() => bridge.append('BA=='), /Invalid/);
  bridge.start(false, 0);
  assert.deepEqual([...sent[0].bytes], [1,2,3]);
  const bundle = new Uint8Array(42);
  new DataView(bundle.buffer).setUint32(0, 16, true);
  new DataView(bundle.buffer).setUint32(21, 16, true);
  bundle[25] = 1;
  bridge.worker.onmessage({data:{kind:'packets', bytes:bundle}});
  assert.equal(bridge.read()[0], 0);
  assert.equal(sent.length, 1);
  assert.equal(bridge.read()[0], 1);
  assert.equal(sent.at(-1).kind, 'consumed');
  assert.equal(bridge.read(), null);
  bridge.worker.onmessage({data:{kind:'packets', bytes:new Uint8Array([1,2])}});
  assert.equal(bridge.read(), null);
  assert.match(bridge.error, /Malformed/);
});

function packet(kind, payload = '') {
  const out = Buffer.alloc(16 + Buffer.byteLength(payload));
  out.write('FLNP'); out.writeUInt16LE(3, 4); out[6] = kind;
  out.write(payload, 16);
  return new Uint8Array(out);
}

async function startWorker(t, input, replay, seek = 0) {
  const code = `const {parentPort} = require('node:worker_threads');
    globalThis.self = globalThis;
    globalThis.location = {href: ${JSON.stringify(pathToFileURL(resolve(root, 'tools/web/simulation-worker.js')).href)}};
    globalThis.postMessage = (data, transfer) => parentPort.postMessage(data, transfer);
    globalThis.close = () => process.exit(0);
    globalThis.fetch = async () => ({ok:true, arrayBuffer:async () => {
      const b = await require('node:fs/promises').readFile(${JSON.stringify(wasm)});
      return b.buffer.slice(b.byteOffset, b.byteOffset+b.byteLength);
    }});
    import(location.href).then(() => parentPort.on('message', data => self.onmessage({data})));`;
  const worker = new Worker(code, {eval:true});
  t.after(() => worker.terminate());
  const packets = [], messages = [];
  let wake;
  worker.on('message', message => {
    messages.push(message);
    if (message.kind === 'packets') {
      const bytes = message.bytes;
      for (let offset = 0; offset < bytes.length;) {
        const length = new DataView(bytes.buffer, bytes.byteOffset + offset, 4).getUint32(0, true);
        assert.ok(length >= 16 && offset + 5 + length <= bytes.length);
        packets.push(bytes.slice(offset + 5, offset + 5 + length));
        offset += 5 + length;
      }
      worker.postMessage({kind:'consumed'});
    }
    wake?.();
  });
  const wait = async predicate => {
    while (!predicate()) {
      const error = messages.find(m => m.kind === 'error');
      if (error) throw new Error(error.message);
      await new Promise(r => {wake = r;});
    }
  };
  worker.postMessage({kind:'start', bytes:new Uint8Array(input), replay, seek});
  await wait(() => messages.some(m => m.kind === 'ready'));
  worker.postMessage({kind:'open'});
  await wait(() => packets.some(p => p[6] === 22));
  return {worker, packets, messages, wait};
}

test('actual worker runs native recordings, verifies conclusions and records live commands', {skip:!contract, timeout:30000}, async t => {
  await access(wasm);
  const recorded = await readFile(contract);
  const replay = await startWorker(t, recorded, true, 120);
  await replay.wait(() => replay.packets.some(p => p[6] === 29));
  const status = JSON.parse(Buffer.from(replay.packets.find(p => p[6] === 29).slice(16)));
  assert.equal(status.verified, true);
  assert.equal(status.position, 2);
  const live = await startWorker(t, await readFile(contract + '.initial'), false);
  live.worker.postMessage({kind:'packet', bytes:packet(1, '{"t":"chat","text":"Browser test","team_only":true}')});
  live.worker.postMessage({kind:'packet', bytes:packet(2)});
  await live.wait(() => live.packets.some(p => p[6] === 25 && Buffer.from(p.slice(16)).toString().includes('Browser test')));
  live.worker.postMessage({kind:'stop'});
  await live.wait(() => live.messages.some(m => m.kind === 'finished'));
  const recording = live.messages.find(m => m.kind === 'finished').bytes;
  const {instance} = await WebAssembly.instantiate(await readFile(wasm), {});
  const api = instance.exports;
  const pointer = api.input_resize(recording.length);
  new Uint8Array(api.memory.buffer, pointer, recording.length).set(recording);
  assert.equal(api.run(1, 0), 0, 'A fresh verifier must accept the worker recording');
  const verified = JSON.parse(new TextDecoder().decode(new Uint8Array(api.memory.buffer, api.output_pointer(), api.output_length())));
  assert.ok(verified.frames >= 4);
});

// Keep one transferable packet bundle in flight; a slow view cannot flood the browser.
globalThis.FrontlineSimulation = class {
  constructor() {
    this.worker = new Worker(new URL('simulation-worker.js', document.baseURI));
    this.error = '';
    this.metadata = '';
    this.finished = false;
    this.recording = null;
    this.bundle = null;
    this.offset = 0;
    this.input = null;
    this.written = 0;
    this.worker.onerror = event => { this.error = event.message || 'Simulation worker stopped.'; };
    this.worker.onmessage = ({data}) => {
      if (data.kind === 'ready') this.metadata = JSON.stringify(data.metadata);
      else if (data.kind === 'packets') {
        if (this.bundle || !(data.bytes instanceof Uint8Array) || data.bytes.length > 1024 * 1024) {
          this.error = 'Invalid simulation packet bundle.';
          return;
        }
        this.bundle = data.bytes;
        this.offset = 0;
      } else if (data.kind === 'error') this.error = data.message;
      else if (data.kind === 'finished') {
        this.recording = data.bytes;
        this.finished = true;
        this.worker.terminate();
      }
    };
  }
  allocate(length) {
    if (!Number.isSafeInteger(length) || length <= 0 || length > 512 * 1024 * 1024) return false;
    this.input = new Uint8Array(length);
    this.written = 0;
    return true;
  }
  append(base64) {
    const chunk = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
    if (!this.input || this.written + chunk.length > this.input.length) throw new Error('Invalid simulation handoff.');
    this.input.set(chunk, this.written);
    this.written += chunk.length;
  }
  start(replay, seek) {
    if (!this.input || this.written !== this.input.length) throw new Error('Incomplete simulation handoff.');
    this.worker.postMessage({kind: 'start', bytes: this.input, replay, seek}, [this.input.buffer]);
    this.input = null;
  }
  open() { this.worker.postMessage({kind: 'open'}); }
  send(base64) {
    const bytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
    if (bytes.length < 16 || bytes.length > 65568) return false;
    this.worker.postMessage({kind: 'packet', bytes}, [bytes.buffer]);
    return true;
  }
  read() {
    if (!this.bundle) return null;
    const bytes = this.bundle;
    const offset = this.offset;
    const length = bytes.length - offset >= 5 ? new DataView(bytes.buffer, bytes.byteOffset + offset, 4).getUint32(0, true) : 0;
    if (length < 16 || length > 65568 || offset + 5 + length > bytes.length || bytes[offset + 4] > 2) {
      this.error = 'Malformed simulation packet bundle.';
      this.bundle = null;
      return null;
    }
    const packet = bytes.subarray(offset + 4, offset + 5 + length);
    this.offset += 5 + length;
    if (this.offset === bytes.length) {
      this.bundle = null;
      this.worker.postMessage({kind: 'consumed'});
    }
    return packet;
  }
  set_speed(value) { this.worker.postMessage({kind: 'speed', value}); }
  stop() { this.worker.postMessage({kind: 'stop'}); }
  terminate() { this.worker.terminate(); }
};

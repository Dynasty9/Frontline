import {createServer} from 'node:http';
import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
let mode='valid';
const server=createServer((req,res)=>{
 if(req.url==='/') res.end('<div id="root"></div>');
 else if(req.url==='/game/viewer.json') res.end(mode==='fallback' ? '<html>fallback</html>' : JSON.stringify({format:1,manual:3}));
 else res.end(mode==='bad-wasm' ? '<html>fallback</html>' : Buffer.from([0,97,115,109]));
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
try {
 for(const item of ['valid','fallback','bad-wasm']) {
  mode=item;
  const child=spawn(process.execPath,['.github/scripts/production_web_smoke.mjs'],{env:{...process.env,WEB_ORIGIN:`http://127.0.0.1:${server.address().port}`},stdio:'ignore'});
  const code=await new Promise(r=>child.on('exit',r));
  assert.equal(code===0,item==='valid',item);
  console.log(`${item}: expected result`);
 }
} finally {server.close();}

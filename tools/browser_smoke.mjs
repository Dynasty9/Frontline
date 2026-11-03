// Uses the website's existing Playwright dependency against the actual Godot export.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
const require = createRequire(new URL('../web/package.json', import.meta.url));
const playwright = await import(pathToFileURL(process.env.PLAYWRIGHT_MODULE || require.resolve('playwright')).href);
const {chromium} = playwright.default || playwright;
const url = new URL(process.env.FRONTLINE_WEB_URL || 'http://localhost:8080/game/index.html');
const browser = await chromium.launch({headless:true,
  executablePath: process.env.CHROME_BIN || undefined,
  args:['--enable-webgl', '--ignore-gpu-blocklist', '--enable-unsafe-swiftshader']});
try {
  const page = await browser.newPage({viewport:{width:960,height:640}});
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    const text = message.text();
    if (/SCRIPT ERROR|ERROR:|panicked/.test(text)) errors.push(text);
    if (message.type() !== 'warning') console.log(text);
  });
  await page.route(url.href, async route => {
    const response = await route.fetch();
    const html = await response.text();
    assert.ok(html.includes('"args":[]'), 'Expected an unmodified Godot export');
    await route.fulfill({response, body:html.replace('"args":[]','"args":["--","--browser-simulation-test"]')});
  });
  const completed = page.waitForEvent('console', {predicate:message=>message.text().includes('BROWSER_SERVER_TEST'),timeout:300000});
  await page.goto(url.href);
  const result = (await completed).text();
  assert.match(result, /BROWSER_SERVER_TEST failures=0/);
  assert.deepEqual(errors, []);
  await mkdir(resolve('build'), {recursive:true});
  await page.screenshot({path:resolve('build/browser-simulation.png')});
  await page.unroute(url.href);
  await page.addInitScript(() => {
    window.modelMessages = [];
    window.addEventListener('message', event => {
      if (event.source === window && event.origin === location.origin) window.modelMessages.push(event.data);
    });
  });
  const manual = new URL(url);
  manual.searchParams.set('manual', 'hunter');
  await page.goto(manual.href);
  await page.waitForFunction(() => window.modelMessages.some(message => message.type === 'frontline-model-loaded'), undefined, {timeout:60000});
  await page.evaluate(() => window.postMessage({type:'frontline-model', action:'select', key:'hunter'}, location.origin));
  await page.waitForFunction(() => window.modelMessages.some(message => message.type === 'frontline-model-ready' && message.key === 'hunter'), undefined, {timeout:60000});
  await page.screenshot({path:resolve('build/browser-model.png')});
  assert.deepEqual(errors, []);
  console.log('BROWSER_MODEL_TEST passed hunter');
} finally {
  await browser.close();
}

#!/usr/bin/env node
/*
 * Interactive iOS Simulator selector to avoid physical device code signing.
 * Lists available iOS simulators via `xcrun simctl` and runs RN CLI with UDID.
 */

const { execSync, spawn } = require('node:child_process');
const readline = require('node:readline');

function getAvailableSimulators() {
  try {
    const out = execSync('xcrun simctl list devices available -j', {
      encoding: 'utf8',
    });
    const json = JSON.parse(out);
    const devices = json.devices || {};
    const sims = [];
    for (const runtime of Object.keys(devices)) {
      if (!/iOS/i.test(runtime)) continue;
      const osVersionMatch = runtime.match(/iOS[.-](\d+)(?:-(\d+))?/i);
      const osPretty = osVersionMatch
        ? `iOS ${osVersionMatch[1]}${osVersionMatch[2] ? '.' + osVersionMatch[2] : ''}`
        : 'iOS';
      for (const d of devices[runtime] || []) {
        if (!d.isAvailable) continue;
        sims.push({ name: d.name, udid: d.udid, os: osPretty });
      }
    }
    // Prefer iPhone over iPad, then by OS desc, then by name
    sims.sort((a, b) => {
      const aPhone = a.name.toLowerCase().includes('iphone') ? 0 : 1;
      const bPhone = b.name.toLowerCase().includes('iphone') ? 0 : 1;
      if (aPhone !== bPhone) return aPhone - bPhone;
      // Extract numeric OS version for sort
      const osA = parseFloat(a.os.replace(/[^0-9.]/g, '')) || 0;
      const osB = parseFloat(b.os.replace(/[^0-9.]/g, '')) || 0;
      if (osA !== osB) return osB - osA;
      return a.name.localeCompare(b.name);
    });
    return sims;
  } catch {
    return [];
  }
}

function promptSelect(items) {
  return new Promise((resolve) => {
    if (!items.length) return resolve(null);
    console.log('Select an iOS simulator to run:\n');
    items.forEach((it, idx) => {
      const n = String(idx + 1).padStart(2, ' ');
      console.log(`[${n}] ${it.name} (${it.os})  ${it.udid}`);
    });
    console.log();
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });
    rl.question(`Enter number (1-${items.length}, default 1): `, (answer) => {
      rl.close();
      const num = parseInt(String(answer).trim(), 10);
      const idx =
        isFinite(num) && num >= 1 && num <= items.length ? num - 1 : 0;
      resolve(items[idx]);
    });
  });
}

async function main() {
  const sims = getAvailableSimulators();
  if (!sims.length) {
    console.error('No iOS simulators found. Falling back to RN CLI.');
    const child = spawn(
      './node_modules/.bin/react-native',
      ['run-ios', '--list-devices'],
      { stdio: 'inherit' }
    );
    child.on('exit', (code) => process.exit(code || 0));
    return;
  }
  const choice = await promptSelect(sims);
  if (!choice) {
    console.error('No simulator selected. Aborting.');
    process.exit(1);
  }
  const args = ['run-ios', '--udid', choice.udid];
  const child = spawn('./node_modules/.bin/react-native', args, {
    stdio: 'inherit',
  });
  child.on('exit', (code) => process.exit(code || 0));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

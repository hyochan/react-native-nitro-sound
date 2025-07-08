const fs = require('fs');
const path = require('path');

// Read root package.json
const rootPkg = require('../../package.json');
const version = rootPkg.version;

// Generate version.ts content
const versionContent = `// This file is auto-generated. Do not edit manually.
export const version = '${version}';`;

// Write to version.ts
const versionPath = path.join(__dirname, '../src/version.ts');
fs.writeFileSync(versionPath, versionContent, 'utf8');

console.log(`✅ Synced version ${version} to plugin/src/version.ts`);
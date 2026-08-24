const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const tags = {
  'win32-x64': 'win32-x64-msvc',
  'linux-x64': 'linux-x64-gnu',
  'linux-arm64': 'linux-arm64-gnu',
  'darwin-x64': 'darwin-x64',
  'darwin-arm64': 'darwin-arm64',
};

const tag = tags[`${process.platform}-${process.arch}`];
if (!tag) {
  console.error(`Unsupported platform for bundled SyncLite Node package: ${process.platform}-${process.arch}`);
  process.exit(1);
}

const packagePath = path.resolve(__dirname, '..', '..', 'lib', 'nodejs', `synclite-1.1.0-${tag}.tgz`);
if (!fs.existsSync(packagePath)) {
  console.error(`SyncLite Node package not found: ${packagePath}`);
  console.error('Build or install a platform release that contains lib/nodejs/synclite-1.1.0-<platform>.tgz.');
  process.exit(1);
}

const result = spawnSync('npm', ['install', packagePath], {
  cwd: __dirname,
  stdio: 'inherit',
  shell: process.platform === 'win32',
});

if (result.status !== 0 && result.status !== null) {
  process.exit(result.status);
}

process.exit(0);

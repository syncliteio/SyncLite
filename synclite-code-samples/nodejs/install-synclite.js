const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const version = '1.1.0';
const tags = {
  'win32-x64': 'win32-x64-msvc',
  'linux-x64': 'linux-x64-gnu',
  'linux-arm64': 'linux-arm64-gnu',
};

const tag = tags[`${process.platform}-${process.arch}`];
if (!tag) {
  console.error(`Unsupported SyncLite offline platform: ${process.platform}-${process.arch}`);
  process.exit(1);
}

const packageDir = path.resolve(__dirname, '..', '..', 'lib', 'nodejs');
const mainPackage = path.join(packageDir, `synclite-${version}.tgz`);
// npm strips @ and / when deriving an archive name for the scoped package
// @synclite/native-<platform>.
const nativePackage = path.join(packageDir, `synclite-native-${tag}-${version}.tgz`);

for (const packageFile of [mainPackage, nativePackage]) {
  if (!fs.existsSync(packageFile)) {
    console.error(`Missing bundled package: ${packageFile}`);
    process.exit(1);
  }
}

const result = process.platform === 'win32'
  ? spawnSync(
    path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'cmd.exe'),
    ['/d', '/c', `npm install --offline "${mainPackage}" "${nativePackage}"`],
    { cwd: __dirname, stdio: 'inherit', shell: false },
  )
  : spawnSync('npm', ['install', '--offline', mainPackage, nativePackage], {
    cwd: __dirname,
    stdio: 'inherit',
    shell: false,
  });

process.exit(result.status ?? 1);

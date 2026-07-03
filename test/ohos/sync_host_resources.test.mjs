import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const repoRoot = path.resolve(import.meta.dirname, '../..');
const syncScriptPath = path.join(repoRoot, 'scripts/ohos/sync_host_resources.mjs');
const generatedIconPaths = [
  'ohos/AppScope/resources/base/media/app_icon.png',
  'ohos/entry/src/main/resources/base/media/icon.png',
];

test('OHOS host icons are not tracked in git', () => {
  for (const relativePath of generatedIconPaths) {
    const result = spawnSync('git', ['ls-files', '--error-unmatch', relativePath], {
      cwd: repoRoot,
      encoding: 'utf8',
    });

    assert.notEqual(
      result.status,
      0,
      `${relativePath} should be generated from the shared source instead of tracked in git`,
    );
  }
});

test('OHOS rawfile flutter assets are not tracked in git', () => {
  const result = spawnSync(
    'bash',
    ['-lc', 'git ls-files "ohos/entry/src/main/resources/rawfile/flutter_assets/**"'],
    {
      cwd: repoRoot,
      encoding: 'utf8',
    },
  );

  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), '');
});

test('OHOS hvigor build wires the host resource sync plugin', () => {
  const hvigorfile = fs.readFileSync(path.join(repoRoot, 'ohos/hvigorfile.ts'), 'utf8');

  assert.match(hvigorfile, /syncHostResourcesPlugin/);
});

test('host resource sync script copies the shared icon to generated OHOS icon targets', () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'flclash-ohos-host-resources-'));
  const sourcePath = path.join(tempDir, 'source.txt');
  const appIconPath = path.join(tempDir, 'AppScope', 'resources', 'base', 'media', 'app_icon.png');
  const entryIconPath = path.join(tempDir, 'entry', 'src', 'main', 'resources', 'base', 'media', 'icon.png');

  fs.writeFileSync(sourcePath, 'single-source-icon');

  const result = spawnSync(
    'node',
    [
      syncScriptPath,
      '--source',
      sourcePath,
      '--app-icon-dest',
      appIconPath,
      '--entry-icon-dest',
      entryIconPath,
    ],
    {
      cwd: repoRoot,
      encoding: 'utf8',
    },
  );

  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.equal(fs.readFileSync(appIconPath, 'utf8'), 'single-source-icon');
  assert.equal(fs.readFileSync(entryIconPath, 'utf8'), 'single-source-icon');
});

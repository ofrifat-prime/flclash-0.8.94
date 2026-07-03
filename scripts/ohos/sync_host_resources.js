'use strict';

const fs = require('fs');
const path = require('path');

const DEFAULT_SOURCE_PATH = path.resolve(__dirname, '../../assets/images/icon.png');
const DEFAULT_APP_ICON_DEST_PATH = path.resolve(
    __dirname,
    '../../ohos/AppScope/resources/base/media/app_icon.png',
);
const DEFAULT_ENTRY_ICON_DEST_PATH = path.resolve(
    __dirname,
    '../../ohos/entry/src/main/resources/base/media/icon.png',
);

function ensureParentDirSync(filePath) {
  fs.mkdirSync(path.dirname(filePath), {recursive: true});
}

function copyFileSync(sourcePath, destinationPath) {
  if (!fs.existsSync(sourcePath)) {
    throw new Error(`Shared icon does not exist: ${sourcePath}`);
  }

  ensureParentDirSync(destinationPath);
  fs.copyFileSync(sourcePath, destinationPath);
}

function syncHostResources(options = {}) {
  const sourcePath = path.resolve(options.sourcePath ?? DEFAULT_SOURCE_PATH);
  const appIconDestPath = path.resolve(
      options.appIconDestPath ?? DEFAULT_APP_ICON_DEST_PATH,
  );
  const entryIconDestPath = path.resolve(
      options.entryIconDestPath ?? DEFAULT_ENTRY_ICON_DEST_PATH,
  );

  copyFileSync(sourcePath, appIconDestPath);
  copyFileSync(sourcePath, entryIconDestPath);

  return {
    sourcePath,
    destinations: [
      appIconDestPath,
      entryIconDestPath,
    ],
  };
}

module.exports = {
  DEFAULT_APP_ICON_DEST_PATH,
  DEFAULT_ENTRY_ICON_DEST_PATH,
  DEFAULT_SOURCE_PATH,
  syncHostResources,
};

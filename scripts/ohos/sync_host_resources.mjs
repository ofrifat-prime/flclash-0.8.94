import {createRequire} from 'node:module';

const require = createRequire(import.meta.url);
const {syncHostResources} = require('./sync_host_resources.js');

function parseArgs(argv) {
  const options = {};

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const value = argv[index + 1];

    switch (arg) {
      case '--source':
        options.sourcePath = value;
        index += 1;
        break;
      case '--app-icon-dest':
        options.appIconDestPath = value;
        index += 1;
        break;
      case '--entry-icon-dest':
        options.entryIconDestPath = value;
        index += 1;
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return options;
}

try {
  const result = syncHostResources(parseArgs(process.argv.slice(2)));
  console.log(
      `Synced ${result.sourcePath} -> ${result.destinations.join(', ')}`,
  );
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}

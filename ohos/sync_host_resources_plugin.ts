const {syncHostResources} = require('../scripts/ohos/sync_host_resources.js');

export function syncHostResourcesPlugin() {
  return {
    pluginId: 'sync-host-resources-plugin',
    apply(rootNode) {
      const runSync = () => {
        syncHostResources();
      };

      runSync();
      rootNode.afterNodeEvaluate(() => {
        runSync();
      });
    },
  };
}

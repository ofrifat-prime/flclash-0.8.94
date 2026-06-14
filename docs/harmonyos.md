# HarmonyOS NEXT build notes

This repository now contains an `ohos/` host project and minimal local plugin stubs so the codebase can be migrated toward OpenHarmony.

## Current status

- Branch: `feat/ohos-support`
- Added OpenHarmony host project under `ohos/`
- Added local plugin `ohos/` platform skeletons for:
  - `plugins/proxy`
  - `plugins/rust_api`
  - `plugins/wifi_ssid`
  - `plugins/window_ext`
  - `plugins/setup`
- Dart platform checks now treat OpenHarmony as a mobile target where the existing Android/mobile code path is expected
- The local plugin `ohos/` implementations added in this branch are registration/build skeletons, not full feature-complete HarmonyOS ports
- Release HAP compilation and signing now work with the OpenHarmony SDK's built-in demo signing materials when `OHOS_SDK_HOME` points to the OpenHarmony SDK root

## Hard prerequisites

This project is pinned to modern Flutter on the mainline, and the OpenHarmony Flutter toolchain is still published on separate branches/releases. In this environment a verified `.hap` was not produced because the currently available SDK combinations do not yet line up with this repository's Dart and Flutter constraints.

Before building, install and verify:

1. DevEco Studio / OpenHarmony SDK with `hvigor`, `ohpm`, `hdc`
2. OpenHarmony Flutter SDK branch compatible with this project
3. A dependency set that provides `ohos` implementations for all required plugins
4. `OHOS_SDK_HOME` or `OHOS_BASE_SDK_HOME` must point to the OpenHarmony SDK root, for example:

```bash
export OHOS_SDK_HOME=/path/to/sdk/default/openharmony
export OHOS_BASE_SDK_HOME=$OHOS_SDK_HOME
```

## Verified toolchain findings

The following combinations were validated in this branch:

- `3.7.12-ohos-1.0.4`
  - Flutter/Dart toolchain starts, but `flutter pub get` fails immediately because it bundles Dart `2.19.6`
  - This repository requires Dart `>=3.8.0`
- `3.22.1-ohos-1.1.0` and `3.22.1-ohos-1.1.1`
  - `flutter --version --machine` reports a valid OpenHarmony Flutter version
  - Both bundle Dart `3.4.0`
  - This is still below the repository requirement `>=3.8.0`
- `oh-3.35.7-release`
  - Bundles Dart `3.9.2`, which is new enough for this repository
  - The current published branch snapshot reports Flutter version `0.0.0-unknown` during pub version solving
  - Because local plugins such as `plugins/setup` require Flutter `>=3.3.0`, `flutter pub get` still fails before dependency resolution can continue

In this workspace, `oh-3.35.7-release` plus the OpenHarmony 6.0.2(22) SDK can produce a signed release HAP after the local hvigor wrapper prepares signing assets from the SDK-provided OpenHarmony demo keystore.

## Recommended build path

1. Clone OpenHarmony Flutter SDK from the current upstream release source
2. Select a release that is both:
   - published with a valid Flutter semantic version
   - bundled with Dart `>=3.8.0`
3. Point Flutter to the Harmony SDK:

```bash
flutter config --enable-ohos
flutter config --ohos-sdk <OpenHarmony SDK path>
```

4. Regenerate the `ohos/` host if your chosen Flutter OHOS branch requires a newer template
5. Resolve third-party plugin compatibility for:
   - `path_provider`
   - `shared_preferences`
   - `url_launcher`
   - `image_picker`
   - `file_picker`
   - `device_info_plus`
   - `connectivity_plus`
   - `package_info_plus`
   - `app_links`
   - `mobile_scanner`
   - `dynamic_color`

## Build command

After a compatible Harmony toolchain is installed and dependencies are aligned, build from the project root with the Harmony-enabled Flutter SDK:

```bash
dart setup.dart ohos
```

Or build directly in the host project:

```bash
cd ohos
hvigorw --mode module -p product=default -p module=entry assembleHap
```

The host build still emits the default hvigor artifact at:

```text
ohos/entry/build/default/outputs/default/entry-default-signed.hap
```

The release-style artifact copied by `setup.dart` is:

```text
dist/FlClash-<version>-ohos-arm64.hap
```

During the build, `ohos/hvigor/hvigor-wrapper.js` prepares these generated signing assets under `ohos/hvigor/.signing/openharmony/`:

- `OpenHarmonyApplicationRelease.cer`
- `OpenHarmonyProfileRelease.json`
- `OpenHarmonyProfileRelease.p7b`

These files are generated from the SDK's built-in `OpenHarmony.p12` demo keystore and are ignored by git.

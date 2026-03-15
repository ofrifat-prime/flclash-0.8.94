import 'dart:io';

import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tray_manager/tray_manager.dart';

import 'app_localizations.dart';
import 'constant.dart';
import 'system.dart';
import 'window.dart';

class Tray {
  static Tray? _instance;

  Tray._internal();

  factory Tray() {
    _instance ??= Tray._internal();
    return _instance!;
  }

  String get trayIconSuffix {
    return system.isWindows ? 'ico' : 'png';
  }

  Future<void> destroy() async {
    await trayManager.destroy();
  }

  String get _macosIconDir => 'assets/images/icon/macos';

  String getTryIcon({
    required bool isStart,
    required bool tunEnable,
    required bool systemProxy,
    String? customStopped,
    String? customProxy,
    String? customTun,
  }) {
    final defaultSuffix =
        system.isMacOS ? 'png' : trayIconSuffix;
    final defaultDir =
        system.isMacOS ? _macosIconDir : 'assets/images/icon';
    if (!isStart || (!tunEnable && !systemProxy)) {
      final p = customStopped;
      if (p != null && File(p).existsSync()) return p;
      return '$defaultDir/status_1.$defaultSuffix';
    }
    if (tunEnable) {
      final p = customTun;
      if (p != null && File(p).existsSync()) return p;
      return '$defaultDir/status_3.$defaultSuffix';
    }
    final p = customProxy;
    if (p != null && File(p).existsSync()) return p;
    return '$defaultDir/status_2.$defaultSuffix';
  }

  Future _updateSystemTray({
    required bool isStart,
    required bool tunEnable,
    required bool systemProxy,
    String? customStopped,
    String? customProxy,
    String? customTun,
    required bool trayIconUseTemplate,
  }) async {
    if (Platform.isLinux) {
      await trayManager.destroy();
    }
    final iconPath = getTryIcon(
      isStart: isStart,
      tunEnable: tunEnable,
      systemProxy: systemProxy,
      customStopped: customStopped,
      customProxy: customProxy,
      customTun: customTun,
    );
    await trayManager.setIcon(
      iconPath,
      isTemplate: iconPath.startsWith('/') ? trayIconUseTemplate : true,
    );
    if (!Platform.isLinux) {
      await trayManager.setToolTip(appName);
    }
  }

  Future<void> update({
    required TrayState trayState,
    required Traffic traffic,
    String? trayIconStoppedPath,
    String? trayIconProxyPath,
    String? trayIconTunPath,
    required bool trayIconUseTemplate,
  }) async {
    if (system.isAndroid) {
      return;
    }
    if (!system.isLinux) {
      await _updateSystemTray(
        isStart: trayState.isStart,
        tunEnable: trayState.tunEnable,
        systemProxy: trayState.systemProxy,
        customStopped: trayIconStoppedPath,
        customProxy: trayIconProxyPath,
        customTun: trayIconTunPath,
        trayIconUseTemplate: trayIconUseTemplate,
      );
    }
    List<MenuItem> menuItems = [];
    final showMenuItem = MenuItem(
      label: appLocalizations.show,
      onClick: (_) {
        window?.show();
      },
    );
    menuItems.add(showMenuItem);
    final startMenuItem = MenuItem.checkbox(
      label: trayState.isStart ? appLocalizations.stop : appLocalizations.start,
      onClick: (_) async {
        appController.updateStart();
      },
      checked: false,
    );
    menuItems.add(startMenuItem);
    if (system.isMacOS) {
      final speedStatistics = MenuItem.checkbox(
        label: appLocalizations.speedStatistics,
        onClick: (_) async {
          appController.updateSpeedStatistics();
        },
        checked: trayState.showTrayTitle,
      );
      menuItems.add(speedStatistics);
    }
    menuItems.add(MenuItem.separator());
    for (final mode in Mode.values) {
      menuItems.add(
        MenuItem.checkbox(
          label: Intl.message(mode.name),
          onClick: (_) {
            appController.changeMode(mode);
          },
          checked: mode == trayState.mode,
        ),
      );
    }
    menuItems.add(MenuItem.separator());
    if (system.isMacOS) {
      for (final group in trayState.groups) {
        List<MenuItem> subMenuItems = [];
        for (final proxy in group.all) {
          subMenuItems.add(
            MenuItem.checkbox(
              label: proxy.name,
              checked:
                  appController.getSelectedProxyName(group.name) == proxy.name,
              onClick: (_) {
                appController.updateCurrentSelectedMap(group.name, proxy.name);
                appController.changeProxy(
                  groupName: group.name,
                  proxyName: proxy.name,
                );
              },
            ),
          );
        }
        menuItems.add(
          MenuItem.submenu(
            label: group.name,
            submenu: Menu(items: subMenuItems),
          ),
        );
      }
      if (trayState.groups.isNotEmpty) {
        menuItems.add(MenuItem.separator());
      }
    }
    if (trayState.isStart) {
      menuItems.add(
        MenuItem.checkbox(
          label: appLocalizations.tun,
          onClick: (_) {
            appController.updateTun();
          },
          checked: trayState.tunEnable,
        ),
      );
      menuItems.add(
        MenuItem.checkbox(
          label: appLocalizations.systemProxy,
          onClick: (_) {
            appController.updateSystemProxy();
          },
          checked: trayState.systemProxy,
        ),
      );
      menuItems.add(MenuItem.separator());
    }
    final autoStartMenuItem = MenuItem.checkbox(
      label: appLocalizations.autoLaunch,
      onClick: (_) async {
        appController.updateAutoLaunch();
      },
      checked: trayState.autoLaunch,
    );
    final copyEnvVarMenuItem = MenuItem(
      label: appLocalizations.copyEnvVar,
      onClick: (_) async {
        await _copyEnv(trayState.port);
      },
    );
    menuItems.add(autoStartMenuItem);
    menuItems.add(copyEnvVarMenuItem);
    menuItems.add(MenuItem.separator());
    final exitMenuItem = MenuItem(
      label: appLocalizations.exit,
      onClick: (_) async {
        await appController.handleExit();
      },
    );
    menuItems.add(exitMenuItem);
    final menu = Menu(items: menuItems);
    await trayManager.setContextMenu(menu);
    if (system.isLinux) {
      await _updateSystemTray(
        isStart: trayState.isStart,
        tunEnable: trayState.tunEnable,
        systemProxy: trayState.systemProxy,
        customStopped: trayIconStoppedPath,
        customProxy: trayIconProxyPath,
        customTun: trayIconTunPath,
        trayIconUseTemplate: trayIconUseTemplate,
      );
    }
    updateTrayTitle(showTrayTitle: trayState.showTrayTitle, traffic: traffic);
  }

  Future<void> updateTrayTitle({
    required bool showTrayTitle,
    required Traffic traffic,
  }) async {
    if (!system.isMacOS) {
      return;
    }
    if (!showTrayTitle) {
      await trayManager.setTitle('');
    } else {
      await trayManager.setTitle(traffic.trayTitle);
    }
  }

  Future<void> _copyEnv(int port) async {
    final url = 'http://127.0.0.1:$port';

    final cmdline = system.isWindows
        ? 'set \$env:all_proxy=$url'
        : 'export all_proxy=$url';

    await Clipboard.setData(ClipboardData(text: cmdline));
  }
}

final tray = system.isDesktop ? Tray() : null;

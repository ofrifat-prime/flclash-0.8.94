import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class TrayIconView extends ConsumerWidget {
  const TrayIconView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stoppedPath = ref.watch(
      appSettingProvider.select((s) => s.trayIconStoppedPath),
    );
    final proxyPath = ref.watch(
      appSettingProvider.select((s) => s.trayIconProxyPath),
    );
    final tunPath = ref.watch(
      appSettingProvider.select((s) => s.trayIconTunPath),
    );
    final useTemplate = ref.watch(
      appSettingProvider.select((s) => s.trayIconUseTemplate),
    );

    final items = [
      SwitchListTile(
        title: Text(appLocalizations.trayIconUseTemplate),
        subtitle: Text(appLocalizations.trayIconUseTemplateDesc),
        value: useTemplate,
        onChanged: (v) => ref
            .read(appSettingProvider.notifier)
            .update((s) => s.copyWith(trayIconUseTemplate: v)),
      ),
      _TrayIconRow(
        label: appLocalizations.stop,
        iconPath: stoppedPath,
        defaultAsset: 'assets/images/icon/macos/status_1.png',
        onPicked: (path) => ref
            .read(appSettingProvider.notifier)
            .update((s) => s.copyWith(trayIconStoppedPath: path)),
        onReset: () => ref
            .read(appSettingProvider.notifier)
            .update((s) => s.copyWith(trayIconStoppedPath: null)),
      ),
      _TrayIconRow(
        label: appLocalizations.systemProxy,
        iconPath: proxyPath,
        defaultAsset: 'assets/images/icon/macos/status_2.png',
        onPicked: (path) => ref
            .read(appSettingProvider.notifier)
            .update((s) => s.copyWith(trayIconProxyPath: path)),
        onReset: () => ref
            .read(appSettingProvider.notifier)
            .update((s) => s.copyWith(trayIconProxyPath: null)),
      ),
      _TrayIconRow(
        label: appLocalizations.tun,
        iconPath: tunPath,
        defaultAsset: 'assets/images/icon/macos/status_3.png',
        onPicked: (path) => ref
            .read(appSettingProvider.notifier)
            .update((s) => s.copyWith(trayIconTunPath: path)),
        onReset: () => ref
            .read(appSettingProvider.notifier)
            .update((s) => s.copyWith(trayIconTunPath: null)),
      ),
    ];

    return BaseScaffold(
      title: appLocalizations.trayIcon,
      body: ListView.separated(
        itemCount: items.length,
        itemBuilder: (_, index) => items[index],
        separatorBuilder: (_, _) => const Divider(height: 0),
      ),
    );
  }
}

class _TrayIconRow extends StatefulWidget {
  final String label;
  final String? iconPath;
  final String defaultAsset;
  final void Function(String path) onPicked;
  final void Function() onReset;

  const _TrayIconRow({
    required this.label,
    required this.iconPath,
    required this.defaultAsset,
    required this.onPicked,
    required this.onReset,
  });

  @override
  State<_TrayIconRow> createState() => _TrayIconRowState();
}

class _TrayIconRowState extends State<_TrayIconRow> {
  int _imageVersion = 0;

  Widget _buildIconPreview() {
    final path = widget.iconPath;
    if (path != null && File(path).existsSync()) {
      return Image.file(
        File(path),
        key: ValueKey(_imageVersion),
        width: 22,
        height: 22,
      );
    }
    return Image.asset(widget.defaultAsset, width: 22, height: 22);
  }

  Future<void> _pickIcon() async {
    final file = await picker.pickerFile();
    if (file == null) return;
    final srcPath = file.path;
    if (srcPath == null) return;

    final ext = p.extension(srcPath).toLowerCase();
    if (ext != '.png' && ext != '.ico') {
      return;
    }

    final destDir = Directory(
      p.join(await appPath.homeDirPath, 'tray_icons'),
    );
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    final destPath = p.join(destDir.path, '${widget.label}$ext');
    await File(srcPath).copy(destPath);
    PaintingBinding.instance.imageCache.evict(FileImage(File(destPath)));
    setState(() => _imageVersion++);
    widget.onPicked(destPath);
  }

  @override
  Widget build(BuildContext context) {
    final hasCustom = widget.iconPath != null && File(widget.iconPath!).existsSync();
    return ListItem(
      leading: _buildIconPreview(),
      title: Text(widget.label),
      subtitle: hasCustom
          ? Text(
              p.basename(widget.iconPath!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(appLocalizations.defaultText),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: _pickIcon,
            child: Text(appLocalizations.edit),
          ),
          if (hasCustom)
            TextButton(
              onPressed: widget.onReset,
              child: Text(appLocalizations.reset),
            ),
        ],
      ),
      tileTitleAlignment: ListTileTitleAlignment.center,
    );
  }
}


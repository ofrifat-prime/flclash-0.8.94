import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:fl_clash/pages/scan.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

class AddProfileView extends StatelessWidget {
  final BuildContext context;

  const AddProfileView({super.key, required this.context});

  Future<void> _handleAddProfileFormFile() async {
    globalState.container
        .read(profilesActionProvider.notifier)
        .addProfileFormFile();
  }


  Future<void> _toScan() async {
    if (system.isDesktop) {
      final url = await globalState.safeRun(picker.pickerConfigQRCode);
      if (url != null) {
        _toAdd(url);
      }
      return;
    }
    final url = await BaseNavigator.push(context, const ScanPage());
    if (url != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toAdd(url);
      });
    }
  }

  Future<void> _toAdd([String? initialUrl]) async {
    final res = await globalState.showCommonDialog<(String, String?)>(
      child: URLFormDialog(initialUrl: initialUrl ?? ''),
    );
    if (res != null) {
      globalState.container
          .read(profilesActionProvider.notifier)
          .addProfileFormURL(res.$1, userAgent: res.$2);
    }
  }

  @override
  Widget build(context) {
    final appLocalizations = context.appLocalizations;
    return ListView(
      children: [
        ListItem(
          leading: const Icon(Icons.qr_code_sharp),
          title: Text(appLocalizations.qrcode),
          subtitle: Text(appLocalizations.qrcodeDesc),
          onTap: _toScan,
        ),
        ListItem(
          leading: const Icon(Icons.upload_file_sharp),
          title: Text(appLocalizations.file),
          subtitle: Text(appLocalizations.fileDesc),
          onTap: _handleAddProfileFormFile,
        ),
        ListItem(
          leading: const Icon(Icons.cloud_download_sharp),
          title: Text(appLocalizations.url),
          subtitle: Text(appLocalizations.urlDesc),
          onTap: _toAdd,
        ),
      ],
    );
  }
}

class URLFormDialog extends StatefulWidget {
  final String initialUrl;
  const URLFormDialog({super.key, this.initialUrl = ''});

  @override
  State<URLFormDialog> createState() => _URLFormDialogState();
}

class _URLFormDialogState extends State<URLFormDialog> {
  late final _urlController = TextEditingController(text: widget.initialUrl);
  String? _userAgent;

  Future<void> _handleAddProfileFormURL() async {
    final url = _urlController.value.text;
    if (url.isEmpty) return;
    Navigator.of(context).pop<(String, String?)>((url, _userAgent));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.importFromURL,
      actions: [
        TextButton(
          onPressed: _handleAddProfileFormURL,
          child: Text(appLocalizations.submit),
        ),
      ],
      child: SizedBox(
        width: 300,
        child: Wrap(
          runSpacing: 16,
          children: [
            TextField(
              keyboardType: TextInputType.url,
              minLines: 1,
              maxLines: 5,
              onSubmitted: (_) {
                _handleAddProfileFormURL();
              },
              onEditingComplete: _handleAddProfileFormURL,
              controller: _urlController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: appLocalizations.url,
              ),
            ),
            ListItem(
              title: const Text('User-Agent'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _userAgent ?? 'Global',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              onTap: () async {
                final result = await globalState.showCommonDialog<UaResult>(
                  child: UaDialog(
                    title: 'UA',
                    currentUa: _userAgent,
                    defaultLabel: 'Global',
                  ),
                );
                if (result == null) return;
                setState(() {
                  _userAgent = result.value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

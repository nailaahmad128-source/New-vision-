import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/storage/app_data_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppDataController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
        children: [
          _Section(title: 'Preferences', children: [
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Appearance'),
              subtitle: Text(_themeLabel(data.themeModeName)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _themeDialog(context, data),
            ),
            const ListTile(
              leading: Icon(Icons.notifications_none_rounded),
              title: Text('Notifications'),
              subtitle: Text('Document processing notifications are handled by the system'),
            ),
          ]),
          const SizedBox(height: 14),
          _Section(title: 'Scanning', children: [
            ListTile(
              leading: const Icon(Icons.high_quality_rounded),
              title: const Text('Scan quality'),
              subtitle: Text(_qualityLabel(data.scanQuality)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showQualityDialog(context, data),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.document_scanner_rounded),
              title: const Text('Automatic document detection'),
              subtitle: const Text('Detect page edges while scanning'),
              value: data.autoDocumentDetection,
              onChanged: data.setAutoDocumentDetection,
            ),
          ]),
          const SizedBox(height: 14),
          _Section(title: 'Cloud Conversion', children: [
            ListTile(
              leading: Icon(
                (data.cloudConvertApiKey ?? '').isEmpty ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                color: (data.cloudConvertApiKey ?? '').isEmpty ? null : Colors.green,
              ),
              title: const Text('PDF ↔ Word/Excel/PowerPoint'),
              subtitle: Text((data.cloudConvertApiKey ?? '').isEmpty
                  ? 'Not configured — add a CloudConvert API key to enable'
                  : 'Configured with CloudConvert'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _apiKeyDialog(context, data),
            ),
          ]),
          _Section(title: 'About', children: [
            const ListTile(leading: Icon(Icons.picture_as_pdf_rounded), title: Text('PDF Master Tools'), subtitle: Text('Professional document scanner, PDF toolkit and OCR suite')),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (_, snap) => ListTile(
                leading: const Icon(Icons.verified_outlined),
                title: const Text('App version'),
                subtitle: Text(snap.hasData ? '${snap.data!.version} (${snap.data!.buildNumber})' : 'Loading…'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy'),
              onTap: () => showAboutDialog(context: context, applicationName: 'PDF Master Tools', applicationVersion: '${AppConfig.version} (${AppConfig.versionCode})'),
            ),
          ]),
          const SizedBox(height: 14),
          const _Section(title: 'Scanner tips', children: [
            ListTile(leading: Icon(Icons.lightbulb_outline_rounded), title: Text('Better scans'), subtitle: Text('Use bright, even lighting and keep all four document corners visible for best detection.')),
            ListTile(leading: Icon(Icons.auto_awesome_rounded), title: Text('Clean documents'), subtitle: Text('Use the Document filter for a high-contrast paper look before saving your PDF.')),
          ]),
        ],
      ),
    );
  }

  static String _themeLabel(String value) => switch (value) {
    'light' => 'Light',
    'dark' => 'Dark',
    _ => 'System default',
  };

  Future<void> _apiKeyDialog(BuildContext context, AppDataController data) async {
    final controller = TextEditingController(text: data.cloudConvertApiKey ?? '');
    var obscure = true;
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('CloudConvert API key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'API key',
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => launchUrl(Uri.parse('https://cloudconvert.com'), mode: LaunchMode.externalApplication),
                child: const Text(
                  'Get a free API key at cloudconvert.com',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
          actions: [
            if ((data.cloudConvertApiKey ?? '').isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                child: const Text('Remove key'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == null) return;
    await data.setCloudConvertApiKey(saved);
  }

  void _themeDialog(BuildContext context, AppDataController data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Appearance'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _ThemeChoice(label: 'System default', icon: Icons.brightness_auto_rounded, value: 'system', current: data.themeModeName, onTap: () async { await data.setThemeModeName('system'); if (ctx.mounted) Navigator.pop(ctx); }),
          _ThemeChoice(label: 'Light', icon: Icons.light_mode_rounded, value: 'light', current: data.themeModeName, onTap: () async { await data.setThemeModeName('light'); if (ctx.mounted) Navigator.pop(ctx); }),
          _ThemeChoice(label: 'Dark', icon: Icons.dark_mode_rounded, value: 'dark', current: data.themeModeName, onTap: () async { await data.setThemeModeName('dark'); if (ctx.mounted) Navigator.pop(ctx); }),
        ]),
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  final String label, value, current;
  final IconData icon;
  final VoidCallback onTap;
  const _ThemeChoice({required this.label, required this.value, required this.current, required this.icon, required this.onTap});
  @override Widget build(BuildContext context) => ListTile(leading: Icon(icon), title: Text(label), trailing: value == current ? const Icon(Icons.check_circle_rounded) : null, onTap: onTap);
}


String _qualityLabel(String value) => switch (value) {
  'standard' => 'Standard',
  'ultra' => 'Ultra',
  _ => 'High',
};

Future<void> _showQualityDialog(BuildContext context, AppDataController data) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Scan quality'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final item in const [('standard','Standard'),('high','High'),('ultra','Ultra')])
          RadioListTile<String>(value: item.$1, groupValue: data.scanQuality, title: Text(item.$2), onChanged: (v) async { if (v != null) { await data.setScanQuality(v); if (ctx.mounted) Navigator.pop(ctx); } }),
      ]),
    ),
  );
}

class _Section extends StatelessWidget {
  final String title; final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: Theme.of(context).textTheme.titleMedium)), Card(child: Column(children: children))]);
}

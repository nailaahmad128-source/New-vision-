import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/pdf_tools_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/source_picker.dart';
import '../widgets/tool_history_list.dart';
import '../widgets/tool_result_screen.dart';

enum _SecMode { protect, unlock }

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});
  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  String? _path;
  _SecMode _mode = _SecMode.protect;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  bool _allowPrinting = true;
  bool _allowCopying = true;
  bool _obscure = true;
  bool _working = false;

  Future<void> _pickFile() async {
    final picked = await pickSourceFiles(context, allowMultiple: false, extensions: const ['pdf']);
    if (picked.isEmpty) return;
    setState(() => _path = picked.first);
  }

  Future<void> _apply() async {
    if (_path == null) return;
    final tools = context.read<PdfToolsService>();
    final data = context.read<AppDataController>();
    final baseName = p.basenameWithoutExtension(_path!);

    if (_mode == _SecMode.protect) {
      if (_passwordController.text.isEmpty) {
        _showError('Enter a password.');
        return;
      }
      if (_passwordController.text != _confirmController.text) {
        _showError('Passwords do not match.');
        return;
      }
    } else {
      if (_currentPasswordController.text.isEmpty) {
        _showError('Enter the current password.');
        return;
      }
    }

    setState(() => _working = true);
    try {
      final outName = _mode == _SecMode.protect
          ? '${baseName}_protected.pdf'
          : '${baseName}_unlocked.pdf';
      final file = _mode == _SecMode.protect
          ? await tools.protect(
              _path!,
              userPassword: _passwordController.text,
              ownerPassword: _passwordController.text,
              allowPrinting: _allowPrinting,
              allowCopying: _allowCopying,
              outputName: outName,
            )
          : await tools.removePassword(
              _path!,
              _currentPasswordController.text,
              outputName: outName,
            );
      final pages = await tools.pageCount(file.path);
      final doc = await data.registerToolResult(
        tmpFile: file,
        fileName: outName,
        toolId: ToolId.security.name,
        toolTitle: _mode == _SecMode.protect ? 'Protected $baseName' : 'Unlocked $baseName',
        type: 'pdf',
        pageCount: pages,
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ToolResultScreen(
          results: [doc],
          successTitle: _mode == _SecMode.protect ? 'PDF protected!' : 'PDF unlocked!',
        ),
      ));
      setState(() {
        _path = null;
        _passwordController.clear();
        _confirmController.clear();
        _currentPasswordController.clear();
      });
    } catch (e) {
      _showError('Wrong password or unsupported file.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Security')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            SegmentedButton<_SecMode>(
              segments: const [
                ButtonSegment(value: _SecMode.protect, label: Text('Add password')),
                ButtonSegment(value: _SecMode.unlock, label: Text('Remove password')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 20),
            if (_path == null)
              Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: EmptyState(
                      icon: Icons.lock_rounded,
                      title: 'Choose a PDF',
                      message: 'Protect a file with a password, or unlock one you own.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Choose PDF'),
                    ),
                  ),
                ],
              )
            else ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf_rounded),
                  title: Text(p.basename(_path!), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _path = null),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_mode == _SecMode.protect) ...[
                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmController,
                  obscureText: _obscure,
                  decoration: const InputDecoration(labelText: 'Confirm password'),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow printing'),
                  value: _allowPrinting,
                  onChanged: (v) => setState(() => _allowPrinting = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow copying text'),
                  value: _allowCopying,
                  onChanged: (v) => setState(() => _allowCopying = v),
                ),
              ] else
                TextField(
                  controller: _currentPasswordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _working ? null : _apply,
                  child: _working
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_mode == _SecMode.protect ? 'Protect PDF' : 'Unlock PDF'),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const ToolHistorySection(toolId: ToolId.security),
          ],
        ),
      ),
    );
  }
}

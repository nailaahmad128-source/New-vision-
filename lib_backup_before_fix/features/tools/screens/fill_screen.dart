import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/pdf_tools_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../fill_sign/screens/fill_sign_screen.dart';
import '../widgets/source_picker.dart';
import '../widgets/tool_history_list.dart';
import '../widgets/tool_result_screen.dart';

class FillScreen extends StatefulWidget {
  const FillScreen({super.key});
  @override
  State<FillScreen> createState() => _FillScreenState();
}

class _FillScreenState extends State<FillScreen> {
  String? _path;
  List<PdfFormFieldInfo> _fields = [];
  final Map<String, String> _textValues = {};
  final Map<String, bool> _checkValues = {};
  bool _loading = false;
  bool _working = false;

  Future<void> _pickFile() async {
    final picked = await pickSourceFiles(context, allowMultiple: false, extensions: const ['pdf']);
    if (picked.isEmpty) return;
    setState(() { _path = picked.first; _loading = true; });
    try {
      final tools = context.read<PdfToolsService>();
      final fields = await tools.readFormFields(picked.first);
      if (!mounted) return;
      setState(() { _fields = fields; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _path = null; _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't open this PDF. It may be corrupted or password protected."),
      ));
    }
  }

  Future<void> _apply() async {
    if (_path == null) return;
    setState(() => _working = true);
    try {
      final tools = context.read<PdfToolsService>();
      final data = context.read<AppDataController>();
      final baseName = p.basenameWithoutExtension(_path!);
      final outName = '${baseName}_filled.pdf';
      final file = await tools.fillFormFields(
        _path!,
        textValues: _textValues,
        checkValues: _checkValues,
        outputName: outName,
      );
      final pages = await tools.pageCount(file.path);
      final thumb = await tools.generateThumbnail(file.path, type: 'pdf');
      final doc = await data.registerToolResult(
        tmpFile: file,
        fileName: outName,
        toolId: ToolId.fill.name,
        toolTitle: 'Filled $baseName',
        type: 'pdf',
        pageCount: pages,
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ToolResultScreen(results: [doc], successTitle: 'Form filled!'),
      ));
      setState(() { _path = null; _fields = []; _textValues.clear(); _checkValues.clear(); });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fill failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fill PDF')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_path == null)
              Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: EmptyState(
                      icon: Icons.edit_note_rounded,
                      title: 'Choose a fillable PDF',
                      message: 'If the PDF has real form fields, we\'ll detect them automatically. Otherwise use Fill & Sign to place text and a signature anywhere.',
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
            else if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_fields.isEmpty)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: EmptyState(
                      icon: Icons.info_outline_rounded,
                      title: 'No fillable fields found',
                      message: 'This PDF has no AcroForm fields. Use Fill & Sign to add text and a signature anywhere on the page instead.',
                      action: FilledButton.icon(
                        onPressed: () {
                          Navigator.pushReplacement(context, MaterialPageRoute(
                            builder: (_) => FillSignScreen(initialPath: _path),
                          ));
                        },
                        icon: const Icon(Icons.draw_rounded),
                        label: const Text('Open Fill & Sign'),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              Text('${_fields.length} fields found', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              ..._fields.map((f) {
                if (f.isCheckbox) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(f.name),
                    value: _checkValues[f.name] ?? false,
                    onChanged: (v) => setState(() => _checkValues[f.name] = v ?? false),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    decoration: InputDecoration(labelText: f.name),
                    onChanged: (v) => _textValues[f.name] = v,
                  ),
                );
              }),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _working ? null : _apply,
                  child: _working
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Filled PDF'),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const ToolHistorySection(toolId: ToolId.fill),
          ],
        ),
      ),
    );
  }
}

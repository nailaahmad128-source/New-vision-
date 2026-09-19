import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/pdf_tools_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../fill_sign/screens/fill_sign_screen.dart';
import '../widgets/source_picker.dart';
import '../widgets/professional_tool_page.dart';
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
    return ProfessionalToolPage(
      title: 'Fill PDF',
      description: 'Fill real PDF form fields directly and save the completed document.',
      icon: Icons.edit_note_rounded,
      history: const ToolHistorySection(toolId: ToolId.fill),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_path == null) ...[
            const ProfessionalSectionTitle(
              title: 'Create or Import',
              subtitle: 'Choose a fillable PDF from your device.',
            ),
            const SizedBox(height: 16),
            ProfessionalActionGrid(
              children: [
                ProfessionalAction(
                  title: 'Device',
                  subtitle: 'Choose PDF',
                  icon: Icons.folder_rounded,
                  onTap: _pickFile,
                ),
              ],
            ),
          ] else if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_fields.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfessionalFileCard(
                  name: p.basename(_path!),
                  onRemove: () => setState(() {
                    _path = null;
                    _fields = [];
                  }),
                ),
                const SizedBox(height: 18),
                const ProfessionalSectionTitle(
                  title: 'No fillable fields found',
                  subtitle:
                      'This PDF does not contain standard form fields.',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FillSignScreen(
                            initialPath: _path,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.draw_rounded),
                    label: const Text('Open Fill & Sign'),
                  ),
                ),
              ],
            )
          else ...[
            ProfessionalSectionTitle(
              title: '${_fields.length} fields found',
              subtitle: 'Complete the fields below.',
            ),
            const SizedBox(height: 14),
            ..._fields.map((f) {
              if (f.isCheckbox) {
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(f.name),
                  value: _checkValues[f.name] ?? false,
                  onChanged: (v) =>
                      setState(() => _checkValues[f.name] = v ?? false),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: f.name,
                  ),
                  onChanged: (v) => _textValues[f.name] = v,
                ),
              );
            }),
            const SizedBox(height: 8),
            ProfessionalPrimaryButton(
              label: 'Save Filled PDF',
              icon: Icons.check_rounded,
              loading: _working,
              onPressed: _working ? null : _apply,
            ),
          ],
        ],
      ),
    );
  }
}

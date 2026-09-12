import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../translation/services/speech_service.dart';
import '../../../core/storage/app_data_controller.dart';

class TextToSpeechScreen extends StatefulWidget {
  const TextToSpeechScreen({super.key});
  @override State<TextToSpeechScreen> createState() => _TextToSpeechScreenState();
}

class _TextToSpeechScreenState extends State<TextToSpeechScreen> {
  final _text = TextEditingController();
  final _speech = SpeechService();
  String _language = 'en-US';
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    final saved = context.read<AppDataController>().defaultOcrLanguage;
    if (saved == 'urd') _language = 'ur-PK';
    if (saved == 'ara') _language = 'ar-SA';
  }

  Future<void> _speak() async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _speaking = true);
    try { await _speech.speak(_text.text, language: _language); }
    finally { if (mounted) setState(() => _speaking = false); }
  }

  @override
  void dispose() { _speech.dispose(); _text.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Text to Speech')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 32), children: [
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Read text aloud', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6), const Text('Paste or type text, choose a language, and listen.'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(value: _language, decoration: const InputDecoration(labelText: 'Language'), items: const [
            DropdownMenuItem(value: 'en-US', child: Text('English')),
            DropdownMenuItem(value: 'ur-PK', child: Text('Urdu')),
            DropdownMenuItem(value: 'ar-SA', child: Text('Arabic')),
            DropdownMenuItem(value: 'hi-IN', child: Text('Hindi')),
            DropdownMenuItem(value: 'fa-IR', child: Text('Persian')),
          ], onChanged: (v) { if (v != null) setState(() => _language = v); }),
        ]))),
        const SizedBox(height: 14),
        TextField(controller: _text, minLines: 10, maxLines: 18, decoration: const InputDecoration(hintText: 'Type or paste text here…', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: _speaking ? null : _speak, icon: Icon(_speaking ? Icons.volume_up_rounded : Icons.play_arrow_rounded), label: Text(_speaking ? 'Speaking…' : 'Speak'))),
          const SizedBox(width: 10),
          OutlinedButton.icon(onPressed: _speaking ? () => _speech.stop() : null, icon: const Icon(Icons.stop_rounded), label: const Text('Stop')),
        ]),
      ]),
    );
  }
}

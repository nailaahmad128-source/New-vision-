import 'package:flutter/material.dart';

import '../../translation/services/speech_service.dart';

/// Standalone Text to Speech tool: paste or type any text and have it read
/// aloud in English, Urdu, or Arabic. Reuses the same on-device TTS engine
/// already wired into the document detail and text-extraction screens, so
/// this doesn't duplicate any playback logic — just gives it its own entry
/// point in the Tools catalog for text that didn't come from a scan.
class TextToSpeechScreen extends StatefulWidget {
  final String initialText;
  const TextToSpeechScreen({super.key, this.initialText = ''});

  @override
  State<TextToSpeechScreen> createState() => _TextToSpeechScreenState();
}

class _TextToSpeechScreenState extends State<TextToSpeechScreen> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);
  final _speech = SpeechService();
  String _language = 'en-US';
  bool _speaking = false;

  static const _languages = <String, String>{
    'en-US': 'English',
    'ur-PK': 'Urdu',
    'ar-SA': 'Arabic',
  };

  @override
  void initState() {
    super.initState();
    // Keeps the Speak button's enabled state in sync as the user types,
    // since TextEditingController changes don't trigger a rebuild on their own.
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  Future<void> _speak() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _speaking = true);
    try {
      await _speech.speak(text, language: _language);
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _stop() async {
    await _speech.stop();
    if (mounted) setState(() => _speaking = false);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _speech.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Text to Speech')),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _language,
              decoration: const InputDecoration(labelText: 'Voice language', border: OutlineInputBorder()),
              items: _languages.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => _language = v ?? _language),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: TextField(
                controller: _controller,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Type or paste text to have it read aloud…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                  filled: true,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _speaking || _controller.text.trim().isEmpty ? null : _speak,
                    icon: const Icon(Icons.volume_up_rounded),
                    label: Text(_speaking ? 'Speaking…' : 'Speak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _speaking ? _stop : null,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Stop'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

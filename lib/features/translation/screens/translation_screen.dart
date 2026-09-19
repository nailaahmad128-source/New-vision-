import 'package:flutter/material.dart';
import '../services/translation_types.dart';
import '../services/speech_service.dart';
import '../services/translation_service.dart';

class TranslationScreen extends StatefulWidget {
  final String initialText;
  const TranslationScreen({super.key, required this.initialText});
  @override State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final _service = TranslationService();
  final _speech = SpeechService();
  late final TextEditingController _input;
  final _output = TextEditingController();
  TranslateLanguage _source = TranslateLanguage.english;
  TranslateLanguage _target = TranslateLanguage.urdu;
  String _detected = 'Not detected yet';
  bool _busy = false;
  final _languages = <TranslateLanguage>[
    TranslateLanguage.english, TranslateLanguage.urdu, TranslateLanguage.arabic,
    TranslateLanguage.persian, TranslateLanguage.hindi, TranslateLanguage.bengali,
    TranslateLanguage.french, TranslateLanguage.german, TranslateLanguage.spanish,
    TranslateLanguage.turkish, TranslateLanguage.russian, TranslateLanguage.chinese,
    TranslateLanguage.japanese,
  ];

  @override void initState() { super.initState(); _input = TextEditingController(text: widget.initialText); _detect(); }
  String _name(TranslateLanguage l) => l.bcpCode.toUpperCase();

  Future<void> _detect() async {
    final code = await _service.detectLanguageCode(_input.text);
    if (!mounted) return;
    final detected = code == null ? null : _service.languageFromCode(code);
    setState(() => _detected = detected == null ? 'Unknown' : _name(detected));
    if (detected != null) setState(() => _source = detected);
  }

  Future<void> _translate() async {
    final text = _input.text.trim(); if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      _output.text = await _service.translate(text: text, source: _source, target: _target);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Translation ready.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        e is UnsupportedError
            ? 'On-device translation is currently available on Android/iOS.'
            : 'Translation failed. Download the required language models and try again.',
      )));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _speak(String text, TranslateLanguage language) async {
    final code = switch (language) {
      TranslateLanguage.urdu => 'ur-PK', TranslateLanguage.arabic => 'ar-SA',
      TranslateLanguage.persian => 'fa-IR', TranslateLanguage.hindi => 'hi-IN',
      TranslateLanguage.bengali => 'bn-BD', TranslateLanguage.french => 'fr-FR',
      TranslateLanguage.german => 'de-DE', TranslateLanguage.spanish => 'es-ES',
      TranslateLanguage.turkish => 'tr-TR', TranslateLanguage.russian => 'ru-RU',
      TranslateLanguage.chinese => 'zh-CN', TranslateLanguage.japanese => 'ja-JP', _ => 'en-US',
    };
    await _speech.speak(text, language: code);
  }

  @override void dispose() { _input.dispose(); _output.dispose(); _service.dispose(); _speech.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Translate & Listen')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Text('Detected language: $_detected'), const SizedBox(height: 12),
        Row(children: [
          Expanded(child: DropdownButtonFormField<TranslateLanguage>(value: _source, decoration: const InputDecoration(labelText: 'From'), items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(_name(l)))).toList(), onChanged: (v) { if (v != null) setState(() => _source = v); })),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.swap_horiz_rounded)),
          Expanded(child: DropdownButtonFormField<TranslateLanguage>(value: _target, decoration: const InputDecoration(labelText: 'To'), items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(_name(l)))).toList(), onChanged: (v) { if (v != null) setState(() => _target = v); })),
        ]),
        const SizedBox(height: 16),
        TextField(controller: _input, minLines: 7, maxLines: 14, decoration: const InputDecoration(labelText: 'Source text', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        Row(children: [
          OutlinedButton.icon(onPressed: _detect, icon: const Icon(Icons.language_rounded), label: const Text('Detect')),
          const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: _busy ? null : _translate, icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.translate_rounded), label: Text(_busy ? 'Preparing…' : 'Translate'))),
        ]),
        const SizedBox(height: 18),
        TextField(controller: _output, minLines: 7, maxLines: 14, readOnly: true, decoration: InputDecoration(labelText: 'Translation', border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: _output.text.trim().isEmpty ? null : () => _speak(_output.text, _target), icon: const Icon(Icons.volume_up_rounded)))),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(onPressed: _output.text.trim().isEmpty ? null : () => _speak(_output.text, _target), icon: const Icon(Icons.record_voice_over_rounded), label: const Text('Listen to translation')),
      ]),
    );
  }
}

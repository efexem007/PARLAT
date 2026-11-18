import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parlat_focus/core/state/app_controller.dart';
import 'package:parlat_focus/core/theme/app_theme.dart';
import 'package:parlat_focus/core/widgets/liquid_glass.dart';
import 'package:parlat_focus/services/voice_service.dart';

class VoiceDictationSheet extends StatefulWidget {
  const VoiceDictationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const VoiceDictationSheet(),
    );
  }

  @override
  State<VoiceDictationSheet> createState() => _VoiceDictationSheetState();
}

class _VoiceDictationSheetState extends State<VoiceDictationSheet> {
  static const String _defaultSample =
      'Bugün kendimi biraz yorgun hissediyorum. Yarınki programımı hafiflet ama İngilizce çalışmamı iptal etme.';

  late final TextEditingController _textController;
  final VoiceService _voiceService = VoiceService();
  bool _isListening = false;
  double _soundLevel = 0.4;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _defaultSample);
  }

  @override
  void dispose() {
    _voiceService.stop();
    _textController.dispose();
    super.dispose();
  }

  List<IntentTarget> _collectTargets(AppController c) {
    final today = c.selectedDay;
    final tomorrow = today.add(const Duration(days: 1));
    final result = <IntentTarget>[];

    for (final b in c.blocksFor(today)) {
      result.add(
        IntentTarget(
          id: b.id,
          title: b.title,
          minutes: b.durationMinutes,
          isProtected: b.isProtected,
          day: DayRef.today,
        ),
      );
    }
    for (final b in c.blocksFor(tomorrow)) {
      result.add(
        IntentTarget(
          id: b.id,
          title: b.title,
          minutes: b.durationMinutes,
          isProtected: b.isProtected,
          day: DayRef.tomorrow,
        ),
      );
    }
    return result;
  }

  Future<void> _toggleMic() async {
    HapticFeedback.lightImpact();
    if (_isListening) {
      await _voiceService.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
          _textController.text = TurkishText.punctuate(_textController.text);
        });
      }
      return;
    }

    final ok = await _voiceService.init(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    );

    if (!ok) {
      if (!mounted) return;
      setState(() {
        _textController.text = TurkishText.punctuate(_textController.text);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cihaz mikrofonu simülasyon modunda: metni doğrudan düzenleyebilir veya hazır komut seçebilirsiniz.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isListening = true);
    await _voiceService.start(
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _textController.text =
              isFinal ? TurkishText.punctuate(words) : words;
        });
      },
      onSoundLevel: (level) {
        if (!mounted) return;
        setState(() => _soundLevel = (level.abs() / 10.0).clamp(0.15, 1.0));
      },
    );
  }

  void _applyCommand(AppController c, VoiceIntent intent) {
    HapticFeedback.mediumImpact();
    c.applyVoiceCommand(_textController.text);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sesli komut işlendi: esnek bloklar uyarlandı, korumalı hedefler korundu.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final p = context.palette;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    final targets = _collectTargets(c);
    final intent = TurkishIntentParser.parse(
      _textController.text,
      targets: targets,
    );
    final changes = intent.changes;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, viewInsets + 26),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title + TR Noktalama Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Türkçe Sesli Dikte',
                    style: AppTypography.display(
                      size: 20,
                      weight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlassPill(
                      label: 'TR Noktalama',
                      color: p.accent2,
                      textColor: p.accent2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      fontSize: 10.5,
                      onTap: () {
                        setState(() {
                          _textController.text =
                              TurkishText.punctuate(_textController.text);
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    GlassPill(
                      icon: _isListening
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                      label: _isListening ? 'Durdur' : 'Dinle',
                      selected: _isListening,
                      color: p.accent2,
                      onTap: _toggleMic,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Waveform + Editable Transcript Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.elevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _VoiceWaveform(
                    color: p.accent,
                    active: _isListening,
                    level: _soundLevel,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _textController,
                    maxLines: 3,
                    minLines: 2,
                    style: AppTypography.body(
                      size: 13.5,
                      color: p.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText:
                          'Konuşun veya Türkçe sesli komutunuzu düzenleyin...',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // AI Intent Extraction Preview Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.accent, width: 1.3),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI NİYET ÇIKARIMI',
                    style: AppTypography.micro(color: p.accent),
                  ),
                  const SizedBox(height: 6),
                  if (changes.isEmpty)
                    Text(
                      '• Günlük / Tefekkür notu olarak kaydedilecek',
                      style: AppTypography.body(
                        size: 12.5,
                        color: p.textSecondary,
                      ),
                    )
                  else
                    for (final ch in changes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '• ${ch.target}: ${ch.description}',
                          style: AppTypography.body(
                            size: 12.5,
                            weight: FontWeight.w500,
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Confirm & Apply CTA
            FilledButton(
              onPressed: () => _applyCommand(c, intent),
              child: const Text('Onayla & Takvime İşle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceWaveform extends StatelessWidget {
  final Color color;
  final bool active;
  final double level;

  const _VoiceWaveform({
    required this.color,
    required this.active,
    required this.level,
  });

  static const List<double> _baseHeights = [14, 30, 40, 22, 38, 18];

  @override
  Widget build(BuildContext context) {
    final factor = active ? (0.65 + 0.55 * level) : 1.0;
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < _baseHeights.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 5,
              height: (_baseHeights[i] * factor).clamp(8.0, 42.0),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/app_models.dart';

// ---------------------------------------------------------------------------
// Turkish text helpers
// ---------------------------------------------------------------------------

class TurkishText {
  /// Turkish-aware lowercase (İ→i, I→ı).
  static String lower(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

  /// Lowercase + ASCII folding for robust keyword matching.
  static String fold(String s) {
    const map = {'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', 'â': 'a', 'î': 'i', 'û': 'u'};
    final l = lower(s);
    final b = StringBuffer();
    for (final ch in l.split('')) {
      b.write(map[ch] ?? ch);
    }
    return b.toString();
  }

  /// Turkish-aware uppercase of the first letter (i→İ).
  static String capitalize(String s) {
    if (s.isEmpty) return s;
    final f = s[0];
    final up = f == 'i' ? 'İ' : (f == 'ı' ? 'I' : f.toUpperCase());
    return up + s.substring(1);
  }

  /// Post-processing for raw STT output: spacing, commas before Turkish
  /// conjunctions, sentence capitalization and terminal punctuation.
  static String punctuate(String raw) {
    var t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return t;
    // Comma before contrastive / causal conjunctions when missing.
    t = t.replaceAllMapped(
      RegExp(r'(?<![,.;!?])\s(ama|fakat|ancak|çünkü|yoksa|lakin)\s', caseSensitive: false),
      (m) => ', ${m[1]} ',
    );
    // Spoken punctuation commands.
    t = t
        .replaceAll(RegExp(r'\s*\bvirgül\b\s*', caseSensitive: false), ', ')
        .replaceAll(RegExp(r'\s*\bnokta\b\s*', caseSensitive: false), '. ')
        .replaceAll(RegExp(r'\s*\bsoru işareti\b\s*', caseSensitive: false), '? ')
        .replaceAll(RegExp(r'\s*\bünlem\b\s*', caseSensitive: false), '! ');
    // No space before punctuation, single space after.
    t = t.replaceAll(RegExp(r'\s+([,.;!?])'), r'$1');
    t = t.replaceAllMapped(RegExp(r'([,.;!?])(?=[^\s,.;!?])'), (m) => '${m[1]} ');
    t = t.trim();
    // Capitalize each sentence.
    final parts = t.split(RegExp(r'(?<=[.!?])\s+'));
    t = parts.map(capitalize).join(' ');
    if (!RegExp(r'[.!?]$').hasMatch(t)) t = '$t.';
    return t;
  }
}

// ---------------------------------------------------------------------------
// Intent model
// ---------------------------------------------------------------------------

enum IntentActionType { reduce, increase, protect, cancel, create, remind, move, logEmotion }

enum DayRef { today, tomorrow, unspecified }

extension DayRefX on DayRef {
  String get label => const {DayRef.today: 'Bugün', DayRef.tomorrow: 'Yarın', DayRef.unspecified: 'Bugün'}[this]!;
}

/// Snapshot of a schedulable item handed to the parser so it can compute
/// concrete before/after durations.
class IntentTarget {
  final String id;
  final String title;
  final int minutes;
  final bool isProtected;
  final DayRef day;
  const IntentTarget({
    required this.id,
    required this.title,
    required this.minutes,
    this.isProtected = false,
    this.day = DayRef.today,
  });
}

class IntentAction {
  final IntentActionType type;

  /// Canonical subject key, e.g. 'spor', 'ingilizce'; `*` = whole program.
  final String subject;
  final String displayName;
  final DayRef day;
  final int? fromMinutes;
  final int? toMinutes;
  final String? targetId;
  final String? title;

  const IntentAction({
    required this.type,
    required this.subject,
    required this.displayName,
    this.day = DayRef.unspecified,
    this.fromMinutes,
    this.toMinutes,
    this.targetId,
    this.title,
  });

  IntentChange toChange() {
    switch (type) {
      case IntentActionType.reduce:
      case IntentActionType.increase:
        final d = (fromMinutes != null && toMinutes != null)
            ? '$fromMinutes dk → $toMinutes dk'
            : (type == IntentActionType.reduce ? 'Hafifletilecek' : 'Artırılacak');
        return IntentChange(target: displayName, description: d, kind: type.name);
      case IntentActionType.protect:
        return IntentChange(
          target: displayName,
          description: fromMinutes != null ? 'Korundu ($fromMinutes dk)' : 'Korundu',
          kind: 'protect',
        );
      case IntentActionType.cancel:
        return IntentChange(target: displayName, description: 'İptal edilecek', kind: 'cancel');
      case IntentActionType.create:
        return IntentChange(target: 'Yeni Görev', description: title ?? displayName, kind: 'create');
      case IntentActionType.remind:
        return IntentChange(target: 'Hatırlatıcı', description: title ?? displayName, kind: 'create');
      case IntentActionType.move:
        return IntentChange(target: displayName, description: '${day.label} gününe taşınacak', kind: 'move');
      case IntentActionType.logEmotion:
        return IntentChange(target: 'Duygu Kaydı', description: displayName, kind: 'emotion');
    }
  }
}

class VoiceIntent {
  final String transcript;
  final String? emotion;
  final DayRef day;
  final List<IntentAction> actions;

  const VoiceIntent({required this.transcript, this.emotion, this.day = DayRef.unspecified, this.actions = const []});

  bool get isEmpty => actions.isEmpty;
  List<IntentChange> get changes => actions.map((a) => a.toChange()).toList();
  Set<String> get protectedSubjects =>
      actions.where((a) => a.type == IntentActionType.protect).map((a) => a.subject).toSet();
  List<IntentAction> ofType(IntentActionType t) => actions.where((a) => a.type == t).toList();
}

// ---------------------------------------------------------------------------
// Turkish natural-language intent parser (deterministic, offline)
// ---------------------------------------------------------------------------

class TurkishIntentParser {
  /// subject key -> (display name, folded keywords)
  static const Map<String, (String, List<String>)> subjects = {
    'spor': ('Spor', ['spor', 'antrenman', 'egzersiz', 'kosu', 'yuruyus', 'fitness', 'gym', 'idman', 'salon']),
    'ingilizce': ('İngilizce Çalışma', ['ingilizce', 'english', 'yabanci dil', 'dil calis', 'konusma pratig']),
    'okuma': ('Kitap Okuma', ['kitap', 'okuma']),
    'meditasyon': ('Meditasyon', ['meditasyon', 'nefes egzersiz']),
    'proje': ('Proje Çalışması', ['proje']),
    'ders': ('Ders Çalışma', ['ders', 'sinav']),
    'toplanti': ('Toplantı', ['toplanti']),
    'gunluk': ('Günlük & Tefekkür', ['gunluk', 'tefekkur', 'johari']),
  };

  static const Map<String, List<String>> _emotions = {
    'Yorgun': ['yorgun', 'bitkin', 'halsiz', 'uykusuz', 'enerjim yok', 'tukenmis'],
    'İsteksiz': ['isteksiz', 'motivasyonum yok', 'canim istemiyor', 'uset'],
    'Stresli': ['stresli', 'gergin', 'kaygili', 'endiseli', 'bunalmis'],
    'Hasta': ['hastayim', 'hasta hissed', 'ates', 'basim agri'],
    'Motive': ['motive', 'enerjik', 'harika hissed', 'cok iyiyim', 'zinde'],
    'Üzgün': ['uzgun', 'moralim bozuk', 'mutsuz'],
  };

  static const _protectWords = [
    'iptal etme',
    'iptal etmeyin',
    'iptal edilmesin',
    'koru',
    'dokunma',
    'kalsin',
    'ellemeyin',
    'elleme',
    'atlama',
    'kaldirma',
    'silme ',
    'azaltma',
    'hafifletme',
    'aynen',
    'oldugu gibi',
    'ertelemeyin',
    'erteleme',
  ];
  static const _cancelWords = ['iptal et', 'kaldir', 'sil', 'atla', 'yapmayacagim', 'vazgec'];
  static const _reduceWords = ['hafiflet', 'azalt', 'kisalt', 'dusur', 'indir', 'hafif tut', 'yumusat', 'gevset'];
  static const _increaseWords = ['artir', 'uzat', 'yogunlastir', 'agirlastir'];
  static const _createWords = ['ekle', 'olustur', 'planla', 'yaz '];
  static const _remindWords = ['hatirlat'];
  static const _moveWords = ['ertele', 'yarina al', 'yarina tasi', 'sonraya al'];

  /// Subject key for an arbitrary title (e.g. block title), or null.
  static String? subjectOf(String title) {
    final f = TurkishText.fold(title);
    for (final e in subjects.entries) {
      if (e.value.$2.any(f.contains)) return e.key;
    }
    return null;
  }

  static int _roundTo5(num v) => (v / 5).round() * 5;

  /// Lightened duration for a flexible block.
  static int lightenedMinutes(String? subject, int minutes) {
    if (subject == 'spor') return minutes <= 20 ? minutes : 20; // 45 → 20 (spec)
    final v = _roundTo5(minutes * 0.6);
    return v < 15 ? (minutes < 15 ? minutes : 15) : v;
  }

  /// Word-start aware containment on folded (ASCII) text.
  static bool _containsWord(String f, String w) =>
      RegExp('(^|[^a-z0-9])${RegExp.escape(w.trimRight())}').hasMatch(f);

  static bool _hasAny(String f, List<String> words) => words.any((w) => _containsWord(f, w));

  static bool _hasCancel(String f) {
    for (final w in _cancelWords) {
      for (final m in RegExp('(^|[^a-z0-9])${RegExp.escape(w)}').allMatches(f)) {
        final after = f.substring(m.end);
        // 'iptal etme' / 'silme' / 'kaldirma' / 'atlama' are negations.
        final negated = after.startsWith('me') || after.startsWith('ma') || after.startsWith('ilmesin');
        if (!negated) return true;
      }
    }
    return false;
  }

  static List<String> _subjectsIn(String f) => [
        for (final e in subjects.entries)
          if (e.value.$2.any((w) => _containsWord(f, w))) e.key
      ];

  static VoiceIntent parse(String transcript, {List<IntentTarget> targets = const []}) {
    final text = transcript.trim();
    if (text.isEmpty) return VoiceIntent(transcript: text);
    final folded = TurkishText.fold(text);

    // Emotion (whole utterance).
    String? emotion;
    for (final e in _emotions.entries) {
      if (e.value.any(folded.contains)) {
        emotion = e.key;
        break;
      }
    }

    // Split into clauses on sentence ends and contrastive connectors.
    final clauses = folded
        .split(RegExp(r'[.!?;]+|,|\bama\b|\bfakat\b|\bancak\b|\blakin\b|\bve\b|\bsonra\b'))
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    DayRef currentDay = DayRef.unspecified;
    DayRef commandDay = DayRef.unspecified;
    final protect = <String>{};
    final cancel = <String>{};
    final reduce = <String>{};
    final increase = <String>{};
    final move = <String>{};
    bool reduceProgram = false;
    final explicitMinutes = <String, int>{};
    final creates = <String>[];
    final reminders = <String>[];

    for (final c in clauses) {
      if (c.contains('yarin')) currentDay = DayRef.tomorrow;
      if (c.contains('bugun')) currentDay = DayRef.today;
      final subs = _subjectsIn(c);
      final isProtect = _hasAny(c, _protectWords);
      final isCancel = !isProtect && _hasCancel(c);
      final isReduce = !isProtect && _hasAny(c, _reduceWords);
      final isIncrease = !isProtect && _hasAny(c, _increaseWords);
      final isMove = !isProtect && _hasAny(c, _moveWords);
      final isRemind = _hasAny(c, _remindWords);
      final isCreate = !isRemind && _hasAny(c, _createWords);
      final isCommand = isProtect || isCancel || isReduce || isIncrease || isMove || isRemind || isCreate;
      if (isCommand && currentDay != DayRef.unspecified) commandDay = currentDay;

      final mm = RegExp(r'(\d{1,3})\s*(dk|dakika)').firstMatch(c);

      if (isProtect) protect.addAll(subs);
      if (isCancel) cancel.addAll(subs);
      if (isReduce) {
        if (subs.isEmpty) reduceProgram = true;
        reduce.addAll(subs);
        if (mm != null) {
          for (final s in subs) {
            explicitMinutes[s] = int.parse(mm.group(1)!);
          }
        }
      }
      if (isIncrease) increase.addAll(subs);
      if (isMove) move.addAll(subs);
      if (isRemind) reminders.add(_extractTitle(text, 'hatırlat'));
      if (isCreate && subs.isEmpty) creates.add(_extractTitle(text, 'ekle'));
    }
    if (commandDay == DayRef.unspecified) commandDay = currentDay;

    // Protection overrides everything else for the same subject.
    reduce.removeAll(protect);
    cancel.removeAll(protect);
    move.removeAll(protect);

    final actions = <IntentAction>[];
    if (emotion != null) {
      actions.add(IntentAction(type: IntentActionType.logEmotion, subject: 'emotion', displayName: emotion));
    }

    final dayTargets = targets.where((t) => commandDay == DayRef.unspecified || t.day == commandDay ||
        (commandDay == DayRef.today && t.day == DayRef.unspecified)).toList();

    IntentTarget? findTarget(String subject) {
      for (final t in dayTargets) {
        if (subjectOf(t.title) == subject) return t;
      }
      return null;
    }

    String nameOf(String s) => subjects[s]?.$1 ?? s;

    for (final s in protect) {
      final t = findTarget(s);
      actions.add(IntentAction(
        type: IntentActionType.protect,
        subject: s,
        displayName: nameOf(s),
        day: commandDay,
        fromMinutes: t?.minutes,
        toMinutes: t?.minutes,
        targetId: t?.id,
      ));
    }

    final reduceSubjects = <String>{...reduce};
    if (reduceProgram) {
      for (final t in dayTargets) {
        final s = subjectOf(t.title);
        if (s == null || protect.contains(s) || t.isProtected) continue;
        reduceSubjects.add(s);
      }
      if (targets.isEmpty) reduceSubjects.add('spor'); // most demanding flexible block
      reduceSubjects.removeAll(protect);
    }
    for (final s in reduceSubjects) {
      final t = findTarget(s);
      if (t != null && t.isProtected && !reduce.contains(s)) continue;
      final from = t?.minutes;
      final to = explicitMinutes[s] ?? (from != null ? lightenedMinutes(s, from) : (s == 'spor' ? 20 : null));
      if (from != null && to != null && to >= from) continue;
      actions.add(IntentAction(
        type: IntentActionType.reduce,
        subject: s,
        displayName: nameOf(s),
        day: commandDay,
        fromMinutes: from ?? (s == 'spor' ? 45 : null),
        toMinutes: to,
        targetId: t?.id,
      ));
    }
    for (final s in increase) {
      final t = findTarget(s);
      final from = t?.minutes;
      actions.add(IntentAction(
        type: IntentActionType.increase,
        subject: s,
        displayName: nameOf(s),
        day: commandDay,
        fromMinutes: from,
        toMinutes: from != null ? _roundTo5(from * 1.5) : null,
        targetId: t?.id,
      ));
    }
    for (final s in cancel) {
      final t = findTarget(s);
      actions.add(IntentAction(
        type: IntentActionType.cancel,
        subject: s,
        displayName: nameOf(s),
        day: commandDay,
        fromMinutes: t?.minutes,
        targetId: t?.id,
      ));
    }
    for (final s in move) {
      final t = findTarget(s);
      actions.add(IntentAction(
        type: IntentActionType.move,
        subject: s,
        displayName: nameOf(s),
        day: DayRef.tomorrow,
        targetId: t?.id,
      ));
    }
    for (final c in creates) {
      actions.add(IntentAction(
          type: IntentActionType.create, subject: 'task', displayName: c, title: c, day: commandDay));
    }
    for (final r in reminders) {
      actions.add(IntentAction(
          type: IntentActionType.remind, subject: 'reminder', displayName: r, title: r, day: commandDay));
    }

    return VoiceIntent(transcript: text, emotion: emotion, day: commandDay, actions: actions);
  }

  /// Extracts a human title from the clause containing [verb].
  static String _extractTitle(String original, String verb) {
    final sentences = original.split(RegExp(r'[.!?]'));
    final foldedVerb = TurkishText.fold(verb);
    for (final s in sentences) {
      if (TurkishText.fold(s).contains(foldedVerb.substring(0, foldedVerb.length - 1))) {
        var t = s
            .replaceAll(RegExp(r'\b(bana|lütfen|bir|yarın|bugün)\b', caseSensitive: false), ' ')
            .replaceAll(RegExp(r'\b\w*(hatırlat|ekle|oluştur|planla)\w*\b', caseSensitive: false), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (t.isEmpty) t = s.trim();
        return TurkishText.capitalize(t);
      }
    }
    return TurkishText.capitalize(original.trim());
  }
}

// ---------------------------------------------------------------------------
// Speech-to-text service (Android native recognizer, Turkish first)
// ---------------------------------------------------------------------------

enum VoiceState { idle, initializing, listening, processing, unavailable, error }

/// Wraps `speech_to_text` for Turkish dictation. When the native recognizer is
/// unavailable (no Google speech services, permission denied, emulator) the UI
/// falls back to manual text input; the same intent parser runs offline.
class VoiceService {
  VoiceService({SpeechToText? engine}) : _engine = engine;

  SpeechToText? _engine;
  bool _initialized = false;
  bool available = false;
  String? localeId;
  String? lastError;

  static const preferredLocales = ['tr_TR', 'tr-TR', 'tr'];

  SpeechToText get _stt => _engine ??= SpeechToText();

  bool get isListening => _initialized && _stt.isListening;

  Future<bool> init({void Function(String status)? onStatus, void Function(String error)? onError}) async {
    if (_initialized) return available;
    try {
      available = await _stt.initialize(
        onStatus: (s) => onStatus?.call(s),
        onError: (SpeechRecognitionError e) {
          lastError = e.errorMsg;
          onError?.call(e.errorMsg);
        },
        debugLogging: false,
      );
      _initialized = true;
      if (available) {
        final locales = await _stt.locales();
        for (final pref in preferredLocales) {
          final hit = locales.where((l) => l.localeId.toLowerCase().replaceAll('-', '_') == pref.toLowerCase().replaceAll('-', '_'));
          if (hit.isNotEmpty) {
            localeId = hit.first.localeId;
            break;
          }
        }
        localeId ??= locales.where((l) => l.localeId.toLowerCase().startsWith('tr')).map((l) => l.localeId).firstOrNull;
        localeId ??= 'tr_TR';
      }
    } catch (e) {
      // MissingPluginException (tests / unsupported platform) or platform error.
      debugPrint('VoiceService.init failed: $e');
      lastError = e.toString();
      available = false;
      _initialized = true;
    }
    return available;
  }

  Future<void> start({
    required void Function(String text, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
  }) async {
    if (!available) return;
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) => onResult(r.recognizedWords, r.finalResult),
      onSoundLevelChange: onSoundLevel,
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        listenMode: ListenMode.dictation,
        autoPunctuation: true,
        cancelOnError: true,
      ),
    );
  }

  Future<void> stop() async {
    if (_initialized && available) await _stt.stop();
  }

  Future<void> cancel() async {
    if (_initialized && available) await _stt.cancel();
  }
}

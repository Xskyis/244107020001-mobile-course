import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Hasil generasi catatan dari AI atau fallback lokal.
class GeneratedNoteResult {
  const GeneratedNoteResult({
    required this.title,
    required this.body,
    required this.rawResponse,
    this.isFallback = false,
    this.fromCache = false,
  });

  final String title;
  final String body;
  final String rawResponse;
  final bool isFallback;
  final bool fromCache;
}

class AiMissingKeyException implements Exception {
  const AiMissingKeyException([
    this.message =
        'Layanan AI cloud sedang tidak aktif. Gunakan Fallback Lokal untuk membuat draf catatan.',
  ]);
  final String message;

  @override
  String toString() => message;
}

class AiOfflineException implements Exception {
  const AiOfflineException([
    this.message = 'Mode offline aktif. Layanan AI cloud tidak dapat diakses.',
  ]);
  final String message;

  @override
  String toString() => message;
}

class AiQuotaExceededException implements Exception {
  const AiQuotaExceededException([
    this.message = 'Batas harian request AI tercapai. Gunakan fallback lokal.',
  ]);
  final String message;

  @override
  String toString() => message;
}

class AiPrivacyException implements Exception {
  const AiPrivacyException([
    this.message =
        'Prompt terdeteksi mengandung data sensitif (API key/NIK/sandi). Hapus data sensitif sebelum mengirim ke AI.',
  ]);
  final String message;

  @override
  String toString() => message;
}

class AiApiException implements Exception {
  const AiApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Service untuk integrasi fitur AI Chat Auto-Generate Notes
/// dengan penyimpanan API key aman, rate limiting, cache lokal,
/// proteksi privasi, dan fallback offline.
class AiService {
  AiService({
    FlutterSecureStorage? storage,
    http.Client? client,
    this.maxDailyRequests = 20,
    Future<SharedPreferences> Function()? prefsProvider,
    String? Function()? envKeyProvider,
    String? Function()? envModelProvider,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _client = client ?? http.Client(),
       _prefsProvider = prefsProvider ?? SharedPreferences.getInstance,
       _envKeyProvider = envKeyProvider ?? _defaultEnvKey,
       _envModelProvider = envModelProvider ?? _defaultEnvModel;

  static const String apiKeyStorageKey = 'ai_api_key';
  static const String _dailyCountKey = 'ai_daily_request_count';
  static const String _dailyDateKey = 'ai_daily_request_date';

  static const String defaultModel = 'gemini-flash-lite-latest';
  static const String _baseApiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static String buildEndpoint(String model) =>
      '$_baseApiUrl/$model:generateContent';

  static String? _defaultEnvKey() =>
      dotenv.isInitialized ? dotenv.env['GEMINI_API_KEY'] : null;

  static String? _defaultEnvModel() =>
      dotenv.isInitialized ? dotenv.env['GEMINI_MODEL'] : null;

  static const String systemPrompt = '''
Kamu adalah asisten pembuat catatan cerdas untuk aplikasi mobile "Offline First Notes".
Tugasmu adalah mengubah topik, instruksi, atau ide pengguna menjadi catatan yang ringkas, jelas, dan terstruktur dalam Bahasa Indonesia.

Format output WAJIB persis seperti berikut:
JUDUL: <judul singkat maksimal 60 karakter>
ISI:
<isi catatan terstruktur dengan poin-poin bila relevan, maksimal 800 karakter>

Aturan privasi & keamanan:
- Jangan meminta atau menyertakan data pribadi sensitif (NIK, password, nomor rekening, atau API key).
- Jawab langsung sesuai format tanpa basa-basi pembuka atau penutup.
''';

  final FlutterSecureStorage _storage;
  final http.Client _client;
  final int maxDailyRequests;
  final Future<SharedPreferences> Function() _prefsProvider;
  final String? Function() _envKeyProvider;
  final String? Function() _envModelProvider;
  final Map<String, GeneratedNoteResult> _cache = {};

  /// Simpan API key secara aman ke FlutterSecureStorage.
  Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: apiKeyStorageKey);
      return;
    }
    await _storage.write(key: apiKeyStorageKey, value: trimmed);
  }

  /// Baca API key dari FlutterSecureStorage, lalu fallback ke .env (GEMINI_API_KEY).
  Future<String?> readApiKey() async {
    final secureKey = (await _storage.read(key: apiKeyStorageKey))?.trim();
    if (secureKey != null && secureKey.isNotEmpty) {
      return secureKey;
    }
    final envKey = _envKeyProvider()?.trim();
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }
    return null;
  }

  /// Ambil nama model aktif dari .env (GEMINI_MODEL) atau default gemini-flash-lite-latest.
  String get activeModel {
    final envModel = _envModelProvider()?.trim();
    return (envModel != null && envModel.isNotEmpty) ? envModel : defaultModel;
  }

  /// Cek apakah API key sudah tersedia.
  Future<bool> hasApiKey() async {
    final key = await readApiKey();
    return key != null && key.trim().isNotEmpty;
  }

  /// Hapus API key dari secure storage.
  Future<void> clearApiKey() => _storage.delete(key: apiKeyStorageKey);

  /// Cek apakah input mengandung pola data sensitif sebelum dikirim ke cloud.
  static bool containsSensitiveData(String input) {
    final patterns = [
      RegExp(r'AIza[0-9A-Za-z\-_]{20,}'), // Google API key
      RegExp(r'sk-[0-9A-Za-z]{20,}'), // OpenAI/secret key
      RegExp(r'\b\d{16}\b'), // 16 digit NIK / nomor kartu
      RegExp(r'(password|kata sandi|pin)\s*[:=]\s*\S+', caseSensitive: false),
    ];
    return patterns.any((pattern) => pattern.hasMatch(input));
  }

  /// Ambil jumlah pemakaian request AI hari ini.
  Future<int> getDailyUsageCount() async {
    final prefs = await _prefsProvider();
    final today = _todayKey();
    final savedDate = prefs.getString(_dailyDateKey);
    if (savedDate != today) {
      return 0;
    }
    return prefs.getInt(_dailyCountKey) ?? 0;
  }

  Future<void> _incrementDailyUsage() async {
    final prefs = await _prefsProvider();
    final today = _todayKey();
    final savedDate = prefs.getString(_dailyDateKey);
    final current = savedDate == today ? (prefs.getInt(_dailyCountKey) ?? 0) : 0;
    await prefs.setString(_dailyDateKey, today);
    await prefs.setInt(_dailyCountKey, current + 1);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Generate catatan terstruktur melalui Gemini API.
  Future<GeneratedNoteResult> generateNote(
    String userPrompt, {
    bool forceOffline = false,
  }) async {
    final cleanPrompt = userPrompt.trim();
    if (cleanPrompt.isEmpty) {
      throw const AiApiException('Prompt tidak boleh kosong.');
    }

    if (containsSensitiveData(cleanPrompt)) {
      throw const AiPrivacyException();
    }

    final cacheKey = cleanPrompt.toLowerCase();
    final cached = _cache[cacheKey];
    if (cached != null) {
      return GeneratedNoteResult(
        title: cached.title,
        body: cached.body,
        rawResponse: cached.rawResponse,
        fromCache: true,
      );
    }

    if (forceOffline) {
      throw const AiOfflineException();
    }

    final apiKey = await readApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AiMissingKeyException();
    }

    final usage = await getDailyUsageCount();
    if (usage >= maxDailyRequests) {
      throw const AiQuotaExceededException();
    }

    final endpoint = buildEndpoint(activeModel);
    final response = await _client
        .post(
          Uri.parse('$endpoint?key=${apiKey.trim()}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'system_instruction': {
              'parts': [
                {'text': systemPrompt},
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': cleanPrompt},
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.4,
              'maxOutputTokens': 512,
            },
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw AiApiException(
        'Gagal memanggil AI API (HTTP ${response.statusCode}).',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const AiApiException('AI tidak mengembalikan kandidat respons.');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final rawText = (parts?.first['text'] as String?)?.trim() ?? '';
    if (rawText.isEmpty) {
      throw const AiApiException('Respons AI kosong.');
    }

    await _incrementDailyUsage();
    final parsed = parseGeneratedNote(rawText, fallbackTitle: cleanPrompt);
    _cache[cacheKey] = parsed;
    return parsed;
  }

  /// Simulasi streaming teks bertahap untuk pengalaman chat yang responsif.
  Stream<String> streamTextChunks(String fullText) async* {
    final words = fullText.split(' ');
    final buffer = StringBuffer();
    for (var i = 0; i < words.length; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write(words[i]);
      yield buffer.toString();
      await Future<void>.delayed(const Duration(milliseconds: 22));
    }
  }

  /// Fallback lokal ketika offline, API key belum diatur, atau layanan AI down.
  static GeneratedNoteResult generateFallbackNote(String prompt) {
    final clean = prompt.trim();
    final shortTitle = clean.length <= 45
        ? clean
        : '${clean.substring(0, 42)}...';
    final title = 'Catatan: ${_capitalize(shortTitle)}';
    final body = [
      'Ringkasan topik: $clean',
      '',
      'Poin Utama (Draft Offline):',
      '- Tujuan utama: Pelajari & pecah topik "$shortTitle" menjadi langkah kecil.',
      '- Hal penting yang perlu dicatat dan ditindaklanjuti.',
      '- Verifikasi kembali hasil akhir saat perangkat terhubung ke layanan AI.',
    ].join('\n');

    return GeneratedNoteResult(
      title: title,
      body: body,
      rawResponse: 'JUDUL: $title\nISI:\n$body',
      isFallback: true,
    );
  }

  /// Parser terstruktur untuk respons format JUDUL: ... / ISI: ...
  static GeneratedNoteResult parseGeneratedNote(
    String rawText, {
    String fallbackTitle = 'Catatan AI',
  }) {
    final normalized = rawText.trim();
    final titleMatch = RegExp(
      r'^JUDUL:\s*(.+)$',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(normalized);
    final bodyMatch = RegExp(
      r'ISI:\s*([\s\S]+)$',
      caseSensitive: false,
    ).firstMatch(normalized);

    if (titleMatch != null && bodyMatch != null) {
      final title = titleMatch.group(1)!.trim();
      final body = bodyMatch.group(1)!.trim();
      if (title.isNotEmpty) {
        return GeneratedNoteResult(
          title: title,
          body: body,
          rawResponse: normalized,
        );
      }
    }

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return GeneratedNoteResult(
        title: fallbackTitle,
        body: '',
        rawResponse: normalized,
      );
    }

    final title = lines.first.replaceAll(RegExp(r'^[#*>\-\s]+'), '').trim();
    final body = lines.length > 1 ? lines.skip(1).join('\n') : '';
    return GeneratedNoteResult(
      title: title.isEmpty ? fallbackTitle : title,
      body: body,
      rawResponse: normalized,
    );
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

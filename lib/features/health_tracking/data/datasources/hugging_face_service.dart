import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'browser_llm.dart';

class HuggingFaceException implements Exception {
  final String message;

  const HuggingFaceException(this.message);

  @override
  String toString() => message;
}

/// Un message de conversation envoyé au modèle
class HfMessage {
  final String role; // system | user | assistant
  final String content;

  const HfMessage(this.role, this.content);

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Accès à un modèle de langage ouvert hébergé sur Hugging Face.
///
/// Sur le web, le modèle tourne par défaut dans le navigateur (Transformers.js),
/// sans jeton ni serveur. Deux autres modes peuvent être choisis dans .env :
///  1. Space Hugging Face du projet (gratuit) : le modèle est déployé dans
///     notre propre Space (dossier hf_space/ du dépôt).
///       HF_SPACE_URL=https://<compte>-<space>.hf.space
///  2. Inference Providers (crédits payants) :
///       HF_TOKEN=hf_xxx
///   HF_MODEL=...   (facultatif, nom du modèle)
class HuggingFaceService {
  static const String endpoint = 'https://router.huggingface.co/v1/chat/completions';
  static const String defaultModel = 'meta-llama/Llama-3.3-70B-Instruct';
  static const String defaultSpaceModel = 'Qwen/Qwen2.5-1.5B-Instruct';
  static const Duration timeout = Duration(seconds: 25);

  /// Un Space gratuit tourne sur processeur : la réponse est plus lente
  static const Duration spaceTimeout = Duration(seconds: 150);

  /// Modèle exécuté dans le navigateur avec Transformers.js (gratuit, sans jeton)
  static const String defaultBrowserModel = 'onnx-community/Qwen2.5-0.5B-Instruct';

  /// Le premier appel télécharge le modèle dans le navigateur
  static const Duration browserTimeout = Duration(minutes: 12);

  final http.Client _client;
  final String? tokenOverride;
  final String? modelOverride;
  final String? spaceUrlOverride;
  final BrowserLlm browserLlm;

  HuggingFaceService({
    http.Client? client,
    this.tokenOverride,
    this.modelOverride,
    this.spaceUrlOverride,
    BrowserLlm? browserLlm,
  }) : _client = client ?? http.Client(),
       browserLlm = browserLlm ?? createBrowserLlm();

  /// Sur le web, le modèle tourne dans le navigateur (sauf si un Space est configuré)
  bool get usesBrowser => !usesSpace && browserLlm.isSupported;

  static String? _env(String key) {
    if (!dotenv.isInitialized) return null;
    final value = dotenv.env[key]?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String? get token => tokenOverride ?? _env('HF_TOKEN');

  /// Adresse du Space du projet, sans barre oblique finale (null si non configuré)
  String? get spaceUrl => (spaceUrlOverride ?? _env('HF_SPACE_URL'))?.replaceAll(RegExp(r'/+$'), '');

  bool get usesSpace => spaceUrl != null;

  String get model {
    if (modelOverride != null) return modelOverride!;
    if (usesBrowser) return _env('HF_BROWSER_MODEL') ?? defaultBrowserModel;
    return _env('HF_MODEL') ?? (usesSpace ? defaultSpaceModel : defaultModel);
  }

  /// Nom court du modèle pour l'affichage (sans l'organisation)
  String get modelName => model.split('/').last.split(':').first;

  bool get isConfigured => usesSpace || usesBrowser || token != null;

  Future<String> chat(List<HfMessage> messages, {int maxTokens = 400, double temperature = 0.3}) async {
    if (usesBrowser) return _chatInBrowser(messages, maxTokens);
    final key = token;
    final space = spaceUrl;
    if (space == null && key == null) {
      throw const HuggingFaceException('Hugging Face non configuré (HF_SPACE_URL ou HF_TOKEN dans .env).');
    }

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(space != null ? '$space/v1/chat/completions' : endpoint),
            // Le Space du projet est public : le jeton n'y est pas envoyé
            headers: {if (space == null) 'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'messages': messages.map((m) => m.toJson()).toList(),
              'max_tokens': maxTokens,
              'temperature': temperature,
            }),
          )
          .timeout(space != null ? spaceTimeout : timeout);
    } on TimeoutException {
      throw const HuggingFaceException('Le modèle met trop de temps à répondre.');
    } catch (_) {
      throw const HuggingFaceException('Connexion à Hugging Face impossible.');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const HuggingFaceException('Jeton Hugging Face refusé.');
    }
    if (response.statusCode == 402 || response.statusCode == 429) {
      throw const HuggingFaceException('Quota Hugging Face atteint.');
    }
    if (response.statusCode != 200) {
      throw HuggingFaceException('Erreur Hugging Face (${response.statusCode}).');
    }

    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = (data['choices'] as List).first['message']['content'] as String;
      if (content.trim().isEmpty) throw const FormatException();
      return content;
    } catch (_) {
      throw const HuggingFaceException('Réponse du modèle illisible.');
    }
  }

  Future<String> _chatInBrowser(List<HfMessage> messages, int maxTokens) async {
    try {
      final text = await browserLlm
          .generate(model, messages.map((m) => m.toJson()).toList(), maxTokens)
          .timeout(browserTimeout);
      if (text.trim().isEmpty) throw const HuggingFaceException('Réponse du modèle illisible.');
      return text;
    } on HuggingFaceException {
      rethrow;
    } on TimeoutException {
      throw const HuggingFaceException('Le modèle met trop de temps à répondre.');
    } catch (_) {
      throw const HuggingFaceException('Le modèle n\'a pas pu être chargé dans le navigateur.');
    }
  }

  void close() => _client.close();
}

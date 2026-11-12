import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../constants/orientation_constants.dart';

/// Exceptions spécifiques à l'API Gemini
abstract class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);

  @override
  String toString() => message;
}

class GeminiKeyMissingException extends GeminiException {
  const GeminiKeyMissingException(
      [super.message =
          "Service d'orientation non configuré : clé API Gemini absente."]);
}

class GeminiAuthException extends GeminiException {
  const GeminiAuthException(
      [super.message = "Clé API Gemini invalide ou non autorisée (401/403)."]);
}

class GeminiQuotaException extends GeminiException {
  const GeminiQuotaException(
      [super.message =
          "Quota ou limite de requêtes Gemini dépassé (429). Veuillez réessayer dans quelques instants."]);
}

class GeminiServerException extends GeminiException {
  const GeminiServerException(
      [super.message =
          "Le service d'orientation Gemini rencontre un problème temporaire (5xx)."]);
}

class GeminiSafetyException extends GeminiException {
  const GeminiSafetyException(
      [super.message =
          "Votre message a été filtré par les règles de sécurité de l'IA."]);
}

class GeminiNetworkException extends GeminiException {
  const GeminiNetworkException(
      [super.message =
          "Impossible de joindre le service d'orientation. Vérifiez votre connexion Internet."]);
}

class GeminiParsingException extends GeminiException {
  const GeminiParsingException(
      [super.message =
          "La réponse de l'IA n'a pas pu être analysée correctement."]);
}

class GeminiApiException extends GeminiException {
  const GeminiApiException(super.message);
}

/// Service HTTP pour communiquer avec l'API Google Gemini
class GeminiService {
  final http.Client _client;
  final String? apiKeyOverride;
  final String _model;

  GeminiService({
    http.Client? client,
    this.apiKeyOverride,
    String? model,
  })  : _client = client ?? http.Client(),
        _model = (model != null && model.isNotEmpty)
            ? model
            : OrientationConstants.defaultGeminiModel;

  /// Récupère la clé API actuelle (.env ou surcharge)
  String? get apiKey {
    if (apiKeyOverride != null) {
      final trimmed = apiKeyOverride!.trim();
      return trimmed.isNotEmpty ? trimmed : null;
    }
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key != null && key.trim().isNotEmpty) {
      return key.trim();
    }
    return null;
  }

  /// Indique si une clé API est configurée
  bool get hasApiKey => apiKey != null;

  /// Envoie la description des symptômes à Gemini et retourne la réponse JSON brute décodée
  Future<Map<String, dynamic>> orientSymptoms({
    required String symptomsText,
    required List<String> allowedSpecialties,
  }) async {
    final key = apiKey;
    if (key == null) {
      throw const GeminiKeyMissingException();
    }

    final systemInstruction =
        OrientationConstants.buildSystemPrompt(allowedSpecialties);

    final requestBody = {
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': symptomsText}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': OrientationConstants.responseSchema,
        'temperature': 0.2,
        'maxOutputTokens': 800,
      }
    };

    final candidateModels = [
      _model,
      if (_model != OrientationConstants.fallbackGeminiModel)
        OrientationConstants.fallbackGeminiModel,
    ];

    http.Response? response;
    Object? lastNetworkError;

    for (final modelName in candidateModels) {
      final uri = Uri.parse(
        '${OrientationConstants.geminiApiBaseUrl}/$modelName:generateContent?key=$key',
      );

      int attempt = 0;
      while (attempt < 2) {
        attempt++;
        try {
          final res = await _client
              .post(
                uri,
                headers: {'Content-Type': 'application/json; charset=utf-8'},
                body: jsonEncode(requestBody),
              )
              .timeout(OrientationConstants.requestTimeout);

          // Si le modèle n'existe pas (404) ou est surchargé (503), essayer le modèle suivant
          if ((res.statusCode == 404 || res.statusCode == 503) &&
              modelName != candidateModels.last) {
            break;
          }

          response = res;
          break;
        } on SocketException catch (_) {
          if (attempt >= 2) throw const GeminiNetworkException();
        } on TimeoutException catch (_) {
          if (attempt >= 2) throw const GeminiNetworkException();
        } catch (e) {
          if (attempt >= 2) {
            throw GeminiNetworkException("Erreur de connexion : $e");
          }
        }
      }

      if (response != null && response.statusCode == 200) {
        break;
      }
    }

    if (response == null) {
      throw const GeminiNetworkException();
    }

    return _processResponse(response);
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode == 401 || statusCode == 403) {
      throw const GeminiAuthException();
    } else if (statusCode == 429) {
      throw const GeminiQuotaException();
    } else if (statusCode >= 500) {
      throw GeminiServerException(
          "Erreur serveur Gemini ($statusCode). Veuillez réessayer plus tard.");
    } else if (statusCode == 400) {
      throw GeminiApiException("Requête invalide vers Gemini ($statusCode).");
    } else if (statusCode != 200) {
      throw GeminiApiException("Erreur inattendue de l'API Gemini ($statusCode).");
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const GeminiParsingException(
          "Format de réponse JSON HTTP invalide.");
    }

    // Vérification du blocage de sécurité global
    final promptFeedback = body['promptFeedback'] as Map<String, dynamic>?;
    if (promptFeedback != null && promptFeedback['blockReason'] != null) {
      throw const GeminiSafetyException();
    }

    final candidates = body['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const GeminiParsingException(
          "Aucune réponse générée par l'IA Gemini.");
    }

    final firstCandidate = candidates.first as Map<String, dynamic>;
    final finishReason = firstCandidate['finishReason'] as String?;
    if (finishReason == 'SAFETY') {
      throw const GeminiSafetyException();
    }

    final content = firstCandidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw const GeminiParsingException("Contenu de réponse Gemini vide.");
    }

    final text = parts.first['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw const GeminiParsingException("Texte de réponse JSON Gemini vide.");
    }

    try {
      return jsonDecode(text.trim()) as Map<String, dynamic>;
    } catch (_) {
      throw const GeminiParsingException(
          "La structure JSON retournée par Gemini est corrompue.");
    }
  }

  void close() {
    _client.close();
  }
}

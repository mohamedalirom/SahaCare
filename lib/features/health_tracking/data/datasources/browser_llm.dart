import 'browser_llm_stub.dart' if (dart.library.js_interop) 'browser_llm_web.dart' as impl;

/// État du modèle exécuté dans le navigateur
class BrowserLlmState {
  /// idle | loading | generating | ready | error
  final String status;

  /// Avancement du téléchargement du modèle (0 à 100)
  final int progress;

  /// webgpu | wasm
  final String device;

  const BrowserLlmState({this.status = 'idle', this.progress = 0, this.device = ''});
}

/// Modèle de langage Hugging Face exécuté sur l'appareil, dans le navigateur,
/// avec Transformers.js (web/saha_llm.js). Disponible uniquement sur le web.
abstract class BrowserLlm {
  bool get isSupported;

  BrowserLlmState get state;

  /// [messages] : liste de {role, content}. Le premier appel télécharge le modèle.
  Future<String> generate(String model, List<Map<String, String>> messages, int maxTokens);
}

BrowserLlm createBrowserLlm() => impl.createBrowserLlm();

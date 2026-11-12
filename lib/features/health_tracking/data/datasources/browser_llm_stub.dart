import 'browser_llm.dart';

/// Hors navigateur (mobile, bureau, tests) : pas de modèle embarqué
class _UnsupportedBrowserLlm implements BrowserLlm {
  @override
  bool get isSupported => false;

  @override
  BrowserLlmState get state => const BrowserLlmState();

  @override
  Future<String> generate(String model, List<Map<String, String>> messages, int maxTokens) {
    throw UnsupportedError('Modèle embarqué disponible uniquement dans le navigateur.');
  }
}

BrowserLlm createBrowserLlm() => _UnsupportedBrowserLlm();

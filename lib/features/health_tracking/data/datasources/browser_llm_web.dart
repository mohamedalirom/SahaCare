import 'dart:convert';
import 'dart:js_interop';

import 'browser_llm.dart';

@JS('sahaLlm')
external _SahaLlm? get _sahaLlm;

extension type _SahaLlm._(JSObject _) implements JSObject {
  external bool supported();
  external String state();
  external JSPromise<JSString> generate(String model, String messagesJson, int maxTokens);
}

class _WebBrowserLlm implements BrowserLlm {
  @override
  bool get isSupported => _sahaLlm?.supported() ?? false;

  @override
  BrowserLlmState get state {
    final llm = _sahaLlm;
    if (llm == null) return const BrowserLlmState();
    final data = jsonDecode(llm.state()) as Map<String, dynamic>;
    return BrowserLlmState(
      status: data['status'] as String? ?? 'idle',
      progress: (data['progress'] as num?)?.round() ?? 0,
      device: data['device'] as String? ?? '',
    );
  }

  @override
  Future<String> generate(String model, List<Map<String, String>> messages, int maxTokens) async {
    final result = await _sahaLlm!.generate(model, jsonEncode(messages), maxTokens).toDart;
    return result.toDart;
  }
}

BrowserLlm createBrowserLlm() => _WebBrowserLlm();

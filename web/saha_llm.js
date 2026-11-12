// Saha Intelligence : modèle de langage Hugging Face exécuté dans le navigateur.
// Le modèle tourne dans un Web Worker (saha_llm_worker.js) avec Transformers.js,
// la bibliothèque JavaScript de Hugging Face. Aucune donnée ne quitte l'appareil.
(function () {
  let worker = null;
  let nextId = 1;
  const pending = new Map();
  const state = { status: 'idle', progress: 0, device: '', error: '' };

  function ensureWorker() {
    if (worker) return;
    worker = new Worker('saha_llm_worker.js', { type: 'module' });
    worker.onmessage = (event) => {
      const msg = event.data;
      if (msg.type === 'status') {
        state.status = msg.status;
        if (msg.device) state.device = msg.device;
        if (msg.progress !== undefined) state.progress = msg.progress;
      } else if (msg.type === 'result' || msg.type === 'error') {
        const entry = pending.get(msg.id);
        pending.delete(msg.id);
        state.status = msg.type === 'error' ? 'error' : 'ready';
        state.error = msg.type === 'error' ? msg.message : '';
        if (!entry) return;
        if (msg.type === 'result') entry.resolve(msg.text);
        else entry.reject(new Error(msg.message));
      }
    };
    worker.onerror = (event) => {
      state.status = 'error';
      state.error = event.message || 'worker';
      for (const entry of pending.values()) entry.reject(new Error(state.error));
      pending.clear();
      worker = null;
    };
  }

  window.sahaLlm = {
    supported: () => typeof Worker !== 'undefined' && typeof WebAssembly !== 'undefined',
    state: () => JSON.stringify(state),
    generate: (model, messagesJson, maxTokens) =>
      new Promise((resolve, reject) => {
        try {
          ensureWorker();
          const id = nextId++;
          pending.set(id, { resolve, reject });
          worker.postMessage({ id, model, messages: JSON.parse(messagesJson), maxTokens });
        } catch (error) {
          reject(error);
        }
      }),
  };
})();

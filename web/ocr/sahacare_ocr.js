/* SahaCare local OCR adapter. Images and recognized text stay in this page/worker. */
(() => {
  'use strict';
  const root = new URL('.', document.currentScript.src);
  let library;
  let active;
  let generation = 0;
  const local = path => new URL(path, root).href;
  function loadLibrary() {
    if (library) return library;
    library = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = local('tesseract.min.js');
      script.onload = resolve;
      script.onerror = () => reject(new Error('Moteur OCR local introuvable.'));
      document.head.appendChild(script);
    }).catch(error => { library = undefined; throw error; });
    return library;
  }
  window.sahaCareOcr = Object.freeze({
    async recognize(bytes, progress) {
      if (active) throw new Error('Une analyse OCR est déjà en cours.');
      const task = ++generation;
      let worker;
      try {
        await loadLibrary();
        if (task !== generation) throw new Error('Analyse annulée.');
        worker = await Tesseract.createWorker('fra+eng', 1, {
          workerPath: local('worker.min.js'),
          corePath: local('core/'),
          langPath: local('data/'),
          workerBlobURL: false,
          cacheMethod: 'none',
          logger: message => {
            if (task === generation && Number.isFinite(message.progress)) {
              progress(Math.max(0, Math.min(1, message.progress)));
            }
          },
        });
        if (task !== generation) throw new Error('Analyse annulée.');
        active = worker;
        const result = await worker.recognize(new Blob([bytes], {type:'image/png'}), {rotateAuto:true});
        if (task !== generation) throw new Error('Analyse annulée.');
        return {text: result.data.text || '', confidence: Number.isFinite(result.data.confidence) ? result.data.confidence : null};
      } catch (_) {
        throw new Error('OCR local interrompu ou indisponible. Vérifiez l’image et les ressources locales.');
      } finally {
        if (active === worker) active = undefined;
        if (worker) { try { await worker.terminate(); } catch (_) {} }
      }
    },
    cancel() {
      generation++;
      if (active) { const worker = active; active = undefined; worker.terminate().catch(() => {}); }
    },
  });
})();

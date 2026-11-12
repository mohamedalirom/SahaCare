// Web Worker : charge un modèle du Hub Hugging Face avec Transformers.js et
// génère le texte sans bloquer l'interface. WebGPU si disponible, sinon WebAssembly.
import { pipeline } from 'https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.7.0/dist/transformers.min.js';

let generator = null;
let loadedModel = null;
let device = '';

async function load(model) {
  if (generator && loadedModel === model) return;
  generator = null;

  const onProgress = (p) => {
    if (p.status === 'progress' && p.file && p.file.includes('.onnx')) {
      self.postMessage({ type: 'status', status: 'loading', progress: Math.round(p.progress || 0) });
    }
  };

  let hasGpu = false;
  try {
    hasGpu = !!self.navigator.gpu && !!(await self.navigator.gpu.requestAdapter());
  } catch (_) {
    hasGpu = false;
  }
  // q4f16 (demi-précision) produit un texte incohérent sur certaines cartes graphiques : on reste en q4
  const attempts = hasGpu ? [['webgpu', 'q4'], ['wasm', 'q4']] : [['wasm', 'q4']];

  let lastError = null;
  for (const [dev, dtype] of attempts) {
    try {
      self.postMessage({ type: 'status', status: 'loading', progress: 0, device: dev });
      generator = await pipeline('text-generation', model, { device: dev, dtype, progress_callback: onProgress });
      loadedModel = model;
      device = dev;
      return;
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError || new Error('Chargement du modèle impossible');
}

self.onmessage = async (event) => {
  const { id, model, messages, maxTokens } = event.data;
  try {
    await load(model);
    self.postMessage({ type: 'status', status: 'generating', device });
    const output = await generator(messages, { max_new_tokens: maxTokens, do_sample: false, repetition_penalty: 1.1 });
    const text = output[0].generated_text.at(-1).content;
    self.postMessage({ type: 'result', id, text });
  } catch (error) {
    self.postMessage({ type: 'error', id, message: String((error && error.message) || error) });
  }
};

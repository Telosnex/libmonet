import {type Argb} from './color.js';
import {quantizeArgbPixels, type QuantizerResult} from './extract.js';

export interface SerializedQuantizerResultEntries {
  argbToCount: Array<[Argb, number]>;
  inputPixelToClusterPixel?: Array<[Argb, Argb]>;
  lstarToCount?: Array<[number, number]>;
}

export interface QuantizeWorkerRequest {
  id: number;
  type: 'libmonet.quantize';
  pixels: Argb[];
  colorCount: number;
}

export interface QuantizeWorkerResponse {
  id: number;
  type: 'libmonet.quantize.result';
  result?: SerializedQuantizerResultEntries;
  error?: string;
}

export interface WorkerLike {
  postMessage(message: unknown, transfer?: Transferable[]): void;
  addEventListener(type: 'message', listener: (event: MessageEvent<unknown>) => void): void;
  removeEventListener(type: 'message', listener: (event: MessageEvent<unknown>) => void): void;
  terminate?(): void;
}

export interface QuantizeWorkerScope {
  postMessage(message: unknown): void;
  addEventListener(type: 'message', listener: (event: MessageEvent<unknown>) => void): void;
}

export function serializeQuantizerResultEntries(result: QuantizerResult): SerializedQuantizerResultEntries {
  return {
    argbToCount: Array.from(result.argbToCount.entries()),
    ...(result.inputPixelToClusterPixel === undefined ? {} : {inputPixelToClusterPixel: Array.from(result.inputPixelToClusterPixel.entries())}),
    ...(result.lstarToCount === undefined ? {} : {lstarToCount: Array.from(result.lstarToCount.entries())}),
  };
}

export function deserializeQuantizerResultEntries(serialized: SerializedQuantizerResultEntries): QuantizerResult {
  return {
    argbToCount: new Map(serialized.argbToCount),
    ...(serialized.inputPixelToClusterPixel === undefined ? {} : {inputPixelToClusterPixel: new Map(serialized.inputPixelToClusterPixel)}),
    ...(serialized.lstarToCount === undefined ? {} : {lstarToCount: new Map(serialized.lstarToCount)}),
  };
}

let nextRequestId = 1;

export function createQuantizeWorker(): Worker {
  return new Worker(new URL('./quantize-worker.js', import.meta.url), {type: 'module'});
}

export function quantizeArgbPixelsInWorker(
  pixels: readonly Argb[],
  colorCount = 128,
  worker: WorkerLike = createQuantizeWorker(),
  options: {terminateWhenDone?: boolean} = {},
): Promise<QuantizerResult> {
  const id = nextRequestId++;
  const ownsWorker = options.terminateWhenDone ?? arguments.length < 3;
  return new Promise((resolve, reject) => {
    const onMessage = (event: MessageEvent<unknown>) => {
      const message = event.data as Partial<QuantizeWorkerResponse>;
      if (message?.type !== 'libmonet.quantize.result' || message.id !== id) return;
      worker.removeEventListener('message', onMessage);
      if (ownsWorker) worker.terminate?.();
      if (message.error !== undefined) {
        reject(new Error(message.error));
      } else if (message.result !== undefined) {
        resolve(deserializeQuantizerResultEntries(message.result));
      } else {
        reject(new Error('Quantize worker returned neither result nor error'));
      }
    };
    worker.addEventListener('message', onMessage);
    const request: QuantizeWorkerRequest = {
      id,
      type: 'libmonet.quantize',
      pixels: Array.from(pixels),
      colorCount,
    };
    worker.postMessage(request);
  });
}

export function installQuantizeWorkerHandler(scope: QuantizeWorkerScope = globalThis as unknown as QuantizeWorkerScope): void {
  scope.addEventListener('message', (event: MessageEvent<unknown>) => {
    const request = event.data as Partial<QuantizeWorkerRequest>;
    if (request?.type !== 'libmonet.quantize' || request.id === undefined) return;
    try {
      const result = quantizeArgbPixels(request.pixels ?? [], request.colorCount ?? 128);
      const response: QuantizeWorkerResponse = {
        id: request.id,
        type: 'libmonet.quantize.result',
        result: serializeQuantizerResultEntries(result),
      };
      scope.postMessage(response);
    } catch (error) {
      const response: QuantizeWorkerResponse = {
        id: request.id,
        type: 'libmonet.quantize.result',
        error: error instanceof Error ? error.message : String(error),
      };
      scope.postMessage(response);
    }
  });
}

// When this module is loaded as the worker entry point, install the default
// handler. In window/main-thread imports, DedicatedWorkerGlobalScope is absent.
const globalWithWorkerCtor = globalThis as typeof globalThis & {DedicatedWorkerGlobalScope?: new (...args: never[]) => unknown};
if (globalWithWorkerCtor.DedicatedWorkerGlobalScope !== undefined && globalThis instanceof globalWithWorkerCtor.DedicatedWorkerGlobalScope) {
  installQuantizeWorkerHandler(globalThis as unknown as QuantizeWorkerScope);
}

import {describe, expect, test} from 'vitest';
import {
  deserializeQuantizerResultEntries,
  installQuantizeWorkerHandler,
  quantizeArgbPixels,
  quantizeArgbPixelsInWorker,
  serializeQuantizerResultEntries,
  type QuantizeWorkerRequest,
  type QuantizeWorkerResponse,
  type QuantizeWorkerScope,
  type WorkerLike,
} from '../index.js';

class FakeWorker implements WorkerLike {
  terminated = false;
  private mainListeners = new Set<(event: MessageEvent<unknown>) => void>();
  private handler?: (event: MessageEvent<unknown>) => void;
  readonly sent: unknown[] = [];

  constructor() {
    const scope: QuantizeWorkerScope = {
      addEventListener: (_type: 'message', listener: (event: MessageEvent<unknown>) => void) => { this.handler = listener; },
      postMessage: (message: unknown) => {
        queueMicrotask(() => {
          for (const listener of this.mainListeners) listener({data: message} as MessageEvent<unknown>);
        });
      },
    };
    installQuantizeWorkerHandler(scope);
  }

  postMessage(message: unknown): void {
    this.sent.push(message);
    this.handler?.({data: message} as MessageEvent<unknown>);
  }

  addEventListener(_type: 'message', listener: (event: MessageEvent<unknown>) => void): void {
    this.mainListeners.add(listener);
  }

  removeEventListener(_type: 'message', listener: (event: MessageEvent<unknown>) => void): void {
    this.mainListeners.delete(listener);
  }

  terminate(): void { this.terminated = true; }
}

describe('quantize worker service', () => {
  test('serializes quantizer results as ordered entries', () => {
    const result = quantizeArgbPixels([0xffff0000, 0xffff0000, 0xff0000ff], 2);
    const serialized = serializeQuantizerResultEntries(result);
    const roundTripped = deserializeQuantizerResultEntries(serialized);
    expect(Array.from(roundTripped.argbToCount.entries())).toEqual(Array.from(result.argbToCount.entries()));
  });

  test('quantizeArgbPixelsInWorker matches direct quantization', async () => {
    const pixels = [0xffff0000, 0xffff0000, 0xff00ff00, 0xff0000ff, 0xff0000ff];
    const direct = quantizeArgbPixels(pixels, 3);
    const fake = new FakeWorker();
    const workerResult = await quantizeArgbPixelsInWorker(pixels, 3, fake, {terminateWhenDone: true});
    expect(Array.from(workerResult.argbToCount.entries())).toEqual(Array.from(direct.argbToCount.entries()));
    expect(fake.terminated).toBe(true);
    expect((fake.sent[0] as QuantizeWorkerRequest).type).toBe('libmonet.quantize');
  });

  test('worker handler returns errors for invalid requests', async () => {
    const fake = new FakeWorker();
    const response = await new Promise<QuantizeWorkerResponse>(resolve => {
      fake.addEventListener('message', event => resolve(event.data as QuantizeWorkerResponse));
      fake.postMessage({id: 99, type: 'libmonet.quantize', pixels: undefined, colorCount: -1});
    });
    expect(response.type).toBe('libmonet.quantize.result');
    expect(response.id).toBe(99);
    expect(response.result ?? response.error).toBeDefined();
  });
});

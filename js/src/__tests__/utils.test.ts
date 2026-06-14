import {describe, expect, test} from 'vitest';
import {LruCache, lerpDouble, signum, sizeScale} from '../index.js';

describe('core math utilities', () => {
  test('signum mirrors Dart core/math.dart', () => {
    expect(signum(-2)).toBe(-1);
    expect(signum(0)).toBe(0);
    expect(signum(3.5)).toBe(1);
  });

  test('lerpDouble mirrors Dart lerp', () => {
    expect(lerpDouble(10, 20, 0)).toBe(10);
    expect(lerpDouble(10, 20, 0.25)).toBe(12.5);
    expect(lerpDouble(10, 20, 1)).toBe(20);
    expect(() => lerpDouble(0, 1, -0.1)).toThrow(RangeError);
    expect(() => lerpDouble(0, 1, 1.1)).toThrow(RangeError);
  });
});

describe('sizeScale utility', () => {
  test('returns square-root area scale', () => {
    expect(sizeScale(0)).toBe(0);
    expect(sizeScale(0.25)).toBe(0.5);
    expect(sizeScale(1)).toBe(1);
  });
});

describe('LruCache', () => {
  test('evicts least recently used and bumps on read', () => {
    expect(() => new LruCache<string, number>(0)).toThrow(RangeError);
    const lru = new LruCache<string, number>(2);
    lru.set('a', 1);
    lru.set('b', 2);
    expect(lru.get('a')).toBe(1);
    lru.set('c', 3);
    expect(lru.containsKey('a')).toBe(true);
    expect(lru.containsKey('b')).toBe(false);
    expect([...lru.keysUnsafeForIteration()]).toEqual(['a', 'c']);
  });

  test('putIfAbsent and copy preserve Dart semantics', () => {
    const lru = new LruCache<string, number | null>(2);
    lru.set('nullable', null);
    expect(lru.putIfAbsent('nullable', () => 1)).toBeNull();
    expect([...lru.keysUnsafeForIteration()]).toEqual(['nullable']);
    expect(lru.putIfAbsent('new', () => 2)).toBe(2);
    const copy = lru.copy();
    lru.set('third', 3);
    expect([...copy.entries()]).toEqual([['nullable', null], ['new', 2]]);
    expect([...lru.entries()]).toEqual([['new', 2], ['third', 3]]);
  });
});

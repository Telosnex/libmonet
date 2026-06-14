export class LruCache<K, V> {
  private readonly map = new Map<K, V>();

  constructor(readonly capacity: number) {
    if (capacity <= 0) throw new RangeError('capacity must be > 0');
  }

  get(key: K): V | undefined {
    if (!this.map.has(key)) return undefined;
    const value = this.map.get(key) as V;
    this.map.delete(key);
    this.map.set(key, value);
    return value;
  }

  set(key: K, value: V): void {
    const haveKey = this.map.has(key);
    if (!haveKey && this.map.size === this.capacity) {
      const first = this.map.keys().next().value as K | undefined;
      if (first !== undefined) this.map.delete(first);
    }
    if (haveKey) this.map.delete(key);
    this.map.set(key, value);
  }

  remove(key: K): void { this.map.delete(key); }
  containsKey(key: K): boolean { return this.map.has(key); }
  clear(): void { this.map.clear(); }
  getValue(key: K): V | undefined { return this.get(key); }
  putValue(key: K, value: V): void { this.set(key, value); }

  values(): IterableIterator<V> { return this.map.values(); }
  keysUnsafeForIteration(): IterableIterator<K> { return this.map.keys(); }
  entries(): IterableIterator<[K, V]> { return this.map.entries(); }

  copy(): LruCache<K, V> {
    const clone = new LruCache<K, V>(this.capacity);
    for (const [key, value] of this.map.entries()) clone.map.set(key, value);
    return clone;
  }

  putIfAbsent(key: K, ifAbsent: () => V): V {
    if (this.map.has(key)) return this.get(key) as V;
    const value = ifAbsent();
    this.set(key, value);
    return value;
  }
}

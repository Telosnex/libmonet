import 'dart:collection';

class LruCache<K, V> {
  LruCache({required this.capacity}) : assert(capacity > 0);

  final int capacity;
  // ignore: prefer_collection_literals
  final _map = LinkedHashMap<K, V>();

  // ---------- public API -----------------------------------------------------

  /// Lookup that also bumps the entry to MRU.
  ///
  /// Uses [containsKey] rather than null-checking the value, so that
  /// nullable [V] types with legitimately stored `null` values are
  /// handled correctly (bumped to MRU and returned, not deleted).
  V? operator [](K key) {
    if (!_map.containsKey(key)) return null;
    final val = _map.remove(key); // unlink
    _map[key] = val as V; // re-insert at tail
    return val;
  }

  /// Insert/update; evicts LRU if the cache is full.
  void operator []=(K key, V value) {
    final haveKey = _map.containsKey(key); // one lookup
    if (!haveKey && _map.length == capacity) {
      _map.remove(_map.keys.first); // evict eldest
    }
    if (haveKey) _map.remove(key); // unlink old node (no-op if new)
    _map[key] = value; // insert as MRU
  }

  void remove(K key) => _map.remove(key);
  bool containsKey(K key) => _map.containsKey(key);
  void clear() => _map.clear();
  V? getValue(K key) => this[key];
  void putValue(K key, V value) {
    this[key] = value;
  }

  /// Returns all values in the cache.
  Iterable<V> get values => _map.values;
  Iterable<K> get keysUnsafeForIteration => _map.keys;
  Iterable<MapEntry<K, V>> get entries => _map.entries;

  /// Shallow clone; values themselves are *not* copied.
  LruCache<K, V> copy() {
    final clone = LruCache<K, V>(capacity: capacity);
    clone._map.addAll(_map); // order preserved
    return clone;
  }

  /// Look up the value of [key], or add a new entry if it isn't there.
  ///
  /// Returns the value associated to [key], if there is one.
  /// Otherwise calls [ifAbsent] to get a new value, associates [key] to
  /// that value, and then returns the new value.
  ///
  /// That is, if the key is currently in the map,
  /// `map.putIfAbsent(key, ifAbsent)` is equivalent to `map[key]`.
  /// If the key is not currently in the map,
  /// it's instead equivalent to `map[key] = ifAbsent()`
  /// (but without any guarantee that the `[]` and `[]=` operators are
  /// actually called to achieve that effect).
  ///
  /// ```dart
  /// final diameters = <num, String>{1.0: 'Earth'};
  /// final otherDiameters = <double, String>{0.383: 'Mercury', 0.949: 'Venus'};
  ///
  /// for (final item in otherDiameters.entries) {
  ///   diameters.putIfAbsent(item.key, () => item.value);
  /// }
  /// print(diameters); // {1.0: Earth, 0.383: Mercury, 0.949: Venus}
  ///
  /// // If the key already exists, the current value is returned.
  /// final result = diameters.putIfAbsent(0.383, () => 'Random');
  /// print(result); // Mercury
  /// print(diameters); // {1.0: Earth, 0.383: Mercury, 0.949: Venus}
  /// ```
  /// The [ifAbsent] function is allowed to modify the map,
  /// and if so, it behaves the same as the equivalent `map[key] = ifAbsent()`.
  ///
  /// Uses [containsKey] rather than null-checking, so that nullable [V]
  /// types with stored `null` values return the existing value rather
  /// than invoking [ifAbsent].
  V putIfAbsent(K key, V Function() ifAbsent) {
    if (_map.containsKey(key)) {
      return this[key] as V; // bumps to MRU and returns
    }
    final newValue = ifAbsent();
    this[key] = newValue;
    return newValue;
  }
}

import 'dart:collection';

/// A fixed-capacity least-recently-used cache.
///
/// A [HashMap] of nodes threaded on a doubly linked list, eldest first. Read,
/// insert, bump, and evict are O(1). A [LinkedHashMap] with remove/reinsert
/// is not: each removal at the front leaves a deleted slot that
/// `keys.first` walks past until the map compacts, which made a full cache
/// with many misses several times slower than no cache.
class LruCache<K, V> {
  LruCache({required this.capacity, this.onEvict}) : assert(capacity > 0);

  final int capacity;
  final void Function(V value)? onEvict;
  final _nodes = HashMap<K, _LruNode<K, V>>();

  /// Sentinel: [_LruNode.next] is the eldest entry, [_LruNode.previous] the
  /// newest.
  final _head = _LruLink<K, V>();

  /// Bumped on structural changes so iterators can detect them.
  int _modifications = 0;

  // ---------- public API -----------------------------------------------------

  /// Lookup that also bumps the entry to MRU.
  ///
  /// Nullable [V] types with a stored `null` are a hit: bumped and returned.
  V? operator [](K key) {
    final node = _nodes[key];
    if (node == null) return null;
    _moveToNewest(node);
    return node.value;
  }

  /// Insert/update; evicts LRU if the cache is full.
  void operator []=(K key, V value) {
    final existing = _nodes[key];
    if (existing != null) {
      final old = existing.value;
      existing.value = value;
      _moveToNewest(existing);
      if (!identical(old, value) && old != null) onEvict?.call(old);
      return;
    }
    if (_nodes.length == capacity) {
      final eldest = _head.next as _LruNode<K, V>;
      _unlink(eldest);
      _nodes.remove(eldest.key);
      final evicted = eldest.value;
      if (evicted != null) onEvict?.call(evicted);
    }
    final node = _LruNode<K, V>(key, value);
    _nodes[key] = node;
    _linkNewest(node);
  }

  void remove(K key) {
    final node = _nodes.remove(key);
    if (node == null) return;
    _unlink(node);
    final old = node.value;
    if (old != null) onEvict?.call(old);
  }

  bool containsKey(K key) => _nodes.containsKey(key);

  void clear() {
    final callback = onEvict;
    if (callback != null) {
      for (var link = _head.next; link != _head; link = link.next) {
        final value = (link as _LruNode<K, V>).value;
        if (value != null) callback(value);
      }
    }
    _nodes.clear();
    _head
      ..next = _head
      ..previous = _head;
    _modifications++;
  }

  V? getValue(K key) => this[key];
  void putValue(K key, V value) {
    this[key] = value;
  }

  /// All values, eldest first.
  Iterable<V> get values => _LruIterable(this, (node) => node.value);

  /// All keys, eldest first. The cache must not change during iteration.
  Iterable<K> get keysUnsafeForIteration =>
      _LruIterable(this, (node) => node.key);

  Iterable<MapEntry<K, V>> get entries =>
      _LruIterable(this, (node) => MapEntry(node.key, node.value));

  /// Shallow clone; values themselves are *not* copied.
  LruCache<K, V> copy() {
    final clone = LruCache<K, V>(capacity: capacity, onEvict: onEvict);
    for (var link = _head.next; link != _head; link = link.next) {
      final node = link as _LruNode<K, V>;
      final copy = _LruNode<K, V>(node.key, node.value);
      clone._nodes[node.key] = copy;
      clone._linkNewest(copy);
    }
    return clone;
  }

  void _moveToNewest(_LruNode<K, V> node) {
    if (identical(node, _head.previous)) return;
    _unlink(node);
    _linkNewest(node);
  }

  void _linkNewest(_LruNode<K, V> node) {
    final newest = _head.previous;
    node
      ..previous = newest
      ..next = _head;
    newest.next = node;
    _head.previous = node;
    _modifications++;
  }

  void _unlink(_LruNode<K, V> node) {
    node.previous.next = node.next;
    node.next.previous = node.previous;
    _modifications++;
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
  /// Nullable [V] types with a stored `null` return the existing value
  /// rather than invoking [ifAbsent].
  V putIfAbsent(K key, V Function() ifAbsent) {
    final node = _nodes[key];
    if (node != null) {
      _moveToNewest(node);
      return node.value;
    }
    final newValue = ifAbsent();
    this[key] = newValue;
    return newValue;
  }
}

/// A position on the list. The cache's sentinel is a bare link.
class _LruLink<K, V> {
  _LruLink() {
    previous = this;
    next = this;
  }

  late _LruLink<K, V> previous;
  late _LruLink<K, V> next;
}

final class _LruNode<K, V> extends _LruLink<K, V> {
  _LruNode(this.key, this.value);

  final K key;
  V value;
}

/// A live, eldest-first view. `length` and `first` are O(1), so trimming by
/// `remove(keys.first)` in a loop stays linear.
final class _LruIterable<K, V, T> extends Iterable<T> {
  const _LruIterable(this._cache, this._project);

  final LruCache<K, V> _cache;
  final T Function(_LruNode<K, V> node) _project;

  @override
  Iterator<T> get iterator => _LruIterator(_cache, _project);

  @override
  int get length => _cache._nodes.length;

  @override
  bool get isEmpty => _cache._nodes.isEmpty;

  @override
  bool get isNotEmpty => _cache._nodes.isNotEmpty;

  @override
  T get first {
    final eldest = _cache._head.next;
    if (identical(eldest, _cache._head)) throw StateError('No element');
    return _project(eldest as _LruNode<K, V>);
  }

  @override
  T get last {
    final newest = _cache._head.previous;
    if (identical(newest, _cache._head)) throw StateError('No element');
    return _project(newest as _LruNode<K, V>);
  }
}

final class _LruIterator<K, V, T> implements Iterator<T> {
  _LruIterator(this._cache, this._project)
    : _modifications = _cache._modifications,
      _node = _cache._head;

  final LruCache<K, V> _cache;
  final T Function(_LruNode<K, V> node) _project;
  final int _modifications;
  _LruLink<K, V> _node;
  T? _current;

  @override
  T get current => _current as T;

  @override
  bool moveNext() {
    if (_modifications != _cache._modifications) {
      throw ConcurrentModificationError(_cache);
    }
    final next = _node.next;
    if (identical(next, _cache._head)) {
      _current = null;
      return false;
    }
    _node = next;
    _current = _project(next as _LruNode<K, V>);
    return true;
  }
}

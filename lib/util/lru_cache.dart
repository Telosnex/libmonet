import 'dart:collection';

class LruCache<K, V> {
  final _cacheData = <K, V>{};
  final _keys = Queue<K>();
  final int capacity;

  LruCache({required this.capacity});

  V? operator [](K key) {
    return getValue(key);
  }

  void operator []=(K key, V value) {
    putValue(key, value);
  }

  V? getValue(K key) {
    V? value = _cacheData[key];
    if (value != null) {
      _keys.remove(key);
      _keys.addFirst(key);
    }
    return value;
  }

  void putValue(K key, V value) {
    if (!_cacheData.containsKey(key)) {
      if (_keys.length == capacity) {
        K lastKey = _keys.removeLast();
        _cacheData.remove(lastKey);
      }
      _keys.addFirst(key);
    } else {
      _keys.remove(key);
      _keys.addFirst(key);
    }
    _cacheData[key] = value;
  }
}

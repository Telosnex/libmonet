import 'package:flutter_test/flutter_test.dart';
import 'package:monet_ui/util/lru_cache.dart';

void main() {
  group('LruCache', () {
    test('iterates eldest to newest and evicts the eldest', () {
      final evicted = <int>[];
      final cache = LruCache<String, int>(capacity: 3, onEvict: evicted.add);
      cache['a'] = 1;
      cache['b'] = 2;
      cache['c'] = 3;
      expect(cache.keysUnsafeForIteration, ['a', 'b', 'c']);
      expect(cache['a'], 1, reason: 'a read bumps a to newest');
      expect(cache.keysUnsafeForIteration, ['b', 'c', 'a']);
      cache['d'] = 4;
      expect(evicted, [2]);
      expect(cache.keysUnsafeForIteration, ['c', 'a', 'd']);
      expect(cache.values, [3, 1, 4]);
      expect(
        [for (final e in cache.entries) '${e.key}${e.value}'],
        ['c3', 'a1', 'd4'],
      );
      expect(cache.keysUnsafeForIteration.length, 3);
      expect(cache.keysUnsafeForIteration.first, 'c');
    });

    test('update replaces, bumps, and evicts the replaced value', () {
      final evicted = <int>[];
      final cache = LruCache<String, int>(capacity: 2, onEvict: evicted.add);
      cache['a'] = 1;
      cache['b'] = 2;
      // ignore: avoid-unnecessary-reassignment
      cache['a'] = 10;
      expect(evicted, [1]);
      expect(cache.keysUnsafeForIteration, ['b', 'a']);
      cache['a'] = 10;
      expect(evicted, [1], reason: 'the identical value is not evicted');
    });

    test('a stored null is a hit', () {
      final cache = LruCache<String, int?>(capacity: 2);
      cache['a'] = null;
      cache['b'] = 1;
      expect(cache.containsKey('a'), isTrue);
      expect(cache['a'], isNull);
      expect(cache.keysUnsafeForIteration, ['b', 'a']);
      expect(cache.putIfAbsent('a', () => 5), isNull);
      expect(cache.putIfAbsent('c', () => 5), 5);
      expect(cache.keysUnsafeForIteration, ['a', 'c']);
    });

    test('remove, clear, and copy', () {
      final evicted = <int>[];
      final cache = LruCache<String, int>(capacity: 3, onEvict: evicted.add);
      cache['a'] = 1;
      cache['b'] = 2;
      cache['c'] = 3;
      cache.remove('b');
      cache.remove('missing');
      expect(evicted, [2]);
      expect(cache.keysUnsafeForIteration, ['a', 'c']);

      final clone = cache.copy();
      clone['z'] = 26;
      cache['a'];
      expect(clone.keysUnsafeForIteration, ['a', 'c', 'z']);
      expect(cache.keysUnsafeForIteration, ['c', 'a']);

      cache.clear();
      expect(evicted, [2, 3, 1]);
      expect(cache.keysUnsafeForIteration, isEmpty);
      expect(clone.values, [1, 3, 26]);
    });

    test('evicting by removing keys.first in a loop', () {
      // markdown_column_parser and tool_search_catalog trim this way.
      final cache = LruCache<int, int>(capacity: 100);
      for (var i = 0; i < 10; i++) {
        cache[i] = i;
      }
      while (cache.keysUnsafeForIteration.length > 4) {
        cache.remove(cache.keysUnsafeForIteration.first);
      }
      expect(cache.keysUnsafeForIteration, [6, 7, 8, 9]);
    });

    test('mutation during iteration throws', () {
      final cache = LruCache<int, int>(capacity: 4);
      cache[1] = 1;
      cache[2] = 2;
      expect(() {
        for (final key in cache.keysUnsafeForIteration) {
          cache[key + 10] = key;
        }
      }, throwsA(isA<ConcurrentModificationError>()));
    });

    test('long churn at capacity matches a reference model', () {
      final cache = LruCache<int, int>(capacity: 64);
      final model = <int>[];
      var seed = 7;
      for (var i = 0; i < 20000; i++) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        final key = seed % 200;
        if (seed.isEven) {
          final hit = cache[key];
          expect(hit, model.contains(key) ? key : null);
          if (model.remove(key)) model.add(key);
        } else {
          cache[key] = key;
          if (!model.remove(key) && model.length == 64) model.removeAt(0);
          model.add(key);
        }
      }
      expect(cache.keysUnsafeForIteration, model);
    });
  });
}

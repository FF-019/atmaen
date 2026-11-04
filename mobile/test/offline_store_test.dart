import 'package:flutter_test/flutter_test.dart';

import 'package:atmaen/core/offline_store.dart';

void main() {
  group('normalize', () {
    test('drops diacritics and the definite article', () {
      expect(OfflineStore.normalize('الكُلُور'), OfflineStore.normalize('كلور'));
    });

    test('unifies ta marbuta and alef forms', () {
      expect(OfflineStore.normalize('بطارية'), OfflineStore.normalize('بطاريه'));
      expect(OfflineStore.normalize('أسيتون'), OfflineStore.normalize('اسيتون'));
    });

    test('lowercases latin text', () {
      expect(OfflineStore.normalize('Panadol'), 'panadol');
    });
  });
}

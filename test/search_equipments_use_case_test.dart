import 'package:app_mantenimiento/models/equipment.dart';
import 'package:app_mantenimiento/models/media_item.dart';
import 'package:app_mantenimiento/use_cases/search_equipments_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchEquipmentsUseCase', () {
    const useCase = SearchEquipmentsUseCase();

    final source = <Equipment>[
      const Equipment(
        id: '1',
        title: 'Bomba de agua principal',
        description: 'Mantenimiento preventivo',
        status: 'pendiente',
        priority: 'media',
        location: '',
        piso: '',
        area: '',
        areaTecnica: '',
        tags: <String>['bomba', 'agua'],
        media: <MediaItem>[],
      ),
      const Equipment(
        id: '2',
        title: 'Tablero electrico UTI',
        description: 'Revision de contactores',
        status: 'pendiente',
        priority: 'alta',
        location: '',
        piso: '',
        area: '',
        areaTecnica: '',
        tags: <String>['electrico'],
        media: <MediaItem>[],
      ),
    ];

    test('retorna todo cuando termino vacio', () {
      final result = useCase.call(source: source, term: '   ');
      expect(result.length, 2);
    });

    test('filtra por titulo y tags', () {
      final byTitle = useCase.call(source: source, term: 'tablero');
      expect(byTitle.length, 1);
      expect(byTitle.first.id, '2');

      final byTag = useCase.call(source: source, term: 'agua');
      expect(byTag.length, 1);
      expect(byTag.first.id, '1');
    });
  });
}

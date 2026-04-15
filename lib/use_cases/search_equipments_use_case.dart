import '../models/equipment.dart';

class SearchEquipmentsUseCase {
  const SearchEquipmentsUseCase();

  List<Equipment> call({
    required List<Equipment> source,
    required String term,
  }) {
    final normalized = term.trim().toLowerCase();
    if (normalized.isEmpty) return source;

    return source
        .where(
          (equipment) =>
              equipment.title.toLowerCase().contains(normalized) ||
              equipment.description.toLowerCase().contains(normalized) ||
              equipment.tags.any(
                (tag) => tag.toLowerCase().contains(normalized),
              ),
        )
        .toList();
  }
}

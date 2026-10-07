import 'package:flutter_test/flutter_test.dart';

import '../lib/models/operation.dart';

Operation operation(Frequence frequency, DateTime start) => Operation(
  id: 'test',
  desc: 'Test',
  montant: 10,
  depense: true,
  date: start,
  banque: 'Test',
  f: frequency,
);

void main() {
  test('weekly dates include every week', () {
    final op = operation(Frequence.semaine, DateTime(2026, 1, 5));
    expect(op.occurrencesUntil(DateTime(2026, 2, 2)).toList(), [
      DateTime(2026, 1, 5),
      DateTime(2026, 1, 12),
      DateTime(2026, 1, 19),
      DateTime(2026, 1, 26),
      DateTime(2026, 2, 2),
    ]);
  });
  test('monthly 31 resumes after short months without drifting', () {
    final op = operation(Frequence.mois, DateTime(2026, 1, 31));
    expect(op.occurrencesUntil(DateTime(2026, 5, 31)).toList(), [
      DateTime(2026, 1, 31),
      DateTime(2026, 3, 31),
      DateTime(2026, 5, 31),
    ]);
  });
  test('quarterly dates survive a month without the start day', () {
    final op = operation(Frequence.trimestre, DateTime(2026, 1, 31));
    expect(op.occurrencesUntil(DateTime(2026, 10, 31)).toList(), [
      DateTime(2026, 1, 31),
      DateTime(2026, 7, 31),
      DateTime(2026, 10, 31),
    ]);
  });
  test('yearly leap day resumes in the next leap year', () {
    final op = operation(Frequence.an, DateTime(2024, 2, 29));
    expect(op.occurrencesUntil(DateTime(2028, 2, 29)).toList(), [
      DateTime(2024, 2, 29),
      DateTime(2028, 2, 29),
    ]);
  });
  test('exclusions and recurrence end are respected', () {
    final op = operation(Frequence.semaine, DateTime(2026, 1, 5));
    op.exclusions.add('2026-01-12');
    op.finRecurrence = DateTime(2026, 1, 19);
    expect(op.occurrencesUntil(DateTime(2026, 2, 2)).toList(), [
      DateTime(2026, 1, 5),
      DateTime(2026, 1, 19),
    ]);
  });
  test('point past removes past unchecks and preserves future ones', () {
    final op = operation(Frequence.semaine, DateTime(2026, 1, 5));
    op.pointages.addAll(['2026-01-05', '2026-01-12', '2026-01-19']);
    op.autoPointPast(DateTime(2026, 1, 12));
    expect(op.pointages, ['2026-01-19']);
    expect(op.isPointed(DateTime(2026, 1, 5)), true);
    expect(op.isPointed(DateTime(2026, 1, 19)), false);
  });
  test('single operation is counted only at or after its date', () {
    final op = operation(Frequence.ponctuel, DateTime(2026, 1, 5));
    expect(op.occurrencesUntil(DateTime(2026, 1, 4)).toList(), <DateTime>[]);
    expect(op.occurrencesUntil(DateTime(2026, 1, 6)).toList(), [
      DateTime(2026, 1, 5),
    ]);
  });
  test('daily dates stay at midnight across clock changes', () {
    final op = operation(Frequence.jour, DateTime(2026, 10, 24));
    expect(op.occurrencesUntil(DateTime(2026, 10, 27)).toList(), [
      DateTime(2026, 10, 24),
      DateTime(2026, 10, 25),
      DateTime(2026, 10, 26),
      DateTime(2026, 10, 27),
    ]);
  });
}

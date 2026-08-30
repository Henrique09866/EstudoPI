import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/study_cycle_subject.dart';

void main() {
  test('matéria do ciclo e marcação preservam dados no mapa', () {
    const subject = StudyCycleSubject(
      id: 'math',
      name: 'Matemática',
      colorIndex: 2,
    );
    final checkIn = StudyCycleCheckIn(
      subjectId: subject.id,
      day: DateTime(2026, 8, 29, 18),
    );

    expect(StudyCycleSubject.fromMap(subject.toMap()), subject);
    expect(StudyCycleCheckIn.fromMap(checkIn.toMap()), checkIn);
    expect(checkIn.id, 'math@2026-08-29');
  });

  test('calendário do ciclo inicia a semana na segunda-feira', () {
    final days = StudyCycleCalendar.weekDays(DateTime(2026, 8, 30));

    expect(days.first, DateTime(2026, 8, 24));
    expect(days.last, DateTime(2026, 8, 30));
  });
}

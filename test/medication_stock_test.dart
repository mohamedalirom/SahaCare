import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/domain/entities/medication_stock.dart';

void main() {
  StockQuantity q(String value) => StockQuantity.parse(value);
  MedicationStock stock({
    String remaining = '10',
    String threshold = '2',
    bool enabled = true,
    int anomalies = 0,
    StockUnit unit = StockUnit.tablet,
  }) => MedicationStock(
    enabled: enabled,
    unit: unit,
    initialQuantity: q('10'),
    remaining: q(remaining),
    unitsPerDose: q('1'),
    lowThreshold: q(threshold),
    referenceQuantity: q('10'),
    pendingAnomalies: anomalies,
  );

  test('fractional quantities use exact integers, accept comma and render without rounding', () {
    expect(q('2,125').milliUnits, 2125);
    expect(q('0.1') + q('0.1') + q('0.1'), q('0.3'));
    expect((q('10') - q('0.125')).display, '9,875');
    expect(StockQuantity(-125).display, '-0,125');
    expect(q('0002.500').display, '2,5');
  });
  test('invalid inputs, excess precision, negative counts and overflow are rejected', () {
    for (final value in [
      '',
      '-1',
      '1.0001',
      '1,2,3',
      '500 mg',
      'NaN',
      'Infinity',
      '1e3',
      '1000000001',
    ]) {
      expect(() => q(value), throwsFormatException, reason: value);
    }
    expect(
      () => StockQuantity(StockQuantity.maxMilliUnits + 1),
      throwsArgumentError,
    );
  });
  test(
    'units are explicit; mg is never converted to tablets or capsule counts',
    () {
      StockUnit.milligram.validate(q('500'));
      StockUnit.milliliter.validate(q('2.5'));
      StockUnit.tablet.validate(q('0.5'));
      expect(() => StockUnit.capsule.validate(q('0.5')), throwsArgumentError);
      expect(() => StockUnit.drop.validate(q('0.5')), throwsArgumentError);
      expect(q('500').milliUnits, 500000);
    },
  );
  test('stock is never negative and per-intake amount is positive', () {
    expect(
      () => stock().copyWith(remaining: StockQuantity(-1)),
      throwsArgumentError,
    );
    expect(() => stock().copyWith(unitsPerDose: q('0')), throwsArgumentError);
  });
  test('alerts use inclusive threshold, zero and outstanding anomalies', () {
    expect(stock().alert, StockAlert.normal);
    expect(stock(remaining: '2').alert, StockAlert.low);
    expect(stock(remaining: '0').alert, StockAlert.empty);
    expect(stock(anomalies: 1).alert, StockAlert.anomaly);
    expect(stock(enabled: false, anomalies: 1).alert, StockAlert.disabled);
    expect(stock().copyWith(referenceQuantity: q('0')).fraction, 0);
    expect(stock(remaining: '12').fraction, 1);
  });
}

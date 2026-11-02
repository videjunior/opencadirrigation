import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/units.dart';

/// Numbers read and shown in the notation of the interface language (UI-08,
/// MOD-11): "2.000" is two thousand in Portuguese, "1,500" one thousand five
/// hundred in English, and the screen writes the decimal comma where the
/// language does, while files and exports keep the point.
void main() {
  group('the decimal separator of each language', () {
    test('comma in Portuguese, Spanish, German, French, Indonesian, Turkish, Russian and Vietnamese', () {
      for (final l in ['pt', 'es', 'de', 'fr', 'id', 'tr', 'ru', 'vi']) {
        expect(decimalSeparatorOf(l), ',', reason: l);
      }
      for (final l in ['en', 'zh', 'ja', 'hi', 'mr', 'bn', 'pa', 'te', 'ar', 'ur', 'ha', 'sw']) {
        expect(decimalSeparatorOf(l), '.', reason: l);
      }
    });
  });

  group('reading', () {
    test('a single separator followed by three digits follows the language (it was always decimal)', () {
      // Portuguese: 2.000 L/h and 1.500 m are two thousand and one thousand five hundred
      expect(parseNumber('2.000', decimalSeparator: ','), 2000);
      expect(parseNumber('1.500', decimalSeparator: ','), 1500);
      expect(parseNumber('-1.500', decimalSeparator: ','), -1500);
      // English: 1,234 is one thousand two hundred and thirty-four
      expect(parseNumber('1,234', decimalSeparator: '.'), 1234);
      // without a language the old reading stays (files of unknown notation)
      expect(parseNumber('2.000'), 2);
      expect(parseNumber('1,234'), closeTo(1.234, 1e-12));
    });

    test('anything else keeps its plain reading', () {
      expect(parseNumber('2,5', decimalSeparator: ','), 2.5);
      expect(parseNumber('2.5', decimalSeparator: ','), 2.5, reason: 'a decimal point typed in Portuguese');
      expect(parseNumber('2.50', decimalSeparator: ','), 2.5);
      expect(parseNumber('0.500', decimalSeparator: ','), 0.5, reason: 'a leading zero is no thousands group');
      expect(parseNumber('12.3456', decimalSeparator: ','), 12.3456);
      expect(parseNumber('1.234,56', decimalSeparator: ','), 1234.56);
      expect(parseNumber('1,234.56', decimalSeparator: ','), 1234.56);
      expect(parseNumber('1.234.567', decimalSeparator: ','), 1234567);
      expect(parseNumber('1 234,5', decimalSeparator: ','), 1234.5);
      expect(parseNumber('2,5', decimalSeparator: '.'), 2.5, reason: 'a decimal comma typed in English');
      expect(parseNumber('2000', decimalSeparator: ','), 2000);
      expect(parseNumber('1e3', decimalSeparator: ','), 1000);
      expect(parseNumber('abc', decimalSeparator: ','), isNull);
      expect(parseNumber('', decimalSeparator: ','), isNull);
    });

    test('inside other text (lenient): a price without cents', () {
      expect(parseNumber(r'R$ 1.234', lenient: true, decimalSeparator: ','), 1234);
      expect(parseNumber(r'R$ 1.234,56', lenient: true, decimalSeparator: ','), 1234.56);
      expect(parseNumber(r'US$ 1,234', lenient: true, decimalSeparator: '.'), 1234);
      expect(parseNumber('35 m', lenient: true, decimalSeparator: ','), 35);
    });

    test('what reads two ways', () {
      expect(numberIsAmbiguous('2.000', ','), isTrue);
      expect(numberIsAmbiguous('1,500', '.'), isTrue);
      expect(numberIsAmbiguous('2,000', ','), isFalse, reason: 'a decimal comma in Portuguese');
      expect(numberIsAmbiguous('2.5', ','), isFalse);
      expect(numberIsAmbiguous('12.3456', ','), isFalse);
      expect(numberIsAmbiguous('0.500', ','), isFalse);
      expect(numberIsAmbiguous('1.234.567', ','), isFalse);
    });

    test('the notation of a column read from a file', () {
      expect(guessDecimalSeparator(['1.234,5', '12', '3']), ',');
      expect(guessDecimalSeparator(['12,25', '0,5']), ',');
      expect(guessDecimalSeparator(['0.5', '12.25', '1,234.5']), '.');
      expect(guessDecimalSeparator(['1.234.567', '2']), ',', reason: 'points that group thousands');
      expect(guessDecimalSeparator(['1.500', '2.000']), isNull, reason: 'both readings are possible');
      expect(guessDecimalSeparator(['1', '2']), isNull);
    });
  });

  group('showing', () {
    test('the decimal comma on the screen, the point in the files', () {
      expect(fmtLocale(12.5, 2, 'pt'), '12,50');
      expect(fmtLocale(12.5, 2, 'en'), '12.50');
      expect(fmtLocale(-0.001, 2, 'pt'), '0,00');
      expect(fmt(12.5), '12.50', reason: 'exports and the AI keep the point');
    });

    test('the numbers inside a text', () {
      expect(localizeNumbers('12.35 ha', 'pt'), '12,35 ha');
      expect(localizeNumbers('15.2 m³/h @ 31.4 m.c.a.', 'pt'), '15,2 m³/h @ 31,4 m.c.a.');
      expect(localizeNumbers('12.35 ha', 'en'), '12.35 ha');
      expect(localizeNumbers('v1.6.0+14', 'pt'), 'v1.6.0+14', reason: 'a version is no number');
      expect(localizeNumbers(r'R$ 1.234,56', 'pt'), r'R$ 1.234,56', reason: 'a price already in Portuguese');
      expect(localizeNumbers(r'US$ 1,234.56', 'pt'), r'US$ 1,234.56');
      expect(localizeNumbers('e12.5', 'pt'), 'e12.5', reason: 'inside a word');
      expect(localizeNumbers('DN 32 PN 4.0', 'pt'), 'DN 32 PN 4,0');
      expect(localizeNumbers('-3.25', 'de'), '-3,25');
    });
  });
}

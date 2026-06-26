import 'package:test/test.dart';
import '../lib/go/sgf_parser.dart';
import '../lib/go/stone.dart';

void main() {
  group('SgfParser', () {
    test('parses minimal SGF with one move', () {
      const sgf = '(;GM[1]FF[4]SZ[9];B[cd])';
      final (history, _) = SgfParser.parse(sgf, defaultSize: 9);
      expect(history.data.moveNumber, equals(0)); // rewound to start

      // Navigate to the move.
      history.next();
      expect(history.data.moveNumber, equals(1));
      expect(history.data.lastMove, equals([2, 3])); // cd = (2,3) on 9x9
      expect(history.data.lastMoveColor, equals(Stone.black));
    });

    test('parses SGF with two alternating moves', () {
      const sgf = '(;GM[1]FF[4]SZ[9];B[cd];W[ef])';
      final (history, _) = SgfParser.parse(sgf, defaultSize: 9);
      history.toEnd();
      expect(history.data.moveNumber, equals(2));
      expect(history.data.lastMove, equals([4, 5])); // ef = (4,5)
      expect(history.data.lastMoveColor, equals(Stone.white));
    });

    test('parses SGF with komi and handicap in header', () {
      const sgf = '(;GM[1]FF[4]SZ[19]KM[6.5]HA[2];B[pd];W[dd])';
      final (history, info) = SgfParser.parse(sgf);
      expect(history.data.width, equals(19));
      expect(history.data.height, equals(19));
      expect(info.komi, equals(6.5));
      expect(info.handicap, equals(2));
      // Verify moves parse.
      history.toEnd();
      expect(history.data.moveNumber, equals(2));
    });

    test('parses SGF with setup stones (AB)', () {
      const sgf = '(;GM[1]FF[4]SZ[9]AB[cd][ef])';
      final (history, _) = SgfParser.parse(sgf);
      final idx1 = 2 * 9 + 3; // cd = (2,3)
      final idx2 = 4 * 9 + 5; // ef = (4,5)
      expect(history.data.stones[idx1], equals(Stone.black));
      expect(history.data.stones[idx2], equals(Stone.black));
    });

    test('parses SGF with comment', () {
      const sgf = '(;GM[1]FF[4]SZ[9];B[cd]C[test comment])';
      final (history, _) = SgfParser.parse(sgf);
      history.next();
      expect(history.data.comment, equals('test comment'));
    });

    test('parses SGF with variations', () {
      const sgf = '(;GM[1]FF[4]SZ[9];B[cd](;W[ef])(;W[gh]))';
      final (history, _) = SgfParser.parse(sgf);
      history.next(); // B[cd]
      expect(history.data.moveNumber, equals(1));
      expect(history.head.childCount, equals(2)); // two variations
      // Navigate to first variation.
      history.next();
      expect(history.data.lastMove, equals([4, 5])); // ef
    });

    test('serialize round-trip: minimal', () {
      const sgf = '(;GM[1]FF[4]SZ[9]KM[6.5];B[cd];W[ef])';
      final (history, _) = SgfParser.parse(sgf, defaultSize: 9);
      final output = SgfParser.serialize(history);
      // Verify it contains the essential structure.
      expect(output, contains('SZ[9]'));
      expect(output, contains('B[cd]'));
      expect(output, contains('W[ef]'));
    });

    test('SGF coordinate tt passes', () {
      const sgf = '(;GM[1]FF[4]SZ[9];B[tt])';
      final (history, _) = SgfParser.parse(sgf);
      history.next();
      // tt is a pass — lastMove should be null.
      expect(history.data.lastMove, isNull);
    });
  });
}

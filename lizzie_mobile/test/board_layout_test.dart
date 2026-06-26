import 'package:flutter_test/flutter_test.dart';
import 'package:lizzie_mobile/ui/board/board_layout.dart';

void main() {
  group('BoardLayout.compute', () {
    test(
      'cellSize is computed so that SizedBox + 2*Padding exactly fits maxDim',
      () {
        const maxDim = 400.0;
        final layout = BoardLayout.compute(
          width: 19,
          height: 19,
          maxDim: maxDim,
        );
        final total = layout.boardSize.width + 2 * layout.outerPadding.top;
        // The total should equal maxDim (within a small epsilon for float
        // rounding).
        expect(
          (total - maxDim).abs(),
          lessThan(1e-9),
          reason: 'SizedBox + 2*Padding should equal maxDim, got $total',
        );
      },
    );

    test('boardSize shrinks with width', () {
      final small = BoardLayout.compute(width: 9, height: 9, maxDim: 400);
      final large = BoardLayout.compute(width: 19, height: 19, maxDim: 400);
      expect(large.boardSize.width, greaterThan(small.boardSize.width));
    });

    test('non-square boards compute valid dimensions', () {
      // 9x19 board on a 400px maxDim. The cellSize is based on width
      // (the smaller dimension by convention), so the board's
      // height may exceed maxDim if h > w. We just sanity-check the
      // basics here; the UI is responsible for not requesting a
      // non-square board in a square-ish LayoutBuilder.
      final layout = BoardLayout.compute(width: 9, height: 19, maxDim: 400);
      expect(layout.padding, greaterThan(0));
      expect(layout.cellSize, greaterThan(0));
      expect(layout.boardSize.width, layout.cellSize * 8);
      expect(layout.boardSize.height, layout.cellSize * 18);
    });
  });

  group('BoardLayout.toBoardX / toBoardY', () {
    // Use a fixed layout: 19x19, maxDim=400.
    // padding = 400 / 21 * 0.5 = ~9.524
    // cellSize = (400 - 2*9.524) / 19 = ~20.052
    // Stone 0 at LayoutBuilder-relative (9.524 + 0.5*20.052, ...) = (~19.55, ~19.55)
    // Stone 18 at (~19.55 + 18*20.052, ...) = (~380.484, ~380.484)
    final layout = BoardLayout.compute(width: 19, height: 19, maxDim: 400);

    test('taps at exact stone centers map to the right column/row', () {
      for (var i = 0; i < 19; i++) {
        final cx = layout.stoneX(i);
        final cy = layout.stoneY(i);
        expect(layout.toBoardX(cx), i, reason: 'stone $i at x=$cx');
        expect(layout.toBoardY(cy), i, reason: 'stone $i at y=$cy');
      }
    });

    test('taps between two stones round to the nearer one', () {
      // Halfway between stone 5 and stone 6 should round to 5 or 6
      // (banker's rounding may push either way; just verify it's one of
      // the two neighbors).
      final mid = (layout.stoneX(5) + layout.stoneX(6)) / 2;
      final result = layout.toBoardX(mid);
      expect(result, isIn([5, 6]));
    });

    test(
      'taps just outside the board snap to the nearest stone (intentional UX)',
      () {
        // Taps within ~half a cell of the grid should snap to the nearest
        // intersection, not be ignored. This is the desired UX for
        // finger taps that are slightly off the grid line.
        expect(
          layout.toBoardX(layout.stoneX(0) - 1),
          0,
          reason: 'tap 1px left of first stone snaps to first stone',
        );
        expect(
          layout.toBoardX(layout.stoneX(18) + 1),
          18,
          reason: 'tap 1px right of last stone snaps to last stone',
        );
        expect(layout.toBoardY(layout.stoneY(0) - 1), 0);
        expect(layout.toBoardY(layout.stoneY(18) + 1), 18);
      },
    );

    test('taps far outside the board return null', () {
      // A full cell beyond the grid is clearly outside; return null.
      expect(layout.toBoardX(layout.stoneX(0) - layout.cellSize * 2), isNull);
      expect(layout.toBoardX(layout.stoneX(18) + layout.cellSize * 2), isNull);
      expect(layout.toBoardY(layout.stoneY(0) - layout.cellSize * 2), isNull);
      expect(layout.toBoardY(layout.stoneY(18) + layout.cellSize * 2), isNull);
    });

    test(
      'taps on the label area (within the Padding but outside the grid) snap or return null',
      () {
        // Taps within the Padding but well outside the grid are 2+ cells
        // away and should be ignored. A tap 1 cell away from the first
        // stone is on the border of the snap region; depending on the
        // exact padding it may snap to stone 0 or be ignored. We just
        // check that the result is one of those two.
        final justLeft = layout.toBoardX(layout.stoneX(0) - layout.cellSize);
        expect(justLeft, anyOf(isNull, equals(0)));
      },
    );
  });

  group('regression: old cellSize formula caused off-by-one at edges', () {
    test(
      'taps at the right-edge center were off by one with the old formula',
      () {
        // This test documents the bug we just fixed. The old code did
        //   cellSize = renderBox.size.width / (data.width - 1)
        //   x = (dx / cellSize).round()
        // which gave x=18 for the rightmost column when the user tapped
        // at the right edge. Verify the new formula gives the right answer.
        final layout = BoardLayout.compute(width: 19, height: 19, maxDim: 400);

        // Simulate the OLD buggy computation:
        //   oldCellSize = 400 / (19 - 1) = 22.222
        //   oldX = (380.484 / 22.222).round() = 17  (WRONG; should be 18)
        final oldCellSize = 400 / (19 - 1);
        final rightmostStoneLayoutX = layout.stoneX(18);
        final oldComputedX = (rightmostStoneLayoutX / oldCellSize).round();
        expect(
          oldComputedX,
          lessThan(18),
          reason: 'old formula returned $oldComputedX for the rightmost stone',
        );

        // And the NEW formula returns 18 (correct):
        expect(layout.toBoardX(rightmostStoneLayoutX), 18);
      },
    );
  });
}

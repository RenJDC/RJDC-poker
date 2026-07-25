import 'package:flutter/material.dart';
import 'card_selector.dart';

class GridSwipeCardSelector implements CardSelector {
  int? _selectedRank;
  Offset? _swipeDown;
  Offset? _swipeLast;
  int? _swipePointerId;
  bool _isProcessed = false;

  static const double minSwipeDistance = 8.0;

  @override
  Widget buildSelector({
    required BuildContext context,
    required void Function(int rank, int? suit) onCardSelected,
    required VoidCallback onRequestBack,
  }) {
    _resetAll();
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (_isProcessed) return;

        if (_selectedRank == null) {
          return;
        }

        if (_swipePointerId == null) {
          _swipePointerId = event.pointer;
          _swipeDown = event.position;
          _swipeLast = event.position;
        }
      },
      onPointerMove: (event) {
        if (event.pointer != _swipePointerId) return;
        if (_isProcessed) return;
        _swipeLast = event.position;
      },
      onPointerUp: (event) {
        if (_isProcessed) {
          _resetAll();
          return;
        }

        if (_selectedRank == null) {
          return;
        }

        if (event.pointer == _swipePointerId && _swipeDown != null) {
          Offset delta = _swipeLast! - _swipeDown!;
          int? suit = _calculateSuit(delta);

          if (suit != null) {
            onCardSelected(_selectedRank!, suit);
            _isProcessed = true;
          }
          _resetSwipe();
        }
      },
      onPointerCancel: (event) {
        if (event.pointer == _swipePointerId) {
          _resetSwipe();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          if (_isProcessed) return;
          if (_selectedRank != null) return;

          final size = MediaQuery.of(context).size;
          int rank = _calculateRank(details.localPosition, size);

          if (rank >= 14) {
            onCardSelected(rank, null);
            _isProcessed = true;
            return;
          }

          _selectedRank = rank;
        },
        child: Container(color: Colors.black),
      ),
    );
  }

  int _calculateRank(Offset position, Size screenSize) {
    double cellWidth = screenSize.width / 3;
    double cellHeight = screenSize.height / 5;

    int col = (position.dx / cellWidth).floor().clamp(0, 2);
    int row = (position.dy / cellHeight).floor().clamp(0, 4);

    return row * 3 + col + 1;
  }

  int? _calculateSuit(Offset delta) {
    double distance = delta.distance;
    if (distance < minSwipeDistance) return null;

    if (delta.dx.abs() > delta.dy.abs()) {
      return delta.dx > 0 ? 1 : 3;
    } else {
      return delta.dy > 0 ? 2 : 0;
    }
  }

  void _resetSwipe() {
    _swipePointerId = null;
    _swipeDown = null;
    _swipeLast = null;
  }

  void _resetAll() {
    _selectedRank = null;
    _isProcessed = false;
    _resetSwipe();
  }

  @override
  void dispose() {
    _resetAll();
  }
}
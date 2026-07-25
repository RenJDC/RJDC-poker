import 'package:flutter/widgets.dart';

/// 抽象类：定义选择扑克牌的方式
abstract class CardSelector {
  /// 构建选择器界面，该界面负责监听用户输入并决定何时选出一张牌
  /// [context] 用于获取屏幕尺寸等信息
  /// [onCardSelected] 当用户选出一张牌时调用，传入 rank (1-15) 和 suit (0-3 或 null)
  /// [onRequestBack] 当选择器需要回到待机模式时调用（例如点击空白区域）
  Widget buildSelector({
    required BuildContext context,
    required void Function(int rank, int? suit) onCardSelected,
    required VoidCallback onRequestBack,
  });

  /// 释放选择器占用的资源（如定时器、流订阅等）
  void dispose();
}

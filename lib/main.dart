import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'card_selector.dart';
import 'grid_swipe_selector.dart';

void main() {
  runApp(const PokerMagicApp());
}

class PokerMagicApp extends StatelessWidget {
  const PokerMagicApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const PokerMagicHome(),
    );
  }
}

enum AppMode { standby, display }

class PokerMagicHome extends StatefulWidget {
  const PokerMagicHome({super.key});

  @override
  State<PokerMagicHome> createState() => _PokerMagicHomeState();
}

class _PokerMagicHomeState extends State<PokerMagicHome> {
  late CardSelector _selector;
  AppMode _mode = AppMode.standby;
  int? _currentRank; // 1-15
  int? _currentSuit; // 0-3（花色）或 null（大小王）

  @override
  void initState() {
    super.initState();
    _selector = GridSwipeCardSelector();
  }

  @override
  void dispose() {
    _selector.dispose();
    super.dispose();
  }

  void _onCardSelected(int rank, int? suit) {
    setState(() {
      _currentRank = rank;
      _currentSuit = suit;
      _mode = AppMode.display;
    });
  }

  void _onBackToStandby() {
    setState(() {
      _mode = AppMode.standby;
      _currentRank = null;
      _currentSuit = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _mode == AppMode.standby
          ? _selector.buildSelector(
              context: context,
              onCardSelected: _onCardSelected,
              onRequestBack: _onBackToStandby, // 默认选择器未使用，但保留供其他实现调用
            )
          : _buildDisplay(),
    );
  }

  Widget _buildDisplay() {
    final screenHeight = MediaQuery.of(context).size.height;
    final double imageHeight = screenHeight * 0.7;

    return GestureDetector(
      onTap: _onBackToStandby,
      child: Container(
        color: Colors.black,
        child: Center(
          child: (_currentRank == null)
              ? null
              : Image.asset(
                  _getCardImagePath(_currentRank!, _currentSuit),
                  height: imageHeight,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '牌面图片加载失败。\n'
                        '请确认资源存在并已在 pubspec.yaml 的 assets 中声明：\n'
                        '${_getCardImagePath(_currentRank!, _currentSuit)}\n\n'
                        '错误：$error',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  String _getCardImagePath(int rank, int? suit) {
    if (rank == 14) return 'assets/images/xiaowang.png';
    if (rank == 15) return 'assets/images/dawang.png';
    if (suit == null) return ''; // 安全保护
    const suits = ['heitao', 'hongtao', 'meihua', 'fangpian'];
    String suitStr = suits[suit];
    String rankStr;
    if (rank == 1) {
      rankStr = 'A';
    } else if (rank >= 2 && rank <= 10)
      rankStr = rank.toString();
    else if (rank == 11)
      rankStr = 'J';
    else if (rank == 12)
      rankStr = 'Q';
    else if (rank == 13)
      rankStr = 'K';
    else
      rankStr = ''; // 无效
    return 'assets/images/${suitStr}_$rankStr.png';
  }
}

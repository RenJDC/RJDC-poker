import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'card_selector.dart';

/// 语音命令选择器（使用 sherpa-onnx + flutter_sound）
class VoiceCommandCardSelector implements CardSelector {
  // sherpa-onnx 识别器
  OnlineRecognizer? _recognizer;
  OnlineStream? _stream;
  bool _initScheduled = false;
  bool _initInProgress = false;
  bool _listeningScheduled = false;
  static bool _bindingsInited = false;

  // 录音相关
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  StreamController<Uint8List>? _audioController;
  StreamSubscription<Uint8List>? _audioSubscription;
  static bool _isRecorderInitialized = false;

  // 识别结果
  String _lastWords = '';
  int? _lastVoiceRank;
  int? _lastVoiceSuit;

  // 模型文件在 assets 中的路径（保持不变）
  static const List<String> _assetModelFiles = [
    'assets/models/encoder-epoch-99-avg-1.int8.onnx',
    'assets/models/decoder-epoch-99-avg-1.int8.onnx',
    'assets/models/joiner-epoch-99-avg-1.int8.onnx',
    'assets/models/tokens.txt',
  ];

  // 复制后的目标文件路径（在应用文档目录下）
  late String _encoderPath;
  late String _decoderPath;
  late String _joinerPath;
  late String _tokensPath;

  // 外部传入的 setState 回调
  final void Function(VoidCallback) setState;

  VoiceCommandCardSelector({required this.setState});

  @override
  Widget buildSelector({
    required BuildContext context,
    required void Function(int rank, int? suit) onCardSelected,
    required VoidCallback onRequestBack,
  }) {
    if (!_initScheduled && !_initInProgress && _recognizer == null) {
      _initScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initRecognizer(onCardSelected);
      });
    }

    if (_recognizer != null && !_isRecording && !_listeningScheduled) {
      _listeningScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await _startListening(onCardSelected);
        } finally {
          _listeningScheduled = false;
        }
      });
    }

    // 如果要显示屏幕上的提示语

    return GestureDetector(
      onTap: () {
        // 在用户点击时，根据当前整句识别文本解析出“最后一张牌”
        if (_lastWords.isNotEmpty) {
          _parseCommand(
            _lastWords,
            // 这里不直接出牌，只是利用 _parseCommand 更新 _lastVoiceRank/_lastVoiceSuit
            (int _, int? __) {},
          );
        }

        if (_lastVoiceRank != null) {
          final rank = _lastVoiceRank!;
          final suit = _lastVoiceSuit;
          _lastVoiceRank = null;
          _lastVoiceSuit = null;
          setState(() => _lastWords = '');
          // 选牌后暂停本轮聆听，等用户看完牌再返回
          _stopListening();
          onCardSelected(rank, suit);
        }
      },
      onLongPress: onRequestBack,
      // 显示文字
      /*
      child: Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_recognizer == null)
                Text(
                  _lastWords.isNotEmpty ? _lastWords : '正在加载语音模型...\n首次使用需等待几秒',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                )
              else if (!_isRecording)
                Text(
                  _lastWords.isNotEmpty ? _lastWords : '准备就绪，开始说话吧',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                )
              else
                Text(
                  _lastWords.isEmpty ? '正在聆听...' : _lastWords,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
      */
      // 不显示文字
      child: Container(color: Colors.black),
    );
  }

  Future<void> _initRecognizer(
    void Function(int rank, int? suit) onCardSelected,
  ) async {
    if (_initInProgress || _recognizer != null) return;
    _initInProgress = true;
    try {
      print("开始初始化 sherpa-onnx 识别器...");
      setState(() => _lastWords = '准备加载语音模型...');

      // 获取应用文档目录并设置目标路径
      final dir = await getApplicationDocumentsDirectory();
      final targetDir = dir.path;
      _encoderPath = '$targetDir/encoder-epoch-99-avg-1.int8.onnx';
      _decoderPath = '$targetDir/decoder-epoch-99-avg-1.int8.onnx';
      _joinerPath = '$targetDir/joiner-epoch-99-avg-1.int8.onnx';
      _tokensPath = '$targetDir/tokens.txt';

      // 复制模型文件（如果不存在）
      await _copyModelsIfNeeded(targetDir);

      // 检查复制后的文件是否存在
      if (!File(_encoderPath).existsSync()) {
        setState(() => _lastWords = '模型文件复制失败: encoder');
        return;
      }
      if (!File(_decoderPath).existsSync()) {
        setState(() => _lastWords = '模型文件复制失败: decoder');
        return;
      }
      if (!File(_joinerPath).existsSync()) {
        setState(() => _lastWords = '模型文件复制失败: joiner');
        return;
      }
      if (!File(_tokensPath).existsSync()) {
        setState(() => _lastWords = '模型文件复制失败: tokens');
        return;
      }

      print("模型文件检查通过，开始配置识别器...");

      if (!_bindingsInited) {
        // sherpa_onnx 需要先初始化 FFI bindings，否则会抛出
        // "Please initialize sherpa-onnx first"
        try {
          initBindings();
          _bindingsInited = true;
          print("sherpa-onnx bindings 初始化成功");
        } catch (e) {
          print("sherpa-onnx bindings 初始化失败: $e");
          setState(() => _lastWords = '语音引擎初始化失败: bindings error');
          return;
        }
      }

      final config = OnlineRecognizerConfig(
        feat: FeatureConfig(sampleRate: 16000, featureDim: 80),
        model: OnlineModelConfig(
          transducer: OnlineTransducerModelConfig(
            encoder: _encoderPath,
            decoder: _decoderPath,
            joiner: _joinerPath,
          ),
          tokens: _tokensPath,
          numThreads: 2,
          debug: false,
        ),
        decodingMethod: 'greedy_search',
        maxActivePaths: 4,
      );

      _recognizer = OnlineRecognizer(config);
      print("识别器创建成功，开始监听...");
      setState(() => _lastWords = '语音引擎已就绪，正在打开麦克风...');

      // 延迟一下再启动监听，避免竞态条件
      Future.delayed(const Duration(milliseconds: 500), () {
        _startListening(onCardSelected);
      });
    } catch (e) {
      print('初始化 sherpa-onnx 失败: $e');
      print('堆栈: ${StackTrace.current}');
      setState(() => _lastWords = '语音引擎初始化失败: $e');
    } finally {
      _initInProgress = false;
    }
  }

  // 复制模型文件（如果不存在）
  Future<void> _copyModelsIfNeeded(String targetDir) async {
    for (String assetPath in _assetModelFiles) {
      final fileName = assetPath.split('/').last;
      final targetFile = File('$targetDir/$fileName');

      if (!await targetFile.exists()) {
        setState(() => _lastWords = '正在复制模型文件: $fileName...');
        print("复制模型文件: $fileName");

        try {
          // 从 assets 加载
          final byteData = await rootBundle.load(assetPath);
          final buffer = byteData.buffer;
          await targetFile.writeAsBytes(
            buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
          );
          print("完成复制: $fileName");
        } catch (e) {
          print("复制 $fileName 失败: $e");
          rethrow;
        }
      } else {
        print("模型文件已存在: $fileName");
      }
    }
    setState(() => _lastWords = '模型文件准备就绪');
    print("所有模型文件已就绪");
  }

  Future<void> _startListening(
    void Function(int rank, int? suit) onCardSelected,
  ) async {
    // 如果已经在录音或正在初始化，直接返回
    if (_isRecording) {
      print("已经在录音中，跳过");
      return;
    }

    // 如果录音器已被创建但未释放，先强制释放
    if (_recorder != null) {
      await _forceReleaseRecorder();
    }

    PermissionStatus status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _lastWords = '需要麦克风权限');
      return;
    }

    try {
      // 每次创建全新的实例，确保状态干净
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();

      // 录音器完全就绪后再创建识别器
      _audioController = StreamController<Uint8List>();

      await _recorder!.startRecorder(
        toStream: _audioController!.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
      );

      // 延迟200ms再连接识别器，避免资源竞争
      Future.delayed(const Duration(milliseconds: 200), () {
        _audioSubscription = _audioController!.stream.listen(
          (Uint8List data) {
            Float32List samples = _convertUint8ToFloat32(data);
            _processAudio(samples, onCardSelected);
          },
          onError: (error) {
            print('音频流错误: $error');
            _stopListening();
          },
        );

        _isRecording = true;
        setState(() => _lastWords = '正在聆听...');
        print("录音开始成功");
      });
    } catch (e) {
      print("启动录音失败: $e");
      await _forceReleaseRecorder();
      // 避免一开始就吓到用户，不在界面上显示失败文案
      // 可以稍后自动重试一次
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_isRecording) {
          _startListening(onCardSelected);
        }
      });
    }
  }

  // 强制释放录音器
  Future<void> _forceReleaseRecorder() async {
    _isRecording = false;

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    await _audioController?.close();
    _audioController = null;

    // 忽略所有错误，强制释放
    try {
      await _recorder?.stopRecorder();
    } catch (_) {}
    try {
      await _recorder?.closeRecorder();
    } catch (_) {}

    _recorder = null;
  }

  Future<void> _stopListening() async {
    print("停止录音...");
    _isRecording = false;

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    await _audioController?.close();
    _audioController = null;

    try {
      await _recorder?.stopRecorder();
    } catch (e) {
      print("停止录音器时忽略错误: $e");
    }

    try {
      await _recorder?.closeRecorder();
    } catch (e) {
      print("关闭录音器时忽略错误: $e");
    }

    _recorder = null;
    print("录音已停止");
  }

  Float32List _convertUint8ToFloat32(Uint8List data) {
    int length = data.length ~/ 2;
    var samples = Float32List(length);
    for (int i = 0; i < length; i++) {
      int low = data[i * 2];
      int high = data[i * 2 + 1];
      int val = (high << 8) | low;
      if (val > 32767) val -= 65536;
      samples[i] = val / 32768.0;
    }
    return samples;
  }

  // 修正后的音频处理方法
  void _processAudio(
    Float32List samples,
    void Function(int rank, int? suit) onCardSelected,
  ) {
    try {
      if (!_isRecording || _recognizer == null) return;
      if (samples.isEmpty) return;

      // 确保流存在
      _stream ??= _recognizer!.createStream();

      // 将音频数据送入流（需要同时提供 sampleRate）
      _stream!.acceptWaveform(samples: samples, sampleRate: 16000);

      // 按官方推荐：只有在 isReady 时才解码，避免 C++ GetFrames 越界
      while (_recognizer!.isReady(_stream!)) {
        _recognizer!.decode(_stream!);
      }

      // 只更新最后一次完整识别文本，不在这里解析牌面
      final result = _recognizer!.getResult(_stream!);
      final String text = result.text;

      /*
      if (text.isNotEmpty && text != _lastWords) {
        _lastWords = text;
        print("识别到文本: $text");
        setState(() {});
      }
      */

      // 激进方案：每次有新的识别文本时，立即重置流
      if (text.isNotEmpty) {
        // 如果文本发生变化，更新显示
        if (text != _lastWords) {
          _lastWords = text;
          print("识别到文本: $text");
          setState(() {});
        }

        // 检查文本长度，超过50字才重置流
        if (text.length > 50) {
          print("文本长度超过50字，重置流。当前长度: ${text.length}");
          // 重置流
          _stream?.free();
          _stream = _recognizer!.createStream();
          print("流已重置，准备识别下一句");
        }
      }
    } catch (e) {
      print("处理音频时出错: $e");
    }
  }

  void _parseCommand(
    String text,
    void Function(int rank, int? suit) onCardSelected,
  ) {
    // const suits = {'黑桃': 0, '红桃': 1, '梅花': 2, '方块': 3, '方片': 3};
    const suits = {
      // 黑桃 (0)
      '黑桃': 0,
      '黑': 0,
      '黑套': 0,
      '黑逃': 0,
      '黑掏': 0,
      '黑涛': 0,
      '黑滔': 0,
      '黑焘': 0,
      '黑韬': 0,
      '黑匋': 0,
      '黑洮': 0,
      '黑萄': 0,
      '黑梼': 0,
      '黑綯': 0,
      '嘿桃': 0,
      '嘿套': 0,
      '嗨桃': 0,
      '嗨套': 0,
      '核桃': 0,
      '黑陶': 0,
      '黑淘': 0,
      '黑啕': 0,
      '黑弢': 0,
      '黑绹': 0,
      '黑醄': 0,
      '黑騊': 0,
      '黑鼗': 0,

      // 红桃 (1)
      '红桃': 1,
      '红': 1,
      '红套': 1,
      '红逃': 1,
      '红掏': 1,
      '红涛': 1,
      '红滔': 1,
      '红焘': 1,
      '红韬': 1,
      '红匋': 1,
      '红洮': 1,
      '红萄': 1,
      '红梼': 1,
      '红綯': 1,
      '鸿桃': 1,
      '洪桃': 1,
      '虹桃': 1,
      '宏桃': 1,
      '弘桃': 1,
      '红陶': 1,
      '红淘': 1,
      '红啕': 1,
      '红弢': 1,
      '红绹': 1,
      '红醄': 1,
      '红騊': 1,
      '红鼗': 1,
      '哄桃': 1,
      '轰桃': 1,
      '烘桃': 1,
      '蕻桃': 1,
      '薨桃': 1,
      '黉桃': 1,

      // 梅花 (2)
      '梅花': 2,
      '梅': 2,
      '没花': 2,
      '没画': 2,
      '没化': 2,
      '没话': 2,
      '没华': 2,
      '没桦': 2,
      '没铧': 2,
      '没骅': 2,
      '媒花': 2,
      '煤花': 2,
      '霉花': 2,
      '莓花': 2,
      '枚花': 2,
      '眉花': 2,
      '湄花': 2,
      '嵋花': 2,
      '猸花': 2,
      '媚花': 2,
      '魅花': 2,
      '镁花': 2,
      '美花': 2,
      '每花': 2,
      '妹花': 2,
      '昧花': 2,
      '袂花': 2,
      '墨花': 2,
      '默花': 2,
      '陌花': 2,
      '漠花': 2,
      '莫花': 2,
      '寞花': 2,
      '磨花': 2,
      '蘑花': 2,
      '魔花': 2,
      '模花': 2,
      '膜花': 2,
      '抹花': 2,
      '末花': 2,
      '沫花': 2,
      '茉花': 2,
      '秣花': 2,
      '蓦花': 2,
      '麦花': 2,
      '买花': 2,
      '卖花': 2,
      '迈花': 2,
      '脉花': 2,
      '埋花': 2,
      '霾花': 2,
      '玫花': 2,
      '霉画': 2,
      '媒画': 2,
      '煤画': 2,
      '没划': 2,
      '没哗': 2,
      '梅花鹿': 2, // 口语习惯
      // 方块 (3) 和 方片 (3)
      '方块': 3,
      '方片': 3,
      '方': 3,
      '片': 3,
      '快': 3,
      '块': 3,
      '方快': 3,
      '方筷': 3,
      '方侩': 3,
      '方郐': 3,
      '方狯': 3,
      '方脍': 3,
      '方哙': 3,
      '方浍': 3,
      '方蒯': 3,
      '方向': 3,
      '芳香': 3,
      '房款': 3,
      '放款': 3,
      '放快': 3,
      '放筷': 3,
      '房块': 3,
      '房快': 3,
      '防快': 3,
      '纺块': 3,
      '访块': 3,
      '仿块': 3,
      '舫块': 3,
      '彷块': 3,
      '方馊': 3,
      '方艘': 3,
      '方叟': 3,
      '方嗾': 3,
      '方溲': 3,
      '方嗖': 3,
      '方飕': 3,
      '方锼': 3,
      '方螋': 3,
      '方艏': 3,
      '方手': 3,
      '方守': 3,
      '方首': 3,
      '方寿': 3,
      '方受': 3,
      '方授': 3,
      '方售': 3,
      '方瘦': 3,
      '方兽': 3,
      '方狩': 3,
      '方绶': 3,
      '方痩': 3,
      '方膄': 3,
      '方便': 3,
      '方面': 3,
      '防范': 3,
      '访遍': 3,
      '旁边': 3,
      '胖边': 3,
      '螃边': 3,
      '膀边': 3,
      '磅边': 3,
      '镑边': 3,
      '滂边': 3,
      '彷边': 3,
      '乓边': 3,
      '雱边': 3,
      '方偏': 3,
      '方篇': 3,
      '方翩': 3,
      '方片儿': 3,
      '方片子': 3,
      '方块儿': 3,
      '方块子': 3,
      '方片片': 3,
      '方片块': 3,
      '方片快': 3,
      '方块片': 3,
      '方块快': 3,
      '方片方': 3,
      '方块方': 3,
      '方框': 3,
      '方筐': 3,
      '方匡': 3,
      '方诓': 3,
      '方哐': 3,
      '方洭': 3,
      '方恇': 3,
      '方眶': 3,
      '方箧': 3,
      '方框框': 3,
      '方片糖': 3, // 生活用语
      '方糖': 3, // 生活用语
      '冰糖': 3, // 误读
      '白糖': 3, // 误读
      '四方块': 3,
      '四方片': 3,
      '四方快': 3,
      '四方筷': 3,
      '四块': 3,
      '四快': 3,
      '四筷': 3,
      '四片': 3,
      '方巾': 3, // 近似音
      '方今': 3,
      '方斤': 3,
      '方金': 3,
      '方津': 3,
      '方筋': 3,
      '方襟': 3,
      '方锦': 3,
      '方紧': 3,
      '方仅': 3,
      '方尽': 3,
      '方进': 3,
      '方近': 3,
      '方劲': 3,
      '方浸': 3,
      '方禁': 3,
      '方噤': 3,
      '方言': 3,
      '方圆': 3,
      '房源': 3,
      '法院': 3,
      '放远': 3,
      '访员': 3,
      '仿元': 3,
      '纺原': 3,
    };

    String lowerText = text.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    // 先在整句里解析点数，如果是大小王，则直接处理（无花色）
    final globalRank = _matchRank(lowerText);
    if (globalRank == 14 || globalRank == 15) {
      _lastVoiceRank = globalRank;
      _lastVoiceSuit = null;
      final label = globalRank == 15 ? '大王' : '小王';
      setState(() => _lastWords = '识别到：$label\n轻触屏幕显示');
      return;
    }

    int? suit;
    String? matchedSuitKey;
    int bestSuitIndex = -1;
    for (var entry in suits.entries) {
      final keyLower = entry.key.toLowerCase();
      final idx = lowerText.lastIndexOf(keyLower);
      if (idx != -1 && idx > bestSuitIndex) {
        bestSuitIndex = idx;
        suit = entry.value;
        matchedSuitKey = entry.key;
      }
    }
    if (suit == null) return;

    String afterSuit = lowerText
        .substring(bestSuitIndex + matchedSuitKey!.length)
        .trim();

    int? rank = _matchRank(afterSuit);
    if (rank == null) return;

    _lastVoiceRank = rank;
    _lastVoiceSuit = suit;

    final shownRank = (rank == 1)
        ? 'A'
        : (rank >= 2 && rank <= 10)
        ? '$rank'
        : (rank == 11)
        ? 'J'
        : (rank == 12)
        ? 'Q'
        : 'K';
    setState(() => _lastWords = '识别到：$matchedSuitKey $shownRank\n轻触屏幕显示');
  }

  int? _matchRank(String text) {
    final t = text.toLowerCase().replaceAll(RegExp(r'[，。,.!！?？:：;；]'), '');

    int? bestRank;
    int bestIndex = -1;

    void consider(String pattern, int rankValue) {
      final idx = t.lastIndexOf(pattern);
      if (idx != -1 && idx >= bestIndex) {
        bestIndex = idx;
        bestRank = rankValue;
      }
    }

    // 大小王（无花色）
    consider('大王', 15);
    consider('小王', 14);
    // 小王 (14) - 全面扩充
    consider('14', 14);
    consider('小王', 14);
    consider('小', 14);
    consider('消', 14);
    consider('笑', 14);
    consider('晓', 14);
    consider('宵', 14);
    consider('销', 14);
    consider('肖', 14);
    consider('孝', 14);
    consider('校', 14);
    consider('效', 14);
    consider('啸', 14);
    consider('小亡', 14);
    consider('小鬼', 14);
    consider('鬼', 14);
    consider('贵', 14);
    consider('跪', 14);
    consider('柜', 14);
    consider('桂', 14);
    consider('瑰', 14);
    consider('规', 14);
    consider('归', 14);
    consider('龟', 14);
    consider('闺', 14);
    consider('硅', 14);
    consider('轨', 14);
    consider('癸', 14);
    consider('小网', 14);
    consider('小往', 14);
    consider('小望', 14);
    consider('小亡', 14);
    consider('小汪', 14);
    consider('小忘', 14);
    consider('小妄', 14);
    consider('小旺', 14);
    consider('小威', 14);
    consider('小伟', 14);
    consider('小卫', 14);
    consider('小喂', 14);
    consider('小薇', 14);
    consider('小微', 14);
    consider('小魏', 14);
    consider('小未', 14);
    consider('小位', 14);
    consider('小味', 14);
    consider('小畏', 14);
    consider('小尉', 14);
    consider('小慰', 14);
    consider('小蔚', 14);
    consider('小玮', 14);
    consider('小炜', 14);
    consider('小萎', 14);
    consider('小苇', 14);
    consider('小娓', 14);
    consider('小隗', 14);
    consider('小魍', 14);
    consider('小惘', 14);
    consider('小魉', 14); // 和小鬼搭配
    consider('小魁', 14);
    consider('小傀', 14);
    consider('小瑰', 14);
    consider('小妫', 14);
    consider('小溾', 14);
    consider('小螝', 14);
    consider('小襘', 14);
    consider('小郐', 14);
    consider('小鱖', 14);
    consider('小鳜', 14);
    consider('小厥', 14);

    // 大王 (15) - 全面扩充
    consider('15', 15);
    consider('大王', 15);
    consider('大', 15);
    consider('打', 15);
    consider('达', 15);
    consider('答', 15);
    consider('搭', 15);
    consider('大亡', 15);
    consider('大鬼', 15);
    consider('亡', 15);
    consider('网', 15);
    consider('往', 15);
    consider('望', 15);
    consider('汪', 15);
    consider('忘', 15);
    consider('妄', 15);
    consider('旺', 15);
    consider('威', 15);
    consider('伟', 15);
    consider('卫', 15);
    consider('喂', 15);
    consider('薇', 15);
    consider('微', 15);
    consider('魏', 15);
    consider('未', 15);
    consider('位', 15);
    consider('味', 15);
    consider('畏', 15);
    consider('尉', 15);
    consider('慰', 15);
    consider('蔚', 15);
    consider('玮', 15);
    consider('炜', 15);
    consider('萎', 15);
    consider('苇', 15);
    consider('娓', 15);
    consider('隗', 15);
    consider('魍', 15);
    consider('惘', 15);
    consider('魉', 15); // 和大鬼搭配
    consider('魁', 15);
    consider('傀', 15);
    consider('瑰', 15);
    consider('妫', 15);
    consider('溾', 15);
    consider('螝', 15);
    consider('襘', 15);
    consider('郐', 15);
    consider('鱖', 15);
    consider('鳜', 15);
    consider('厥', 15);
    consider('大网', 15);
    consider('大往', 15);
    consider('大望', 15);
    consider('大汪', 15);
    consider('大忘', 15);
    consider('大妄', 15);
    consider('大旺', 15);
    consider('大威', 15);
    consider('大伟', 15);
    consider('大卫', 15);
    consider('大喂', 15);
    consider('大薇', 15);
    consider('大微', 15);
    consider('大魏', 15);
    consider('大未', 15);
    consider('大位', 15);
    consider('大味', 15);
    consider('大畏', 15);
    consider('大尉', 15);
    consider('大慰', 15);
    consider('大蔚', 15);
    consider('大玮', 15);
    consider('大炜', 15);
    consider('大萎', 15);
    consider('大苇', 15);
    consider('大娓', 15);
    consider('大隗', 15);
    consider('大魍', 15);
    consider('大惘', 15);
    consider('大魉', 15);
    consider('大魁', 15);
    consider('大傀', 15);
    consider('大瑰', 15);
    consider('大妫', 15);
    consider('大溾', 15);
    consider('大螝', 15);
    consider('大襘', 15);
    consider('大郐', 15);
    consider('大鱖', 15);
    consider('大鳜', 15);
    consider('大厥', 15);

    // 扑克牌1 (A)
    consider('1', 1);
    consider('一', 1);
    consider('幺', 1);
    consider('腰', 1);
    consider('邀', 1);
    consider('妖', 1);
    consider('要', 1);
    consider('药', 1);
    consider('摇', 1);
    consider('谣', 1);
    consider('姚', 1);
    consider('咬', 1);
    consider('尖', 1);
    consider('间', 1);
    consider('A', 1);
    consider('a', 1);
    consider('诶', 1);
    consider('埃', 1);
    consider('哀', 1);
    consider('爱', 1);
    consider('矮', 1);
    consider('艾', 1);
    consider('碍', 1);
    consider('埃斯', 1);

    // 扑克牌2
    consider('2', 2);
    consider('二', 2);
    consider('两', 2);
    consider('俩', 2);
    consider('尔', 2);
    consider('儿', 2);
    consider('而', 2);
    consider('耳', 2);
    consider('饵', 2);
    consider('洱', 2);
    consider('贰', 2);
    consider('二两', 2);
    consider('二儿', 2);
    consider('二二', 2);

    // 扑克牌3
    consider('3', 3);
    consider('三', 3);
    consider('仨', 3);
    consider('叁', 3);
    consider('山', 3);
    consider('删', 3);
    consider('衫', 3);
    consider('珊', 3);
    consider('煽', 3);
    consider('闪', 3);
    consider('善', 3);
    consider('伞', 3);
    consider('散', 3);
    consider('三儿', 3);
    consider('三三', 3);
    consider('三仨', 3);

    // 扑克牌4
    consider('4', 4);
    consider('四', 4);
    consider('肆', 4);
    consider('是', 4);
    consider('事', 4);
    consider('市', 4);
    consider('死', 4);
    consider('丝', 4);
    consider('司', 4);
    consider('思', 4);
    consider('撕', 4);
    consider('斯', 4);
    consider('私', 4);
    consider('寺', 4);
    consider('似', 4);
    consider('四儿', 4);
    consider('四四', 4);

    // 扑克牌5
    consider('5', 5);
    consider('五', 5);
    consider('伍', 5);
    consider('我', 5);
    consider('无', 5);
    consider('吴', 5);
    consider('武', 5);
    consider('舞', 5);
    consider('午', 5);
    consider('乌', 5);
    consider('屋', 5);
    consider('务', 5);
    consider('勿', 5);
    consider('雾', 5);
    consider('物', 5);
    consider('五儿', 5);
    consider('五五', 5);
    consider('捂', 5);

    // 扑克牌6
    consider('6', 6);
    consider('六', 6);
    consider('陆', 6);
    consider('溜', 6);
    consider('流', 6);
    consider('刘', 6);
    consider('留', 6);
    consider('柳', 6);
    consider('六儿', 6);
    consider('六六', 6);
    consider('碌', 6);
    consider('绿', 6);
    consider('录', 6);
    consider('路', 6);
    consider('露', 6);
    consider('炉', 6);
    consider('芦', 6);
    consider('鲁', 6);
    consider('鹿', 6);
    consider('陆陆', 6);
    consider('溜溜', 6);

    // 扑克牌7
    consider('7', 7);
    consider('七', 7);
    consider('柒', 7);
    consider('拐', 7);
    consider('吃', 7);
    consider('尺', 7);
    consider('迟', 7);
    consider('池', 7);
    consider('赤', 7);
    consider('翅', 7);
    consider('斥', 7);
    consider('七儿', 7);
    consider('七七', 7);
    consider('欺', 7);
    consider('妻', 7);
    consider('期', 7);
    consider('漆', 7);
    consider('齐', 7);
    consider('旗', 7);
    consider('起', 7);
    consider('气', 7);
    consider('弃', 7);
    consider('汽', 7);

    // 扑克牌8
    consider('8', 8);
    consider('八', 8);
    consider('捌', 8);
    consider('发', 8);
    consider('吧', 8);
    consider('把', 8);
    consider('爸', 8);
    consider('拔', 8);
    consider('八儿', 8);
    consider('八八', 8);
    consider('巴', 8);
    consider('扒', 8);
    consider('叭', 8);
    consider('芭', 8);
    consider('疤', 8);
    consider('靶', 8);
    consider('罢', 8);
    consider('霸', 8);
    consider('坝', 8);

    // 扑克牌9
    consider('9', 9);
    consider('九', 9);
    consider('玖', 9);
    consider('酒', 9);
    consider('久', 9);
    consider('旧', 9);
    consider('就', 9);
    consider('救', 9);
    consider('舅', 9);
    consider('究', 9);
    consider('九儿', 9);
    consider('九九', 9);
    consider('纠', 9);
    consider('揪', 9);
    consider('韭', 9);
    consider('灸', 9);
    consider('疚', 9);
    consider('厩', 9);

    // 扑克牌10
    consider('10', 10);
    consider('十', 10);
    consider('拾', 10);
    consider('使', 10);
    consider('时', 10);
    consider('是', 10);
    consider('石', 10);
    consider('食', 10);
    consider('实', 10);
    consider('识', 10);
    consider('史', 10);
    consider('矢', 10);
    consider('屎', 10);
    consider('始', 10);
    consider('式', 10);
    consider('试', 10);
    consider('视', 10);
    consider('士', 10);
    consider('世', 10);
    consider('势', 10);
    consider('事', 10);
    consider('释', 10);
    consider('十儿', 10);
    consider('十十', 10);
    consider('湿', 10);
    consider('诗', 10);
    consider('师', 10);
    consider('失', 10);
    consider('施', 10);
    consider('尸', 10);
    consider('虱', 10);

    // 扑克牌J (11) - 扩充
    consider('11', 11);
    consider('j', 11);
    consider('杰', 11);
    consider('借', 11);
    consider('姐', 11);
    consider('节', 11);
    consider('街', 11);
    consider('捷', 11);
    consider('劫', 11);
    consider('解', 11);
    consider('戒', 11);
    consider('界', 11);
    consider('介', 11);
    consider('沟', 11);
    consider('钩', 11);
    consider('勾', 11);
    consider('狗', 11);
    consider('够', 11);
    consider('构', 11);
    consider('购', 11);
    consider('苟', 11);
    consider('佝', 11);
    consider('笱', 11);
    consider('遘', 11);
    consider('觏', 11);

    // 扑克牌Q (12) - 扩充
    consider('12', 12);
    consider('q', 12);
    consider('Q', 12);
    consider('后', 12);
    consider('皇后', 12);
    consider('球', 12);
    consider('求', 12);
    consider('秋', 12);
    consider('丘', 12);
    consider('囚', 12);
    consider('糗', 12);
    consider('区', 12);
    consider('去', 12);
    consider('取', 12);
    consider('曲', 12);
    consider('圈', 12);
    consider('库', 12);
    consider('酷', 12);
    consider('哭', 12);
    consider('苦', 12);
    consider('裤', 12);
    consider('库尔', 12);
    consider('困', 12);
    consider('昆', 12);
    consider('坤', 12);
    consider('捆', 12);
    consider('阔', 12);
    consider('括', 12);
    consider('扩', 12);
    consider('廓', 12);

    // 扑克牌K (13) - 扩充
    consider('13', 13);
    consider('k', 13);
    consider('K', 13);
    consider('国王', 13);
    consider('凯', 13);
    consider('开', 13);
    consider('看', 13);
    consider('科', 13);
    consider('克', 13);
    consider('可', 13);
    consider('刻', 13);
    consider('客', 13);
    consider('咳', 13);
    consider('壳', 13);
    consider('渴', 13);
    consider('肯', 13);
    consider('坑', 13);
    consider('孔', 13);
    consider('空', 13);
    consider('控', 13);
    consider('卡', 13);
    consider('咖', 13);
    consider('咔', 13);
    consider('咯', 13);
    consider('拷', 13);
    consider('靠', 13);
    consider('考', 13);
    consider('烤', 13);
    consider('铐', 13);
    consider('尻', 13);

    const cn = {
      '一': 1,
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
    for (final e in cn.entries) {
      consider(e.key, e.value);
    }

    final digitMatches = RegExp(r'[2-9]').allMatches(t);
    if (digitMatches.isNotEmpty) {
      final last = digitMatches.last;
      final val = int.tryParse(last.group(0)!);
      if (val != null && last.start >= bestIndex) {
        bestIndex = last.start;
        bestRank = val;
      }
    }

    return bestRank;
  }

  @override
  void dispose() {
    _stopListening();
    _stream?.free();
    _recognizer?.free();
  }
}

/// 随机点击选择器：点击屏幕任意位置随机选一张牌（包括大小王）
class RandomTapCardSelector implements CardSelector {
  final Random _random = Random();

  @override
  Widget buildSelector({
    required BuildContext context,
    required void Function(int rank, int? suit) onCardSelected,
    required VoidCallback onRequestBack,
  }) {
    return GestureDetector(
      onTap: () {
        // 随机生成 rank 1-15
        int rank = _random.nextInt(15) + 1;
        int? suit;

        // 如果是普通牌（1-13），随机生成花色（0-3）
        if (rank <= 13) {
          suit = _random.nextInt(4);
        } else {
          suit = null; // 大小王无花色
        }

        onCardSelected(rank, suit);
      },
      onLongPress: onRequestBack, // 长按返回待机
      child: Container(
        color: Colors.black,
        // 如果想显示提示文字，可保留以下 Center；若希望完全黑屏，请替换为 Container(color: Colors.black)
        child: const Center(
          child: Text(
            '点击屏幕随机选牌\n长按返回待机',
            style: TextStyle(color: Colors.white, fontSize: 20),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 没有资源需要释放
  }
}

/// 默认的基于网格和滑动的选择器（3x5网格 + 方向判断）
class GridSwipeCardSelector implements CardSelector {
  // 触摸追踪相关
  int? _activePointerId;
  Offset? _downPosition;
  Offset? _lastPosition;
  Timer? _directionTimer;
  bool _isProcessed = false;
  Size? _screenSize;

  static const double minSwipeDistance = 8.0;

  @override
  Widget buildSelector({
    required BuildContext context,
    required void Function(int rank, int? suit) onCardSelected,
    required VoidCallback onRequestBack,
  }) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (_activePointerId != null) return; // 只追踪一个手指

        final size = MediaQuery.of(context).size;
        _activePointerId = event.pointer;
        _downPosition = event.position;
        _lastPosition = event.position;
        _screenSize = size;
        _isProcessed = false;

        _directionTimer?.cancel();
        _directionTimer = Timer(const Duration(milliseconds: 500), () {
          if (!_isProcessed && mounted(context)) {
            _resolveCard(onCardSelected);
          }
          _directionTimer = null;
        });
      },
      onPointerMove: (event) {
        if (event.pointer != _activePointerId) return;
        if (_isProcessed) return;
        _lastPosition = event.position;
      },
      onPointerUp: (event) {
        if (event.pointer != _activePointerId) return;
        if (_isProcessed) {
          _resetTracking();
          return;
        }
        _directionTimer?.cancel();
        _directionTimer = null;
        _resolveCard(onCardSelected);
        _resetTracking();
      },
      onPointerCancel: (event) {
        if (event.pointer == _activePointerId) {
          _resetTracking();
        }
      },
      child: Container(color: Colors.black),
    );
  }

  // 根据起始点位置计算牌面数字 (1~15)
  int _calculateRank(Offset position, Size screenSize) {
    double cellWidth = screenSize.width / 3;
    double cellHeight = screenSize.height / 5;

    int col = (position.dx / cellWidth).floor().clamp(0, 2);
    int row = (position.dy / cellHeight).floor().clamp(0, 4);

    return row * 3 + col + 1;
  }

  // 根据位移向量计算花色 (0: 黑桃, 1: 红桃, 2: 梅花, 3: 方块)
  int? _calculateSuit(Offset delta) {
    double distance = delta.distance;
    if (distance < minSwipeDistance) return null;

    double angleRad = atan2(delta.dx, -delta.dy);
    double angleDeg = (angleRad * 180 / pi + 360) % 360;

    if (angleDeg < 90) return 0;
    if (angleDeg < 180) return 1;
    if (angleDeg < 270) return 2;
    return 3;
  }

  void _resolveCard(void Function(int, int?) onCardSelected) {
    if (_isProcessed) return;
    if (_downPosition == null || _lastPosition == null || _screenSize == null) {
      return;
    }

    int rank = _calculateRank(_downPosition!, _screenSize!);
    Offset delta = _lastPosition! - _downPosition!;
    int? suit = _calculateSuit(delta);

    // 如果滑动距离过小导致无花色，且数字是普通牌（1-13），则此次操作无效
    if (suit == null && rank <= 13) {
      _resetTracking();
      return;
    }

    onCardSelected(rank, suit);
    _isProcessed = true;
    _resetTracking();
  }

  void _resetTracking() {
    _directionTimer?.cancel();
    _directionTimer = null;
    _activePointerId = null;
    _downPosition = null;
    _lastPosition = null;
    _screenSize = null;
    _isProcessed = false;
  }

  // 辅助方法：检查当前 context 是否仍然 mounted (Flutter 3.7+)
  bool mounted(BuildContext context) => context.mounted;

  @override
  void dispose() {
    _directionTimer?.cancel();
  }
}

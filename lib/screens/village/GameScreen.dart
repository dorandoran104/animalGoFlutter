import 'dart:convert';

import 'package:animalgo/screens/village/Animal.dart';
import 'package:animalgo/screens/village/CharacterListView.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late WebSocketChannel channel;
  List<Animal> characterList = [];
  StreamSubscription? _subscription;
  Set<String> _activeCollisions = {};
  bool _isWebSocketConnected = false;
  List<Rect> blockedZones = [
    Rect.fromLTWH(0.51, 0.0001, 0.037, 0.6333), //가운대 선
    Rect.fromLTWH(0.00001, 0.000001, 0.99999, 0.333), // 위
    Rect.fromLTWH(0.00001, 0.69999, 0.99999, 0.99999), // 아래
  ];

  Offset _relativePosition = Offset.zero;
  final GlobalKey _imageKey = GlobalKey();
  Size _imageSize = Size.zero;

  // 움직임 관련 변수들
  late Timer _movementTimer;
  late Timer _directionTimer;
  late Timer _pauseTimer;
  final Random _random = Random();
  late List<Offset> _velocities;
  bool _isPaused = false;

  // 4방향 (오른쪽, 왼쪽, 아래, 위)
  final List<Offset> _directions = const [
    Offset(1, 0),
    Offset(-1, 0),
    Offset(0, 1),
    Offset(0, -1),
  ];

  void _connectWebSocket() {
    if (_isWebSocketConnected) return;

    var wsUrl = dotenv.env['WS_URL'] ?? 'ws://122.46.89.124:7000/ws';
    wsUrl += '/1';
    print(wsUrl);
    if (kIsWeb) {
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    } else {
      channel = IOWebSocketChannel.connect(wsUrl);
    }
    _subscription = channel.stream.listen(
      (message) {
        print('Received message: $message');
        // TODO: 메시지 처리 로직 추가
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
      onDone: () {
        print('WebSocket connection closed');
        _isWebSocketConnected = false;
      },
    );
    _isWebSocketConnected = true;
  }

  Future<void> _getCharacters() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('cookie') ?? 1;
    try {
      Dio dio = Dio(
        BaseOptions(
          baseUrl: "http://127.0.0.1:8000",
          headers: {'Content-Type': 'application/json'},
        ),
      );
      var response = await dio.get("/village/get_characters/${token}");
      if (response.statusCode == 200 && response.data["result"]) {
        Map<String, dynamic> responseMap =
            response.data as Map<String, dynamic>;
        List<dynamic> data = responseMap["character_list"];
        setState(() {
          characterList = data.map((json) {
            final animal =
                Animal.fromJson(json, screenSize: MediaQuery.of(context).size);

            print("Created animal: ${animal.nickname}");
            return animal;
          }).toList();
          // 초기 _velocities 설정 – 캐릭터 수와 동일하게 할당
          _velocities = characterList.map((_) {
            return _directions[_random.nextInt(_directions.length)];
          }).toList();
        });
      }
    } on DioException catch (e) {
      setState(() {
        print(e);
        characterList = [];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getCharacters();
    _connectWebSocket();
    startMove();
  }

  void startMove() {
    //   // 60fps: 약 16ms마다 위치 업데이트 (화면 사이즈는 캐릭터 컨테이너 50x50 기준)
    _movementTimer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      if (!_isPaused && characterList.isNotEmpty && _velocities.isNotEmpty) {
        setState(() {
          int count = min(characterList.length, _velocities.length);
          // 캐릭터끼리 충돌 체크 (간단히 50x50 박스 기준)
          for (var i = 0; i < count; i++) {
            for (var j = i + 1; j < count; j++) {
              final a = characterList[i];
              final b = characterList[j];
              String pairKey = (a.nickname.compareTo(b.nickname) < 0)
                  ? "${a.nickname}_${b.nickname}"
                  : "${b.nickname}_${a.nickname}";
              if ((a.x - b.x).abs() < 50 && (a.y - b.y).abs() < 50) {
                // 이미 충돌 메시지가 전송되지 않은 경우에만 전송
                if (!_activeCollisions.contains(pairKey)) {
                  _activeCollisions.add(pairKey);
                  final collisionData = {
                    'event': 'collision',
                    'pairKey': pairKey,
                    'characters': [
                      {
                        'id': a.character_id,
                        'nickname': a.nickname,
                        'x': a.x,
                        'y': a.y,
                        'animaltype': a.animalType,
                        'personality': a.personality
                      },
                      {
                        'id': b.character_id,
                        'nickname': b.nickname,
                        'x': b.x,
                        'y': b.y,
                        'animaltype': b.animalType,
                        'personality': b.personality
                      },
                    ],
                  };
                  channel.sink.add(jsonEncode(collisionData));
                  // print("Collision detected between ${a.nickname} and ${b.nickname}");
                }
                // // 충돌 시 해당 캐릭터들의 이동 정지
                // _velocities[i] = Offset.zero;
                // _velocities[j] = Offset.zero;
              }
            }
          }

          final screenSize = MediaQuery.of(context).size;
          final maxX = screenSize.width - 50;
          final maxY = screenSize.height - 50;
          
          for (var i = 0; i < count; i++) {
            final newX = characterList[i].x + _velocities[i].dx;
            final newY = characterList[i].y + _velocities[i].dy;

            // 블록된 영역과의 충돌 체크
            bool isBlocked = false;
            
            for (var zone in blockedZones) {
            final scaledZone = Rect.fromLTRB(
              zone.left * _imageSize.width,
              zone.top * _imageSize.height,
              zone.right * _imageSize.width,
              zone.bottom * _imageSize.height,
            );
            if (scaledZone.contains(Offset(newX + 50, newY+50))) {
              isBlocked = true;
              break;
            }
          }

            if (!isBlocked) {
              characterList[i].x = newX;
              characterList[i].y = newY;
            } else {
              // 충돌 시 반대 방향으로 이동
              _velocities[i] = Offset(-_velocities[i].dx, -_velocities[i].dy);
            }

            // x축 경계 체크 및 반대 방향 전환
            if (characterList[i].x < 0) {
              characterList[i].x = 0;
              _velocities[i] =
                  Offset(_velocities[i].dx.abs(), _velocities[i].dy);
            } else if (characterList[i].x > maxX) {
              characterList[i].x = maxX;
              _velocities[i] =
                  Offset(-_velocities[i].dx.abs(), _velocities[i].dy);
            }
            // y축 경계 체크 및 반대 방향 전환
            if (characterList[i].y < 0) {
              characterList[i].y = 0;
              _velocities[i] =
                  Offset(_velocities[i].dx, _velocities[i].dy.abs());
            } else if (characterList[i].y > maxY) {
              characterList[i].y = maxY;
              _velocities[i] =
                  Offset(_velocities[i].dx, -_velocities[i].dy.abs());
            }
          }
        });
      }
    });

    // 10초마다 각 캐릭터의 방향을 랜덤하게 변경
    _directionTimer = Timer.periodic(Duration(seconds: 4), (timer) {
      if (characterList.isNotEmpty && _velocities.isNotEmpty) {
        setState(() {
          int count = min(characterList.length, _velocities.length);
          for (var i = 0; i < count; i++) {
            _velocities[i] = _directions[_random.nextInt(_directions.length)];
          }
        });
      }
    });

    // 1초마다 이동을 정지/재개 (1초 정지, 1초 이동 반복)
    // _pauseTimer = Timer.periodic(Duration(seconds: 1), (timer) {
    //   setState(() {
    //     _isPaused = !_isPaused;
    //   });
    // });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    channel.sink.close();
    _movementTimer.cancel();
    _directionTimer.cancel();
    _pauseTimer.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final renderBox =
          _imageKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        setState(() {
          _imageSize = renderBox.size;
          _relativePosition = Offset(0.4, 0.5); // 예시로 이미지의 중앙을 설정
          // print(blockedZones);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 배경 이미지
          Positioned.fill(
            child:
                Image.asset("assets/images/backgroundv2.png", fit: BoxFit.fill),
            key: _imageKey,
          ),
          CustomPaint(
            size: Size.infinite,
            painter: GamePainter(blockedZones, _relativePosition, _imageSize),
          ),
          // 캐릭터 리스트 (위에서 업데이트되는 characterList를 그대로 사용)
          CharacterListView(characters: characterList)
        ],
      ),
    );
  }
}

class GamePainter extends CustomPainter {
  final List<Rect> blockedZones;
  final Offset relativePosition;
  final Size imageSize;

  GamePainter(this.blockedZones, this.relativePosition, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.red.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // 불가능한 영역을 그리기
    for (var zone in blockedZones) {
      final relativeZone = Rect.fromLTRB(
        zone.left * size.width,
        zone.top * size.height,
        zone.right * size.width,
        zone.bottom * size.height,
      );
      canvas.drawRect(relativeZone, paint); // 각 불가능한 영역을 빨간색으로 그리기
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

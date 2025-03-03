import 'dart:convert';
import 'package:animalgo/screens/village/Animal.dart';
import 'package:animalgo/screens/village/CharacterListView.dart';
import '../chat/ChatRoomScreen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

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

  Animal? playerCharacter;
  bool _isPlayerVisible = true;
  List<String> _logs = [];
  bool _isColliding = false;
  bool _isCollidingWithPlayer = false;
  String? _lastCollidedAnimalId;
  String? _lastCollidedAnimalName;
  bool _isClearingCollisions = false;
  bool _disablePlayerCollision = false;

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

  final List<Offset> _directions = const [
    Offset(1, 0),
    Offset(-1, 0),
    Offset(0, 1),
    Offset(0, -1),
  ];

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, message);
      if (_logs.length > 10) _logs.removeLast();
      print('Log added: $message');
    });
  }

  void _connectWebSocket() {
    if (_isWebSocketConnected) return;

    var wsUrl = dotenv.env['WS_URL'] ?? 'ws://122.46.89.124:7000/ws';
    wsUrl += '/1';
    print(wsUrl);
    _addLog('Connecting to WebSocket: $wsUrl');
    if (kIsWeb) {
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    } else {
      channel = IOWebSocketChannel.connect(wsUrl);
    }
    _subscription = channel.stream.listen(
      (message) {
        print('Received message: $message');
        _addLog('WS Received: $message');
      },
      onError: (error) {
        print('WebSocket error: $error');
        _addLog('WS Error: $error');
      },
      onDone: () {
        print('WebSocket connection closed');
        _addLog('WS Closed');
        _isWebSocketConnected = false;
      },
    );

    _isWebSocketConnected = true;
  }

  Future<void> _getCharacters() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('cookie') ?? 1;
    final userId = prefs.getString('user_id') ?? 'default_user';

    try {
      Dio dio = Dio(
        BaseOptions(
          baseUrl: "http://122.46.89.124:7000",
          headers: {'Content-Type': 'application/json'},
        ),
      );
      _addLog('Fetching characters...');
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

          final playerIndex =
              characterList.indexWhere((animal) => animal.userId == userId);
          if (playerIndex != -1) {
            characterList[playerIndex].isPlayer = true;
            playerCharacter = characterList[playerIndex];
            _addLog('Player set: ${playerCharacter!.nickname}');
          } else {
            playerCharacter = Animal(
              x: MediaQuery.of(context).size.width / 2,
              y: MediaQuery.of(context).size.height / 2,
              characterPath: 'assets/images/char1.png',
              originalPath: '',
              animalType: 'default',
              appearance: 'default',
              nickname: 'Player',
              personality: 'neutral',
              status: 'idle',
              userId: userId,
              character_id: 'player_default',
              isPlayer: true,
            );
            characterList.add(playerCharacter!);
            _addLog('Added default player: ${playerCharacter!.nickname}');
          }

          print('Character list length: ${characterList.length}');
          print(
              'Player character: ${playerCharacter?.nickname}, isPlayer: ${playerCharacter?.isPlayer}');
          _velocities = List.generate(characterList.length, (_) => Offset.zero);
        });
      }
    } on DioException catch (e) {
      setState(() {
        print('Error fetching characters: $e');
        _addLog('Error fetching characters: $e');
        characterList = [];
        playerCharacter = null;
        _velocities = [];
      });
    }
  }

  Future<void> _updateAffinity(String characterId, String action) async {
    try {
      Dio dio = Dio(
        BaseOptions(
          baseUrl: "http://122.46.89.124:7000",
          headers: {'Content-Type': 'application/json'},
        ),
      );
      // 친밀도 변경 API 호출
      var response = await dio.post("/village/action/$characterId/$action");
      if (response.statusCode == 200) {
        _addLog('$action 성공: ${response.data.toString()}');
        // 친밀도 조회 API 호출
        var affinityResponse =
            await dio.get("/village/get_affinity/$characterId");
        if (affinityResponse.statusCode == 200) {
          _addLog('현재 친밀도: ${affinityResponse.data.toString()}');
        } else {
          _addLog('친밀도 조회 실패: ${affinityResponse.statusCode}');
        }
      } else {
        _addLog('$action 실패: ${response.statusCode}');
      }
    } catch (e) {
      _addLog('$action 오류: $e');
    }
  }

  void _clearPlayerCollisions() {
    setState(() {
      _isClearingCollisions = true;
      _disablePlayerCollision = true;
      _activeCollisions.removeWhere((pair) {
        return characterList
            .any((animal) => animal.isPlayer && pair.contains(animal.nickname));
      });
      _isCollidingWithPlayer = false;
      _isColliding = false;
      _lastCollidedAnimalId = null;
      _lastCollidedAnimalName = null;

      // 모든 동물 속도 재설정
      for (var i = 0; i < characterList.length; i++) {
        if (!characterList[i].isPlayer &&
            !_activeCollisions
                .any((pair) => pair.contains(characterList[i].nickname))) {
          _velocities[i] = _directions[_random.nextInt(_directions.length)];
        }
      }
      _addLog('플레이어와의 충돌 해제, 동물 움직임 복구');

      // 3초 후 플레이어 충돌 감지 재활성화
      Timer(Duration(seconds: 3), () {
        setState(() {
          _disablePlayerCollision = false;
          _addLog('플레이어 충돌 감지 재활성화');
        });
      });
    });
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
                if (characterList[i].isPlayer && !_isPlayerVisible) continue;
                final scaledZone = Rect.fromLTRB(
                  zone.left * _imageSize.width,
                  zone.top * _imageSize.height,
                  zone.right * _imageSize.width,
                  zone.bottom * _imageSize.height,
                );
                if (scaledZone.contains(Offset(newX + 50, newY + 50))) {
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

            // 충돌 감지 및 상태 업데이트
            bool isCollidingWithPlayer = false;
            if (!_isClearingCollisions && !_disablePlayerCollision) {
              for (var i = 0; i < count; i++) {
                final animalI = characterList[i];
                for (var j = i + 1; j < count; j++) {
                  final animalJ = characterList[j];
                  if (animalI.isPlayer && !_isPlayerVisible) continue;
                  if (animalJ.isPlayer && !_isPlayerVisible) continue;

                  String pairKey =
                      (animalI.nickname.compareTo(animalJ.nickname) < 0)
                          ? "${animalI.nickname}_${animalJ.nickname}"
                          : "${animalJ.nickname}_${animalI.nickname}";
                  if ((animalI.x - animalJ.x).abs() < 50 &&
                      (animalI.y - animalJ.y).abs() < 50) {
                    if (!_activeCollisions.contains(pairKey)) {
                      _activeCollisions.add(pairKey);
                      final collisionData = {
                        'event': 'collision',
                        'pairKey': pairKey,
                        'characters': [
                          {
                            'id': animalI.character_id,
                            'nickname': animalI.nickname,
                            'x': animalI.x,
                            'y': animalI.y,
                            'animaltype': animalI.animalType,
                            'personality': animalI.personality
                          },
                          {
                            'id': animalJ.character_id,
                            'nickname': animalJ.nickname,
                            'x': animalJ.x,
                            'y': animalJ.y,
                            'animaltype': animalJ.animalType,
                            'personality': animalJ.personality
                          },
                        ],
                      };
                      channel.sink.add(jsonEncode(collisionData));
                      _addLog(
                          '${animalI.nickname}과 ${animalJ.nickname}이(가) 충돌했습니다.');
                      if (animalI.isPlayer || animalJ.isPlayer) {
                        isCollidingWithPlayer = true;
                        if (animalI.isPlayer) {
                          _lastCollidedAnimalId = animalJ.character_id;
                          _lastCollidedAnimalName = animalJ.nickname;
                        } else {
                          _lastCollidedAnimalId = animalI.character_id;
                          _lastCollidedAnimalName = animalI.nickname;
                        }
                      }
                    }
                    if (!isCollidingWithPlayer) {
                      _velocities[i] = Offset.zero;
                      _velocities[j] = Offset.zero;
                    }
                  } else {
                    if (_activeCollisions.contains(pairKey)) {
                      _activeCollisions.remove(pairKey);
                    }
                  }
                }
              }

              _isColliding = isCollidingWithPlayer ||
                  _activeCollisions.any((pair) {
                    return characterList.any((animal) =>
                        animal.isPlayer && (pair.contains(animal.nickname)));
                  });

              _isCollidingWithPlayer = isCollidingWithPlayer ||
                  _activeCollisions.any((pair) {
                    return characterList.any((animal) =>
                        animal.isPlayer && (pair.contains(animal.nickname)));
                  });
            }

            for (var i = 0; i < count; i++) {
              if (_isCollidingWithPlayer) {
                _velocities[i] = Offset.zero;
              } else if (_activeCollisions
                  .any((pair) => pair.contains(characterList[i].nickname))) {
                _velocities[i] = Offset.zero;
              } else if (!characterList[i].isPlayer &&
                  _velocities[i] == Offset.zero) {
                _velocities[i] =
                    _directions[_random.nextInt(_directions.length)];
              }
            }

            _isClearingCollisions = false;
          });
        }
      });

      // 10초마다 각 캐릭터의 방향을 랜덤하게 변경
      _directionTimer = Timer.periodic(Duration(seconds: 10), (timer) {
        if (characterList.isNotEmpty && _velocities.isNotEmpty) {
          setState(() {
            int count = min(characterList.length, _velocities.length);
            for (var i = 0; i < count; i++) {
              if (_isCollidingWithPlayer) {
                _velocities[i] = Offset.zero;
              } else if (!characterList[i].isPlayer &&
                  !_activeCollisions.any(
                      (pair) => pair.contains(characterList[i].nickname))) {
                _velocities[i] =
                    _directions[_random.nextInt(_directions.length)];
              }
            }
          });
        }
      });

      // 1초마다 이동을 정지/재개 (1초 정지, 1초 이동 반복)
      _pauseTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _isPaused = !_isPaused;
          _addLog('Pause toggled: $_isPaused');
        });
      });
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

  void _updatePosition(StickDragDetails details) {
    setState(() {
      if (playerCharacter != null && _isPlayerVisible) {
        final speed = 2.0;
        playerCharacter!.x += details.x * speed;
        playerCharacter!.y += details.y * speed;
        _addLog(
            'Player moved to (${playerCharacter!.x.toInt()}, ${playerCharacter!.y.toInt()})');
      }
    });
  }

  void _togglePlayerVisibility() {
    setState(() {
      _isPlayerVisible = !_isPlayerVisible;
      _addLog('Player visibility: $_isPlayerVisible');
    });
  }

  void _startChat() async {
    if (_isCollidingWithPlayer &&
        _lastCollidedAnimalId != null &&
        _lastCollidedAnimalName != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            chatId: _lastCollidedAnimalId!,
            friendName: _lastCollidedAnimalName!,
          ),
        ),
      );
      _clearPlayerCollisions();
    } else {
      _addLog('채팅할 동물이 없습니다. 동물과 충돌하세요!');
    }
  }

  void _feedAnimal() async {
    if (_isCollidingWithPlayer &&
        _lastCollidedAnimalId != null &&
        _lastCollidedAnimalName != null) {
      await _updateAffinity(_lastCollidedAnimalId!, 'feeding');
      _clearPlayerCollisions();
    } else {
      _addLog('먹이를 줄 동물이 없습니다. 동물과 충돌하세요!');
    }
  }

  void _ignoreAnimal() async {
    if (_isCollidingWithPlayer &&
        _lastCollidedAnimalId != null &&
        _lastCollidedAnimalName != null) {
      await _updateAffinity(_lastCollidedAnimalId!, 'ignore');
      _clearPlayerCollisions();
    } else {
      _addLog('무시할 동물이 없습니다. 동물과 충돌하세요!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _isPlayerVisible
        ? characterList
        : characterList.where((character) => !character.isPlayer).toList();

    return Scaffold(
        body: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/images/backgroundv2.png",
                fit: BoxFit.fill),
          ),
          CharacterListView(
            characters: displayList,
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Container(
                width: 300,
                height: 100,
                color: Colors.black.withOpacity(0.7),
                child: _logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No logs available',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 2.0, horizontal: 4.0),
                            child: Text(
                              _logs[index],
                              style: const TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _togglePlayerVisibility,
                    child: Text(_isPlayerVisible ? '숨기기' : '보이기'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Joystick(
                      mode: JoystickMode.all,
                      listener: (details) => _updatePosition(details),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: AnimatedOpacity(
                opacity: _isColliding ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 300),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: _startChat,
                      child: const Text('채팅하기'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _feedAnimal,
                      child: const Text('먹이주기'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _ignoreAnimal,
                      child: const Text('무시하기'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      )
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

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
    //_addLog('Connecting to WebSocket: $wsUrl');
    if (kIsWeb) {
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    } else {
      channel = IOWebSocketChannel.connect(wsUrl);
    }
    _subscription = channel.stream.listen(
          (message) {
        print('Received message: $message');
        // _addLog('WS Received: $message');
      },
      onError: (error) {
        print('WebSocket error: $error');
        // _addLog('WS Error: $error');
      },
      onDone: () {
        print('WebSocket connection closed');
        // _addLog('WS Closed');
        _isWebSocketConnected = false;
      },
    );
    _isWebSocketConnected = true;
  }
  Future<void> _getCharacters() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('cookie');
    final userId = prefs.getString('user_id') ?? 'default_user';
    final nickname = prefs.getString('nickname') ??
        'Player'; // 저장된 닉네임 가져오기, 없으면 'Player' 사용
    try {
      Dio dio = Dio(
        BaseOptions(
          baseUrl: "http://122.46.89.124:7000",
          headers: {'Content-Type': 'application/json'},
        ),
      );
      //addLog('Fetching characters...');
      var response = await dio.get("/village/get_characters/${token}");
      print('Server response: ${response.data}');
      if (response.statusCode == 200 && response.data["result"]) {
        Map<String, dynamic> responseMap = response.data as Map<String,
            dynamic>;
        List<dynamic> data = responseMap["character_list"];
        setState(() {
          characterList = data.map((json) {
            final animal = Animal.fromJson(json, screenSize: MediaQuery
                .of(context)
                .size);
            return animal;
          }).toList();

          // `isPlayer`가 true인 캐릭터를 플레이어로 설정
          final playerIndex = characterList.indexWhere((animal) =>
          animal.isPlayer);
          if (playerIndex != -1) {
            playerCharacter = characterList[playerIndex];
            // _addLog('Player set: ${playerCharacter!.nickname}');
          } else {
            // 기본 플레이어 생성
            playerCharacter = Animal(
              x: MediaQuery
                  .of(context)
                  .size
                  .width / 2,
              y: MediaQuery
                  .of(context)
                  .size
                  .height / 2,
              characterPath: 'assets/images/char1.png',
              originalPath: '',
              animalType: 'default',
              appearance: 'default',
              nickname: nickname,
              // 로그인 시 저장된 닉네임 사용
              personality: 'neutral',
              status: 'idle',
              userId: userId,
              character_id: 'player_default',
              isPlayer: true,
            );
            characterList.add(playerCharacter!);
            //_addLog('Added default player: ${playerCharacter!.nickname}');
          }

          _velocities = List.generate(characterList.length, (_) => Offset.zero);
        });
      }
    } on DioException catch (e) {
      setState(() {
        print('Error fetching characters: $e');
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
      var response = await dio.post("/village/action/$characterId/$action");
      if (response.statusCode == 200) {
        var affinityResponse = await dio.get(
            "/village/get_affinity/$characterId");
        if (affinityResponse.statusCode == 200) {
          final points = affinityResponse.data?['affinity']?['points'] ?? 'N/A';
          // 캐릭터 이름과 함께 친밀도 포인트 표시
          _addLog('${_lastCollidedAnimalName}의 현재 친밀도 : $points');
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
        return characterList.any((animal) =>
        animal.isPlayer && pair.contains(animal.nickname));
      });
      _isCollidingWithPlayer = false;
      _isColliding = false;
      _lastCollidedAnimalId = null;
      _lastCollidedAnimalName = null;

      // 모든 동물 속도 재설정
      for (var i = 0; i < characterList.length; i++) {
        if (!characterList[i].isPlayer && !_activeCollisions.any((pair) =>
            pair.contains(characterList[i].nickname))) {
          _velocities[i] = _directions[_random.nextInt(_directions.length)];
        }
      }
      // _addLog('플레이어와의 충돌 해제, 동물 움직임 복구');

      // 3초 후 플레이어 충돌 감지 재활성화
      Timer(Duration(seconds: 3), () {
        setState(() {
          _disablePlayerCollision = false;
          //    _addLog('플레이어 충돌 감지 재활성화');
        });
      });
    });
  }

  void _exitCollision() {
    setState(() {
      _disablePlayerCollision = true; // 충돌 비활성화
      _activeCollisions.removeWhere((pair) {
        return characterList.any((animal) =>
        animal.isPlayer && pair.contains(animal.nickname));
      });
      _isCollidingWithPlayer = false;
      _isColliding = false;
      _lastCollidedAnimalId = null;
      _lastCollidedAnimalName = null;

      // 로그 추가
      //_addLog('충돌이 3초간 비활성화되었습니다.');

      // 3초 후 충돌 감지 재활성화
      Timer(Duration(seconds: 3), () {
        setState(() {
          _disablePlayerCollision = false;
          // _addLog('충돌 감지가 재활성화되었습니다.');
        });
      });
    });
  }
  @override
  void initState() {
    super.initState();
    _getCharacters();
    _connectWebSocket();
    _movementTimer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      if (!_isPaused && characterList.isNotEmpty && _velocities.isNotEmpty) {
        setState(() {
          int count = min(characterList.length, _velocities.length);

          // 위치 업데이트 먼저 수행
          final screenSize = MediaQuery
              .of(context)
              .size;
          final maxX = screenSize.width - 50;
          final maxY = screenSize.height - 50;
          for (var i = 0; i < count; i++) {
            if (characterList[i].isPlayer && !_isPlayerVisible) continue;
            characterList[i].x += _velocities[i].dx;
            characterList[i].y += _velocities[i].dy;
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

                String pairKey = (animalI.nickname.compareTo(animalJ.nickname) <
                    0)
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
                        '${animalI.nickname}과 ${animalJ.nickname}가(이) 충돌했습니다.');
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

            _isColliding =
                isCollidingWithPlayer || _activeCollisions.any((pair) {
                  return characterList.any((animal) =>
                  animal.isPlayer && (pair.contains(animal.nickname)));
                });

            _isCollidingWithPlayer =
                isCollidingWithPlayer || _activeCollisions.any((pair) {
                  return characterList.any((animal) =>
                  animal.isPlayer && (pair.contains(animal.nickname)));
                });
          }

          for (var i = 0; i < count; i++) {
            if (_isCollidingWithPlayer) {
              _velocities[i] = Offset.zero;
            } else if (_activeCollisions.any((pair) =>
                pair.contains(characterList[i].nickname))) {
              _velocities[i] = Offset.zero;
            } else
            if (!characterList[i].isPlayer && _velocities[i] == Offset.zero) {
              _velocities[i] = _directions[_random.nextInt(_directions.length)];
            }
          }
          _isClearingCollisions = false;
        });
      }
    });
    _directionTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (characterList.isNotEmpty && _velocities.isNotEmpty) {
        setState(() {
          int count = min(characterList.length, _velocities.length);
          for (var i = 0; i < count; i++) {
            if (_isCollidingWithPlayer) {
              _velocities[i] = Offset.zero;
            } else if (!characterList[i].isPlayer &&
                !_activeCollisions.any((pair) =>
                    pair.contains(characterList[i].nickname))) {
              _velocities[i] = _directions[_random.nextInt(_directions.length)];
            }
          }
        });
      }
    });
    _pauseTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _isPaused = !_isPaused;
        // _addLog('Pause toggled: $_isPaused');
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
  void _updatePosition(StickDragDetails details) {
    setState(() {
      if (playerCharacter != null && _isPlayerVisible) {
        final speed = 2.0;
        playerCharacter!.x += details.x * speed;
        playerCharacter!.y += details.y * speed;
        //   _addLog('Player moved to (${playerCharacter!.x.toInt()}, ${playerCharacter!.y.toInt()})');
      }
    });
  }

  void _togglePlayerVisibility() {
    setState(() {
      _isPlayerVisible = !_isPlayerVisible;
      //  _addLog('Player visibility: $_isPlayerVisible');
    });
  }

  void _startChat() async {
    if (_isCollidingWithPlayer && _lastCollidedAnimalId != null &&
        _lastCollidedAnimalName != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ChatRoomScreen(
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
    if (_isCollidingWithPlayer && _lastCollidedAnimalId != null &&
        _lastCollidedAnimalName != null) {
      _addLog('${_lastCollidedAnimalName}에게 먹이를 주었습니다.');

      // 충돌한 캐릭터의 말풍선 활성화
      final collidedAnimalIndex = characterList.indexWhere((animal) =>
      animal.character_id == _lastCollidedAnimalId);
      print(
          'Collided Animal Index: $collidedAnimalIndex, ID: $_lastCollidedAnimalId'); // 디버깅 로그 추가
      if (collidedAnimalIndex != -1) {
        print('Setting speech bubble for ${characterList[collidedAnimalIndex]
            .nickname}'); // 디버깅 로그 추가
      } else {
        print(
            'Failed to find collided animal with ID: $_lastCollidedAnimalId'); // 디버깅 로그 추가
      }

      await _updateAffinity(_lastCollidedAnimalId!, 'feeding');
      _clearPlayerCollisions();
    } else {
      _addLog('먹이를 줄 동물이 없습니다. 동물과 충돌하세요!');
    }
  }

  void _ignoreAnimal() async {
    if (_isCollidingWithPlayer && _lastCollidedAnimalId != null &&
        _lastCollidedAnimalName != null) {
      _addLog('${_lastCollidedAnimalName}을(를) 무시했습니다.'); // 캐릭터 이름 포함
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
            // 전체 화면 배경 (backgroundv2.png)
            Positioned.fill(
              child: Image.asset(
                "assets/images/backgroundv2.png",
                fit: BoxFit.cover,
              ),
            ),
            CharacterListView(
              characters: displayList,
            ),
            // 로그 창
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 0.0),
                child: Container(
                  width: 382,
                  height: 180,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage("assets/images/log.png"),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.9),
                        BlendMode.dstATop,
                      ),
                    ),
                  ),
                  child: ClipRect(
                    child: SizedBox(
                      height: 150,
                      child: _logs.isEmpty
                          ? const Center(
                        child: Text(
                          '',
                          style: TextStyle(
                            fontFamily: 'Galmuri9',
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                      )
                          : Padding(
                        padding: const EdgeInsets.only(top: 26.0, bottom: 5.0),
                        child: ListView.builder(
                          reverse: true,
                          itemCount: _logs.length,
                          shrinkWrap: true,
                          physics: ClampingScrollPhysics(),
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 2.0, horizontal: 4.0),
                              child: Text(
                                _logs[index],
                                style: const TextStyle(
                                  fontFamily: 'Galmuri9',
                                  fontSize: 12,
                                  color: Colors.black,
                                  overflow: TextOverflow.ellipsis,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 2.0,
                                      color: Colors.white,
                                      offset: Offset(1.0, 1.0),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 숨기기/보이기 버튼과 조이스틱
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSelectButton( // select.png 사용
                      onPressed: _togglePlayerVisibility,
                      text: _isPlayerVisible ? '숨기' : '나타나기',
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
// 2x2 버튼 그룹
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: AnimatedOpacity(
                  opacity: _isColliding ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSelect2Button( // select2.png 사용
                            onPressed: _startChat,
                            text: '채팅하기',
                          ),
                          const SizedBox(width: 16),
                          _buildSelect2Button( // select2.png 사용
                            onPressed: _feedAnimal,
                            text: '먹이주기',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSelect2Button( // select2.png 사용
                            onPressed: _ignoreAnimal,
                            text: '무시하기',
                          ),
                          const SizedBox(width: 16),
                          _buildSelect2Button( // select2.png 사용
                            onPressed: _exitCollision,
                            text: '나가기',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
// select.png용 버튼
  Widget _buildSelectButton({
    required VoidCallback onPressed,
    required String text,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ButtonStyle(
        padding: MaterialStateProperty.all(const EdgeInsets.all(0)),
        backgroundColor: MaterialStateProperty.all(Colors.transparent),
        foregroundColor: MaterialStateProperty.all(Colors.transparent),
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        elevation: MaterialStateProperty.all(0),
        minimumSize: MaterialStateProperty.all(const Size(80, 40)),
      ),
      child: Container(
        width: 80,
        height: 40,
        child: Stack(
          children: [
            Positioned(
              top: 10,
              left: 0,
              right: 4,
              bottom: 0,
              child: Image.asset(
                'assets/images/select.png',
                fit: BoxFit.contain,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'Galmuri9',
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// select2.png용 버튼 (크기 조정 포함)
  Widget _buildSelect2Button({
    required VoidCallback onPressed,
    required String text,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ButtonStyle(
        padding: MaterialStateProperty.all(const EdgeInsets.all(0)),
        backgroundColor: MaterialStateProperty.all(Colors.transparent),
        foregroundColor: MaterialStateProperty.all(Colors.transparent),
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        elevation: MaterialStateProperty.all(0),
        minimumSize: MaterialStateProperty.all(
            const Size(90, 48)), // 버튼 자체 크기 키움
      ),
      child: Container(
        width: 100, // 컨테이너 크기 증가
        height: 60,
        child: Stack(
          children: [
            Positioned(
              top: 13,
              // 더 큰 이미지에 맞게 조정
              left: -2,
              right: 5,
              bottom: -5,
              child: Image.asset(
                'assets/images/select2.png',
                fit: BoxFit.contain,
                width: 94, // 더 큰 너비
                height: 52, // 더 큰 높이
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12), // 텍스트 위치 조정
              child: Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'Galmuri9',
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
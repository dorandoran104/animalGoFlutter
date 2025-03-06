import 'dart:convert';
import 'package:animalgo/screens/village/Animal.dart';
import 'package:animalgo/screens/village/CharacterListView.dart';
import '../chat/ChatRoomScreen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:web_socket_channel/io.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:http/http.dart' as http;

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}
class _GameScreenState extends State<GameScreen> {
  late WebSocketChannel channel;
  List<Animal> characterList = [];
  StreamSubscription? _subscription;
  Set<String> _activeCollisions = {};
  // bool _isWebSocketConnected = false;
  Animal? playerCharacter;
  bool _isPlayerVisible = true;
  List<String> _logs = [];
  bool _isColliding = false;
  bool _isCollidingWithPlayer = false;
  String? _lastCollidedAnimalId;
  String? _lastCollidedAnimalName;
  bool _isClearingCollisions = false;
  bool _disablePlayerCollision = false;
  bool _firstDisable = true;
  final client = http.Client();
  StreamSubscription<String>? _streamingSubscription;
  // Timer? _speechBubbleTimer;


  List<Rect> blockedZones = [
    Rect.fromLTWH(0.43333, 0.0001, 0.1111, 0.6333), //가운대 선
    Rect.fromLTWH(0.00001, 0.000001, 0.99999, 0.333), // 위
    Rect.fromLTWH(0.00001, 0.69999, 0.99999, 0.99999), // 아래
  ];

  Offset _relativePosition = Offset.zero;
  final GlobalKey _imageKey = GlobalKey();
  Size _imageSize = Size.zero;

  // 움직임 관련 변수들
  late Timer _movementTimer;
  late Timer _directionTimer;
  // late Timer _pauseTimer;
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
  // void _connectWebSocket() {
  //   if (_isWebSocketConnected) return;
  //   var wsUrl = dotenv.env['WS_URL'] ?? 'ws://122.46.89.124:7000/ws';
  //   wsUrl += '/1';
  //   print(wsUrl);
  //   //_addLog('Connecting to WebSocket: $wsUrl');
  //   if (kIsWeb) {
  //     channel = WebSocketChannel.connect(Uri.parse(wsUrl));
  //   } else {
  //     channel = IOWebSocketChannel.connect(wsUrl);
  //   }
  //   _subscription = channel.stream.listen(
  //         (message) {
  //       print('Received message: $message');
  //       // _addLog('WS Received: $message');
  //     },
  //     onError: (error) {
  //       print('WebSocket error: $error');
  //       // _addLog('WS Error: $error');
  //     },
  //     onDone: () {
  //       print('WebSocket connection closed');
  //       // _addLog('WS Closed');
  //       _isWebSocketConnected = false;
  //     },
  //   );
  //   _isWebSocketConnected = true;
  // }

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
          // baseUrl: "http://127.0.0.1:8000",
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
          // characterList = data.map((json) {
          //   final animal =
          //       Animal.fromJson(json, screenSize: MediaQuery.of(context).size);

          //   print("Created animal: ${animal.nickname}");
          //   return animal;
            characterList = data.asMap().entries.map((entry) {
            final index = entry.key; // 인덱스를 사용하여 순서 지정
            final json = entry.value;
            final animal = Animal.fromJson(json, screenSize: MediaQuery.of(context).size);

            // 기존 animal.y 값에 100씩 index에 곱한 값을 더해 y 좌표가 100씩 증가하도록 설정
            // animal.y = animal.y + (index * 100);
            // animal.x = animal.x + (index * 10);

            print("Created animal: ${animal.nickname} with y: ${animal.y}");
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
              x: MediaQuery.of(context).size.width / 2,
              y: MediaQuery.of(context).size.height / 2,
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
              interaction: false,
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
      Animal player = characterList.firstWhere((animal) => animal.isPlayer);

      player.interaction = false;
      // 모든 동물 속도 재설정
      for (var i = 0; i < characterList.length; i++) {
        if (!characterList[i].isPlayer && !_activeCollisions.any((pair) =>
            pair.contains(characterList[i].nickname))) {
          _velocities[i] = _directions[_random.nextInt(_directions.length)];
        }
      }
      // _addLog('플레이어와의 충돌 해제, 동물 움직임 복구');

      // 3초 후 플레이어 충돌 감지 재활성화
      if (!mounted) return;
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
      if (!mounted) return;
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
    // _connectWebSocket();

    _movementTimer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      if (!_isPaused && characterList.isNotEmpty && _velocities.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          int count = min(characterList.length, _velocities.length);

          // 위치 업데이트 먼저 수행
          final screenSize = MediaQuery.of(context).size;
          final maxX = screenSize.width - 50;
          final maxY = screenSize.height - 50;
          for (var i = 0; i < count; i++) {
            // if (characterList[i].isPlayer && !_isPlayerVisible) continue;
            final newX = characterList[i].x + _velocities[i].dx;
            final newY = characterList[i].y + _velocities[i].dy;

            // 블록된 영역과의 충돌 체크
            bool isBlocked = false;
            
            for (var zone in blockedZones) {
              // if (characterList[i].isPlayer && !_isPlayerVisible) continue;
              final scaledZone = Rect.fromLTRB(
                zone.left * _imageSize.width,
                zone.top * _imageSize.height,
                zone.right * _imageSize.width,
                zone.bottom * _imageSize.height,
              );
              // print('Checking zone: $scaledZone with position: (${newX + 50}, ${newY + 50})');

              if (scaledZone.contains(Offset(newX, newY))) {
                isBlocked = true;
                // print('Collision detected with zone: $scaledZone');
                break;
              }
            }
            // print("캐릭터 ${i} -> 현재: (${characterList[i].x}, ${characterList[i].y}), 새 위치: ($newX, $newY), isBlocked: $isBlocked");

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
              _velocities[i] =Offset(_velocities[i].dx.abs(), _velocities[i].dy);
            } else if (characterList[i].x > maxX) {
              characterList[i].x = maxX;
              _velocities[i] =Offset(-_velocities[i].dx.abs(), _velocities[i].dy);
            }
            if (characterList[i].y < 0) {
              characterList[i].y = 0;
              _velocities[i] =Offset(_velocities[i].dx, _velocities[i].dy.abs());
            } else if (characterList[i].y > maxY) {
              characterList[i].y = maxY;
              _velocities[i] =Offset(_velocities[i].dx, -_velocities[i].dy.abs());
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
                  if (_firstDisable){
                    continue;
                  }

                  // 충돌 쌍이 아직 등록되지 않았고, 두 캐릭터가 상호작용 중이 아닌 경우
                  if (!_activeCollisions.contains(pairKey) &&
                      !animalI.interaction &&
                      !animalJ.interaction) {
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
                    // 상호작용시 다른 동물과 상호작용 안하게 설정
                    print("true");
                    animalJ.interaction = true;
                    animalI.interaction = true;

                    chatAnimal(collisionData);
                    // channel.sink.add(jsonEncode(collisionData));
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
                  // if (!isCollidingWithPlayer) {
                  //   _velocities[i] = Offset.zero;
                  //   _velocities[j] = Offset.zero;
                  // }
                } else {
                  if (_activeCollisions.contains(pairKey)) {
                    animalJ.interaction = false;
                    animalI.interaction = false;
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
    if (!mounted) return;
    Timer(Duration(seconds: 5), () {
      setState(() {
        _firstDisable = false;
      });
    });

    // 1초마다 이동을 정지/재개 (1초 정지, 1초 이동 반복)
    // _pauseTimer = Timer.periodic(Duration(seconds: 1), (timer) {
    // setState(() {
    //   _isPaused = !_isPaused;
    //   _addLog('Pause toggled: $_isPaused');
    // });
    // });
  }

  //마주치면 상호작용 시작하기
  void chatAnimal(
    collisionData,
  ) async {
    var pairKey = collisionData["pairKey"];
    String character_1_nickname = pairKey.toString().split("_")[0];
    String character_2_nickname = pairKey.toString().split("_")[1];

    Animal? character_1;
    Animal? character_2;
    int? character_1_index;
    int? character_2_index;

    List<Animal> animal_list = [];

    for (int i = 0; i < characterList.length; i++) {
      Animal animal = characterList[i];
      if (animal.nickname == character_1_nickname) {
        character_1_index = i;
        character_1 = animal;
        continue;
      }

      if (animal.nickname == character_2_nickname) {
        character_2_index = i;
        character_2 = animal;
        continue;
      }
    }

    if (character_1 == null || character_2 == null) {
      return;
    }

    if (character_1.isPlayer || character_2.isPlayer) {
      return;
    }

    animal_list.add(character_1);
    animal_list.add(character_2);

    animal_list.sort((a, b) => a.character_id.compareTo(b.character_id));

    final url = Uri.parse('http://127.0.0.1:8000/home/ai_characters_chats'); // FastAPI 엔드포인트
    // final url = Uri.parse('http://122.46.89.124:7000/home/ai_characters_chats'); // FastAPI 엔드포인트
    final request = http.MultipartRequest('POST', url);

    request.headers['Accept'] = 'text/event-stream';

    request.fields['charac_1'] = animal_list[0].character_id;
    request.fields['charac_2'] = animal_list[1].character_id;

    final streamedResponse = await client.send(request);
    var characterMap = collisionData["characters"];
    if (streamedResponse.statusCode == 200) {
      streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (String line) {
          // Timer(Duration(seconds: 3),(){
          //   setState((){
          //     speechBubble = Container();
          //   });
          // });
          speechBubble = Container();
          var jsonData = jsonDecode(line);
          var targetCharacter = characterMap
              .firstWhere((animal) => animal['id'] == jsonData['speaker']);

          var targetX = targetCharacter["x"];
          var targetY = targetCharacter["y"];
          if (!mounted) return;
          setState(() {
            speechBubble = Positioned(
              left: targetX, // 화면상의 X좌표
              top: targetY - 50, // 캐릭터 위 50픽셀 위치
              child: Container(
                padding: EdgeInsets.all(8),
                constraints: BoxConstraints(maxWidth: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black),
                ),
                child: Text(
                  jsonData["message"], // 말풍선에 표시할 내용
                  style: TextStyle(fontSize: 14, color: Colors.black),
                ),
              ),
            );
          });      
        },
        onError: (error) {
          print('Error: $error');
        },
        onDone: () {
          print('Stream completed');
          

          // client.close();
          // Timer(Duration(seconds: 3), () {
          //   if(!mounted) return
          //   setState(() {
          //     speechBubble = Container();
          //   });
          // });
          speechBubble =  Container();

          Offset direction1 = _directions[_random.nextInt(_directions.length)];
          Offset direction2;

          do {
            direction2 = _directions[_random.nextInt(_directions.length)];
          } while (direction1 == direction2);

          _velocities[character_1_index!] = direction1;
          _velocities[character_2_index!] = direction2;

          if (!_isCollidingWithPlayer) {
            if (!mounted) return;
            Timer(Duration(seconds: 3), () {
              setState(() {
                _activeCollisions.remove(pairKey);
              });

              // 다시 3초 후에 interaction 속성을 false로 설정
              if (!mounted) return;
              Timer(Duration(seconds: 10), () {
                setState(() {
                  character_1!.interaction = false;
                  character_2!.interaction = false;
                });
              });
            });
          }
          // 3초 후에 _activeCollisions에서 pairKey를 제거
        },
      );
    } else {
      print('Failed to connect: ${streamedResponse.statusCode}');
      client.close();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    // channel.sink.close();
    _movementTimer.cancel();
    _directionTimer.cancel();
    // _pauseTimer.cancel();
    _streamingSubscription?.cancel();
    client.close();
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
    Widget speechBubble = Container();

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
            child:
                Image.asset("assets/images/backgroundv2.png", fit: BoxFit.fill),
            key: _imageKey,
          ),
          
          // CustomPaint(
          //             size : Size.infinite,
          //             painter : GamePainter(blockedZones, _relativePosition, _imageSize)
          //           ),
          CharacterListView(
            characters: displayList,
          ),
          speechBubble,
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0),
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
import 'dart:async';
import 'dart:math';
import '../chat/ChatListScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import '../myPage/my_page.dart';
import '../home/HomeScreen.dart';
import '../../components/BottomBar.dart';

class VillageScreen extends StatefulWidget {
  @override
  _VillageScreenState createState() => _VillageScreenState();
}

class _VillageScreenState extends State<VillageScreen> {
  final Random random = Random();
  final double screenWidth = 360; // 배경 사이즈 (가로)
  final double screenHeight = 600; // 배경 사이즈 (세로)

  double characterX = 0;
  double characterY = 0;
  double speed = 5.0;

  double get playerAbsoluteX => characterX + MediaQuery.of(context).size.width / 2 - 25;
  double get playerAbsoluteY => characterY + MediaQuery.of(context).size.height / 2 - 25;

  List<Map<String, dynamic>> characters = [];
  List<bool> isPaused = []; // 캐릭터 멈춤 여부
  List<Map<String, dynamic>> speechBubbles = []; // 말풍선 리스트

  // ✅ 사용할 여러 개의 캐릭터 이미지 (왼쪽/오른쪽 방향)
  final List<Map<String, String>> characterSprites = [
    {"left": "assets/images/cat_left.png", "right": "assets/images/cat_right.png"},
    {"left": "assets/images/cow_left.png", "right": "assets/images/cow_right.png"},
    {"left": "assets/images/dog_left.png", "right": "assets/images/dog_right.png"},
    {"left": "assets/images/bear_left.png", "right": "assets/images/bear_right.png"},
    {"left": "assets/images/horse_left.png", "right": "assets/images/horse_right.png"},
    {"left": "assets/images/zebra_left.png", "right": "assets/images/zebra_right.png"}
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      double screenWidth = MediaQuery.of(context).size.width;
      double screenHeight = MediaQuery.of(context).size.height;

      for (int i = 0; i < 6; i++) {
        double initialX = getRandomX(screenWidth);
        double initialY = getRandomY(screenHeight);
        characters.add({
          'x': initialX, // 목표 X 좌표
          'y': initialY, // 목표 Y 좌표
          'currentX': initialX, // 현재 X 좌표
          'currentY': initialY, // 현재 Y 좌표
          'prevX': initialX, // 이전 X 좌표
          'prevY': initialY, // 이전 Y 좌표
          'direction': "right",
          'sprite': characterSprites[i],
          'moveDuration': 3000, // 이동에 걸리는 시간 (밀리초)
          'elapsedTime': 0, // 경과 시간
          'speed': 100.0, // 초당 이동 거리 (픽셀)
        });
        isPaused.add(false);
      }});

    // 단일 타이머로 목표 좌표 설정 및 보간 처리
    Timer.periodic(Duration(milliseconds: 16), (timer) { // 약 60fps
      if (mounted) {
        setState(() {
          double screenWidth = MediaQuery.of(context).size.width;
          double screenHeight = MediaQuery.of(context).size.height;

          for (int i = 0; i < characters.length; i++) {
            if (!isPaused[i]) {
              var char = characters[i];
              int currentTime = DateTime.now().millisecondsSinceEpoch;

              // 이동 완료 시 새 목표 설정
              if (char['elapsedTime'] >= char['moveDuration']) {
                char['prevX'] = char['currentX'];
                char['prevY'] = char['currentY'];
                char['x'] = getRandomX(screenWidth);
                char['y'] = getRandomY(screenHeight);
                char['elapsedTime'] = 0;

                // 방향 설정
                char['direction'] = char['x'] > char['currentX'] ? "right" : "left";

                // 새 목표까지의 거리에 따라 이동 시간 계산
                double dx = char['x'] - char['currentX'];
                double dy = char['y'] - char['currentY'];
                double distance = sqrt(dx * dx + dy * dy);
                char['moveDuration'] = (distance / char['speed'] * 1000).toInt();
              }

              // 선형 보간으로 부드럽게 이동
              double progress = char['elapsedTime'] / char['moveDuration'];
              char['currentX'] = char['prevX'] + (char['x'] - char['prevX']) * progress.clamp(0.0, 1.0);
              char['currentY'] = char['prevY'] + (char['y'] - char['prevY']) * progress.clamp(0.0, 1.0);
              char['elapsedTime'] += 16; // 프레임당 경과 시간 증가
            }
          }
          _checkPlayerCollision();
        });
      }
    });
  }

  double getRandomX(double screenWidth) {
    return random.nextDouble() * (screenWidth - 50);
  }

  double getRandomY(double screenHeight) {
    return random.nextDouble() * (screenHeight - 50);
  }

  void _updateCharacterPositions() {
    for (int i = 0; i < characters.length; i++) {
      double progress = 0.5; // 🔥 이동 중간 위치를 사용
      characters[i]['currentX'] = getCurrentPosition(characters[i]['prevX'], characters[i]['x'], progress);
      characters[i]['currentY'] = getCurrentPosition(characters[i]['prevY'], characters[i]['y'], progress);
    }
  }

  // 위치 업데이트 메서드 수정
  void _updatePosition(StickDragDetails details) {
    setState(() {
      characterX += details.x * speed;
      characterY += details.y * speed;

      // 플레이어가 화면 밖으로 나가지 않도록 제한
      double screenWidth = MediaQuery.of(context).size.width;
      double screenHeight = MediaQuery.of(context).size.height;
      characterX = characterX.clamp(-screenWidth / 2 + 25, screenWidth / 2 - 25);
      characterY = characterY.clamp(-screenHeight / 2 + 25, screenHeight / 2 - 25);
    });
    _checkPlayerCollision(); // 충돌 감지 실행
  }

  double getCurrentPosition(double start, double end, [double progress = 0.5]) {
    return start + (end - start) * progress;
  }
  /// ✅ 충돌 감지 및 멈춤 처리
  Set<int> detectedCharacters = {};

  void _checkPlayerCollision() {
    // 플레이어의 절대 좌표 계산 (화면 좌측 상단 기준)
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double adjustedCharacterX = screenWidth / 2 + characterX; // 중심점
    double adjustedCharacterY = screenHeight / 2 + characterY; // 중심

    // print("플레이어 위치: ($adjustedCharacterX, $adjustedCharacterY)");

    for (int i = 0; i < characters.length; i++) {
      // NPC 캐릭터의 실시간 절대 좌표 사용
      double realX = characters[i]['currentX'];
      double realY = characters[i]['currentY'];
      // print("NPC[$i] 위치: ($realX, $realY)");

      // 거리 계산
      double dx = adjustedCharacterX - realX;
      double dy = adjustedCharacterY - realY;
      double distance = sqrt(dx * dx + dy * dy);
      // print("NPC[$i]와의 거리: $distance");

      // 충돌 감지 범위 (50으로 설정)
      if (distance < 50) {
        if (!detectedCharacters.contains(i)) {
          detectedCharacters.add(i);
          _showInteractionDialog(i);
        }
      } else {
        detectedCharacters.remove(i);
      }
    }
  }

  /// ✅ 채팅하기 동작
  void _startChat(int characterIndex) {
    setState(() {
      speechBubbles.add({
        'id': "player_chat_${DateTime.now().millisecondsSinceEpoch}",
        'x': characters[characterIndex]['currentX'], // NPC의 실시간 X 좌표
        'y': characters[characterIndex]['currentY'] - 50, // NPC 위에 표시
        'message': "안녕! 대화하자!",
      });
    });

    Future.delayed(Duration(seconds: 3), () {
      setState(() {
        speechBubbles.removeWhere((bubble) => bubble['id'].toString().startsWith("player_chat"));
      });
    });
  }

  /// ✅ 쓰다듬기 동작
  void _petCharacter(int characterIndex) {
    setState(() {
      speechBubbles.add({
        'id': "player_pet_${DateTime.now().millisecondsSinceEpoch}",
        'x': characters[characterIndex]['currentX'], // NPC의 실시간 X 좌표
        'y': characters[characterIndex]['currentY'] - 40, // NPC 위에 표시
        'message': "🤗 기분 좋아 보이네!",
      });
    });

    Future.delayed(Duration(seconds: 3), () {
      setState(() {
        speechBubbles.removeWhere((bubble) => bubble['id'].toString().startsWith("player_pet"));
      });
    });
  }

  /// ✅ 플레이어 충돌 시 선택 UI 표시
  bool isDialogOpen = false; // 다이얼로그 중복 실행 방지

  void _showInteractionDialog(int characterIndex) {
    if (isDialogOpen) return; // 🔥 이미 다이얼로그가 떠 있으면 실행 안 함

    isDialogOpen = true; // 다이얼로그 열림 상태 변경

    print("🛠 다이얼로그 실행 시도! 캐릭터[$characterIndex]");

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("무엇을 할까요?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startChat(characterIndex); // 채팅 시작
                },
                child: Text("💬 채팅하기"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _petCharacter(characterIndex); // 쓰다듬기 동작
                },
                child: Text("🤗 쓰다듬기"),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      isDialogOpen = false; // 다이얼로그가 닫힐 때 상태 변경
      print("🛠 다이얼로그가 닫혔습니다.");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("마을")),
      body: Stack(
        children: [
          // 배경 이미지
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.jpg', // 배경 이미지
              fit: BoxFit.cover,
            ),
          ),
          // ✅ 캐릭터 (파란색 원)
          Positioned(
            left: characterX + MediaQuery.of(context).size.width / 2 - 25,
            top: characterY + MediaQuery.of(context).size.height / 2 - 25,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ),

          // ✅ Joystick 추가 (화면 왼쪽 하단)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: SizedBox(
                width: 80, // ✅ 조이스틱 크기 조절 (기본값보다 작게)
                height: 80,
                child: Joystick(
                  mode: JoystickMode.all, // 모든 방향 가능 (상하좌우 + 대각선)
                  listener: (details) {
                    _updatePosition(details);
                  },
                ),
              ),
            ),
          ),


          // 캐릭터들을 랜덤하게 배치
          for (int i = 0; i < characters.length; i++)
            Positioned(
              left: characters[i]['currentX'],
              top: characters[i]['currentY'],
              child: Image.asset(
                characters[i]['sprite'][characters[i]['direction']]!,
                width: 50,
                height: 50,
              ),
            ),
          // ✅ 말풍선 추가
          for (var bubble in speechBubbles)
            Positioned(
              left: bubble['x'],
              top: bubble['y'],
              child: _buildSpeechBubble(bubble['message']),
            ),
        ],

      ),

      bottomNavigationBar: Bottombar(
        currentIndex: 1,
        onTabSelected: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(),
                  transitionDuration: Duration.zero,
                ),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => VillageScreen(),
                  transitionDuration: Duration.zero,
                ),
              );
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => ChatListScreen(),
                  transitionDuration: Duration.zero,
                ),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => MyPage(),
                  transitionDuration: Duration.zero,
                ),
              );
              break;
          }
        },
      ),
    );
  }
  /// ✅ 말풍선 UI
  Widget _buildSpeechBubble(String message) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
///✅ 말풍선 UI
// Widget _Joystick_menual(BuildContext context) {
//   return Scaffold(
//     backgroundColor: Colors.white,
//     body: Stack(
//       children: [
//         // ✅ 캐릭터 (파란색 원)
//         Positioned(
//           left: characterX + MediaQuery.of(context).size.width / 2 - 25,
//           top: characterY + MediaQuery.of(context).size.height / 2 - 25,
//           child: Container(
//             width: 50,
//             height: 50,
//             decoration: BoxDecoration(
//               color: Colors.blue,
//               shape: BoxShape.circle,
//             ),
//           ),
//         ),
//
//         // ✅ Joystick 추가 (화면 왼쪽 하단)
//         Align(
//           alignment: Alignment.bottomLeft,
//           child: Padding(
//             padding: const EdgeInsets.all(32.0),
//             child: Joystick(
//               mode: JoystickMode.all, // 모든 방향 가능 (상하좌우 + 대각선)
//               listener: (details) {
//                 _updatePosition(details);
//               },
//             ),
//           ),
//         ),
//       ],
//     ),
//   );
// }
}

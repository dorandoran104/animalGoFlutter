import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import '../models/character.dart';
import 'character_movement.dart';
import 'skill_manager.dart';
import 'collision_detector.dart';
import 'speech_bubble.dart';
import '../../../components/BottomBar.dart';
import '../../home/Homescreen.dart';
import '../../chat/ChatListScreen.dart';
import '../../myPage/my_page.dart';

class VillageScreen extends StatefulWidget {
  final String selectedCharacter;
  VillageScreen({required this.selectedCharacter});

  @override
  _VillageScreenState createState() => _VillageScreenState();
}

class _VillageScreenState extends State<VillageScreen> with SingleTickerProviderStateMixin {
  late CharacterMovement movement;
  late SkillManager skillManager;
  late CollisionDetector collisionDetector;
  List<Character> characters = [];
  List<Map<String, dynamic>> speechBubbles = [];
  Random random = Random();
  late AnimationController _jumpController;
  late Animation<double> _jumpAnimation;
  bool isJumping = false;
  bool isJumpSkillActive = false;

  @override
  void initState() {
    super.initState();

    movement = CharacterMovement(
      screenWidth: 360,
      screenHeight: 600,
      speed: 5.0,
      characterX: 0,
      characterY: 0,
    );

    skillManager = SkillManager(
      onHitDetected: _checkSkillHits,
      onSkillEnd: () => setState(() {}),
    );

    collisionDetector = CollisionDetector();

    characters = movement.initializeCharacters(_getCharacterSprites(), 5);
    movement.startMovingCharacters(characters, () => setState(() {}));

    _jumpController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500), // 점프 시간
    );
    _jumpAnimation = Tween<double>(begin: 0, end: -50) // 위로 50px 이동
        .animate(
        CurvedAnimation(parent: _jumpController, curve: Curves.easeOut));

    _jumpController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _jumpController.reverse(); // 점프 후 다시 내려옴
      } else if (status == AnimationStatus.dismissed) {
        setState(() {
          isJumping = false; // 점프 종료
        });
      }
    });

    movement.startMovingCharacters(characters, () => setState(() {}));
    _checkCollisions;
  }

  /// ✅ **캐릭터 스프라이트 데이터를 제공하는 함수 추가**
  List<Map<String, String>> _getCharacterSprites() {
    return [
      {
        "left": "assets/images/bear_left.png",
        "right": "assets/images/bear_right.png"
      },
      {
        "left": "assets/images/cat_left.png",
        "right": "assets/images/cat_right.png"
      },
      {
        "left": "assets/images/cow_left.png",
        "right": "assets/images/cow_right.png"
      },
      {
        "left": "assets/images/dog_left.png",
        "right": "assets/images/dog_right.png"
      },
      {
        "left": "assets/images/horse_left.png",
        "right": "assets/images/horse_right.png"
      },
      {
        "left": "assets/images/zebra_left.png",
        "right": "assets/images/zebra_right.png"
      }
    ];
  }

  void _checkCollisions() {
    for (int i = 0; i < characters.length; i++) {
      for (int j = i + 1; j < characters.length; j++) {
        if (collisionDetector.isColliding(characters[i], characters[j])) {
          collisionDetector.handleCollision(
              characters, i, j, _showSpeechBubbles, () => setState(() {}));
        }
      }
    }
  }

  /// ✅ 충돌 시 두 캐릭터 모두 말풍선을 띄우도록 설정
  void _showSpeechBubbles(int i, int j) {
    if (!mounted) return; // 🚀 위젯이 제거되었으면 실행 안 함
    String bubbleId1 = "${i}_${DateTime
        .now()
        .millisecondsSinceEpoch}";
    String bubbleId2 = "${j}_${DateTime
        .now()
        .millisecondsSinceEpoch}";

    List<String> messages = [
      "안녕!", "반가워!", "좋은 날이야!", "뭐해?", "같이 놀자!", "재밌겠다!"
    ];
    String message1 = messages[random.nextInt(messages.length)];
    String message2 = messages[random.nextInt(messages.length)];

    setState(() {
      speechBubbles.add({
        'id': bubbleId1,
        'x': characters[i].x,
        'y': characters[i].y - 40,
        'message': message1,
      });
      speechBubbles.add({
        'id': bubbleId2,
        'x': characters[j].x,
        'y': characters[j].y - 40,
        'message': message2,
      });
    });

    // ✅ 6초 후 말풍선 삭제
    Future.delayed(Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() {
        speechBubbles.removeWhere(
                (bubble) =>
            bubble['id'] == bubbleId1 || bubble['id'] == bubbleId2);
      });
    });
  }

  void _checkSkillHits() {
    double skillRange = 48;
    for (var character in characters) {
      if (collisionDetector.isWithinRange(
          movement.characterX, movement.characterY, character.x, character.y,
          skillRange)) {
        setState(() {
          speechBubbles.add(
              {'x': character.x, 'y': character.y - 40, 'message': "HIT!"});
        });

        Future.delayed(Duration(seconds: 1), () {
          if (!mounted) return;
          setState(() {
            speechBubbles.removeWhere((bubble) => bubble['message'] == "HIT!");
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _jumpController.dispose();
    super.dispose();
  }

  /// ✅ 점프 버튼 클릭 시 실행
  void _jump() {
    if (!isJumping) {
      setState(() {
        isJumping = true;
      });
      _jumpController.forward(); // 점프 시작
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("마을")),
      body: Stack(
        children: [
          _buildBackground(),
          _buildCharacters(),
          _buildSpeechBubbles(),
          _buildCharacterAnimation(),
          _buildJumpSkillAnimation(),
          _buildJoystick(),
          _buildSkillButton(),
          _buildJumpButton(),
        ],
      ),
      bottomNavigationBar: Bottombar(
        currentIndex: 1,
        onTabSelected: _handleNavigation,
      ),
    );
  }

  /// ✅ 사용자 캐릭터 기본 이미지 (조이스틱 이동)
  Widget _buildCharacter() {
    String imagePath = 'assets/images/walk/${widget.selectedCharacter}_walk_${movement.characterDirection}_${movement.animationFrame}.png';
    print("🖼️ Loading Image: $imagePath"); // ✅ 현재 표시 중인 이미지 확인

    return Positioned(
      left: movement.characterX,
      top: movement.characterY,
      child: Image.asset(
        imagePath,
        width: 50,
        height: 50,
      ),
    );
  }


  /// ✅ 캐릭터 애니메이션을 올바르게 관리하는 위젯
  Widget _buildCharacterAnimation() {
    return Stack(
      children: [
        if (!isJumping && !skillManager.isUsingSkill &&
            !isJumpSkillActive) // ✅ 기본 상태에서만 캐릭터 표시
          _buildCharacter(),

        if (isJumping && !isJumpSkillActive) // ✅ 점프 중이지만 점프 스킬이 아닐 때만 표시
          _buildJumpAnimation(),

        if (isJumpSkillActive) // ✅ 점프 스킬 실행 시 점프 애니메이션 대신 표시
          _buildJumpSkillAnimation(),

        if (skillManager.isUsingSkill) // ✅ 일반 스킬 실행 시 해당 애니메이션 표시
          _buildSkillAnimation(),
      ],
    );
  }

  /// ✅ 배경 이미지
  Widget _buildBackground() {
    return Positioned.fill(
      child: Image.asset('assets/images/background.jpg', fit: BoxFit.cover),
    );
  }


  /// ✅ 캐릭터 배치
  Widget _buildCharacters() {
    return Stack(
      children: characters.map((character) {
        return AnimatedPositioned(
          duration: Duration(seconds: 6),
          left: character.x,
          top: character.y,
          child: Image.asset(
            character.sprite[character.direction]!,
            width: 50,
            height: 50,
          ),
        );
      }).toList(),
    );
  }

  /// ✅ 말풍선 표시
  Widget _buildSpeechBubbles() {
    return Stack(
      children: speechBubbles.map((bubble) {
        return Positioned(
          left: bubble['x'],
          top: bubble['y'],
          child: SpeechBubble(message: bubble['message']),
        );
      }).toList(),
    );
  }

  /// ✅ 사용자 캐릭터의 점프 애니메이션 표시 (점프 중일 때만 실행)
  Widget _buildJumpAnimation() {
    return AnimatedBuilder(
      animation: _jumpAnimation,
      builder: (context, child) {
        return Positioned(
          left: movement.characterX,
          top: movement.characterY + _jumpAnimation.value,
          child: Image.asset(
            'assets/images/jump/${widget.selectedCharacter}_jump_${movement
                .characterDirection}.png',
            width: 50,
            height: 50,
          ),
        );
      },
    );
  }


  /// ✅ 스킬 애니메이션 (스킬 실행 중일 때만 표시)
  Widget _buildSkillAnimation() {
    return skillManager.isUsingSkill
        ? Positioned(
      left: movement.characterX,
      top: movement.characterY,
      child: skillManager
          .getSkillFrames(widget.selectedCharacter, movement.characterDirection)
          .isNotEmpty
          ? Image.asset(
        skillManager.getSkillFrames(
            widget.selectedCharacter, movement.characterDirection)[skillManager
            .currentFrame],
        width: 50,
        height: 50,
      )
          : SizedBox(),
    )
        : SizedBox();
  }

  /// ✅ 점프 스킬 애니메이션 표시
  Widget _buildJumpSkillAnimation() {
    return skillManager.isUsingJumpSkill
        ? Positioned(
      left: movement.characterX,
      top: movement.characterY + _jumpAnimation.value,
      child: skillManager
          .getJumpSkillFrames(
          widget.selectedCharacter, movement.characterDirection)
          .isNotEmpty
          ? Image.asset(
        skillManager.getJumpSkillFrames(
            widget.selectedCharacter, movement.characterDirection)[skillManager
            .currentFrame],
        width: 50,
        height: 50,
      )
          : SizedBox(),
    )
        : SizedBox();
  }

  /// ✅ 조이스틱 추가
  Widget _buildJoystick() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: SizedBox(
          width: 80,
          height: 80,
          child: Joystick(
            mode: JoystickMode.all,
            listener: (details) {
              if (details.x == 0 && details.y == 0) {
                movement.stopAnimation(() => setState(() {})); // ⬅️ 이동 멈출 때 기본 프레임 유지
              } else {
                movement.updatePosition(details, () => setState(() {})); // ⬅️ 이동할 때 애니메이션 실행
              }
            },
          ),
        ),
      ),
    );
  }


  /// ✅ 스킬 버튼 추가
  Widget _buildSkillButton() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: ElevatedButton(
          onPressed: isJumping ? null : () =>
              skillManager.playSkillAnimation(() => setState(() {})),
          style: ElevatedButton.styleFrom(
            shape: CircleBorder(),
            padding: EdgeInsets.all(10),
            backgroundColor: isJumping ? Colors.grey : Colors.red,
          ),
          child: Icon(Icons.flash_on, size: 15, color: Colors.white),
        ),
      ),
    );
  }

  /// ✅ 점프 & 점프 스킬 버튼 자동 전환
  Widget _buildJumpButton() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [

              /// ✅ 점프 버튼 (점프 전만 활성화)
              Visibility(
                visible: !isJumping && !skillManager.isUsingSkill,
                child: ElevatedButton(
                  onPressed: () {
                    if (!skillManager.isUsingSkill) { // ✅ 스킬 중이 아니면 점프 가능
                      _jump();
                    }
                    },
                  style: ElevatedButton.styleFrom(
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(10),
                    backgroundColor: Colors.blue,
                  ),
                  child: Icon(
                      Icons.arrow_upward, size: 20, color: Colors.white),
                ),
              ),

              /// ✅ 점프 스킬 버튼 (점프 중일 때만 활성화)
              Visibility(
                visible: isJumping && !skillManager.isUsingSkill,
                child: ElevatedButton(
                  onPressed: () {
                    if (!skillManager.isUsingSkill) {
                      setState(() {
                        isJumpSkillActive = true; // ✅ 점프 스킬 실행 시 기본 점프 애니메이션 숨김
                      });
                      skillManager.playJumpSkillAnimation(() {
                        setState(() {
                          isJumpSkillActive = false; // ✅ 점프 스킬 종료 시 원래 상태 복귀
                          isJumping = false; // ✅ 점프 종료 처리
                        });
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(10),
                    backgroundColor: Colors.purple,
                  ),
                  child: Icon(
                      Icons.airplanemode_active, size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  /// ✅ 네비게이션 핸들러
  void _handleNavigation(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(selectedCharacter: widget.selectedCharacter),
            transitionDuration: Duration.zero,
          ),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => VillageScreen(selectedCharacter: widget.selectedCharacter),
            transitionDuration: Duration.zero,
          ),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => ChatListScreen(selectedCharacter: widget.selectedCharacter),
            transitionDuration: Duration.zero,
          ),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => MyPage(selectedCharacter: widget.selectedCharacter),
            transitionDuration: Duration.zero,
          ),
        );
        break;
    }
  }
}

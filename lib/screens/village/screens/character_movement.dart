import 'dart:async';
import 'dart:math';
import 'package:flutter_joystick/flutter_joystick.dart';
import '../models/character.dart';

class CharacterMovement {
  final double screenWidth;
  final double screenHeight;
  final double speed;
  double characterX;
  double characterY;
  String characterDirection = "down";
  int animationFrame = 0; // 걷는 모션을 위한 애니메이션 프레임
  final Random random = Random();
  Timer? _movementTimer;
  Timer? _animationTimer;

  CharacterMovement({
    required this.screenWidth,
    required this.screenHeight,
    required this.speed,
    required this.characterX,
    required this.characterY,
  });

  /// ✅ **NPC(동물)들이 자동으로 이동하도록 설정**
  void startMovingCharacters(List<Character> characters, Function updateUI) {
    _movementTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      for (var character in characters) {
        if (!character.isPaused) {
          double newX = random.nextDouble() * (screenWidth - 50);
          double newY = random.nextDouble() * (screenHeight - 50);
          String newDirection = newX < character.x ? "left" : "right";

          character.x = newX;
          character.y = newY;
          character.direction = newDirection;
        }
      }
      updateUI();
    });
  }

  /// ✅ **조이스틱 이동 처리 + 걷는 모션 추가**
  void updatePosition(StickDragDetails details, Function updateUI) {
    print("🎮 Joystick moved - Starting Animation");
    double newX = characterX + details.x * speed;
    double newY = characterY + details.y * speed;

    if (newX >= 0 && newX <= screenWidth - 50) characterX = newX;
    if (newY >= 0 && newY <= screenHeight - 50) characterY = newY;

    if (details.y < -0.5) characterDirection = "up";
    else if (details.y > 0.5) characterDirection = "down";
    else if (details.x < -0.5) characterDirection = "left";
    else if (details.x > 0.5) characterDirection = "right";

    if (_animationTimer == null || !_animationTimer!.isActive) {
      startAnimation(updateUI);
    }
    updateUI();
  }

  /// ✅ **애니메이션 시작 (2프레임 반복)**
  void startAnimation(Function updateUI) {
    _animationTimer?.cancel(); // 기존 타이머 취소
    _animationTimer = Timer.periodic(Duration(milliseconds: 200), (timer) {
      animationFrame = (animationFrame + 1) % 2; // 0과 1을 번갈아 변경
      print("🔄 Animation Frame Changed: $animationFrame");
      updateUI();
    });
  }

  /// ✅ **애니메이션 정지 (멈추면 기본 프레임으로)**
  void stopAnimation(Function updateUI) {
    _animationTimer?.cancel();
    animationFrame = 0; // 기본 프레임으로 초기화
    updateUI();
  }

  /// ✅ **캐릭터 초기화 함수 (NPC 스프라이트 설정)**
  List<Character> initializeCharacters(List<Map<String, String>> characterSprites, int count) {
    List<Character> characters = [];

    for (int i = 0; i < count; i++) {
      characters.add(Character(
        x: random.nextDouble() * (screenWidth - 50),
        y: random.nextDouble() * (screenHeight - 50),
        direction: random.nextBool() ? "left" : "right",
        sprite: characterSprites[i % characterSprites.length],
      ));
    }
    return characters;
  }

  /// ✅ **NPC 이동 정지 + 애니메이션 정지**
  void stopMovingCharacters() {
    _movementTimer?.cancel();
    _animationTimer?.cancel();
  }
}

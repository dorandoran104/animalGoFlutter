import '../models/character.dart';

class CollisionDetector {
  bool isColliding(Character c1, Character c2) {
    double dx = (c1.x - c2.x).abs();
    double dy = (c1.y - c2.y).abs();
    return dx < 50 && dy < 50;
  }
  /// ✅ 충돌한 캐릭터를 6초 동안 멈춘 후, 말풍선 표시
  void handleCollision(
      List<Character> characters, int i, int j, Function showSpeechBubble, Function updateUI) {
    if (!characters[i].isPaused && !characters[j].isPaused) {
      characters[i].isPaused = true;
      characters[j].isPaused = true;
      updateUI(); // UI 업데이트

      // 6초 후 다시 이동 가능하게 설정
      Future.delayed(Duration(seconds: 6), () {
        characters[i].isPaused = false;
        characters[j].isPaused = false;
        updateUI();
      });

      // ✅ 충돌 시 말풍선 표시
      showSpeechBubble(i, j);
    }
  }

  void pauseCharacters(List<Character> characters, int i, int j, Function updateUI) {
    if (!characters[i].isPaused && !characters[j].isPaused) {
      characters[i].isPaused = true;
      characters[j].isPaused = true;
      updateUI();

      Future.delayed(Duration(seconds: 6), () {
        characters[i].isPaused = false;
        characters[j].isPaused = false;
        updateUI();
      });
    }
  }

  /// ✅ 캐릭터와 스킬이 충돌했는지 감지하는 함수 추가
  bool isWithinRange(double x1, double y1, double x2, double y2, double range) {
    return (x1 - x2).abs() < range && (y1 - y2).abs() < range;
  }
}

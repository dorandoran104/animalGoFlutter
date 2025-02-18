class Character {
  double x;
  double y;
  String direction;
  Map<String, String> sprite;
  bool isPaused = false; // ✅ 충돌 시 캐릭터를 멈출 수 있도록 추가

  Character({
    required this.x,
    required this.y,
    required this.direction,
    required this.sprite,
  });
}

import 'package:flutter/material.dart';
import 'dart:math';

class Animal {
  double x;
  double y;
  final double size = 40;
  final String characterPath;
  final String originalPath;
  final String animalType;
  final String appearance;
  final String nickname;
  final String personality;
  final String status;
  final String userId;
  final String character_id;

  Animal({
    required this.x,
    required this.y,
    required this.characterPath,
    required this.originalPath,
    required this.animalType,
    required this.appearance,
    required this.nickname,
    required this.personality,
    required this.status,
    required this.userId,
    required this.character_id
  });

factory Animal.fromJson(Map<String, dynamic> json, {Size? screenSize, double containerSize = 40.0}) {
  double x, y;
  if (screenSize != null) {
    // 화면 내에 캐릭터가 들어갈 수 있는 최대값을 구함.
    final Random random = Random();
    final double maxX = screenSize.width - containerSize;
    final double maxY = screenSize.height - containerSize;
    x = 150;
    y = 400;
    // x = random.nextDouble() * maxX;
    // y = random.nextDouble() * maxY;
  } else {
    // x = json['position_x']?.toDouble() ?? 50.0;
    // y = json['position_y']?.toDouble() ?? 100.0;
    x = 150;
    y = 400;
  }
  return Animal(
    x: x,
    y: y,
    characterPath: json['character_path'] ?? '',
    originalPath: json['original_path'] ?? '',
    animalType: json['animaltype'] ?? '',
    appearance: json['appearance'] ?? '',
    nickname: json['nickname'] ?? '',
    personality: json['personality'] ?? '',
    status: json['status'] ?? '',
    userId: json['user_id'] ?? '',
    character_id: json["character_id"] ?? ""
  );
}
}
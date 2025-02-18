import 'dart:async';
import 'package:flutter/material.dart';

class SkillManager {
  bool isUsingSkill = false;
  bool isUsingJumpSkill = false;
  int currentFrame = 0;
  Function onHitDetected;
  Function onSkillEnd;

  SkillManager({required this.onHitDetected, required this.onSkillEnd});

  /// ✅ 점프 스킬 애니메이션 프레임 가져오기
  List<String> getJumpSkillFrames(String userCharacter, String direction) {
    return [
      "assets/images/jump_skill/${userCharacter}_jump_skill_1_${direction}.png",
      "assets/images/jump_skill/${userCharacter}_jump_skill_2_${direction}.png",
      "assets/images/jump_skill/${userCharacter}_jump_skill_3_${direction}.png",
      "assets/images/jump_skill/${userCharacter}_jump_skill_4_${direction}.png",
    ];
  }

  List<String> getSkillFrames(String userCharacter, String direction) {
    if (direction == "up" || direction == "down") return [];
    return [
      "assets/images/skill/${userCharacter}_skill_1_${direction}.png",
      "assets/images/skill/${userCharacter}_skill_2_${direction}.png",
      "assets/images/skill/${userCharacter}_skill_3_${direction}.png",
      "assets/images/skill/${userCharacter}_skill_4_${direction}.png",
    ];
  }

  void playSkillAnimation(VoidCallback updateUI) {
    isUsingSkill = true;
    currentFrame = 0;

    Timer.periodic(Duration(milliseconds: 200), (timer) {
      if (currentFrame < 3) {
        currentFrame++;
        onHitDetected();
        updateUI();
      } else {
        timer.cancel();
        isUsingSkill = false;
        onSkillEnd();
        updateUI();
      }
    });
  }
  void playJumpSkillAnimation(VoidCallback updateUI) {
      isUsingJumpSkill = true;
      currentFrame = 0;

    Timer.periodic(Duration(milliseconds: 250), (timer) {
      if (currentFrame < 3) {
          currentFrame++;
          onHitDetected();
      } else {
        timer.cancel();
          isUsingJumpSkill = false;
          onSkillEnd();
          updateUI();
      }
    });
  }
}

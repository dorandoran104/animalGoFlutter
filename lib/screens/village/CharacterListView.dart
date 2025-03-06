import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'Animal.dart';
import 'dart:async';
import 'dart:math';

class CharacterListView extends StatefulWidget {
  final List<Animal> characters;
  final Animal? playerCharacter; // ✅ 플레이어 캐릭터 추가

  const CharacterListView({
    Key? key,
    required this.characters,
    this.playerCharacter, // ✅ 추가
  }) : super(key: key);

  @override
  _CharacterListViewState createState() => _CharacterListViewState();
}

class _CharacterListViewState extends State<CharacterListView> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: widget.characters.map((character) {
        final isPlayer = character.isPlayer; // 플레이어 캐릭터 여부 확인
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 16),
          curve: Curves.linear,
          left: character.x,
          top: character.y,
          child: GestureDetector(
            onTap: () {
              print('${isPlayer ? "Player" : "Character"} clicked: ${character.nickname}');
              print('${character}');
            },
            child: Container(
              width: isPlayer ? 60 : 50, // 플레이어 캐릭터 크기 키움
              height: isPlayer ? 60 : 50,
              decoration: isPlayer
                  ? BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 3), // 파란 테두리
                shape: BoxShape.circle,
              )
                  : null,
              child: CircleAvatar(
                radius: isPlayer ? 25 : 20,
                backgroundImage: isPlayer
                    ? const AssetImage('assets/images/char1.png') as ImageProvider
                    : NetworkImage('${dotenv.env['SERVER_URL']}/image/show_image?character_id=${character.character_id}&type=village') as ImageProvider,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
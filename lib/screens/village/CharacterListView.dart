import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'Animal.dart';
import 'dart:async';
import 'dart:math';
class CharacterListView extends StatefulWidget {
  final List<Animal> characters;

  const CharacterListView({
    Key? key,
    required this.characters,
  }) : super(key: key);

  @override
  _CharacterListViewState createState() => _CharacterListViewState();
}

class _CharacterListViewState extends State<CharacterListView> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: widget.characters.map((character) {
        return AnimatedPositioned(
          duration: Duration(milliseconds: 16),
          curve: Curves.linear,
          left: character.x,
          top: character.y,
          child: GestureDetector(
            onTap: () {
              print('Character clicked: ${character.nickname}');
            },
            child: Container(
              width: 50,
              height: 50,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(
                      '${dotenv.env['SERVER_URL']}/image/show_image?character_id=${character.character_id}'
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
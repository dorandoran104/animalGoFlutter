import 'package:animalgo/screens/home/HomeScreen.dart';
import 'package:animalgo/screens/login/LoginScreen.dart';
import 'package:flutter/material.dart';
import 'screens/village_screen.dart'; // 마을 화면 import

class CharacterSelectScreen extends StatefulWidget {
  @override
  _CharacterSelectScreenState createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  final List<String> characters = [
    "carnage",
    "venom",
    "toxin",
    "anti_venom",
  ];

  String selectedCharacter = "carnage"; // 기본 선택 캐릭터

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, title: Text("캐릭터 선택")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("캐릭터를 선택하세요!", style: TextStyle(fontSize: 20)),
              SizedBox(height: 20),

              // 캐릭터 선택 버튼
              Wrap(
                spacing: 10,
                children: characters.map((character) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCharacter = character;
                      });
                    },
                    child: Column(
                      children: [
                        Image.asset(
                          "assets/images/main/${character}_main.png", // 오른쪽 이미지 사용
                          width: 80,
                          height: 80,
                        ),
                        Text(character, style: TextStyle(fontSize: 16)),
                        if (selectedCharacter == character)
                          Icon(Icons.check, color: Colors.green),
                      ],
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: 40),

              // 선택 완료 버튼
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          LoginScreen(selectedCharacter: selectedCharacter),
                    ),
                  );
                },
                child: Text("확인"),
              ),
            ],
          ),
        ));
  }
}

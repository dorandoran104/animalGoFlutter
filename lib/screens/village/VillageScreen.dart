import 'package:animalgo/screens/chat/ChatListScreen.dart';
import 'package:flutter/material.dart';
import '../../components/BottomBar.dart'; // BottomNavBar 컴포넌트 임포트
import '../../components/TopBar.dart'; // CustomAppBar 임포트
// import '../../service/ApiService.dart';
import 'package:animalgo/service/ApiService.dart';
// import '../camera/CameraScreen.dart';
// import '../login/LoginScreen.dart';
import 'package:animalgo/screens/home/HomeScreen.dart';
import 'package:animalgo/screens/myPage/my_page.dart';
import 'package:animalgo/screens/village/VillageScreen.dart';
import 'package:animalgo/screens/village/GameScreen.dart';

class VillageScreen extends StatefulWidget {
  const VillageScreen({Key? key}) : super(key: key);

  @override
  _VillageScreenState createState() => _VillageScreenState();
}

class _VillageScreenState extends State<VillageScreen>{
  
  @override
  Widget build (BuildContext context){
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text("마을"),
      // ),
      body: GameScreen(),
      bottomNavigationBar: Bottombar(
        currentIndex: 1,
        onTabSelected: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      HomeScreen(),
                  transitionDuration: Duration.zero,
                ),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      VillageScreen(),
                  transitionDuration: Duration.zero,
                ),
              );
              break;
            case 2: // ✅ 채팅 리스트 화면으로 이동
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      ChatListScreen(), // ✅ userId 전달 제거
                  transitionDuration: Duration.zero,
                ),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      MyPage(),
                  transitionDuration: Duration.zero,
                ),
              );
              break;
          }
        },
      ),
    );
  }
}
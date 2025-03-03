import 'package:animalgo/components/SnackbarHelper.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'FriendList.dart'; // FriendList 임포트
import '../../components/BottomBar.dart'; // BottomNavBar 컴포넌트 임포트
import '../../components/TopBar.dart'; // CustomAppBar 임포트
import '../camera/CameraScreen.dart';
import '../login/LoginScreen.dart';
import '../myPage/my_page.dart';
import '../chat/ChatListScreen.dart'; // ✅ 채팅 리스트 화면 추가
import 'package:shared_preferences/shared_preferences.dart';
// import '../village_test/Village.dart';
import 'package:animalgo/screens/village/VillageScreen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> friends = []; // ✅ 상태로 관리할 친구 목록
  bool isLoading = true; // ✅ 로딩 상태 관리

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('cookie'); // ✅ 쿠키 값 가져오기

    if (token == null || token.isEmpty) {
      // ✅ 토큰이 없으면 로그인 화면으로 이동
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (context) => LoginScreen()),
      // );
      // return;
    }

    // await _fetchFriends(token); // ✅ 토큰이 있으면 친구 목록 불러오기
  }

  Future<void> _fetchFriends(String token) async {
    FormData formData = FormData.fromMap({
      'user_id': token ?? "1"
    });

    try {
      Dio _dio = Dio(
        BaseOptions(
          baseUrl: dotenv.env['SERVER_URL'] ?? 'default_value', // ✅ 서버 기본 주소 설정
          connectTimeout: Duration(seconds: 10), // ✅ 연결 타임아웃 (10초)
          receiveTimeout: Duration(seconds: 10), // ✅ 응답 타임아웃 (10초)
          headers: {"Content-Type": "application/json"}, // ✅ 기본 헤더 설정
        ),
      );

      var response = await _dio.post('/home/characters', data: formData);
      if (response.statusCode == 200) {
        setState(() {
          Map<String, dynamic> responseMap = response.data as Map<String, dynamic>;
          List<dynamic> friendList = responseMap['characters'] ?? [];
          friends = friendList.map((friend) {
            return {
              "nickname": friend["nickname"],
              // "image": friend["character_path"],
              "character_id" : friend["character_id"]
            };
          }).toList();
          isLoading = false; // ✅ 로딩 상태 업데이트
        });
      }
    } on DioException catch(e){
      setState(() {
        isLoading = false; // ✅ 로딩 상태 업데이트
      });
    } catch(e1){
      print(e1);
      SnackbarHelper.showSnackbar(context, "서버에 오류가 발생했습니다.");
      setState(() {
        isLoading = false; // ✅ 로딩 상태 업데이트
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin을 사용하려면 필요합니다.
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: Topbar(
        title: "내 친구들 (${friends.length})",
        showBackButton : false,
      ), // CustomAppBar 사용
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // 로딩 중일 때 표시할 위젯
          : FriendList(friends: friends), // 데이터 로드 완료 시 표시할 위젯
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CameraScreen()),
          );
        },
        backgroundColor: Colors.black,
        child: Icon(Icons.camera_alt, color: Colors.white),
      ),
      bottomNavigationBar: Bottombar(
        currentIndex: 0,
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

  @override
  bool get wantKeepAlive => true; // 상태를 유지하도록 설정
}


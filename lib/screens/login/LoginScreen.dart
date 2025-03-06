import 'package:flutter/material.dart';
import 'SocialLoginButton.dart';
import '../regist/RegistScreen.dart';
import '../../service/ApiService.dart';
import '../../components/SnackbarHelper.dart';
import '../home/HomeScreen.dart';
import 'package:dio/dio.dart';
import 'package:dio/src/form_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    _idFocusNode.addListener(() {
      // setState(() {
      //   _idController.text = '';
      // });
    });
    _passwordFocusNode.addListener(() {
      // setState(() {
      //   _passwordController.text = '';
      // });
    });
  }

  @override
  void dispose() {
    _idFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _login() async {
    final String id = _idController.text;
    final String password = _passwordController.text;

    if (id.isEmpty) {
      SnackbarHelper.showSnackbar(context, '아이디를 입력해주세요.');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     duration: Duration(seconds: 1),
      //     content: Text(
      //       '아이디를 입력해주세요.',
      //       style: TextStyle(
      //         color: Colors.white,
      //         fontSize: 16,
      //         ),
      //         textAlign: TextAlign.center,
      //       ),
      //     backgroundColor: Colors.red,
      //   ),
      // );
      return;
    }

    if (password.isEmpty) {
      SnackbarHelper.showSnackbar(context, "비밀번호를 입력해주세요.");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     duration: Duration(seconds: 1),
      //     content: Text(
      //       '비밀번호를 입력해주세요.',
      //       style: TextStyle(
      //         color: Colors.white,
      //         fontSize: 16,
      //         ),
      //         textAlign: TextAlign.center,
      //       ),
      //     backgroundColor: Colors.red,
      //   ),
      // );
      return;
    }
    Dio _dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env["SERVER_URL"] ?? 'default', // ✅ 서버 기본 주소 설정
        connectTimeout: Duration(seconds: 10), // ✅ 연결 타임아웃 (10초)
        receiveTimeout: Duration(seconds: 10), // ✅ 응답 타임아웃 (10초)
        headers: {"Content-Type": "application/json"}, // ✅ 기본 헤더 설정
      ),
    );
    try {
      FormData formdata = FormData.fromMap({
        'user_id': id,
        'password': password,
      });

      var response = await _dio.post('/home/login', data: formdata);
      final prefs = await SharedPreferences.getInstance();
      String? cookie = prefs.getString('cookie');
      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        String? serverCookie = responseData['cookie']; // 서버에서 제공하는 쿠키
        String? nickname = responseData['user_nickname']; // 서버에서 제공하는 닉네임

        // cookie 저장 (서버 쿠키가 없으면 id 사용)
        if (cookie == null || cookie.isEmpty) {
          cookie = serverCookie ?? id;
          await prefs.setString("cookie", cookie);
          print("쿠키 저장 완료: $cookie");
        }

        // user_id 저장
        await prefs.setString('user_id', id);

        // nickname 저장
        if (nickname != null) {
          await prefs.setString('nickname', nickname);
          print("닉네임 저장 완료: $nickname");
        } else {
          print("서버에서 닉네임을 제공하지 않음");
        }

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(),
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        if (e.response?.data is Map<String, dynamic>) {
          final responseData = e.response?.data as Map<String, dynamic>;
          if (responseData.containsKey('detail')) {
            String message = responseData['detail'];
            if (message == '401: Invalid password') {
              SnackbarHelper.showSnackbar(context, '아이디 또는 비밀번호를 확인해 주세요.');
            } else if (message == '404: User not found') {
              SnackbarHelper.showSnackbar(context, '아이디 또는 비밀번호를 확인해 주세요.');
            }
          } else {
            SnackbarHelper.showSnackbar(context, '아이디 또는 비밀번호를 확인해 주세요.');
          }
        }
      }
    } catch (e) {
      SnackbarHelper.showSnackbar(context, '서버에서 오류가 발생했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        //   leading:  IconButton(
        //         icon: Icon(Icons.arrow_back, color: Colors.black),
        //         onPressed: () {
        //           Navigator.pushReplacement( // 이전 화면으로 이동
        //             context,
        //             PageRouteBuilder(
        //               pageBuilder: (context, animation, secondaryAnimation) =>
        //                   HomeScreen(),
        //               transitionDuration: Duration.zero,
        //             ),
        //           );
        //         },
        //       )
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ANIMAL GO',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              // 아이디 입력 필드
              TextField(
                controller: _idController,
                focusNode: _idFocusNode,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '아이디',
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // 패스워드 입력 필드
              TextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '패스워드',
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 40),
              // 로그인 버튼
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(4), // 로그인 버튼의 border radius
                  ),
                ),
                child: const Text(
                  '로그인',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              // 회원가입
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegistScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(4), // 로그인 버튼의 border radius
                      side: BorderSide(
                          color: const Color.fromARGB(255, 190, 190, 190),
                          width: 1.0)),
                ),
                child: const Text(
                  '회원가입',
                  style: TextStyle(color: Colors.black),
                ),
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              SocialLoginButton(
                iconPath: 'assets/images/google.webp',
                label: 'Sign in with Google',
                onPressed: () {},
              ),
              const SizedBox(height: 10),
              SocialLoginButton(
                iconPath: 'assets/images/naver.png',
                label: 'Sign in with Naver',
                onPressed: () {},
              ),
              const SizedBox(height: 10),
              SocialLoginButton(
                iconPath: 'assets/images/kakao.png',
                label: 'Sign in with Kakao',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// class _LoginScreenState extends State<LoginScreen> {
//   // const LoginScreen({Key? key}) : super(key: key);

//   final FocusNode _idFocusNode = FocusNode();
//   final FocusNode _passwordFocusNode = FocusNode();



//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.white, elevation: 0,
//         leading:  IconButton(
//               icon: Icon(Icons.arrow_back, color: Colors.black),
//               onPressed: () {
//                 Navigator.pop(context); // 이전 화면으로 이동
//               },
//             )
//       ),
//       backgroundColor: Colors.white,
//       body: Padding(
//         padding: const EdgeInsets.all(20.0),
//         child: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               Text(
//                 'ANIMAL GO',
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   fontSize: 32,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 40),
//               // 아이디 입력 필드
//               TextField(
//                 decoration: InputDecoration(
//                   border: OutlineInputBorder(),
//                   hintText: '아이디',
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.black),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 20),
//               // 패스워드 입력 필드
//               TextField(
//                 decoration: InputDecoration(
//                   border: OutlineInputBorder(),
//                   hintText: '패스워드',
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.black),
//                   ),
//                 ),
//                 obscureText: true,
//               ),
//               const SizedBox(height: 20),
//               // 로그인 버튼
//               ElevatedButton(
//                 onPressed: () {},
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.black,
//                   padding: const EdgeInsets.symmetric(vertical: 15),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(4), // 로그인 버튼의 border radius
//                   ),
//                 ),
//                 child: const Text(
//                   '로그인',
//                   style: TextStyle(color: Colors.white),
//                 ),
//               ),
//                const SizedBox(height: 20),
//               // 회원가입
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (context) => RegistScreen()),
//                   );
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(vertical: 15),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(4), // 로그인 버튼의 border radius
//                     side : BorderSide(color: const Color.fromARGB(255, 190, 190, 190), width: 1.0)
//                   ),
//                 ),
//                 child: const Text(
//                   '회원가입',
//                   style: TextStyle(color: Colors.black),
//                 ),
//               ),

//               const SizedBox(height: 20),
//               const Divider(),
//               const SizedBox(height: 10),
//               SocialLoginButton(
//                 iconPath: 'assets/images/google.webp',
//                 label: 'Sign in with Google',
//                 onPressed: () {

//                 },
//               ),
//               const SizedBox(height: 10),
//               SocialLoginButton(
//                 iconPath: 'assets/images/naver.png',
//                 label: 'Sign in with Naver',
//                 onPressed: () {

//                 },
//               ),
//               const SizedBox(height: 10),
//               SocialLoginButton(
//                 iconPath: 'assets/images/kakao.png',
//                 label: 'Sign in with Kakao',
//                 onPressed: () {

//                 },
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
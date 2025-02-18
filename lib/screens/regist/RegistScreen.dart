import 'package:animalgo/components/SnackbarHelper.dart';
import 'package:animalgo/screens/login/LoginScreen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:animalgo/service/ApiService.dart';

class RegistScreen extends StatefulWidget {
  final String selectedCharacter;
  const RegistScreen({
    Key? key,
    required this.selectedCharacter,
  }) : super(key: key);
  @override
  _RegistScreenState createState() => _RegistScreenState();
}

class _RegistScreenState extends State<RegistScreen> {
  late String userCharacter;
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();

  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final FocusNode _nicknameFocusNode = FocusNode();

  bool _obscureText1 = true;
  bool _obscureText2 = true;

  // String? _passwordMismatchMessage;
  bool _isValid = true;

  void _togglePasswordVisibility1() {
    setState(() {
      _obscureText1 = !_obscureText1;
    });
  }

  void _togglePasswordVisibility2() {
    setState(() {
      _obscureText2 = !_obscureText2;
    });
  }

  @override
  void initState() {
    super.initState();
    userCharacter = widget.selectedCharacter;

    // FocusNode에 리스너 추가
    _idFocusNode.addListener(() {
      setState(() {});
    });
    _passwordFocusNode.addListener(() {
      setState(() {});
    });
    _confirmPasswordFocusNode.addListener(() {
      setState(() {});
    });
    _nicknameFocusNode.addListener(() {
      setState(() {});
    });

    _passwordController.addListener(_checkPassword);
    _confirmPasswordController.addListener(_checkPassword);
  }

  @override
  void dispose() {
    _idFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _nicknameFocusNode.dispose();
    super.dispose();
  }

  bool _checkPassword() {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        // _passwordMismatchMessage = '비밀번호가 일치하지 않습니다.';
        _isValid = false;
      });
      // SnackbarHelper.showSnackbar(context, "비밀번호가 일치하지 않")
      return false;
    } else {
      setState(() {
        // _passwordMismatchMessage = null; // 일치하면 메시지 제거
        _isValid = true;
      });
      return true;
    }
  }

  void _register() async {
    // 회원가입 로직 추가
    final String id = _idController.text;
    final String password = _passwordController.text;
    final String nickname = _nicknameController.text;

    if (id.isEmpty) {
      SnackbarHelper.showSnackbar(context, "아이디를 입력해주세요.");
      return;
    }

    if (password.isEmpty) {
      SnackbarHelper.showSnackbar(context, "비밀번호를 입력해주세요.");
      return;
    }

    if (_confirmPasswordController.text.isEmpty) {
      SnackbarHelper.showSnackbar(context, "비밀번호 확인을 입력해주세요.");
      return;
    }

    if (!_checkPassword()) {
      SnackbarHelper.showSnackbar(context, "비밀번호가 일치하지 않습니다.");
      return;
    }
    ;

    if (nickname.isEmpty) {
      SnackbarHelper.showSnackbar(context, "닉네임을 입력해주세요.");
      return;
    }

    try {
      FormData formdata = FormData.fromMap({
        "user_id": id,
        "password": password,
        "confirm_password": _confirmPasswordController.text,
        "user_nickname": nickname,
      });
      Dio _dio = Dio(
        BaseOptions(
          baseUrl: dotenv.env["SERVER_URL"] ?? 'default', // ✅ 서버 기본 주소 설정
          connectTimeout: Duration(seconds: 10), // ✅ 연결 타임아웃 (10초)
          receiveTimeout: Duration(seconds: 10), // ✅ 응답 타임아웃 (10초)
          headers: {"Content-Type": "application/json"}, // ✅ 기본 헤더 설정
        ),
      );
      try {
        var response = await _dio.post('/home/register', data: formdata);
        if(response.statusCode == 200){
          Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    LoginScreen(selectedCharacter: userCharacter,),
                transitionDuration: Duration.zero,
              ),
            );
        }
      } on DioException catch (e) {
        if (e.response != null) {
          print("에러 응답 코드: ${e.response?.statusCode}");
          print("에러 응답 바디: ${e.response?.data}"); // ✅ 서버에서 반환한 바디
          if (e.response?.data is Map<String, dynamic>) {
            // 응답이 Map인지 확인
            final responseData = e.response?.data as Map<String, dynamic>;
            if (responseData.containsKey('detail')) {
              String message = responseData['detail'];
              if(message == '400: User ID already exists'){
                SnackbarHelper.showSnackbar(context,'이미 사용중인 아이디 입니다.');
              }
            }
          }
        } else {
          SnackbarHelper.showSnackbar(context,'서버 오류가 발생했습니다.');
          // print("요청 실패: ${e.message}");
        }
      }
    } catch (e) {
      print(e);
      SnackbarHelper.showSnackbar(context, "회원가입에 실패했습니다.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('회원가입', style: TextStyle(color: Colors.black)),
        iconTheme: IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _idController,
              focusNode: _idFocusNode,
              style: TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: '아이디',
                labelStyle: TextStyle(color: Colors.black),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      // color: _idFocusNode.hasFocus ? Colors.blue : Colors.grey,
                      ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            SizedBox(height: 25),
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: _obscureText1,
              style: TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: '패스워드',
                labelStyle: TextStyle(color: Colors.black),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: _confirmPasswordController.text == '' &&
                            _passwordController.text == ''
                        ? Colors.black
                        : (_isValid ? Colors.blue : Colors.red),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: _confirmPasswordController.text == '' &&
                            _passwordController.text == ''
                        ? Colors.black
                        : (_isValid ? Colors.blue : Colors.red),
                  ),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText1 ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: _togglePasswordVisibility1,
                ),
              ),
            ),
            SizedBox(height: 25),
            TextField(
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocusNode,
              obscureText: _obscureText2,
              style: TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: '패스워드 확인',
                labelStyle: TextStyle(color: Colors.black),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: _confirmPasswordController.text == '' &&
                            _passwordController.text == ''
                        ? Colors.black
                        : (_isValid ? Colors.blue : Colors.red),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    // color: _isValid && _confirmPasswordController.text != '' && _passwordController.text != '' ? Colors.blue : Colors.red,
                    color: _confirmPasswordController.text == '' &&
                            _passwordController.text == ''
                        ? Colors.black
                        : (_isValid ? Colors.blue : Colors.red),
                  ),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText2 ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: _togglePasswordVisibility2,
                ),
              ),
            ),
            SizedBox(height: 25),
            TextField(
              controller: _nicknameController,
              focusNode: _nicknameFocusNode,
              style: TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: '닉네임',
                labelStyle: TextStyle(color: Colors.black),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      // color: _nicknameFocusNode.hasFocus ? Colors.blue : Colors.grey,
                      ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            SizedBox(height: 32),
            Spacer(),
            ElevatedButton(
              onPressed: _register,
              child: const Text(
                '회원가입',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                minimumSize: Size(double.infinity, 0),
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(
                      color: const Color.fromARGB(255, 190, 190, 190),
                      width: 1.0),
                ),
              ),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

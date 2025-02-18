import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'my_page.dart';

class EditProfileScreen extends StatefulWidget {
  final String selectedCharacter;
  const EditProfileScreen({Key? key, required this.selectedCharacter})
      : super(key: key);
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late String userCharacter;
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();

  bool _obscureText1 = true;
  bool _obscureText2 = true;
  String? _passwordMismatchMessage;
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    userCharacter = widget.selectedCharacter;
  }

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

  void _checkPassword() {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _passwordMismatchMessage = '비밀번호가 일치하지 않습니다.';
        _isValid = false;
      });
    } else {
      setState(() {
        _passwordMismatchMessage = null;
        _isValid = true;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_isValid) return;

    final url = Uri.parse('https://your-server.com/api/update_profile'); // 서버 URL 변경 필요
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': _idController.text,
        'password': _passwordController.text,
        'nickname': _nicknameController.text,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수정이 완료되었습니다.')),
      );
      // MyPageScreen으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyPage(selectedCharacter: userCharacter)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수정에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('개인정보 수정', style: TextStyle(color: Colors.black)),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                labelText: '아이디',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: _obscureText1,
              decoration: InputDecoration(
                labelText: '새 비밀번호',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText1 ? Icons.visibility_off : Icons.visibility),
                  onPressed: _togglePasswordVisibility1,
                ),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureText2,
              onChanged: (_) => _checkPassword(),
              decoration: InputDecoration(
                labelText: '비밀번호 확인',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText2 ? Icons.visibility_off : Icons.visibility),
                  onPressed: _togglePasswordVisibility2,
                ),
              ),
            ),
            if (_passwordMismatchMessage != null) ...[
              SizedBox(height: 10),
              Text(
                _passwordMismatchMessage!,
                style: TextStyle(color: Colors.red),
              ),
            ],
            SizedBox(height: 20),
            TextField(
              controller: _nicknameController,
              decoration: InputDecoration(
                labelText: '닉네임',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _updateProfile,
              child: Text('수정하기', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                minimumSize: Size(double.infinity, 0),
                backgroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

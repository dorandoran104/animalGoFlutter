import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../chat/ChatListScreen.dart';

class ImageFromServer extends StatefulWidget {
  final String characterId;
  final String segmentedImagePath;

  const ImageFromServer({
    Key? key,
    required this.characterId,
    required this.segmentedImagePath,
  }) : super(key: key);

  @override
  _ImageFromServerState createState() => _ImageFromServerState();
}

class _ImageFromServerState extends State<ImageFromServer> {
  final TextEditingController nicknameController = TextEditingController();
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white,title: Text("닉네임 변경")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ 원본 이미지 표시
            Image.file(File(widget.segmentedImagePath), height: 200, fit: BoxFit.cover),
            const SizedBox(height: 20),

            Text("새로운 닉네임 입력"),
            TextField(
              controller: nicknameController,
              decoration: InputDecoration(
                hintText: "닉네임을 입력하세요",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: isLoading ? null : () => _sendNicknameToServer(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromRGBO(230, 150, 248, 0.6), // 버튼 색상 변경
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // 둥근 모서리
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // 버튼 크기 조절
                ),
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "닉네임 저장",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // 글씨 색상을 흰색으로 변경
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ `application/x-www-form-urlencoded` 방식으로 닉네임 전송
  Future<void> _sendNicknameToServer() async {
    final String serverUrl = "http://122.46.89.124:7000/home/nickname";

    if (nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("닉네임을 입력하세요.")),
      );
      return;
    }

    if (widget.characterId.isEmpty) {
      print("❌ characterId가 비어 있음!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("characterId가 없습니다. 다시 시도하세요.")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    // ✅ 폼 데이터를 쿼리 스트링 방식으로 변환
    final Map<String, String> formData = {
      'character_id': widget.characterId.isNotEmpty ? widget.characterId : "unknownId",
      'nickname': nicknameController.text.trim().isNotEmpty ? nicknameController.text.trim() : "Unnamed",
    };

    final String encodedBody = formData.entries.map((entry) =>
    '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}'
    ).join('&');

    try {
      var response = await http.post(
        Uri.parse(serverUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8', // ✅ UTF-8 추가
          'Accept': 'application/json',
        },
        body: utf8.encode(encodedBody), // ✅ UTF-8 인코딩
      );

      final responseData = utf8.decode(response.bodyBytes); // ✅ UTF-8 디코딩
      print("🔹 서버 응답 본문: $responseData");

      if (response.statusCode == 200) {
        try {
          final jsonResponse = jsonDecode(responseData);
          if (jsonResponse.containsKey('message')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("닉네임 설정 등록되었습니다")),
            );
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatListScreen(
              ),
            ),
          );
        } catch (e) {
          print("❌ JSON 파싱 실패: $e");
          print("🔹 서버 응답 (비 JSON 형식일 가능성 있음): $responseData");
        }
      } else {
        print("❌ 서버 오류: ${response.statusCode}");
        print("❌ 서버 응답 본문: $responseData");
      }
    } catch (e) {
      print("❌ 서버 저장 실패: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }


}

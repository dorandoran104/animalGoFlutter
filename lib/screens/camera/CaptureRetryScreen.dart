import 'package:flutter/material.dart';
import 'CameraScreen.dart';

class CaptureRetryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text('촬영 실패')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              '동물이 탐지되지 않습니다. 다시 촬영해주세요.',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // ✅ 다시 촬영 화면으로 이동
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => CameraScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromRGBO(230, 150, 248, 0.6), // ✅ 버튼 색상 변경
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // ✅ 둥근 모서리
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // ✅ 버튼 크기 조절
              ),
              child: const Text(
                '다시 촬영하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // ✅ 글씨 색상을 흰색으로 변경
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

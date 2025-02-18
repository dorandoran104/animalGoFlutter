import 'package:flutter/material.dart';
import 'CameraScreen.dart';

class CaptureRetryScreen extends StatefulWidget {
  final String selectedCharacter;
  const CaptureRetryScreen({
    Key? key,
    required this.selectedCharacter,
  }) : super(key: key);
  @override
  _CaptureRetryScreenState createState() => _CaptureRetryScreenState();
}
class _CaptureRetryScreenState extends State<CaptureRetryScreen> with WidgetsBindingObserver{
  late String userCharacter;
  @override
  void initState(){
    super.initState();
    userCharacter = widget.selectedCharacter;
  }
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
                  MaterialPageRoute(builder: (context) => CameraScreen(selectedCharacter: userCharacter,)),
                );
              },
              child: Text('다시 촬영하기'),
            ),
          ],
        ),
      ),
    );
  }
}

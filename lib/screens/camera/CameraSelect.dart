import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'setting/settings_provider.dart';


class CameraSelect extends StatefulWidget {
  final String segmentedImagePath; // ✅ 세그멘테이션 이미지 경로
  final String originalImagePath;  // ✅ 원본 이미지 경로

  const CameraSelect({
    Key? key,
    required this.segmentedImagePath,
    required this.originalImagePath,
  }) : super(key: key);


  @override
  _CameraSelectState createState() => _CameraSelectState();
}

class _CameraSelectState extends State<CameraSelect> {
  String? selectedPersonality;
  String? selectedAppearance;
  String? selectedAnimal;
  final TextEditingController nicknameController = TextEditingController();

  final List<String> personalityOptions = ['밝음', '차분함', '활발함', '조용함'];
  final List<String> appearanceOptions = ['귀여움', '멋짐', '상냥함', '강인함'];

  // ✅ COCO 데이터셋의 일반적인 동물 종 목록
  final List<String> animalOptions = [
    '개', '고양이', '말', '양', '코끼리', '곰', '얼룩말', '기린', '소', '새'
  ];

  /// ✅ 저장 함수
  // Future<void> _saveData() async {
  //   final nickname = nicknameController.text.trim();
  //   if (nickname.isEmpty || selectedPersonality == null || selectedAppearance == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('닉네임, 성격, 외모를 모두 입력하세요.'))
  //     );
  //     return;
  //   }
  //
  //   try {
  //     final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
  //
  //     // ✅ 영구 저장 경로 설정
  //     String saveDirectory = settingsProvider.savePath;
  //     if (!await settingsProvider.validateSavePath(saveDirectory)) {
  //       print('저장 경로 검증 실패. 기본 경로 사용');
  //       saveDirectory = '/storage/emulated/0/Pictures/AnimalSegmentation';
  //     }
  //
  //     final directory = Directory(saveDirectory);
  //     if (!await directory.exists()) {
  //       await directory.create(recursive: true);
  //     }
  //
  //     // ✅ 원본 이미지 저장 (original_xxx.jpg)
  //     final String originalSavePath = path.join(saveDirectory, 'original_${DateTime.now().millisecondsSinceEpoch}.jpg');
  //     await File(widget.originalImagePath).copy(originalSavePath);
  //
  //     // ✅ 세그멘테이션 이미지 저장 (segmented_xxx.png)
  //     final String segmentedSavePath = path.join(saveDirectory, 'segmented_${DateTime.now().millisecondsSinceEpoch}.png');
  //     await File(widget.segmentedImagePath).copy(segmentedSavePath);
  //
  //     print('저장 성공: $originalSavePath & $segmentedSavePath');
  //
  //     ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('파일 저장 완료! \n위치: $saveDirectory'))
  //     );
  //
  //     Navigator.pop(context); // 저장 후 이전 화면으로 이동
  //   } catch (e) {
  //     print('파일 저장 실패: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('파일 저장 실패: $e'), backgroundColor: Colors.red)
  //     );
  //   }
  // }
  /// 서버로 데이터 전송 (동물 종 포함)
  Future<void> _saveDataToServer() async {
    final nickname = nicknameController.text.trim();
    if (nickname.isEmpty || selectedPersonality == null ||
        selectedAppearance == null || selectedAnimal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('닉네임, 성격, 외모, 동물의 종을 모두 선택하세요.'))
      );
      return;
    }

    try {
      final String serverUrl = "http://122.46.89.124:7000/home/upload-original-image"; //

      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));

      // ✅ 텍스트 데이터 추가
      request.fields['user_id'] = "1";
      request.fields['personality'] = selectedPersonality!;
      request.fields['appearance'] = selectedAppearance!;
      request.fields['animaltype'] = selectedAnimal!; // 🆕 동물의 종 추가

      // ✅ 이미지 파일 추가
      request.files.add(
          await http.MultipartFile.fromPath('file', widget.originalImagePath));
      // request.files.add(await http.MultipartFile.fromPath('segmented_image', widget.segmentedImagePath));

      var response = await request.send();

      if (response.statusCode == 200) {
        print('서버에 데이터 저장 성공');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('서버에 데이터 저장 완료!'))
        );
      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('서버 저장 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 저장 실패: $e'), backgroundColor: Colors.red)
      );
    }
  }

  ///firestore에 데이터 보내기
  // Future<void> _saveDataToFirestore() async {
  //   final nickname = nicknameController.text.trim();
  //   if (nickname.isEmpty || selectedPersonality == null || selectedAppearance == null || selectedAnimal == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('닉네임, 성격, 외모, 동물의 종을 모두 선택하세요.'))
  //     );
  //     return;
  //   }
  //
  //   try {
  //     // Firestore 인스턴스
  //     final FirebaseFirestore firestore = FirebaseFirestore.instance;
  //     final FirebaseStorage storage = FirebaseStorage.instance;
  //
  //     // ✅ 이미지 업로드 (Firebase Storage)
  //     String originalImageName = 'original_${DateTime.now().millisecondsSinceEpoch}.jpg';
  //     String segmentedImageName = 'segmented_${DateTime.now().millisecondsSinceEpoch}.png';
  //
  //     // Storage에 업로드
  //     UploadTask originalUploadTask = storage.ref('images/$originalImageName').putFile(File(widget.originalImagePath));
  //     UploadTask segmentedUploadTask = storage.ref('images/$segmentedImageName').putFile(File(widget.segmentedImagePath));
  //
  //     // 업로드 완료 후 URL 가져오기
  //     TaskSnapshot originalSnapshot = await originalUploadTask;
  //     TaskSnapshot segmentedSnapshot = await segmentedUploadTask;
  //
  //     String originalImageUrl = await originalSnapshot.ref.getDownloadURL();
  //     String segmentedImageUrl = await segmentedSnapshot.ref.getDownloadURL();
  //
  //     // ✅ Firestore에 데이터 저장
  //     await firestore.collection('users').add({
  //       'nickname': nickname,
  //       'personality': selectedPersonality!,
  //       'appearance': selectedAppearance!,
  //       'animal_species': selectedAnimal!,
  //       'original_image': originalImageUrl,
  //       'segmented_image': segmentedImageUrl,
  //       'timestamp': FieldValue.serverTimestamp(),
  //     });
  //
  //     print('Firestore에 데이터 저장 완료');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('데이터 저장 완료!'))
  //     );
  //   } catch (e) {
  //     print('Firestore 저장 실패: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red)
  //     );
  //   }
  // }


  Widget _buildImageCard(String title, String imagePath) {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Card(
        elevation: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                color: Colors.white, // ✅ 흰색 배경 강제 적용
                colorBlendMode: BlendMode.dstOver, // ✅ 배경이 비어있는 부분을 흰색으로 채움
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 48),
                        SizedBox(height: 8),
                        Text('이미지를 로드할 수 없습니다'),
                        Text(error.toString(), style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          scrolledUnderElevation: 0, // 스크롤 시 배경색 변화 방지
          title: const Text('정보 입력')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ 원본 이미지 표시
            _buildImageCard('원본 사진', widget.originalImagePath),
            SizedBox(height: 20),
            // ✅ 세그멘테이션된 이미지만 표시
            _buildImageCard('세그멘테이션 결과', widget.segmentedImagePath),
            SizedBox(height: 20),

            // 닉네임 입력
            TextField(
              controller: nicknameController,
              decoration: const InputDecoration(
                labelText: '닉네임',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // 성격 선택
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '성격 선택',
                border: OutlineInputBorder(),
              ),
              value: selectedPersonality,
              items: personalityOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedPersonality = newValue;
                });
              },
            ),
            const SizedBox(height: 20),

            // 외모 선택
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '외모 선택',
                border: OutlineInputBorder(),
              ),
              value: selectedAppearance,
              items: appearanceOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedAppearance = newValue;
                });
              },
            ),
            const SizedBox(height: 20),

            // ✅ 동물 종 선택 (COCO 데이터셋 기반)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '동물의 종 선택',
                border: OutlineInputBorder(),
              ),
              value: selectedAnimal,
              items: animalOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedAnimal = newValue;
                });
              },
            ),
            const SizedBox(height: 20),
            // ✅ 저장 버튼 (저장 함수 호출)
            Center(
              child: ElevatedButton(
                onPressed: _saveDataToServer,
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
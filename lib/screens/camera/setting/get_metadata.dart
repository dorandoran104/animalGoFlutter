import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'get_picture.dart';

class MetadataDropdownScreen extends StatefulWidget {
  final String segmentedImagePath; // ✅ 세그멘테이션 이미지 경로
  final String originalImagePath;  // ✅ 원본 이미지 경로

  const MetadataDropdownScreen({
    Key? key,
    required this.segmentedImagePath,
    required this.originalImagePath,
  }) : super(key: key);

  @override
  _MetadataDropdownScreenState createState() => _MetadataDropdownScreenState();
}

class _MetadataDropdownScreenState extends State<MetadataDropdownScreen> {
  List<Map<String, String>> appearanceList = [];
  List<Map<String, String>> personalityList = [];

  String? selectedAppearance;
  String? selectedPersonality;
  String? selectedAnimal;
  String? savedCharacterId;

  final TextEditingController nicknameController = TextEditingController();
  final List<String> animalOptions = [
    '개', '고양이', '말', '양', '코끼리', '곰', '얼룩말', '기린', '소', '새'
  ];

  @override
  void initState() {
    super.initState();
    fetchMetadata();
  }

  /// ✅ 서버로 데이터 저장
  Future<void> _saveDataToServer() async {
    final String serverUrl = "http://122.46.89.124:7000/home/upload-original-image";

    if (selectedAppearance == null || selectedPersonality == null || selectedAnimal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('외모, 성격, 동물의 종을 모두 선택하세요.')),
      );
      return;
    }

    try {
      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));

      request.fields['user_id'] = "1";
      request.fields['appearance'] = selectedAppearance!;
      request.fields['personality'] = selectedPersonality!;
      request.fields['animaltype'] = selectedAnimal!;

      File file = File(widget.segmentedImagePath);
      if (!file.existsSync()) {
        print("❌ 파일이 존재하지 않습니다: ${widget.segmentedImagePath}");
        return;
      }

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      var response = await request.send();
      final responseData = await response.stream.bytesToString();

      print("🔹 서버 응답 본문: $responseData");

      if (response.statusCode == 200) {
        try {
          final jsonResponse = jsonDecode(responseData);
          if (!jsonResponse.containsKey('characterId')) {
            print("❌ 서버 응답 오류: 'characterId' 필드가 없음");
            return;
          }

          setState(() {
            savedCharacterId = (jsonResponse['characterId'] as String?) ?? "";
          });

          print("✅ 서버에서 받은 character_id: $savedCharacterId");

          _sendCharacterIdToServer(savedCharacterId!);

          // ✅ character_id를 `get_picture.dart`로 전달할 때 null 체크 추가
          if (savedCharacterId == null || savedCharacterId!.isEmpty) {
            print("❌ characterId가 NULL이거나 비어 있음!");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("characterId가 유효하지 않습니다. 다시 시도하세요.")),
            );
            return;
          }


          // ✅ `get_picture.dart`로 이동하면서 characterId와 originalImagePath 전달
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageFromServer(
                characterId: savedCharacterId!,
                segmentedImagePath: widget.segmentedImagePath,
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
    }
  }

  /// ✅ `savedCharacterId`를 이용해 `send-character` API에 POST 요청 보내기
  Future<void> _sendCharacterIdToServer(String characterId) async {
    final encodedCharacterId = Uri.encodeComponent(characterId);
    final String sendCharacterUrl = "http://122.46.89.124:7000/send-charater/$encodedCharacterId";

    print("📤 서버로 전송할 character_id: $encodedCharacterId");

    try {


      var response = await http.post( // 🔥 만약 GET 요청이 필요하면 변경 필요
        Uri.parse(sendCharacterUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },

      );
      print(response);

      if (response.statusCode == 200) {
        print("✅ send-character API 요청 성공");
      } else {
        print("❌ send-character API 오류: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ send-character API 요청 실패: $e");
    }
  }

  /// ✅ 서버에서 데이터 가져오기 (GET 요청)
  Future<void> fetchMetadata() async {
    final String url = "http://122.46.89.124:7000/create/get_metadata";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        Uint8List bodyBytes = response.bodyBytes;
        String decodedBody = utf8.decode(bodyBytes);

        final Map<String, dynamic> data = jsonDecode(decodedBody);

        setState(() {
          appearanceList = (data['appearance_list'] as List<dynamic>)
              .map((item) => {
            "korean": item["korean"].toString(),
            "english": item["english"].toString(),
          })
              .toList();

          personalityList = (data['personaliry_list'] as List<dynamic>)
              .map((item) => {
            "id": item["id"].toString(),
            "name": item["name"].toString(),
          })
              .toList();
        });
      } else {
        throw Exception("서버 오류: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ 데이터 가져오기 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: const Text("정보 입력")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageCard('원본 사진', widget.originalImagePath),
            SizedBox(height: 20),
            _buildImageCard('세그멘테이션 결과', widget.segmentedImagePath),
            SizedBox(height: 20),

            // ✅ 외모 선택 드롭다운
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '외모 선택',
                border: OutlineInputBorder(),
              ),
              value: selectedAppearance,
              items: (appearanceList.isNotEmpty)
                  ? appearanceList.map((item) {
                return DropdownMenuItem<String>(
                  value: item["korean"],
                  child: Text(item["korean"]!),
                );
              }).toList()
                  : [],
              onChanged: (value) {
                setState(() {
                  selectedAppearance = value;
                });
              },
            ),

            SizedBox(height: 20),

            // ✅ 성격 선택 드롭다운
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '성격 선택',
                border: OutlineInputBorder(),
              ),
              value: selectedPersonality,
              items: (personalityList.isNotEmpty)
                  ? personalityList.map((item) {
                return DropdownMenuItem<String>(
                  value: item["name"],
                  child: Text(item["name"]!),
                );
              }).toList()
                  : [],
              onChanged: (value) {
                setState(() {
                  selectedPersonality = value;
                });
              },
            ),

            SizedBox(height: 20),

            // ✅ 동물 종 선택
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

            // ✅ 저장 버튼
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  await _saveDataToServer(); // ✅ 서버에 데이터 저장 실행

                },
                child: const Text('저장 후 이미지 보기'),
              ),
            ),

          ],
        ),
      ),
    );
  }

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
              child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
            Image.file(File(imagePath), fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) {
              return Center(child: Icon(Icons.error_outline, color: Colors.red, size: 48));
            }),
          ],
        ),
      ),
    );
  }
}

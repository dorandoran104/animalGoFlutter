import 'dart:convert';
import 'dart:async'; // Timer 사용
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // dotenv 사용


class ChatRoomScreen extends StatefulWidget {
  final String chatId; // 서버에서 관리하는 채팅방 ID
  final String friendName;

  const ChatRoomScreen({
    Key? key,
    required this.chatId,
    required this.friendName,
  }) : super(key: key);

  @override
  _ChatRoomScreenState createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final String userId = '1'; // userId 고정
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> messages = []; // 채팅 내역 리스트
  bool isFetching = false; // API 중복 호출 방지
  bool isSending = false; // 중복 전송 방지

  /// ✅ 자동 스크롤 함수 (마지막 메시지 위치로 이동)
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300), // 부드러운 스크롤 효과
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// 날짜/시간 포맷 변환 함수 (12시간/24시간 모두 지원)
  String formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) {
      print("⚠️ formatTimestamp: timestamp가 null이거나 비어 있음");
      return "unknown";
    }
    try {
      // print("🔍 formatTimestamp: 원본 timestamp → $timestamp");

      // "UTC+0900" 제거 (있을 경우)
      timestamp = timestamp.replaceAll(RegExp(r' UTC[+-]\d{4}'), '').trim();

      // 한국어 날짜 형식을 일부 ISO 형식처럼 변경
      timestamp = timestamp
          .replaceAll("년 ", "-")
          .replaceAll("월 ", "-")
          .replaceAll("일", "")
          .replaceAll("시 ", ":")
          .replaceAll("분 ", ":")
          .replaceAll("초", "")
          .replaceAll("오전 ", "AM ")
          .replaceAll("오후 ", "PM ")
          .trim();

      // print("🔹 변환된 서버 timestamp → $timestamp");

      DateTime parsedDate;
      if (timestamp.contains("AM") || timestamp.contains("PM")) {
        // AM/PM이 포함된 경우 재배치 (예: "2025-02-14 PM 02:40:07" → "2025-02-14 02:40:07 PM")
        RegExp amPmRegex = RegExp(r'^(\d{4}-\d{2}-\d{2}) (AM|PM) (.+)$');
        if (amPmRegex.hasMatch(timestamp)) {
          timestamp = timestamp.replaceAllMapped(amPmRegex, (match) {
            return "${match.group(1)} ${match.group(3)} ${match.group(2)}";
          });
        }
        parsedDate = DateFormat("yyyy-MM-dd hh:mm:ss a").parse(timestamp);
      } else {
        // 24시간 형식인 경우
        parsedDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(timestamp);
      }

      // 최종적으로 한국어 12시간 형식으로 변환 (예: "오후 2:40")
      String formattedTime = DateFormat("a h:mm", "ko_KR").format(parsedDate);
      // print("✅ formatTimestamp 최종 변환 → $formattedTime");
      return formattedTime;
    } catch (e) {
      // print("⚠️ formatTimestamp 오류: $e | 원본: $timestamp");
      return "unknown";
    }
  }

  /// 서버에서 채팅 내역 가져오기 (최신 메시지만 반영)
  Future<void> fetchChatHistory() async {
    if (isFetching) return; // 중복 호출 방지
    isFetching = true;

    try {
      final response = await http.get(
        Uri.parse(
            'http://122.46.89.124:7000/chat/chat/history/${widget.chatId}?user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final String utf8String = utf8.decode(response.bodyBytes);
        final dynamic jsonData = json.decode(utf8String);

        if (jsonData is Map<String, dynamic> &&
            jsonData.containsKey("messages")) {
          List<dynamic> messagesList = jsonData["messages"];

          List<Map<String, dynamic>> newMessages = messagesList.map<
              Map<String, dynamic>>((message) {
            return {
              "message": message["content"]?.toString() ?? "",
              "isSentByMe": message["sender"].toString() == userId,
              "time": formatTimestamp(message["timestamp"]?.toString() ?? ""),
            };
          }).toList();

          if (mounted) {
            setState(() {
              messages = newMessages;
            });

            // 🔹 UI가 업데이트된 후 즉시 스크롤 이동
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          }
        }
      }
    } catch (e) {
      print("⚠️ 채팅 내역 가져오기 오류: $e");
    } finally {
      isFetching = false;
    }
  }

  /// 메시지 전송 함수 (Optimistic Update 적용)
  Future<void> sendMessage() async {
    if (_messageController.text.isEmpty || isSending) return;
    isSending = true; // ✅ UI 업데이트 전에 플래그 설정

    String messageText = _messageController.text;
    DateTime now = DateTime.now();
    String messageTime = DateFormat("yyyy-MM-dd HH:mm:ss").format(now);

    List<String> chatParts = widget.chatId.split("-");
    String characId = chatParts.length > 1 ? chatParts[1] : "";

    Map<String, dynamic> tempMessage = {
      "message": messageText,
      "isSentByMe": true,
      "time": formatTimestamp(messageTime),
      "isPending": true, // 🔹 전송 중 표시
    };

    setState(() {
      messages.add(tempMessage);
      _scrollToBottom();
    });

    _messageController.clear();

    Uri url = Uri.parse(
      'http://122.46.89.124:7000/chat/send_message'
          '?user_input=${Uri.encodeComponent(messageText)}'
          '&user_id=$userId'
          '&charac_id=$characId',
    );

    http.post(url, headers: {"Content-Type": "application/json"}).then((response) {
      if (response.statusCode == 200) {
        print("✅ 메시지 전송 성공");
        fetchChatHistory(); // ✅ 즉시 상대방 메시지 불러오기
      } else {
        print('❌ 메시지 전송 실패: ${response.statusCode}');
      }
    }).catchError((error) {
      print("⚠️ 네트워크 오류: $error");
    }).whenComplete(() {
      isSending = false; // ✅ 서버 응답과 관계없이 빠르게 상태 초기화
    });
  }

  // ✅ 새로운 메시지가 도착하면 호출 (서버에서 WebSocket 또는 Push 방식 추천)
  Future<void> onNewMessageReceived() async {
    if (isFetching) return; // 중복 호출 방지
    await fetchChatHistory();
  }

  String friendNickname = ""; // 상대방 닉네임 저장 변수
  String friendProfileUrl = ""; // 상대방 프로필 사진 URL 저장 변수

  Future<void> fetchChatRoomInfo() async {
    print("🟢 fetchChatRoomInfo() 실행됨!");
    try {
      final response = await http.get(
        Uri.parse('http://122.46.89.124:7000/chat/chat/list/$userId'),
      );

      if (response.statusCode == 200) {
        final String utf8String = utf8.decode(response.bodyBytes);
        final dynamic jsonData = json.decode(utf8String);

        print("📥 서버 응답 데이터 (채팅 목록): $jsonData");

        if (jsonData is Map<String, dynamic> && jsonData.containsKey("chats")) {
          for (var chat in jsonData["chats"]) {
            print("🔍 개별 채팅방 데이터: $chat");

            if (chat["chat_id"] == widget.chatId) {
              setState(() {
                friendNickname = chat["nickname"] ?? "알 수 없는 사용자";
                friendProfileUrl =
                "${dotenv.env['SERVER_URL']}/image/show_image?character_id=${widget.chatId}";
              });

              print("✅ chat_id: ${widget.chatId}");
              print("✅ friendProfileUrl: $friendProfileUrl");

              if (friendProfileUrl.isEmpty) {
                print("⚠️ friendProfileUrl이 빈 값입니다! 서버에서 데이터를 확인하세요.");
              }
              break;
            }
          }
        } else {
          print("❌ 서버 응답 데이터에 'chats' 키가 없습니다!");
        }
      } else {
        print("❌ 서버 응답 오류: ${response.statusCode}");
      }
    } catch (e) {
      print("⚠️ 채팅방 정보 가져오기 오류: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ko_KR', null);
    // 🔹 채팅 내역을 불러오고 즉시 스크롤
    fetchChatRoomInfo();
    fetchChatHistory().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // ✅ 화면 터치하면 키보드 닫기
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true, // ✅ 키보드가 올라올 때 자동으로 스크롤 조정
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          titleSpacing: 0, // 🔹 왼쪽 여백 제거
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min, // 🔹 필요한 크기만 차지
            children: [
              // 🔹 프로필 이미지
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                backgroundImage: (friendProfileUrl.isNotEmpty &&
                    Uri.tryParse(friendProfileUrl)?.hasAbsolutePath == true)
                    ? NetworkImage(friendProfileUrl)
                    : null,
                child: (friendProfileUrl.isEmpty ||
                    Uri.tryParse(friendProfileUrl)?.hasAbsolutePath != true)
                    ? Icon(Icons.person, color: Colors.black, size: 24)
                    : null,
              ),
              SizedBox(width: 9), // 🔹 이미지와 닉네임 사이 간격 9px
              // 🔹 닉네임
              Expanded(
                child: Text(
                  friendNickname.isNotEmpty ? friendNickname : widget.friendName,
                  overflow: TextOverflow.ellipsis, // 닉네임 길 경우 줄임
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // ✅ 채팅 메시지 리스트 (자동 스크롤)
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  bool isSentByMe = messages[index]["isSentByMe"] == true;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: isSentByMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        // ✅ 상대방 메시지일 경우 프로필 사진 표시
                        if (!isSentByMe)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: CircleAvatar(
                              radius: 20, // 프로필 사진 크기
                              backgroundColor: Colors.grey[300], // 기본 배경색
                              backgroundImage: NetworkImage(friendProfileUrl), // 서버 이미지
                              onBackgroundImageError: (exception, stackTrace) {
                                print("확인 : $friendProfileUrl");
                                print("⚠️ 프로필 이미지 로딩 오류: $exception");
                                setState(() {
                                  friendProfileUrl = ""; // 오류 발생 시 기본 아이콘 표시
                                });
                              },
                              child: friendProfileUrl.isEmpty
                                  ? Icon(Icons.person, color: Colors.black, size: 30)
                                  : null,
                            ),
                          ),
                        // ✅ 말풍선과 시간 표시
                        Flexible(
                          child: Column(
                            crossAxisAlignment:
                            isSentByMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSentByMe ? Colors.blueAccent : Colors
                                      .grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  messages[index]["message"]!,
                                  style: TextStyle(
                                    color: isSentByMe ? Colors.white : Colors
                                        .black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                messages[index]["time"]!,
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ✅ 입력창 - 키보드가 올라와도 가려지지 않도록 SafeArea 적용
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        onTap: () {
                          // 🔹 키보드가 올라온 후 프레임이 갱신되었을 때 스크롤 이동
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            Future.delayed(Duration(milliseconds: 300), () {
                              _scrollToBottom(); // ✅ 키보드가 올라온 후 최하단 메시지로 이동
                            });
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "메시지를 입력하세요...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          contentPadding: EdgeInsets.symmetric(vertical: 8,
                              horizontal: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.send, color: Colors.blueAccent),
                      onPressed: sendMessage,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
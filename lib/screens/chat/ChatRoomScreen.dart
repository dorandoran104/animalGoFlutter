import 'dart:convert';
import 'dart:async'; // Timer 사용
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ChatListScreen.dart'; // dotenv 사용

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
  WebSocketChannel? channel; // ✅ nullable로 변경
  late String friendProfileUrl;

  /// ✅ 자동 스크롤 함수 (마지막 메시지 위치로 이동)
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        print("📌 [DEBUG] 자동 스크롤 실행됨 (maxScrollExtent: ${_scrollController.position.maxScrollExtent})");
      } else {
        print("⚠️ [ERROR] ScrollController가 아직 초기화되지 않음");
      }
    });
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

  /// ✅ `ChatListScreen`의 채팅 목록을 업데이트하는 함수 추가
  // void updateChatList(String chatId, String lastMessage, String timestamp) {
  //   // ✅ `ChatListScreen`의 상태를 업데이트하는 글로벌 함수 호출
  //   ChatListScreen.updateChatList(chatId, lastMessage, timestamp);
  // }

  void connectWebSocket() {
    if (channel != null) return;
    channel = WebSocketChannel.connect(
      Uri.parse('ws://122.46.89.124:7000/chat/ws/${widget.chatId}'),
    );

    Stream<dynamic> broadcastStream = channel!.stream.asBroadcastStream();
    broadcastStream.listen((message) {
      print("🔹 WebSocket 수신 데이터: $message");

      try {
        final Map<String, dynamic> receivedData = jsonDecode(message);
        print("📌 [DEBUG] JSON 변환 성공: $receivedData");

        setState(() {
          if (receivedData.containsKey("messages")) {
            // ✅ 여러 개의 메시지를 포함한 경우
            List<dynamic> rawMessages = receivedData["messages"];
            for (var msg in rawMessages) {
              if (msg["message"] == lastSentMessage && msg["user_id"] == userId) {
                print("⚠️ [INFO] 내가 보낸 메시지 중복 추가 방지: ${msg["message"]}");
                continue;
              }

              // ✅ 기존의 "..." 말풍선이 있다면 교체
              int placeholderIndex = messages.indexWhere((m) => m["isPlaceholder"] == true);
              if (placeholderIndex != -1) {
                messages[placeholderIndex] = {
                  "message": msg["message"],
                  "isSentByMe": msg["user_id"] == userId,
                  "time": formatTimestamp(DateTime.now().toString()),
                };
              } else {
                messages.add({
                  "message": msg["message"],
                  "isSentByMe": msg["user_id"] == userId,
                  "time": formatTimestamp(DateTime.now().toString()),
                });

                // ✅ 채팅 목록 업데이트 (ChatListScreen에 반영)
                // updateChatList(widget.chatId, msg["message"], DateTime.now().toString());
              }
            }
          } else if (receivedData.containsKey("message") && receivedData.containsKey("user_id")) {
            if (receivedData["message"] == lastSentMessage && receivedData["user_id"] == userId) {
              print("⚠️ [INFO] 내가 보낸 메시지 중복 추가 방지: ${receivedData["message"]}");
              return;
            }

            // ✅ 기존의 "..." 말풍선을 찾아서 교체
            int placeholderIndex = messages.indexWhere((m) => m["isPlaceholder"] == true);
            if (placeholderIndex != -1) {
              messages[placeholderIndex] = {
                "message": receivedData["message"],
                "isSentByMe": receivedData["user_id"] == userId,
                "time": formatTimestamp(DateTime.now().toString()),
              };
            } else {
              messages.add({
                "message": receivedData["message"],
                "isSentByMe": receivedData["user_id"] == userId,
                "time": formatTimestamp(DateTime.now().toString()),
              });

              // ✅ 채팅 목록 업데이트 (ChatListScreen에 반영)
              // updateChatList(widget.chatId, receivedData["message"], DateTime.now().toString());
            }
          }
        });

        print("📌 [DEBUG] UI 업데이트 후 messages 개수: ${messages.length}");
        _scrollToBottom();
      } catch (e) {
        print("⚠️ [ERROR] JSON 변환 실패: $e | 원본 메시지: $message");
      }
    }, onError: (error) {
      print("⚠️ WebSocket 오류 발생: $error");
    });
    //   broadcastStream.listen((message) {
    //   print("🔹 WebSocket 수신 데이터: $message");
    //
    //   try {
    //     final Map<String, dynamic> receivedData = jsonDecode(message);
    //     print("📌 [DEBUG] JSON 변환 성공: $receivedData");
    //
    //     setState(() {
    //       if (receivedData.containsKey("messages")) {
    //         // ✅ 여러 개의 메시지를 포함한 경우
    //         List<dynamic> rawMessages = receivedData["messages"];
    //         for (var msg in rawMessages) {
    //           if (msg["message"] == lastSentMessage && msg["user_id"] == userId) {
    //             print("⚠️ [INFO] 내가 보낸 메시지 중복 추가 방지: ${msg["message"]}");
    //             continue; 0// 내가 보낸 메시지는 추가하지 않음
    //           }
    //           messages.add({
    //             "message": msg["message"],
    //             "isSentByMe": msg["user_id"] == userId,
    //             "time": formatTimestamp(DateTime.now().toString()),
    //           });
    //         }
    //       } else if (receivedData.containsKey("message") && receivedData.containsKey("user_id")) {
    //         // ✅ 단일 메시지가 올 경우
    //         if (receivedData["message"] == lastSentMessage && receivedData["user_id"] == userId) {
    //           print("⚠️ [INFO] 내가 보낸 메시지 중복 추가 방지: ${receivedData["message"]}");
    //           return; // 내가 보낸 메시지는 추가하지 않음
    //         }
    //         messages.add({
    //           "message": receivedData["message"],
    //           "isSentByMe": receivedData["user_id"] == userId,
    //           "time": formatTimestamp(DateTime.now().toString()),
    //         });
    //       }
    //
    //     });
    //
    //     print("📌 [DEBUG] UI 업데이트 후 messages 개수: ${messages.length}");
    //     _scrollToBottom();
    //   } catch (e) {
    //     print("⚠️ [ERROR] JSON 변환 실패: $e | 원본 메시지: $message");
    //   }
    // }, onError: (error) {
    //   print("⚠️ WebSocket 오류 발생: $error");
    // });
  }


  String lastSentMessage = ""; // 마지막으로 보낸 메시지 저장

  void sendMessage() {
    if (_messageController.text.isEmpty || channel == null) return;
    isSending = true;

    String messageText = _messageController.text;
    lastSentMessage = messageText; // 마지막 보낸 메시지 저장
    Map<String, dynamic> messagePayload = {
      "user_id": userId,
      "message": messageText,
    };


    // ✅ Optimistic UI - 사용자 입력을 즉시 UI에 반영
    setState(() {
      messages.add({
        "message": messageText,
        "isSentByMe": true,
        "time": formatTimestamp(DateTime.now().toString()),
      });

      // ✅ 상대방 메시지가 오기 전에 "..." 말풍선 추가
      messages.add({
        "message": "...", // 플레이스홀더 메시지
        "isSentByMe": false,
        "time": "", // 시간은 비워둠
        "isPlaceholder": true, // 플레이스홀더임을 나타내는 필드 추가
      });

      _scrollToBottom();
    });

    _messageController.clear();

    try {
      channel?.sink.add(jsonEncode(messagePayload));
      print("✅ WebSocket 메시지 전송 완료: $messageText");
    } catch (e) {
      print("⚠️ WebSocket 메시지 전송 오류: $e");
    } finally {
      isSending = false;
    }
  }

  void _forceScrollToBottom() {
    Future.delayed(Duration(milliseconds: 500), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        print("📌 [DEBUG] 1차 스크롤 실행 (500ms 후)");
      }
      Future.delayed(Duration(milliseconds: 500), () {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          print("📌 [DEBUG] 2차 스크롤 실행 (500ms 후)");
        }
      });
    });
  }


  @override
  void initState() {
    super.initState();
    // ✅ 서버에서 프로필 이미지 URL 가져오기
    friendProfileUrl =
    "${dotenv.env['SERVER_URL']}/image/show_image?character_id=${widget.chatId}";
    connectWebSocket();
    // ✅ UI 빌드 후 메시지 리스트가 로드될 때까지 기다림
    // ✅ 강제 스크롤 실행
    _forceScrollToBottom();
  }


  @override
  void dispose() {
    channel?.sink.close(1000); // ✅ null check 후 안전하게 닫기
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
          elevation: 0, // 그림자 제거 (그림자로 인해 회색처럼 보일 가능성 방지)
          scrolledUnderElevation: 0, // 스크롤 시 배경색 변화 방지
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
                  widget.friendName.isNotEmpty ? widget.friendName : widget.friendName,
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
                  var messageData = messages[index];
                  var message = messageData["message"];
                  var isSentByMe = messageData["isSentByMe"];
                  var time = messageData["time"];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment:
                      isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        // ✅ 상대방 메시지일 경우 프로필 사진 표시
                        if (!isSentByMe)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: NetworkImage(friendProfileUrl),
                              onBackgroundImageError: (exception, stackTrace) {
                                print("⚠️ 프로필 이미지 로딩 오류: $exception");
                              },
                              child: friendProfileUrl.isEmpty
                                  ? Icon(Icons.person, color: Colors.black, size: 30)
                                  : null,
                            ),
                          ),

                        // ✅ 내가 보낸 메시지일 경우 [시간] [말풍선] 순서
                        if (isSentByMe)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              time,
                              style: const TextStyle(color: Colors.black54, fontSize: 10),
                            ),
                          ),

                        // ✅ 말풍선 (Flexible 사용하여 가로폭 초과 방지)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSentByMe ? Colors.blueAccent : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              message,
                              style: TextStyle(
                                color: isSentByMe ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),

                        // ✅ 상대방 메시지일 경우 [말풍선] [시간] 순서
                        if (!isSentByMe)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              time,
                              style: const TextStyle(color: Colors.black54, fontSize: 10),
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
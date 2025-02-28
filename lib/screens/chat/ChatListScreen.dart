import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../components/BottomBar.dart';
import '../home/HomeScreen.dart';
import '../myPage/my_page.dart';
import '../village_test/Village.dart';
import 'ChatRoomScreen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final String userId = '1';
  final String serverUrl = 'ws://122.46.89.124:7000/chat/chat/ws/list/1'; // ✅ WebSocket URL
  List<Map<String, dynamic>> chatRooms = [];
  WebSocketChannel? channel; // ✅ WebSocket 채널
  bool isChatListEmpty = false; // ✅ 채팅 목록이 비어있는지 확인하는 변수

  @override
  void initState() {
    super.initState();
    connectWebSocket();
  }

  // ✅ WebSocket 연결 및 데이터 수신
  void connectWebSocket() {
    channel = WebSocketChannel.connect(Uri.parse(serverUrl));

    channel!.stream.listen((message) {
      print("🔹 WebSocket 수신 데이터: $message");

      try {
        final Map<String, dynamic> responseData = jsonDecode(message);
        final List<dynamic>? chatList = responseData["chats"];

        if (chatList == null || chatList.isEmpty) {
          print("⚠️ 서버에서 받은 채팅 목록이 비어 있음!");
          setState(() {
            chatRooms = [];
            isChatListEmpty = true; // ✅ 목록이 비어 있음을 표시
          });
          return;
        }

        List<Map<String, dynamic>> newChatRooms = chatList.map((chat) {
          final lastMessage = chat["last_message"] ?? {};

          // ✅ lastMessage 값 출력
          //print("🔹 [DEBUG] lastMessage: $lastMessage");

          return {
            "chat_id": chat["chat_id"]?.toString() ?? "unknown_id",
            "nickname": chat["nickname"]?.toString() ?? "알 수 없는 사용자",
            "create_at": formatDate(chat["create_at"]),
            "last_active_at": formatDate(chat["last_active_at"]),
            "last_message": {
              "content": lastMessage["content"]?.toString() ?? "메시지가 없습니다.",
              "sender": lastMessage["sender"]?.toString() ?? "unknown",
              "timestamp": formatDate(lastMessage["timestamp"])
            }
          };
        }).toList();

        setState(() {
          chatRooms = newChatRooms;
          isChatListEmpty = false; // ✅ 목록이 채워졌으므로 false 설정
        });

        print("✅ 최신 채팅 목록으로 갱신됨!");
      } catch (e) {
        print("⚠️ [ERROR] JSON 변환 실패: $e | 원본 메시지: $message");
      }
    }, onError: (error) {
      print("⚠️ WebSocket 오류 발생: $error");
    });
  }


  /// 날짜 형식 변환 함수
  String formatDate(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return "unknown";
    try {
      DateTime dateTime = DateTime.parse(dateTimeString);
      return DateFormat('MM/dd').format(dateTime);
    } catch (e) {
      print("⚠️ 날짜 변환 오류: $e");
      return "unknown";
    }
  }

  @override
  void dispose() {
    channel?.sink.close(status.goingAway); // ✅ WebSocket 안전하게 닫기
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("채팅 목록", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0, // 스크롤 시 배경색 변화 방지
      ),
      body: chatRooms.isEmpty // ✅ 채팅 목록이 비어있는 경우
          ? Center(
        child: Text(
          "채팅방이 없습니다.",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : ListView.builder(
        itemCount: chatRooms.length,
        itemBuilder: (context, index) {
          return Dismissible(
            key: Key(chatRooms[index]["chat_id"] ?? "unknown_id"),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "나가기",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.exit_to_app, color: Colors.white),
                ],
              ),
            ),
            child: ListTile(
              tileColor: Colors.white,
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[300],
                backgroundImage: NetworkImage(
                  "${dotenv
                      .env['SERVER_URL']}/image/show_image?character_id=${chatRooms[index]["chat_id"]}",
                ),
                onBackgroundImageError: (exception, stackTrace) {
                  print("⚠️ 이미지 로드 오류: $exception");
                },
                child: chatRooms[index]["character_id"] == "unknown_character"
                    ? Icon(Icons.person, color: Colors.black, size: 30)
                    : null,
              ),
              title: Text(chatRooms[index]["nickname"] ?? "알 수 없는 사용자"),
              subtitle: Text(
                chatRooms[index]["last_message"]?["content"]?.isNotEmpty == true
                    ? chatRooms[index]["last_message"]["content"]
                    : "메시지가 없습니다.",
              ),
              trailing: Text(
                chatRooms[index]["last_active_at"] ?? "unknown",
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ChatRoomScreen(
                          chatId: chatRooms[index]["chat_id"] ?? "unknown_id",
                          friendName: chatRooms[index]["nickname"] ??
                              "알 수 없는 사용자",
                        ),
                  ),
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: Bottombar(
        currentIndex: 2,
        onTabSelected: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      HomeScreen(),
                  transitionDuration: Duration.zero,
                ),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      VillageScreen(),
                  transitionDuration: Duration.zero,
                ),
              );
              break;
            case 2: // ✅ 채팅 리스트 화면으로 이동
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      ChatListScreen(), // ✅ userId 전달 제거
                  transitionDuration: Duration.zero,
                ),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      MyPage(),
                  transitionDuration: Duration.zero,
                ),
              );
              break;
          }
        },
      ),
    );
  }
}
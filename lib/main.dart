import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './routes/app_router.dart';
import 'screens/camera/setting/network_provider.dart';
import 'screens/camera/setting/settings_provider.dart';
import 'screens/village/CharacterSelectScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ 먼저 실행

  final prefs = await SharedPreferences.getInstance();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,  // ✅ 세로 모드 고정
  ]);

  await initializeDateFormatting('ko_KR', null); // ✅ 한국어 날짜 데이터 초기화
  await dotenv.load(fileName: "assets/.env"); // ✅ dotenv 설정 로드

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NetworkProvider()), 
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    try {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Navigation',
        home: CharacterSelectScreen(),
      );
    } catch (e, stack) {
      print("❌ MyApp에서 오류 발생: $e\n$stack");
      return MaterialApp(
        home: Scaffold(
          body: Center(child: Text("앱 실행 중 오류 발생")),
        ),
      );
    }
  }
}

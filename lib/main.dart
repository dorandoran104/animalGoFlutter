import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'screens/camera/CameraScreen.dart';
// import 'package:open_cv/screens/camera/setting/animal_characteristics_provider.dart';
import 'screens/camera/setting/network_provider.dart';
import 'screens/camera/setting/settings_provider.dart';
import 'screens/home/HomeScreen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './routes/app_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart'; // ✅ 날짜 데이터 초기화 추가
import 'package:flutter_dotenv/flutter_dotenv.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,  // 세로 모드로 고정
  ]);
  // ✅ 디버그 페인트 비활성화 (디버그 UI 가이드 제거)
  debugPaintSizeEnabled = false;
  WidgetsFlutterBinding.ensureInitialized(); // ✅ Flutter 엔진과 위젯 바인딩
  await initializeDateFormatting('ko_KR', null); // ✅ 한국어 날짜 데이터 초기화
  await dotenv.load(fileName: "assets/.env");//dotenv 추가
  // await dotenv.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NetworkProvider()), // ✅ 네트워크 프로바이더 추가
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)), // ✅ 설정 관련 프로바이더
        // ChangeNotifierProvider(create: (_) => AnimalCharacteristicsProvider()), // ✅ 동물 특성 관련 프로바이더
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // ✅ 디버그 배너 제거
      title: 'Flutter Navigation',
      theme: ThemeData(
        useMaterial3: true, // ✅ Material3 적용
        primaryColor: Colors.white, // ✅ 기본 색상 흰색
        scaffoldBackgroundColor: Colors.white, // ✅ 전체 배경 흰색
        canvasColor: Colors.white, // ✅ Drawer, Dialog 등의 기본 배경색도 흰색
        highlightColor: Colors.transparent, // ✅ 기본 클릭/터치 효과 제거
        splashColor: Colors.transparent, // ✅ 기본 클릭/터치 스플래시 제거
        focusColor: Colors.transparent, // ✅ 포커스 효과 제거
        dialogBackgroundColor: Colors.white, // ✅ 다이얼로그 배경 흰색
        cardColor: Colors.white, // ✅ 카드 배경 흰색
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white, // ✅ 앱바 배경 흰색
          foregroundColor: Colors.black, // ✅ 앱바 아이콘 및 텍스트 색상 검정
          elevation: 0, // ✅ 앱바 그림자 제거
          scrolledUnderElevation: 0, // ✅ 스크롤 시 색 변화 방지
        ),
      ),
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.generateRoute,
      home: HomeScreen(),
    );
  }
}

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         // This is the theme of your application.
//         //
//         // TRY THIS: Try running your application with "flutter run". You'll see
//         // the application has a purple toolbar. Then, without quitting the app,
//         // try changing the seedColor in the colorScheme below to Colors.green
//         // and then invoke "hot reload" (save your changes or press the "hot
//         // reload" button in a Flutter-supported IDE, or press "r" if you used
//         // the command line to start the app).
//         //
//         // Notice that the counter didn't reset back to zero; the application
//         // state is not lost during the reload. To reset the state, use hot
//         // restart instead.
//         //
//         // This works for code too, not just values: Most code changes can be
//         // tested with just a hot reload.
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//         useMaterial3: true,
//       ),
//       home: const MyHomePage(title: 'Flutter Demo Home Page'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   // This widget is the home page of your application. It is stateful, meaning
//   // that it has a State object (defined below) that contains fields that affect
//   // how it looks.

//   // This class is the configuration for the state. It holds the values (in this
//   // case the title) provided by the parent (in this case the App widget) and
//   // used by the build method of the State. Fields in a Widget subclass are
//   // always marked "final".

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;

//   void _incrementCounter() {
//     setState(() {
//       // This call to setState tells the Flutter framework that something has
//       // changed in this State, which causes it to rerun the build method below
//       // so that the display can reflect the updated values. If we changed
//       // _counter without calling setState(), then the build method would not be
//       // called again, and so nothing would appear to happen.
//       _counter++;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // This method is rerun every time setState is called, for instance as done
//     // by the _incrementCounter method above.
//     //
//     // The Flutter framework has been optimized to make rerunning build methods
//     // fast, so that you can just rebuild anything that needs updating rather
//     // than having to individually change instances of widgets.
//     return Scaffold(
//       appBar: AppBar(
//         // TRY THIS: Try changing the color here to a specific color (to
//         // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
//         // change color while the other colors stay the same.
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         // Here we take the value from the MyHomePage object that was created by
//         // the App.build method, and use it to set our appbar title.
//         title: Text(widget.title),
//       ),
//       body: Center(
//         // Center is a layout widget. It takes a single child and positions it
//         // in the middle of the parent.
//         child: Column(
//           // Column is also a layout widget. It takes a list of children and
//           // arranges them vertically. By default, it sizes itself to fit its
//           // children horizontally, and tries to be as tall as its parent.
//           //
//           // Column has various properties to control how it sizes itself and
//           // how it positions its children. Here we use mainAxisAlignment to
//           // center the children vertically; the main axis here is the vertical
//           // axis because Columns are vertical (the cross axis would be
//           // horizontal).
//           //
//           // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
//           // action in the IDE, or press "p" in the console), to see the
//           // wireframe for each widget.
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             const Text(
//               'You have pushed the button this many times:',
//             ),
//             Text(
//               '$_counter',
//               style: Theme.of(context).textTheme.headlineMedium,
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _incrementCounter,
//         tooltip: 'Increment',
//         child: const Icon(Icons.add),
//       ), // This trailing comma makes auto-formatting nicer for build methods.
//     );
//   }
// }

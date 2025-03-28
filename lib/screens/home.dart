import 'package:bus_tracker_driver_app/screens/login.dart';
import 'package:bus_tracker_driver_app/screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

String selectedRoute = "";

class _HomeState extends State<Home> {
  final List<String> routes = [
    "BUP-Uttara",
    "BUP-JFP-Kakrail",
    "BUP-Maghbazar-Kakrail",
    "BUP-Shahbagh",
    "BUP-Khamar Bari Mor",
    "BUP-Asad Gate",
    "BUP-City College",
    "BUP-Jahangir Gate",
  ];
  final List<String> routesInBangla = [
    "উত্তরা",
    "জেএফপি-কাকরাইল",
    "মগবাজার-কাকরাইল",
    "শাহবাগ",
    "খামার বাড়ি মোর",
    "আসাদ গেট",
    "সিটি কলেজ",
    "জাহাঙ্গীর গেট",
  ];

  Future<String> getCurrentVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  void checkForUpdate() async {
    final updateInfo = await InAppUpdate.checkForUpdate();
    if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
      showUpdateDialog();
    }
  }

  void showUpdateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('আপডেট করুন'),
        backgroundColor: Colors.grey[800],
        content: const Text(
          'অ্যাপটির নতুন আপডেট এসেছে। নতুন সব ফিচার উপভোগ করতে, আপডেট করুন।',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close the dialog
            },
            child: const Text(
              'পরে',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              InAppUpdate.performImmediateUpdate(); // Trigger the update
            },
            child: Text(
              'আপডেট করুন',
              style: TextStyle(
                color: Colors.green[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void routeNameConversion(int index, int id) {
    setState(() {
      selectedRoute = "${routes[index]} $id";
      print("Selected Route: $selectedRoute");
    });
    // Start sharing location directly
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapScreen()),
    );
  }

  SharedPreferences? _prefs;
  bool _isLoggedIn = false;

  void _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();

    _getPrefs();
  }

  void _getPrefs() async {
    setState(() {
      _isLoggedIn = _prefs?.getBool('isLoggedIn') ?? false;
    });
    print("Login status retrieved from SharedPreferences: $_isLoggedIn");
  }

  void _setPrefs() async {
    await _prefs?.setBool('isLoggedIn', true);
    print("Login status saved to SharedPreferences");
  }

  Widget logoutButton() {
    return IconButton(
      icon: const Icon(
        Icons.logout,
        color: Colors.white,
      ),
      onPressed: () {
        _getPrefs();
        if (_isLoggedIn) {
          _prefs?.setBool('isLoggedIn', false);
          print("User logged out");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const DriverLoginPage(),
            ),
          );
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(top: 10.0),
          child: Text(
            'রুট নির্বাচন করুন',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 25.0,
            ),
          ),
        ),
        backgroundColor: Colors.green[900],
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white, // Back button color
        ),
        actions: [
          logoutButton(),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 20.0, left: 10.0, right: 10.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 cards per row
            mainAxisSpacing: 26.0,
            crossAxisSpacing: 10.0,
            childAspectRatio: 1.2, // Aspect ratio for cards
          ),
          itemCount: routesInBangla.length, // Ensure only 8 items are displayed
          itemBuilder: (context, index) {
            final route = routesInBangla[index];
            return Card(
              color: Colors.green[50], //  as const
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.0),
              ),
              elevation: 2.5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    constraints: const BoxConstraints(
                      maxHeight: 60,
                    ),
                    height: 60,
                    padding: const EdgeInsets.all(8),
                    alignment: Alignment.center,
                    child: Text(
                      route,
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ButtonStyle(
                          elevation: const WidgetStatePropertyAll(2),
                          shadowColor:
                              const WidgetStatePropertyAll(Colors.black),
                          backgroundColor:
                              WidgetStateProperty.all(Colors.white),
                        ),
                        onPressed: () {
                          routeNameConversion(index, 1);
                        },
                        child: const Text("১ম"),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ButtonStyle(
                          elevation: const WidgetStatePropertyAll(2),
                          shadowColor:
                              const WidgetStatePropertyAll(Colors.black),
                          backgroundColor:
                              WidgetStateProperty.all(Colors.white),
                        ),
                        onPressed: () {
                          routeNameConversion(index, 2);
                        },
                        child: const Text("২য়"),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      backgroundColor: Colors.grey[200],
    );
  }
}

import 'package:bus_tracker_driver_app/screens/map_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

String selectedRoute = "BUP-Uttara 1";

class _HomeScreenState extends State<HomeScreen> {
  final List<String> routes = [
    "BUP-Uttara 1",
    "BUP-Uttara 2",
    "BUP-JFP-Kakrail 1",
    "BUP-JFP-Kakrail 2",
    "BUP-Maghbazar-Kakrail 1",
    "BUP-Maghbazar-Kakrail 2",
    "BUP-Shahbagh 1",
    "BUP-Shahbagh 2",
    "BUP-Khamar Bari Mor 1",
    "BUP-Khamar Bari Mor 2",
    "BUP-Asad Gate 1",
    "BUP-Asad Gate 2",
    "BUP-City College 1",
    "BUP-City College 2",
    "BUP-Jahangir Gate 1",
    "BUP-Jahangir Gate 2",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Driver App",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[900],
        centerTitle: true,
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Select Your Route",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[900],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 260, // Set the desired width
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey,
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: selectedRoute,
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                    borderRadius: BorderRadius.circular(15),
                    dropdownColor: Colors.white,
                    items: routes
                        .map((route) => DropdownMenuItem(
                              value: route,
                              child: Text(
                                route,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedRoute = value!;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MapScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 80, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  "Start Sharing",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

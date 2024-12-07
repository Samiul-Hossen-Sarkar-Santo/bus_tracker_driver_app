import 'package:bus_tracker_driver_app/screens/map_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedRoute = "Uttara"; // Default route
  final List<String> routes = ["Uttara", "Mirpur", "Banani"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Driver App",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green[900],
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButton<String>(
              value: selectedRoute,
              items: routes
                  .map((route) => DropdownMenuItem(
                        value: route,
                        child: Text(route),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedRoute = value!;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MapScreen()),
                );
              },
              child: const Text("Start Sharing"),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'ventes_screen.dart';
import 'parametres_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          Home(),
          VentesScreen(),
          Parametres(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: "Calendrier",
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale),
            label: "Ventes",
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: "Réglages",
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'favorites_screen.dart';
import 'info_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          // title: const Text('Map & places App'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.map), text: 'Map'),
              Tab(icon: Icon(Icons.favorite), text: 'Favorites'),
              Tab(icon: Icon(Icons.info), text: 'Info'),
          ]),
        ),
        body: const TabBarView(
          children: [
          MapScreen(),
          FavoritesScreen(),
          InfoScreen(),
        ])
      ),
    );
  }
}
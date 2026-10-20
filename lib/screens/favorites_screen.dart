import 'package:flutter/material.dart';
import 'package:map_markers/screens/audit_manager.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final AuditManager _auditManager = AuditManager();

  @override
  Widget build(BuildContext context) {
    final pins = _auditManager.pins;

    return Scaffold(
      body: pins.isEmpty
          ? const Center(
              child: Text(
                'No audit pins saved yet!\nTap anywhere on the map to add pins.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: pins.length,
              itemBuilder: (context, index) {
                final pin = pins[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.red,
                      child: Icon(Icons.place, color: Colors.white),
                    ),
                    title: Text(pin.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(pin.snippet),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _auditManager.removePin(pin.id);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
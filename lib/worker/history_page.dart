import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('punches')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const CircularProgressIndicator();
          return ListView(
            children: snap.data!.docs.map((d) {
              return ListTile(
                title: Text(d['type']),
                subtitle: Text(d['createdAt']?.toDate().toString() ?? ''),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

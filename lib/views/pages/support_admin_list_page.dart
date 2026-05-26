import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'support_page.dart';

class SupportAdminListPage extends StatelessWidget {
  const SupportAdminListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Входящие обращения", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('support_tickets')
            .orderBy('last_message_time', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text("Сообщений пока нет", style: TextStyle(color: Colors.white24))
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final String userId = docs[i].id;
              final String email = data['userEmail'] ?? "Аноним";
              final String lastMsg = data['last_message'] ?? "";

              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.person, color: Colors.blueAccent),
                ),
                title: Text(email, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  lastMsg, 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis, 
                  style: const TextStyle(color: Colors.white54)
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white10),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupportPage(
                        targetUserId: userId, 
                        targetUserEmail: email
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
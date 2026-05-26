import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../viewmodels/app_config_viewmodel.dart';

class SupportPage extends StatefulWidget {
  final String? targetUserId;    
  final String? targetUserEmail; 

  const SupportPage({super.key, this.targetUserId, this.targetUserEmail});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final conf = Provider.of<AppConfigViewModel>(context);
    
    // МАКСИМАЛЬНО ЖЕСТКАЯ ПРОВЕРКА ПОЧТЫ
    final String? userEmail = _auth.currentUser?.email?.trim().toLowerCase();
    const String adminEmail = "anvistanb17@gmail.com";
    final bool isAdmin = userEmail == adminEmail;
    
    // Если админ зашел в конкретный чат — используем ID клиента. 
    // Если зашел сам клиент — используем его собственный ID.
    final String currentChatId = (isAdmin && widget.targetUserId != null) 
        ? widget.targetUserId! 
        : conf.userId;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          isAdmin && widget.targetUserEmail != null 
              ? "Чат с: ${widget.targetUserEmail}" 
              : "Техподдержка",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('support_tickets')
                  .doc(currentChatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Ошибка доступа. Проверьте правила Firebase.", style: TextStyle(color: Colors.red)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final bool isFromAdmin = data['isAdmin'] == true;
                    
                    return _buildBubble(data['message'] ?? "", isFromAdmin, conf);
                  },
                );
              },
            ),
          ),
          _buildInput(currentChatId, isAdmin, conf),
        ],
      ),
    );
  }

  Widget _buildBubble(String msg, bool isFromAdmin, AppConfigViewModel conf) {
    return Align(
      alignment: isFromAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isFromAdmin ? Colors.white.withOpacity(0.1) : conf.accentColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isFromAdmin ? 0 : 16),
            bottomRight: Radius.circular(isFromAdmin ? 16 : 0),
          ),
        ),
        child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
    );
  }

  Widget _buildInput(String chatId, bool isAdmin, AppConfigViewModel conf) {
    return Container(
      padding: EdgeInsets.only(
        left: 10, right: 10, top: 10, 
        bottom: MediaQuery.of(context).padding.bottom + 10
      ),
      color: Colors.white.withOpacity(0.03),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Напишите сообщение...",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: conf.accentColor,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: () async {
                final text = _controller.text.trim();
                if (text.isEmpty) return;
                _controller.clear();

                final String? myEmail = _auth.currentUser?.email;

                // 1. Добавляем сообщение в историю чата
                await FirebaseFirestore.instance
                    .collection('support_tickets')
                    .doc(chatId)
                    .collection('messages')
                    .add({
                  'message': text,
                  'isAdmin': isAdmin,
                  'timestamp': FieldValue.serverTimestamp(),
                });

                // 2. Обновляем "карточку" чата в списке админа
                await FirebaseFirestore.instance.collection('support_tickets').doc(chatId).set({
                  // Если пишет админ, сохраняем email клиента, чтобы он не пропал из списка
                  'userEmail': isAdmin ? widget.targetUserEmail : myEmail, 
                  'last_message': text,
                  'last_message_time': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              },
            ),
          ),
        ],
      ),
    );
  }
}
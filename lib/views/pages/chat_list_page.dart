// lib/views/pages/chat_list_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/app_config_viewmodel.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../models/chat_model.dart';
import 'chat_page.dart';
import 'settings_page.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  // Убираем late, делаем nullable
  ChatViewModel? _chatViewModel;
  
  @override
  void initState() {
    super.initState();
    // Инициализация после получения контекста
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final conf = Provider.of<AppConfigViewModel>(context, listen: false);
      // Создаем экземпляр ChatViewModel
      _chatViewModel = ChatViewModel('', conf);
      // Загружаем чаты
      _chatViewModel!.listenToMyChats(conf.userId);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _chatViewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conf = Provider.of<AppConfigViewModel>(context);
    
    // Если ViewModel еще не инициализирована, показываем загрузку
    if (_chatViewModel == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                "Загрузка чатов...",
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Telegraph", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key, color: Colors.white),
            onPressed: () => _showJoinDialog(context, conf.userId),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => const SettingsPage())
            ),
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: conf.backgrounds[conf.bgIndex],
          ),
        ),
        child: _chatViewModel!.myChats.isEmpty
            ? const Center(
                child: Text("Нет активных чатов", style: TextStyle(color: Colors.white24)),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: _chatViewModel!.myChats.length,
                itemBuilder: (c, i) {
                  final chat = _chatViewModel!.myChats[i];
                  return _buildChatTile(context, chat);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: conf.accentColor,
        onPressed: () => _showCreateChatDialog(context, conf),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, ChatModel chat) {
    final conf = Provider.of<AppConfigViewModel>(context, listen: false);
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.white10,
        child: _buildChatIcon(chat.type),
      ),
      title: Text(
        chat.title, 
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)
      ),
      subtitle: Text(
        chat.lastMessage ?? "Сообщений нет",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 13),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white12, size: 18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => ChatViewModel(chat.id, conf),
              child: ChatPage(chat: chat),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatIcon(ChatType type) {
    switch (type) {
      case ChatType.channel:
        return const Icon(Icons.podcasts, color: Colors.orangeAccent, size: 18);
      case ChatType.group:
        return const Icon(Icons.group, color: Colors.blueAccent, size: 18);
      case ChatType.direct:
        return const Icon(Icons.person, color: Colors.greenAccent, size: 18);
    }
  }

  void _showJoinDialog(BuildContext context, String myUid) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Вступить в чат", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 18),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: "XXXXXX",
                hintStyle: TextStyle(color: Colors.white38, fontSize: 18),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Введите 6-значный код приглашения",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c), 
            child: const Text("ОТМЕНА", style: TextStyle(color: Colors.white38))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              try {
                await _chatViewModel!.joinByInviteCode(codeController.text, myUid);
                if (mounted) {
                  Navigator.pop(c);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ Вы вступили в чат!"))
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("❌ ${e.toString()}"), backgroundColor: Colors.redAccent)
                  );
                }
              }
            },
            child: const Text("ВСТУПИТЬ"),
          ),
        ],
      ),
    );
  }

  void _showCreateChatDialog(BuildContext context, AppConfigViewModel conf) {
    final titleController = TextEditingController();
    ChatType selectedType = ChatType.group;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("Создать чат", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Название",
                  hintStyle: TextStyle(color: Colors.white38),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButton<ChatType>(
                value: selectedType,
                dropdownColor: Colors.grey[900],
                isExpanded: true,
                items: ChatType.values.map((type) {
                  String label = type == ChatType.direct ? "Личный чат" : 
                                 type == ChatType.group ? "Группа" : "Канал";
                  return DropdownMenuItem(
                    value: type,
                    child: Text(label, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedType = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("ОТМЕНА")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: conf.accentColor),
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                final newChat = ChatModel(
                  id: '', 
                  title: title,
                  type: selectedType,
                  participants: [conf.userId], 
                  adminId: conf.userId,
                  updatedAt: DateTime.now(),
                );

                try {
                  await _chatViewModel!.createNewChat(newChat);
                  if (context.mounted) Navigator.pop(c);
                } catch (e) {
                  print("Ошибка: $e");
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.redAccent)
                    );
                  }
                }
              },
              child: const Text("СОЗДАТЬ", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}
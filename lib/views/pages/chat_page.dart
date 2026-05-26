import 'package:chat/services/firebase_service.dart';
import 'package:chat/views/pages/audio_call_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; 

import '../../services/block_service.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../viewmodels/app_config_viewmodel.dart';
import '../../viewmodels/chat_viewmodel.dart';
import 'call_page.dart'; 

class ChatPage extends StatefulWidget {
  final ChatModel chat;
  const ChatPage({super.key, required this.chat});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- ПОКАЗЫВАЕМ ВЫБОР ТИПА ЗВОНКА ---
  void _showCallOptions(ChatViewModel vm, AppConfigViewModel conf) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white70),
              title: const Text("Видеозвонок", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _startVideoCall(vm, conf);
              },
            ),
            ListTile(
              leading: const Icon(Icons.headset, color: Colors.white70),
              title: const Text("Аудиозвонок", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _startAudioCall(vm, conf);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startVideoCall(ChatViewModel vm, AppConfigViewModel conf) {
    final String callId = "call_${DateTime.now().millisecondsSinceEpoch}";
    vm.sendMessage("[CALL_SIGNAL_VIDEO]:$callId");
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CallPage(callId: null)),
    );
  }

  void _startAudioCall(ChatViewModel vm, AppConfigViewModel conf) {
    final String callId = "call_${DateTime.now().millisecondsSinceEpoch}";
    vm.sendMessage("[CALL_SIGNAL_AUDIO]:$callId");
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AudioCallPage(
          callId: null,
          contactName: widget.chat.title,
        ),
      ),
    );
  }

void _showInviteDialog(BuildContext context, ChatViewModel vm) {
  final searchController = TextEditingController();
  // ИСПРАВЛЕНО: меняем String на dynamic
  List<Map<String, dynamic>> searchResults = [];  // ← было List<Map<String, String>>
  bool isSearching = false;
  
  showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Добавить участника", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Введите ник (минимум 3 символа)",
                hintStyle: const TextStyle(color: Colors.white38),
                suffixIcon: isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              onChanged: (value) async {
                if (value.length >= 3) {
                  setState(() => isSearching = true);
                  final results = await vm.searchUsersByNickname(value);
                  setState(() {
                    searchResults = results;
                    isSearching = false;
                  });
                } else {
                  setState(() {
                    searchResults = [];
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            if (searchResults.isEmpty && !isSearching)
              const Text(
                "Введите ник для поиска",
                style: TextStyle(color: Colors.white38),
              )
            else
              ...searchResults.map((user) => ListTile(
                leading: const Icon(Icons.person, color: Colors.white54),
                // используем .toString() для безопасности
                title: Text(user['nickname']?.toString() ?? 'Unknown', 
                  style: const TextStyle(color: Colors.white)),
                subtitle: Text(user['email']?.toString() ?? '', 
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(80, 30),
                  ),
                  onPressed: () async {
                    try {
                      await vm.addUserByUid(widget.chat.id, user['uid']!.toString());
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Пользователь добавлен!"))
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.redAccent)
                      );
                    }
                  },
                  child: const Text("ДОБАВИТЬ", style: TextStyle(fontSize: 11)),
                ),
              )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ЗАКРЫТЬ"),
          ),
        ],
      ),
    ),
  );
}

  void _showBlockUserDialog(BuildContext context, ChatViewModel vm) {
    final TextEditingController reasonCtrl = TextEditingController();
    
    final otherUser = vm.displayMsgs.firstWhere(
      (m) => m.userId != vm.conf.userId,
      orElse: () => MessageModel(
        id: '',
        content: '',
        username: '',
        userId: '',
        roomId: '',
        createdAt: DateTime.now().toIso8601String(),
        isImage: 0,
      ),
    );
    
    if (otherUser.userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не удалось определить пользователя")),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Заблокировать пользователя?", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Вы не сможете получать сообщения от этого пользователя.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Причина (необязательно)",
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("ОТМЕНА"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final blockService = BlockService();
              await blockService.blockUser(
                otherUser.userId,
                reason: reasonCtrl.text.isEmpty ? null : reasonCtrl.text,
              );
              if (mounted) {
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Пользователь заблокирован")),
                );
              }
            },
            child: const Text("ЗАБЛОКИРОВАТЬ"),
          ),
        ],
      ),
    );
  }

  void _showReportUserDialog(BuildContext context, ChatViewModel vm) {
    final List<String> reasons = ["Спам", "Оскорбления", "Угрозы", "Неприемлемый контент", "Другое"];
    
    final otherUser = vm.displayMsgs.firstWhere(
      (m) => m.userId != vm.conf.userId,
      orElse: () => MessageModel(
        id: '',
        content: '',
        username: '',
        userId: '',
        roomId: '',
        createdAt: DateTime.now().toIso8601String(),
        isImage: 0,
      ),
    );
    
    if (otherUser.userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не удалось определить пользователя")),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Пожаловаться на пользователя", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((r) => ListTile(
            title: Text(r, style: const TextStyle(color: Colors.white)),
            onTap: () async {
              final firebaseService = FirebaseService();
              await firebaseService.sendReport(otherUser.userId, r);
              if (mounted) {
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Жалоба отправлена")),
                );
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  void _copyChatId() {
    Clipboard.setData(ClipboardData(text: widget.chat.id)); 
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ID чата скопирован!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0, 
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showMessageOptions(MessageModel message, ChatViewModel vm) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.userId == Provider.of<AppConfigViewModel>(context, listen: false).userId)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text("Удалить сообщение", style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  vm.deleteMessage(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.white70),
              title: const Text("Пожаловаться", style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                _showReportReasons(message, vm);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportReasons(MessageModel message, ChatViewModel vm) {
    final List<String> reasons = ["Спам", "Оскорбление", "Неприемлемо", "Другое"];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: reasons.map((r) => ListTile(
          title: Text(r, style: const TextStyle(color: Colors.white)),
          onTap: () {
            vm.reportMessage(message, r);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Жалоба отправлена"))
            );
          },
        )).toList(),
      ),
    );
  }

  void _handleSendMessage(ChatViewModel vm) {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      vm.sendMessage(text);
      _messageController.clear();
      _scrollToBottom();
    }
  }








  void _showInviteCodeDialog(ChatViewModel vm) async {
  try {
    final code = await vm.generateInviteCode(widget.chat.id);
    if (mounted) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("Код приглашения", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Отправьте этот код друзьям, чтобы они могли вступить в чат",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: SelectableText(
                  code,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 24,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Код действителен 7 дней",
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Код скопирован!")),
                );
              },
              child: const Text("СКОПИРОВАТЬ"),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.redAccent),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final conf = Provider.of<AppConfigViewModel>(context);

    return ChangeNotifierProvider(
      create: (_) => ChatViewModel(widget.chat.id, conf),
      child: Consumer<ChatViewModel>(
        builder: (context, vm, child) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: Text(widget.chat.title, style: const TextStyle(color: Colors.white)),
              leading: IconButton(
                icon: const Icon(CupertinoIcons.back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                // КНОПКА ЗВОНКА (открывает выбор видео/аудио)
                IconButton(
                  icon: const Icon(Icons.phone_outlined, color: Colors.white),
                  tooltip: "Звонок",
                  onPressed: () => _showCallOptions(vm, conf),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_all, color: Colors.white70),
                  tooltip: "Копировать ID чата",
                  onPressed: _copyChatId,
                ),
                if (widget.chat.type != ChatType.direct)
                  IconButton(
                    icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                    onPressed: () => _showInviteDialog(context, vm),
                  ),
                // Меню с блокировкой и жалобой
PopupMenuButton(
  icon: const Icon(Icons.more_vert, color: Colors.white),
  itemBuilder: (context) => [
    const PopupMenuItem(
      value: 'invite_code',
      child: Text("📨 Показать код приглашения"),
    ),
    const PopupMenuItem(
      value: 'block',
      child: Text("🚫 Заблокировать пользователя"),
    ),
    const PopupMenuItem(
      value: 'report_user',
      child: Text("⚠️ Пожаловаться на пользователя"),
    ),
  ],
  onSelected: (value) async {
    if (value == 'invite_code') {
      _showInviteCodeDialog(vm);
    } else if (value == 'block') {
      _showBlockUserDialog(context, vm);
    } else if (value == 'report_user') {
      _showReportUserDialog(context, vm);
    }
  },
),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: vm.displayMsgs.isEmpty 
                    ? const Center(child: Text("Сообщений нет", style: TextStyle(color: Colors.white24)))
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                        itemCount: vm.displayMsgs.length,
                        itemBuilder: (context, index) {
  final msg = vm.displayMsgs[index];
  return _MessageBubble(
    message: msg,
    isMe: msg.userId == conf.userId,
    conf: conf,
    onLongPress: () => _showMessageOptions(msg, vm),
    chatTitle: widget.chat.title, // Добавляем название чата
  );
},
                      ),
                ),
                _buildInputArea(vm, conf),
              ],
            ),
          );
        },
      ),
    );
  }















  

  Widget _buildInputArea(ChatViewModel vm, AppConfigViewModel conf) {
    bool isChannel = widget.chat.type == ChatType.channel;
    bool isAdmin = widget.chat.adminId == conf.userId;

    if (isChannel && !isAdmin) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: Colors.black,
        child: const SafeArea(
          child: Text(
            "Только администраторы могут писать в этот канал",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: Colors.black,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Сообщение...",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send, color: conf.accentColor),
              onPressed: () => _handleSendMessage(vm),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MessageBubble (оставляем без изменений) ---
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final AppConfigViewModel conf;
  final VoidCallback onLongPress;
  final String chatTitle; // Добавляем название чата

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.conf,
    required this.onLongPress,
    required this.chatTitle, // Добавляем в конструктор
  });

  @override
  Widget build(BuildContext context) {
    // Обработка видеозвонка
    if (message.content.startsWith("[CALL_SIGNAL_VIDEO]:")) {
      return _buildCallUI(context, isVideo: true);
    }
    
    // Обработка аудиозвонка
    if (message.content.startsWith("[CALL_SIGNAL_AUDIO]:")) {
      return _buildCallUI(context, isVideo: false);
    }

    String time = "";
    try {
      DateTime dt = DateTime.parse(message.createdAt);
      time = DateFormat('HH:mm').format(dt);
    } catch (_) {}

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Text(
                  message.username,
                  style: TextStyle(color: conf.accentColor.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? conf.accentColor : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      message.content,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallUI(BuildContext context, {required bool isVideo}) {
    final callId = message.content.split(':').last;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Colors.white10 : (isVideo ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isMe ? Colors.white24 : (isVideo ? Colors.green.withOpacity(0.3) : Colors.blue.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Icon(isVideo ? Icons.videocam : Icons.headset, 
               color: isMe ? Colors.white54 : (isVideo ? Colors.greenAccent : Colors.blueAccent)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe 
                ? (isVideo ? "Вы начали видеозвонок" : "Вы начали аудиозвонок")
                : (isVideo ? "Входящий видеозвонок" : "Входящий аудиозвонок"),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          if (!isMe)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isVideo ? Colors.green : Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () {
                if (isVideo) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CallPage(callId: callId)),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AudioCallPage(
                        callId: callId,
                        contactName: chatTitle, // Теперь используем переданный параметр
                      ),
                    ),
                  );
                }
              },
              child: const Text("ОТВЕТИТЬ", style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
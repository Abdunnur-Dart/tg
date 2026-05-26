import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../viewmodels/app_config_viewmodel.dart';

class ProfileCard extends StatelessWidget {
  final AppConfigViewModel conf;

  const ProfileCard({super.key, required this.conf});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Градиент в стиле ваших настроек
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ВАШЕ ИМЯ",
                    style: TextStyle(
                      color: conf.accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    conf.nickname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              // Кнопка редактирования
              _buildEditButton(context),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(color: Colors.white10, height: 1),
          ),
          // Информационные поля
          // _buildInfoRow(
          //   label: "ID аккаунта",
          //   value: conf.userId.length > 10 
          //       ? "${conf.userId.substring(0, 12)}..." 
          //       : conf.userId,
          //   icon: Icons.fingerprint,
          //   onCopy: () {
          //     Clipboard.setData(ClipboardData(text: conf.userId));
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       const SnackBar(content: Text("ID скопирован"), duration: Duration(seconds: 1)),
          //     );
          //   },
          // ),
          
          
        ],
      ),
    );
  }

  Widget _buildEditButton(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: () => _showEditNicknameDialog(context),
      icon: const Icon(Icons.edit_note, size: 24),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white10,
        foregroundColor: Colors.white,
      ),
    );
  }


void _showEditNicknameDialog(BuildContext context) {
  final controller = TextEditingController(text: conf.nickname);
  String? errorText;
  
  showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Изменить имя", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Новый псевдоним (3-20 символов)",
            hintStyle: const TextStyle(color: Colors.white30),
            errorText: errorText,
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: conf.accentColor)),
          ),
          onChanged: (value) {
            setState(() {
              errorText = null;
            });
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("ОТМЕНА")),
          ElevatedButton(
            onPressed: () async {
              try {
                await conf.updateNickname(controller.text);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                setState(() {
                  errorText = e.toString();
                });
              }
            },
            child: const Text("СОХРАНИТЬ"),
          ),
        ],
      ),
    ),
  );
}
}
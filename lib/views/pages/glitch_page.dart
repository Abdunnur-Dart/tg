import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secure_application/secure_application.dart'; // Добавь этот импорт
import '../../viewmodels/app_config_viewmodel.dart';
import 'chat_list_page.dart';
import 'pin_lock_page.dart';

class GlitchScreen extends StatefulWidget {
  const GlitchScreen({super.key});
  @override
  State<GlitchScreen> createState() => _GlitchScreenState();
}

class _GlitchScreenState extends State<GlitchScreen> {
  bool _isBlack = true;

  @override
  void initState() {
    super.initState();
    _simulateError();
  }

  void _simulateError() async {
    // 1. Небольшая задержка для эффекта "черного экрана"
    await Future.delayed(const Duration(seconds: 2));

    // 2. ШАГ 3: АКТИВАЦИЯ ЗАЩИТЫ
    // Включаем безопасный режим. Теперь при сворачивании будет черный экран.
    if (mounted) {
      SecureApplicationProvider.of(context, listen: false)?.secure();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_run_v31', false);

    if (!mounted) return;
    setState(() => _isBlack = false);

    // 3. Задержка, пока висит надпись "Initializing Secure Environment"
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    final conf = Provider.of<AppConfigViewModel>(context, listen: false);

    // 4. Переход в приложение
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => (conf.pinCode == null) 
            ? const ChatListScreen() 
            : const PinLockScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isBlack
            ? const SizedBox.shrink()
            : const Text(
                "Initializing Secure Environment",
                style: TextStyle(
                  color: Color.fromARGB(255, 255, 255, 255),
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}
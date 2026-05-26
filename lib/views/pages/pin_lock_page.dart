import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/encryption_service.dart';
import '../../viewmodels/app_config_viewmodel.dart';
import 'chat_list_page.dart';


class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _enteredPin = "";
  int _attempts = 0;
  bool _isLocked = false;
  int _secondsRemaining = 0;
  Timer? _timer;

  static const int maxAttempts = 5;
  static const int lockoutSeconds = 30;
  static const String _lockoutKey = 'pin_lockout_timestamp';

  @override
  void initState() {
    super.initState();
    _checkLockoutStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockoutStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final int? lastLockoutTime = prefs.getInt(_lockoutKey);

    if (lastLockoutTime != null) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final int diffSeconds = (now - lastLockoutTime) ~/ 1000;

      if (diffSeconds < lockoutSeconds) {
        _startLockout(lockoutSeconds - diffSeconds);
      } else {
        await prefs.remove(_lockoutKey);
      }
    }
  }

  void _onKeyPress(String num) async {
    if (_isLocked || _enteredPin.length >= 4) return;

    setState(() {
      _enteredPin += num;
    });

    if (_enteredPin.length == 4) {
      // Небольшая задержка, чтобы пользователь увидел анимацию последнего кружка
      await Future.delayed(const Duration(milliseconds: 200));
      
      final conf = Provider.of<AppConfigViewModel>(context, listen: false);
      
      // Хешируем с солью (userId)
      final hashedInput = EncryptionService.hashPin(_enteredPin, conf.userId);

      if (hashedInput == conf.pinCode) {
        _unlock();
      } else {
        _handleWrongPin();
      }
    }
  }

  void _backspace() {
    if (_enteredPin.isNotEmpty && !_isLocked) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _unlock() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lockoutKey);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
      );
  }

  void _handleWrongPin() {
      setState(() {
        _attempts++;
        _enteredPin = "";
      });

      if (_attempts >= maxAttempts) {
        _saveLockoutTime();
        _startLockout(lockoutSeconds);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Неверный PIN-код"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _saveLockoutTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lockoutKey, DateTime.now().millisecondsSinceEpoch);
  }

  void _startLockout(int seconds) {
    setState(() {
      _isLocked = true;
      _secondsRemaining = seconds;
      _attempts = 0; 
      _enteredPin = "";
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _isLocked = false;
          _timer?.cancel();
          _clearLockoutData();
        }
      });
    });
  }

  Future<void> _clearLockoutData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lockoutKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, color: Colors.white24, size: 64),
              const SizedBox(height: 20),
              Text(
                _isLocked ? "ДОСТУП ЗАБЛОКИРОВАН" : "ВВЕДИТЕ PIN-КОД",
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 18, 
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 15),
              if (_isLocked)
                Text(
                  "Попробуйте снова через $_secondsRemaining сек.",
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    bool isFilled = index < _enteredPin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? Colors.blueAccent : Colors.white10,
                        border: Border.all(color: isFilled ? Colors.blueAccent : Colors.white24),
                        boxShadow: isFilled ? [
                          BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.5), blurRadius: 10)
                        ] : [],
                      ),
                    );
                  }),
                ),
              const SizedBox(height: 60),
              Opacity(
                opacity: _isLocked ? 0.3 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      if (index == 9) return const SizedBox.shrink();
                      if (index == 10) return _buildNumButton("0");
                      if (index == 11) return _buildIconButton(Icons.backspace_outlined, _backspace);
                      return _buildNumButton("${index + 1}");
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumButton(String num) {
    return InkWell(
      onTap: () => _onKeyPress(num),
      borderRadius: BorderRadius.circular(50),
      child: Center(
        child: Text(
          num,
          style: const TextStyle(
            fontSize: 32, 
            color: Colors.white, 
            fontWeight: FontWeight.w300
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback action) {
    return InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(50),
      child: Center(
        child: Icon(icon, color: Colors.white54, size: 28),
      ),
    );
  }
}
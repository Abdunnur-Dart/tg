import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgeVerificationPage extends StatefulWidget {
  const AgeVerificationPage({super.key});

  @override
  State<AgeVerificationPage> createState() => _AgeVerificationPageState();
}

class _AgeVerificationPageState extends State<AgeVerificationPage> {
  bool _isAdult = false;
  bool _agreeTerms = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 80,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                "ПОДТВЕРЖДЕНИЕ ВОЗРАСТА",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Данное приложение содержит контент, предназначенный только для лиц старше 18 лет.\n\n"
                "Нажимая «Продолжить», вы подтверждаете, что вам есть 18 лет, и вы соглашаетесь с "
                "Пользовательским соглашением и Политикой конфиденциальности.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: _isAdult,
                      onChanged: (val) => setState(() => _isAdult = val ?? false),
                      title: const Text(
                        "Мне есть 18 лет",
                        style: TextStyle(color: Colors.white),
                      ),
                      activeColor: Colors.orangeAccent,
                      checkColor: Colors.white,
                    ),
                    CheckboxListTile(
                      value: _agreeTerms,
                      onChanged: (val) => setState(() => _agreeTerms = val ?? false),
                      title: const Text(
                        "Я принимаю условия использования",
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: GestureDetector(
                        onTap: () => _showTermsDialog(context),
                        child: const Text(
                          "Прочитать соглашение",
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                        ),
                      ),
                      activeColor: Colors.orangeAccent,
                      checkColor: Colors.white,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isAdult && _agreeTerms && !_isLoading)
                      ? _saveVerification
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "ПРОДОЛЖИТЬ",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveVerification() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('age_verified_v1', true);
    
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          "Пользовательское соглашение",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              _getFullTermsText(),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("ЗАКРЫТЬ", style: TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
  }

  String _getFullTermsText() {
    return """
ПОЛЬЗОВАТЕЛЬСКОЕ СОГЛАШЕНИЕ

1. ОБЩИЕ ПОЛОЖЕНИЯ
1.1. Настоящее Соглашение регулирует отношения между администрацией приложения "Telegraph" (далее — Администрация) и Пользователем.
1.2. Использование Приложения означает полное и безоговорочное принятие Пользователем условий настоящего Соглашения.

2. ВОЗРАСТНЫЕ ОГРАНИЧЕНИЯ
2.1. Приложение предназначено для лиц, достигших 18 лет.
2.2. Пользователь несет полную ответственность за предоставление недостоверных сведений о своем возрасте.

3. ЗАПРЕЩЕННЫЙ КОНТЕНТ
3.1. Пользователям запрещается отправлять сообщения, содержащие:
- Нецензурную лексику
- Ссылки на сторонние ресурсы
- Номера телефонов и адреса электронной почты
- Порнографические материалы
- Призывы к насилию и экстремизму
- Оскорбления и клевету
- Рекламу без согласования

4. ОТВЕТСТВЕННОСТЬ
4.1. Администрация не несет ответственности за содержание сообщений, отправленных пользователями.
4.2. Администрация оставляет за собой право удалять любой контент и блокировать пользователей без объяснения причин.

5. КОНФИДЕНЦИАЛЬНОСТЬ
5.1. Администрация обязуется не передавать персональные данные третьим лицам, кроме случаев, предусмотренных законодательством.

6. ИЗМЕНЕНИЕ УСЛОВИЙ
6.1. Администрация оставляет за собой право изменять условия Соглашения в любое время.

7. КОНТАКТЫ
7.1. Все вопросы и жалобы принимаются через раздел "Поддержка" в приложении.

Дата последнего обновления: 14.05.2026
    """;
  }
}
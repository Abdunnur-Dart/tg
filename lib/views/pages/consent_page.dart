import 'package:chat/main.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
 // Вместо '../../widgets/document_viewer.dart'

class ConsentPage extends StatefulWidget {
  const ConsentPage({super.key});

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  bool _isPrivacyChecked = false;
  bool _isTermsChecked = false;
  bool _isLoading = false;

  static const String _privacyUrl = "https://anvistanb17-afk.github.io/politika/";
  static const String _termsUrl = "https://anvistanb17-afk.github.io/Terms-of-Use-/";

  Future<void> _saveConsent() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('user_consent_v1', true);
    
    // В конце метода _saveConsent, вместо Navigator.pushReplacement:
if (mounted) {
  // Просто пересоздаем виджет, чтобы main заново проверил согласие
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const AppInitializer()),
  );
}
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool get _canProceed => _isPrivacyChecked && _isTermsChecked;

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
              const Icon(Icons.security_rounded, size: 64, color: Colors.blueAccent),
              const SizedBox(height: 24),
              const Text(
                "ДОБРО ПОЖАЛОВАТЬ",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              
              // Политика
              Row(
                children: [
                  Checkbox(
                    value: _isPrivacyChecked,
                    onChanged: (val) => setState(() => _isPrivacyChecked = val ?? false),
                    activeColor: Colors.blueAccent,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _launchUrl(_privacyUrl),
                      child: const Text(
                        "Я принимаю Политику конфиденциальности",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Соглашение
              Row(
                children: [
                  Checkbox(
                    value: _isTermsChecked,
                    onChanged: (val) => setState(() => _isTermsChecked = val ?? false),
                    activeColor: Colors.blueAccent,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _launchUrl(_termsUrl),
                      child: const Text(
                        "Я принимаю Пользовательское соглашение",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _canProceed ? _saveConsent : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canProceed ? Colors.blueAccent : Colors.grey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("ПРОДОЛЖИТЬ", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
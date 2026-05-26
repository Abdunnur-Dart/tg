

class ContentFilter {
  // Чёрный список слов (можно расширять)
  static final List<String> _badWords = [
    'хуй', 'пизда', 'бля', 'мудак', 'сука', 'ебал', 'ебать', 
    'нахуй', 'охуел', 'поебень', 'долбоеб', 'пидор', 'гандон',
    // Английские
    'fuck', 'shit', 'bitch', 'cunt', 'dick', 'asshole',
  ];
  
  // Регулярка для поиска ссылок
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?',
    caseSensitive: false,
  );
  
  // Регулярка для телефонов
  static final RegExp _phoneRegex = RegExp(
    r'[\+\(]?[0-9]{1,3}[\)\-]?[0-9]{3,5}[\)\-]?[0-9]{4,6}',
    caseSensitive: false,
  );
  
  // Регулярка для email
  static final RegExp _emailRegex = RegExp(
    r'[\w\.-]+@[\w\.-]+\.\w+',
    caseSensitive: false,
  );
  
  // Проверка на нецензурную лексику
  static bool containsProfanity(String text) {
    final lowerText = text.toLowerCase();
    for (var word in _badWords) {
      if (lowerText.contains(word)) return true;
    }
    return false;
  }
  
  // Проверка на ссылки
  static bool containsLinks(String text) {
    return _urlRegex.hasMatch(text);
  }
  
  // Проверка на телефон
  static bool containsPhone(String text) {
    return _phoneRegex.hasMatch(text);
  }
  
  // Проверка на email
  static bool containsEmail(String text) {
    return _emailRegex.hasMatch(text);
  }
  
  // ЦЕНЗУРИРОВАНИЕ (заменяет плохие слова на ***)
  static String censor(String text) {
    var result = text;
    for (var word in _badWords) {
      final regex = RegExp(word, caseSensitive: false);
      result = result.replaceAll(regex, '*' * word.length);
    }
    return result;
  }
  
  // ОСНОВНОЙ МЕТОД: проверка сообщения перед отправкой
  static ValidationResult validate(String text) {
    if (text.isEmpty) {
      return ValidationResult(false, "Сообщение не может быть пустым");
    }
    
    if (containsProfanity(text)) {
      return ValidationResult(false, "Сообщение содержит недопустимые слова");
    }
    
    if (containsLinks(text)) {
      return ValidationResult(false, "Ссылки запрещены в чатах");
    }
    
    if (containsPhone(text)) {
      return ValidationResult(false, "Номера телефонов запрещены");
    }
    
    return ValidationResult(true, null);
  }
  
  // Для администраторов — разрешить всё, но отметить
  static bool isAdminBypass(String userEmail) {
    // Администратор может отправлять ссылки
    return userEmail == 'anvistanb17@gmail.com';
  }
}

class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  
  ValidationResult(this.isValid, this.errorMessage);
}
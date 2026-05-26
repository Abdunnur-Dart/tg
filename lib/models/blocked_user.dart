class BlockedUser {
  final String userId;
  final String blockedBy;
  final DateTime blockedAt;
  final String? reason;
  
  BlockedUser({
    required this.userId,
    required this.blockedBy,
    required this.blockedAt,
    this.reason,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'blockedBy': blockedBy,
      'blockedAt': blockedAt.toIso8601String(),
      'reason': reason,
    };
  }
  
  factory BlockedUser.fromMap(Map<String, dynamic> map) {
    return BlockedUser(
      userId: map['userId'],
      blockedBy: map['blockedBy'],
      blockedAt: DateTime.parse(map['blockedAt']),
      reason: map['reason'],
    );
  }
}
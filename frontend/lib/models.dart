class UserModel {
  final String id;
  final String username;
  final String role;
  final int xp;
  final int streak;

  UserModel({
    required this.id,
    required this.username,
    required this.role,
    required this.xp,
    required this.streak,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] ?? 'New Hero',
      role: json['role'] ?? 'child', 
      xp: json['xp'] is int ? json['xp'] as int : int.parse(json['xp'].toString()),
      streak: json['streak'] is int ? json['streak'] as int : int.parse(json['streak'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'xp': xp,
      'streak': streak,
    };
  }
}

class DashboardData {
  final UserModel profile;
  final WalletModel wallet;

  DashboardData({required this.profile, required this.wallet});
}

class WalletModel {
  final String profileId; // 💡 Added to uniquely bind ledger instances to owners
  final double saveBalance;
  final double spendBalance;
  final double shareBalance;

  WalletModel({
    required this.profileId, // 💡 Exposed in constructor signature
    required this.saveBalance,
    required this.spendBalance,
    required this.shareBalance,
  });

  double get totalBalance => saveBalance + spendBalance + shareBalance;

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      // Maps your Postgres snake_case column key to your local camelCase property safely
      profileId: json['profile_id'] ?? '', 
      saveBalance: (json['save_balance'] as num?)?.toDouble() ?? 0.0,
      spendBalance: (json['spend_balance'] as num?)?.toDouble() ?? 0.0,
      shareBalance: (json['share_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'save_balance': saveBalance,
      'spend_balance': spendBalance,
      'share_balance': shareBalance,
    };
  }
}

class QuestModel {
  final String id;
  final String title;
  final String story; // 🐯 This is the narrative body text!
  final String choiceA;
  final String choiceB;
  final String outcomeA;
  final String outcomeB;
  final int rewardXp;

  QuestModel({
    required this.id,
    required this.title,
    required this.story,
    required this.choiceA,
    required this.choiceB,
    required this.outcomeA,
    required this.outcomeB,
    required this.rewardXp,
  });

  factory QuestModel.fromJson(Map<String, dynamic> json) {
    return QuestModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      story: json['story'] ?? '', // Maps from your DB column seamlessly
      choiceA: json['choice_a'] ?? '',
      choiceB: json['choice_b'] ?? '',
      outcomeA: json['outcome_a'] ?? '',
      outcomeB: json['outcome_b'] ?? '',
      rewardXp: json['reward_xp'] ?? 0,
    );
  }

  // 💡 Added toJson() method to easily serialize your model if needed
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'story': story,
      'choice_a': choiceA,
      'choice_b': choiceB,
      'outcome_a': outcomeA,
      'outcome_b': outcomeB,
      'reward_xp': rewardXp,
    };
  }
}
class UserModel {
  final String id;
  final String username;
  final String role;
  final int xp;
  final int streak;
  final int completedTasksCount;
  final int earnedBadgesCount;
  final bool hasCompletedOnboarding;

  UserModel({
    required this.id,
    required this.username,
    required this.role,
    required this.xp,
    required this.streak,
    this.completedTasksCount = 0,
    this.earnedBadgesCount = 0,
    this.hasCompletedOnboarding = false,
    
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] ?? 'New Hero',
      role: json['role'] ?? 'child', 
      xp: json['xp'] is int ? json['xp'] as int : int.parse(json['xp'].toString()),
      streak: json['streak'] is int ? json['streak'] as int : int.parse(json['streak'].toString()),
      completedTasksCount: (json['completed_tasks_count'] as num?)?.toInt() ?? 0,
      earnedBadgesCount: (json['earned_badges_count'] as num?)?.toInt() ?? 0,
      hasCompletedOnboarding: json['has_completed_onboarding'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'xp': xp,
      'streak': streak,
      'completed_tasks_count': completedTasksCount,
      'earned_badges_count': earnedBadgesCount,
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
  final String story; // 🐯 This is the narrative body text!
  final String choiceA;
  final String choiceB;
  final String outcomeA;
  final String outcomeB;
  final int rewardXp;

  QuestModel({
    required this.id,
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
      'story': story,
      'choice_a': choiceA,
      'choice_b': choiceB,
      'outcome_a': outcomeA,
      'outcome_b': outcomeB,
      'reward_xp': rewardXp,
    };
  }
}
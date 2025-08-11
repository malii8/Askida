class ApplicationModel {
  final String id;
  final String askiId;
  final String applicantUserId;
  final String applicantUserName;
  final DateTime appliedAt;
  final ApplicationStatus status;

  ApplicationModel({
    required this.id,
    required this.askiId,
    required this.applicantUserId,
    required this.applicantUserName,
    required this.appliedAt,
    this.status = ApplicationStatus.pending,
  });

  Map<String, dynamic> toJson() {
    return {
      'askiId': askiId,
      'applicantUserId': applicantUserId,
      'applicantUserName': applicantUserName,
      'appliedAt': appliedAt.toIso8601String(),
      'status': status.name,
    };
  }

  factory ApplicationModel.fromMap(String id, Map<String, dynamic> map) {
    return ApplicationModel(
      id: id,
      askiId: map['askiId'] ?? '',
      applicantUserId: map['applicantUserId'] ?? '',
      applicantUserName: map['applicantUserName'] ?? '',
      appliedAt: DateTime.parse(map['appliedAt']),
      status: ApplicationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ApplicationStatus.pending,
      ),
    );
  }

  ApplicationModel copyWith({
    String? id,
    String? askiId,
    String? applicantUserId,
    String? applicantUserName,
    DateTime? appliedAt,
    ApplicationStatus? status,
  }) {
    return ApplicationModel(
      id: id ?? this.id,
      askiId: askiId ?? this.askiId,
      applicantUserId: applicantUserId ?? this.applicantUserId,
      applicantUserName: applicantUserName ?? this.applicantUserName,
      appliedAt: appliedAt ?? this.appliedAt,
      status: status ?? this.status,
    );
  }
}

enum ApplicationStatus {
  pending, // Beklemede
  accepted, // Kabul edildi
  rejected, // Reddedildi
}

extension ApplicationStatusExtension on ApplicationStatus {
  String get displayName {
    switch (this) {
      case ApplicationStatus.pending:
        return 'Beklemede';
      case ApplicationStatus.accepted:
        return 'Kabul Edildi';
      case ApplicationStatus.rejected:
        return 'Reddedildi';
    }
  }
}

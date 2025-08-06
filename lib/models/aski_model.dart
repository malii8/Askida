class AskiModel {
  final String id;
  final String productId;
  final String productName;
  final String corporateId;
  final String corporateName;
  final String donorUserId;
  final String donorUserName;
  final String? message;
  final DateTime createdAt;
  final AskiStatus status;
  final String? takenByUserId;
  final String? takenByUserName;
  final DateTime? takenAt;
  final String qrCode;

  AskiModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.corporateId,
    required this.corporateName,
    required this.donorUserId,
    required this.donorUserName,
    this.message,
    required this.createdAt,
    required this.status,
    this.takenByUserId,
    this.takenByUserName,
    this.takenAt,
    required this.qrCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'corporateId': corporateId,
      'corporateName': corporateName,
      'donorUserId': donorUserId,
      'donorUserName': donorUserName,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'takenByUserId': takenByUserId,
      'takenByUserName': takenByUserName,
      'takenAt': takenAt?.toIso8601String(),
      'qrCode': qrCode,
    };
  }

  factory AskiModel.fromJson(Map<String, dynamic> json) {
    return AskiModel(
      id: json['id'] ?? '',
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      corporateId: json['corporateId'] ?? '',
      corporateName: json['corporateName'] ?? '',
      donorUserId: json['donorUserId'] ?? '',
      donorUserName: json['donorUserName'] ?? '',
      message: json['message'],
      createdAt: DateTime.parse(json['createdAt']),
      status: AskiStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AskiStatus.active,
      ),
      takenByUserId: json['takenByUserId'],
      takenByUserName: json['takenByUserName'],
      takenAt: json['takenAt'] != null ? DateTime.parse(json['takenAt']) : null,
      qrCode: json['qrCode'] ?? '',
    );
  }

  AskiModel copyWith({
    String? id,
    String? productId,
    String? productName,
    String? corporateId,
    String? corporateName,
    String? donorUserId,
    String? donorUserName,
    String? message,
    DateTime? createdAt,
    AskiStatus? status,
    String? takenByUserId,
    String? takenByUserName,
    DateTime? takenAt,
    String? qrCode,
  }) {
    return AskiModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      corporateId: corporateId ?? this.corporateId,
      corporateName: corporateName ?? this.corporateName,
      donorUserId: donorUserId ?? this.donorUserId,
      donorUserName: donorUserName ?? this.donorUserName,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      takenByUserId: takenByUserId ?? this.takenByUserId,
      takenByUserName: takenByUserName ?? this.takenByUserName,
      takenAt: takenAt ?? this.takenAt,
      qrCode: qrCode ?? this.qrCode,
    );
  }
}

enum AskiStatus {
  active, // Askıda bekliyor
  taken, // Alındı
  expired, // Süresi doldu
  cancelled, // İptal edildi
}

extension AskiStatusExtension on AskiStatus {
  String get displayName {
    switch (this) {
      case AskiStatus.active:
        return 'Askıda';
      case AskiStatus.taken:
        return 'Alındı';
      case AskiStatus.expired:
        return 'Süresi Doldu';
      case AskiStatus.cancelled:
        return 'İptal Edildi';
    }
  }

  String get description {
    switch (this) {
      case AskiStatus.active:
        return 'Askıda bekliyor, alınabilir';
      case AskiStatus.taken:
        return 'Başka bir kullanıcı tarafından alındı';
      case AskiStatus.expired:
        return 'Askı süresi doldu';
      case AskiStatus.cancelled:
        return 'Askı iptal edildi';
    }
  }
}




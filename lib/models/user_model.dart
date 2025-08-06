class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final UserType userType;
  final String? organizationName; // Sadece kurumsal kullanıcılar için
  final String? phone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVerified;
  final bool isApproved; // Kurumsal kullanıcılar için onay durumu
  final String? companyName; // Şirket adı (kurumsal kullanıcılar için)
  final String? taxNumber; // Vergi numarası (kurumsal kullanıcılar için)

  // Getter'lar için alias'lar
  String get name => fullName;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.userType,
    this.organizationName,
    this.phone,
    required this.createdAt,
    DateTime? updatedAt,
    this.isVerified = false,
    this.isApproved = false,
    this.companyName,
    this.taxNumber,
  }) : updatedAt = updatedAt ?? createdAt;

  // Firestore'dan veri okuma
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      userType: UserType.values.firstWhere(
        (e) => e.toString() == 'UserType.${map['userType']}',
        orElse: () => UserType.individual,
      ),
      organizationName: map['organizationName'],
      phone: map['phone'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt:
          map['updatedAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
              : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      isVerified: map['isVerified'] ?? false,
      isApproved: map['isApproved'] ?? false,
      companyName: map['companyName'],
      taxNumber: map['taxNumber'],
    );
  }

  // Firestore'a veri yazma
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'userType': userType.toString().split('.').last,
      'organizationName': organizationName,
      'phone': phone,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isVerified': isVerified,
      'isApproved': isApproved,
      'companyName': companyName,
      'taxNumber': taxNumber,
    };
  }

  // Kopya oluşturma
  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    UserType? userType,
    String? organizationName,
    String? phone,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isVerified,
    bool? isApproved,
    String? companyName,
    String? taxNumber,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      userType: userType ?? this.userType,
      organizationName: organizationName ?? this.organizationName,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isVerified: isVerified ?? this.isVerified,
      isApproved: isApproved ?? this.isApproved,
      companyName: companyName ?? this.companyName,
      taxNumber: taxNumber ?? this.taxNumber,
    );
  }
}

enum UserType {
  individual, // Bireysel kullanıcı
  corporate, // Kurumsal kullanıcı
}

extension UserTypeExtension on UserType {
  String get displayName {
    switch (this) {
      case UserType.individual:
        return 'Bireysel Kullanıcı';
      case UserType.corporate:
        return 'Kurumsal Kullanıcı';
    }
  }

  String get description {
    switch (this) {
      case UserType.individual:
        return 'Kişisel askılar oluşturun ve paylaşın';
      case UserType.corporate:
        return 'Kuruluş olarak askı sistemi yönetin';
    }
  }
}




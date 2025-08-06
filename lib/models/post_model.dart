class PostModel {
  final String id;
  final String creatorUid;
  final String creatorName;
  final String? organizationName; // Kurumsal kullanıcılar için
  final String title;
  final String description;
  final List<String> imageUrls;
  final PostType postType;
  final PostCategory category;
  final PostStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? selectedUserUid; // Seçilen kullanıcı (rastgele seçim için)
  final List<String> applicantUids; // Başvuran kullanıcılar
  final int maxApplicants; // Maksimum başvuran sayısı
  final String? location; // Konum bilgisi (ileride harita için)
  final Map<String, dynamic>? metadata; // Ek bilgiler

  // Yeni ürün sistemi alanları
  final String productType; // Ürün türü (Kahve, Yemek, vs.)
  final int quantity; // Ürün adedi
  final int remainingQuantity; // Kalan ürün adedi
  final String targetOrganizationId; // Hedef kurum ID'si
  final String targetOrganizationName; // Hedef kurum adı
  final String? claimCode; // 6 haneli teslim alma kodu
  final String? qrCode; // QR kod
  final bool allowRandomClaim; // Rastgele alma izni
  final List<String> claimedByUids; // Ürünü alanların UID'leri

  PostModel({
    required this.id,
    required this.creatorUid,
    required this.creatorName,
    this.organizationName,
    required this.title,
    required this.description,
    this.imageUrls = const [],
    required this.postType,
    required this.category,
    this.status = PostStatus.active,
    required this.createdAt,
    this.expiresAt,
    this.selectedUserUid,
    this.applicantUids = const [],
    this.maxApplicants = 10,
    this.location,
    this.metadata,
    // Yeni ürün sistemi parametreleri
    required this.productType,
    required this.quantity,
    int? remainingQuantity,
    required this.targetOrganizationId,
    required this.targetOrganizationName,
    this.claimCode,
    this.qrCode,
    this.allowRandomClaim = true,
    this.claimedByUids = const [],
  }) : remainingQuantity = remainingQuantity ?? quantity;

  // ID olmadan post oluşturmak için (Firestore'a kaydetmeden önce)
  PostModel.create({
    required this.creatorUid,
    required this.creatorName,
    this.organizationName,
    required this.title,
    required this.description,
    this.imageUrls = const [],
    required this.postType,
    required this.category,
    this.status = PostStatus.active,
    required this.createdAt,
    this.expiresAt,
    this.selectedUserUid,
    this.applicantUids = const [],
    this.maxApplicants = 10,
    this.location,
    this.metadata,
    // Yeni ürün sistemi parametreleri
    required this.productType,
    required this.quantity,
    int? remainingQuantity,
    required this.targetOrganizationId,
    required this.targetOrganizationName,
    this.claimCode,
    this.qrCode,
    this.allowRandomClaim = true,
    this.claimedByUids = const [],
  }) : id = '',
       remainingQuantity = remainingQuantity ?? quantity;

  // Firestore'dan veri okuma
  factory PostModel.fromMap(String id, Map<String, dynamic> map) {
    return PostModel(
      id: id,
      creatorUid: map['creatorUid'] ?? '',
      creatorName: map['creatorName'] ?? '',
      organizationName: map['organizationName'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      postType: PostType.values.firstWhere(
        (e) => e.toString() == 'PostType.${map['postType']}',
        orElse: () => PostType.firstCome,
      ),
      category: PostCategory.values.firstWhere(
        (e) => e.toString() == 'PostCategory.${map['category']}',
        orElse: () => PostCategory.other,
      ),
      status: PostStatus.values.firstWhere(
        (e) => e.toString() == 'PostStatus.${map['status']}',
        orElse: () => PostStatus.active,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      expiresAt:
          map['expiresAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['expiresAt'])
              : null,
      selectedUserUid: map['selectedUserUid'],
      applicantUids: List<String>.from(map['applicantUids'] ?? []),
      maxApplicants: map['maxApplicants'] ?? 10,
      location: map['location'],
      metadata: map['metadata'],
      // Yeni ürün sistemi alanları
      productType: map['productType'] ?? 'Genel',
      quantity: map['quantity'] ?? 1,
      remainingQuantity: map['remainingQuantity'],
      targetOrganizationId: map['targetOrganizationId'] ?? '',
      targetOrganizationName: map['targetOrganizationName'] ?? '',
      claimCode: map['claimCode'],
      qrCode: map['qrCode'],
      allowRandomClaim: map['allowRandomClaim'] ?? true,
      claimedByUids: List<String>.from(map['claimedByUids'] ?? []),
    );
  }

  // Firestore'a veri yazma
  Map<String, dynamic> toMap() {
    return {
      'creatorUid': creatorUid,
      'creatorName': creatorName,
      'organizationName': organizationName,
      'title': title,
      'description': description,
      'imageUrls': imageUrls,
      'postType': postType.toString().split('.').last,
      'category': category.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
      'selectedUserUid': selectedUserUid,
      'applicantUids': applicantUids,
      'maxApplicants': maxApplicants,
      'location': location,
      'metadata': metadata,
      // Yeni ürün sistemi alanları
      'productType': productType,
      'quantity': quantity,
      'remainingQuantity': remainingQuantity,
      'targetOrganizationId': targetOrganizationId,
      'targetOrganizationName': targetOrganizationName,
      'claimCode': claimCode,
      'qrCode': qrCode,
      'allowRandomClaim': allowRandomClaim,
      'claimedByUids': claimedByUids,
    };
  }

  // Kopya oluşturma
  PostModel copyWith({
    String? id,
    String? creatorUid,
    String? creatorName,
    String? organizationName,
    String? title,
    String? description,
    List<String>? imageUrls,
    PostType? postType,
    PostCategory? category,
    PostStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? selectedUserUid,
    List<String>? applicantUids,
    int? maxApplicants,
    String? location,
    Map<String, dynamic>? metadata,
    // Yeni ürün sistemi alanları
    String? productType,
    int? quantity,
    int? remainingQuantity,
    String? targetOrganizationId,
    String? targetOrganizationName,
    String? claimCode,
    String? qrCode,
    bool? allowRandomClaim,
    List<String>? claimedByUids,
  }) {
    return PostModel(
      id: id ?? this.id,
      creatorUid: creatorUid ?? this.creatorUid,
      creatorName: creatorName ?? this.creatorName,
      organizationName: organizationName ?? this.organizationName,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      postType: postType ?? this.postType,
      category: category ?? this.category,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      selectedUserUid: selectedUserUid ?? this.selectedUserUid,
      applicantUids: applicantUids ?? this.applicantUids,
      maxApplicants: maxApplicants ?? this.maxApplicants,
      location: location ?? this.location,
      metadata: metadata ?? this.metadata,
      // Yeni ürün sistemi alanları
      productType: productType ?? this.productType,
      quantity: quantity ?? this.quantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      targetOrganizationId: targetOrganizationId ?? this.targetOrganizationId,
      targetOrganizationName:
          targetOrganizationName ?? this.targetOrganizationName,
      claimCode: claimCode ?? this.claimCode,
      qrCode: qrCode ?? this.qrCode,
      allowRandomClaim: allowRandomClaim ?? this.allowRandomClaim,
      claimedByUids: claimedByUids ?? this.claimedByUids,
    );
  }

  // Yardımcı getterlar
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isCompleted => status == PostStatus.completed;
  bool get canApply => status == PostStatus.active && !isExpired;
  int get remainingSlots => maxApplicants - applicantUids.length;
  bool get hasAvailableSlots => remainingSlots > 0;
}

// Gönderi türü
enum PostType {
  firstCome, // İlk gelen alır
  random, // Rastgele seçim
}

// Gönderi kategorisi
enum PostCategory {
  food, // Yemek
  clothing, // Giyim
  books, // Kitap
  electronics, // Elektronik
  toys, // Oyuncak
  furniture, // Mobilya
  health, // Sağlık
  education, // Eğitim
  other, // Diğer
}

// Gönderi durumu
enum PostStatus {
  active, // Aktif
  completed, // Tamamlandı
  cancelled, // İptal edildi
  expired, // Süresi doldu
}

// Extension'lar
extension PostTypeExtension on PostType {
  String get displayName {
    switch (this) {
      case PostType.firstCome:
        return 'İlk Gelen Alır';
      case PostType.random:
        return 'Rastgele Seçim';
    }
  }

  String get description {
    switch (this) {
      case PostType.firstCome:
        return 'İlk başvuran kişi ürünü alır';
      case PostType.random:
        return 'Belirli süre sonra rastgele seçim yapılır';
    }
  }

  String get icon {
    switch (this) {
      case PostType.firstCome:
        return '⚡';
      case PostType.random:
        return '🎲';
    }
  }
}

extension PostCategoryExtension on PostCategory {
  String get displayName {
    switch (this) {
      case PostCategory.food:
        return 'Yemek';
      case PostCategory.clothing:
        return 'Giyim';
      case PostCategory.books:
        return 'Kitap';
      case PostCategory.electronics:
        return 'Elektronik';
      case PostCategory.toys:
        return 'Oyuncak';
      case PostCategory.furniture:
        return 'Mobilya';
      case PostCategory.health:
        return 'Sağlık';
      case PostCategory.education:
        return 'Eğitim';
      case PostCategory.other:
        return 'Diğer';
    }
  }

  String get icon {
    switch (this) {
      case PostCategory.food:
        return '🍕';
      case PostCategory.clothing:
        return '👕';
      case PostCategory.books:
        return '📚';
      case PostCategory.electronics:
        return '📱';
      case PostCategory.toys:
        return '🧸';
      case PostCategory.furniture:
        return '🪑';
      case PostCategory.health:
        return '💊';
      case PostCategory.education:
        return '🎓';
      case PostCategory.other:
        return '📦';
    }
  }
}

extension PostStatusExtension on PostStatus {
  String get displayName {
    switch (this) {
      case PostStatus.active:
        return 'Aktif';
      case PostStatus.completed:
        return 'Tamamlandı';
      case PostStatus.cancelled:
        return 'İptal Edildi';
      case PostStatus.expired:
        return 'Süresi Doldu';
    }
  }
}




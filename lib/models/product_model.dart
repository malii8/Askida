class ProductModel {
  final String id;
  final String name;
  final String category;
  final String description;
  final String corporateId;
  final String corporateName;
  final double? price;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.corporateId,
    required this.corporateName,
    this.price,
    this.imageUrl,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'corporateId': corporateId,
      'corporateName': corporateName,
      'price': price,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      corporateId: json['corporateId'] ?? '',
      corporateName: json['corporateName'] ?? '',
      price: json['price']?.toDouble(),
      imageUrl: json['imageUrl'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      isActive: json['isActive'] ?? true,
    );
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    String? corporateId,
    String? corporateName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      corporateId: corporateId ?? this.corporateId,
      corporateName: corporateName ?? this.corporateName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

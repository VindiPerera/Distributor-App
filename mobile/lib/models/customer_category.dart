class CustomerCategory {
  final int id;
  final String name;
  final int? parentId;
  final List<CustomerCategory> children;

  CustomerCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.children = const [],
  });

  bool get isSubcategory => parentId != null;

  factory CustomerCategory.fromJson(Map<String, dynamic> json) {
    return CustomerCategory(
      id: json['id'],
      name: json['name'],
      parentId: json['parent_id'],
      children: json['children'] != null
          ? (json['children'] as List)
                .map((e) => CustomerCategory.fromJson(e))
                .toList()
          : const [],
    );
  }
}

class Invoice {
  final int id;
  final int roomId;
  final String? roomName;
  final String? tenantUsername;
  final int month;
  final int year;
  final int electricOld;
  final int electricNew;
  final int waterOld;
  final int waterNew;
  final bool isPaid;
  final double totalAmount;
  final DateTime? createdDate;

  const Invoice({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.tenantUsername,
    required this.month,
    required this.year,
    required this.electricOld,
    required this.electricNew,
    required this.waterOld,
    required this.waterNew,
    required this.isPaid,
    required this.totalAmount,
    required this.createdDate,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: (json['id'] as num?)?.toInt() ?? 0,
      roomId: (json['roomId'] as num?)?.toInt() ?? 0,
      roomName: json['roomName']?.toString(),
      tenantUsername: json['tenantUsername']?.toString(),
      month: (json['month'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      electricOld: (json['electricOld'] as num?)?.toInt() ?? 0,
      electricNew: (json['electricNew'] as num?)?.toInt() ?? 0,
      waterOld: (json['waterOld'] as num?)?.toInt() ?? 0,
      waterNew: (json['waterNew'] as num?)?.toInt() ?? 0,
      isPaid: json['isPaid'] == true,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      createdDate: json['createdDate'] == null
          ? null
          : DateTime.tryParse(json['createdDate'].toString()),
    );
  }
}

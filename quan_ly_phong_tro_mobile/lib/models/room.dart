class Room {
  final int id;
  final String roomName;
  final double price;
  final bool status;
  final String? tenantUsername;
  final double electricPrice;
  final double waterPrice;
  final double wifiPrice;
  final bool hasWifi;
  final double trashPrice;

  const Room({
    required this.id,
    required this.roomName,
    required this.price,
    required this.status,
    required this.tenantUsername,
    required this.electricPrice,
    required this.waterPrice,
    required this.wifiPrice,
    required this.hasWifi,
    required this.trashPrice,
  });

  bool get isEmpty => status;

  factory Room.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) => (value as num?)?.toDouble() ?? 0;
    return Room(
      id: (json['id'] as num?)?.toInt() ?? 0,
      roomName: json['roomName']?.toString() ?? 'Phong',
      price: toDouble(json['price']),
      status: json['status'] == true,
      tenantUsername: json['tenantUsername']?.toString(),
      electricPrice: toDouble(json['electricPrice']),
      waterPrice: toDouble(json['waterPrice']),
      wifiPrice: toDouble(json['wifiPrice']),
      hasWifi: json['hasWifi'] == true,
      trashPrice: toDouble(json['trashPrice']),
    );
  }

  Map<String, dynamic> toRequestJson() => {
        'roomName': roomName,
        'price': price,
        'status': status,
        'tenantUsername': tenantUsername,
        'electricPrice': electricPrice,
        'waterPrice': waterPrice,
        'wifiPrice': wifiPrice,
        'hasWifi': hasWifi,
        'trashPrice': trashPrice,
      };
}

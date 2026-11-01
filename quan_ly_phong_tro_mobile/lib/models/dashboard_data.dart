class DashboardData {
  final int totalRooms;
  final int rentedRooms;
  final int emptyRooms;
  final int totalTenants;
  final double totalMoney;
  final int unpaidInvoices;

  const DashboardData({
    required this.totalRooms,
    required this.rentedRooms,
    required this.emptyRooms,
    required this.totalTenants,
    required this.totalMoney,
    required this.unpaidInvoices,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      totalRooms: (json['totalRooms'] as num?)?.toInt() ?? 0,
      rentedRooms: (json['rentedRooms'] as num?)?.toInt() ?? 0,
      emptyRooms: (json['emptyRooms'] as num?)?.toInt() ?? 0,
      totalTenants: (json['totalTenants'] as num?)?.toInt() ?? 0,
      totalMoney: (json['totalMoney'] as num?)?.toDouble() ?? 0,
      unpaidInvoices: (json['unpaidInvoices'] as num?)?.toInt() ?? 0,
    );
  }
}

class ContractModel {
  final int id;
  final String fullName;
  final String cccd;
  final String address;
  final String phoneNumber;
  final DateTime startDate;
  final int contractTerm;
  final DateTime endDate;
  final DateTime createdDate;
  final String status;

  const ContractModel({
    required this.id,
    required this.fullName,
    required this.cccd,
    required this.address,
    required this.phoneNumber,
    required this.startDate,
    required this.contractTerm,
    required this.endDate,
    required this.createdDate,
    required this.status,
  });

  factory ContractModel.fromJson(Map<String, dynamic> json) {
    DateTime parse(dynamic value) =>
        DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    return ContractModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['fullName']?.toString() ?? '',
      cccd: json['cccd']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      startDate: parse(json['startDate']),
      contractTerm: (json['contractTerm'] as num?)?.toInt() ?? 1,
      endDate: parse(json['endDate']),
      createdDate: parse(json['createdDate']),
      status: json['status']?.toString() ?? 'Pending',
    );
  }
}

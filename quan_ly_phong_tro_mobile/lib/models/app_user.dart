class AppUser {
  final int id;
  final String username;
  final String? fullName;
  final String role;
  final int? roomId;
  final String? roomName;

  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.roomId,
    this.roomName,
  });

  bool get isOwner => role.toLowerCase() == 'owner';
  bool get isManager => role.toLowerCase() == 'manager';
  bool get isTenant => role.toLowerCase() == 'tenant' || role.toLowerCase() == 'user';
  bool get canManageRooms => isOwner || isManager;
  bool get canManageInvoices => isOwner || isManager;
  bool get canManageContracts => isOwner || isManager;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString(),
      role: json['role']?.toString() ?? 'tenant',
      roomId: (json['roomId'] as num?)?.toInt(),
      roomName: json['roomName']?.toString(),
    );
  }
}

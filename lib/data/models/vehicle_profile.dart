class VehicleProfile {
  final String id;
  final String userId;
  final String name;
  final String vehicleType;
  final String? motorcycleType;
  final String? suspensionType;
  final String? phoneMount;
  final double baselineMean;
  final double baselineStd;
  final double baselineRms;
  final double baselinePeak95;
  final Map<String, dynamic> thresholdConfig;
  final DateTime createdAt;
  final DateTime updatedAt;

  VehicleProfile({
    required this.id,
    required this.userId,
    required this.name,
    this.vehicleType = 'motorcycle',
    this.motorcycleType,
    this.suspensionType,
    this.phoneMount,
    required this.baselineMean,
    required this.baselineStd,
    required this.baselineRms,
    required this.baselinePeak95,
    this.thresholdConfig = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory VehicleProfile.fromMap(Map<String, dynamic> map) {
    return VehicleProfile(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      vehicleType: map['vehicle_type'] as String? ?? 'motorcycle',
      motorcycleType: map['motorcycle_type'] as String?,
      suspensionType: map['suspension_type'] as String?,
      phoneMount: map['phone_mount'] as String?,
      baselineMean: (map['baseline_mean'] as num).toDouble(),
      baselineStd: (map['baseline_std'] as num).toDouble(),
      baselineRms: (map['baseline_rms'] as num).toDouble(),
      baselinePeak95: (map['baseline_peak95'] as num).toDouble(),
      thresholdConfig: map['threshold_config'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'vehicle_type': vehicleType,
      'motorcycle_type': motorcycleType,
      'suspension_type': suspensionType,
      'phone_mount': phoneMount,
      'baseline_mean': baselineMean,
      'baseline_std': baselineStd,
      'baseline_rms': baselineRms,
      'baseline_peak95': baselinePeak95,
      'threshold_config': thresholdConfig,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

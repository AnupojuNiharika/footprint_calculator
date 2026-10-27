class CarbonCalculation {
  CarbonCalculation({
    this.id,
    this.userId,
    required this.date,
    required this.transportEmission,
    required this.electricityEmission,
    required this.foodEmission,
    required this.travelEmission,
    required this.totalEmission,
    this.transportDistance,
    this.electricityUnits,
    this.foodType,
    this.travelDistance,
    this.travelType,
  });

  final int? id;
  final int? userId;
  final String date;
  final double transportEmission;
  final double electricityEmission;
  final double foodEmission;
  final double travelEmission;
  final double totalEmission;
  final double? transportDistance;
  final double? electricityUnits;
  final String? foodType;
  final double? travelDistance;
  final String? travelType;

  factory CarbonCalculation.fromMap(Map<String, dynamic> map) {
    return CarbonCalculation(
      id: map['id'] as int?,
      userId: map['user_id'] as int?,
      date: map['date'] as String,
      transportEmission: (map['transport_emission'] as num).toDouble(),
      electricityEmission: (map['electricity_emission'] as num).toDouble(),
      foodEmission: (map['food_emission'] as num).toDouble(),
      travelEmission: (map['travel_emission'] as num).toDouble(),
      totalEmission: (map['total_emission'] as num).toDouble(),
      transportDistance: map['transport_distance'] == null
          ? null
          : (map['transport_distance'] as num).toDouble(),
      electricityUnits: map['electricity_units'] == null
          ? null
          : (map['electricity_units'] as num).toDouble(),
      foodType: map['food_type'] as String?,
      travelDistance: map['travel_distance'] == null
          ? null
          : (map['travel_distance'] as num).toDouble(),
      travelType: map['travel_type'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'date': date,
      'user_id': userId,
      'transport_emission': transportEmission,
      'electricity_emission': electricityEmission,
      'food_emission': foodEmission,
      'travel_emission': travelEmission,
      'total_emission': totalEmission,
      'transport_distance': transportDistance,
      'electricity_units': electricityUnits,
      'food_type': foodType,
      'travel_distance': travelDistance,
      'travel_type': travelType,
    };
  }
}

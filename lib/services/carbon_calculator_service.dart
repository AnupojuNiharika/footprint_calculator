import '../models/carbon_calculation.dart';
import 'emission_factors.dart';

enum TravelMode { car, bike, bus, train, walk }
enum DietType { vegetarian, mixed, meat }

class CarbonInput {
  const CarbonInput({
    required this.travelMode,
    required this.dailyDistanceKm,
    required this.monthlyElectricityUnits,
    required this.dietType,
  });

  final TravelMode travelMode;
  final double dailyDistanceKm;
  final double monthlyElectricityUnits;
  final DietType dietType;
}

class CarbonBreakdown {
  CarbonBreakdown({
    required this.transportEmission,
    required this.electricityEmission,
    required this.foodEmission,
    this.travelEmission,
  });

  final double transportEmission;
  final double electricityEmission;
  final double foodEmission;
  final double? travelEmission;

  double get totalEmission => transportEmission + electricityEmission + foodEmission;

  CarbonCalculation toCalculation({
    required String date,
    required double? transportDistance,
    required double? electricityUnits,
    required String? foodType,
    required double? travelDistance,
    required String? travelType,
  }) {
    return CarbonCalculation(
      date: date,
      transportEmission: transportEmission,
      electricityEmission: electricityEmission,
      foodEmission: foodEmission,
      travelEmission: travelEmission ?? transportEmission,
      totalEmission: totalEmission,
      transportDistance: transportDistance,
      electricityUnits: electricityUnits,
      foodType: foodType,
      travelDistance: travelDistance,
      travelType: travelType,
    );
  }
}

class CarbonCalculatorService {
  CarbonBreakdown calculate(CarbonInput input) {
    final transport = _calculateTransport(input.travelMode, input.dailyDistanceKm);
    final electricity = _calculateElectricity(input.monthlyElectricityUnits);
    final food = _calculateFood(input.dietType);

    return CarbonBreakdown(
      transportEmission: transport,
      electricityEmission: electricity,
      foodEmission: food,
      travelEmission: transport,
    );
  }

  double _calculateTransport(TravelMode mode, double distanceKm) {
    final safeDistance = distanceKm.clamp(0.0, 200.0);
    switch (mode) {
      case TravelMode.car:
        return (safeDistance * 365.0 * EmissionFactors.carPerKm).clamp(0.0, 12.0);
      case TravelMode.bike:
        return 0.08;
      case TravelMode.bus:
        return (safeDistance * 365.0 * EmissionFactors.busPerKm).clamp(0.0, 8.0);
      case TravelMode.train:
        return (safeDistance * 365.0 * EmissionFactors.trainPerKm).clamp(0.0, 8.0);
      case TravelMode.walk:
        return 0.03;
    }
  }

  double _calculateElectricity(double monthlyUnits) {
    final safeUsage = monthlyUnits.clamp(0.0, 5000.0);
    return (safeUsage * 12.0 * EmissionFactors.electricityPerUnit).clamp(0.0, 20.0);
  }

  double _calculateFood(DietType diet) {
    switch (diet) {
      case DietType.vegetarian:
        return EmissionFactors.vegetarianDiet;
      case DietType.mixed:
        return EmissionFactors.mixedDiet;
      case DietType.meat:
        return EmissionFactors.meatDiet;
    }
  }
}

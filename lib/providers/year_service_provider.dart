import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/year_service.dart';

// Provider for the YearService instance
// We assume YearService.create() is potentially async or needs setup,
// but for a simple provider, we might just instantiate it.
// If YearService.create() MUST be awaited, we'd need a FutureProvider
// or initialize it differently (e.g., in main and provide the instance).
// For now, let's assume direct instantiation or that it's handled elsewhere.
// UPDATE: YearService.create() IS async. We need to handle this.
// Let's make YearService itself injectable or provide the created instance.
// Easiest for now: Provide the instance created in main().

// Provider that holds the readily available YearService instance
// This requires passing the instance created in main() to the ProviderScope overrides.
final yearServiceProvider = Provider<YearService>((ref) {
  // This will throw if the instance isn't provided in ProviderScope overrides.
  // An alternative is using a FutureProvider that calls YearService.create().
  throw UnimplementedError(
    'YearService instance must be provided in ProviderScope overrides',
  );
});

// --- Alternative using FutureProvider (if not providing instance from main) ---
/*
final yearServiceFutureProvider = FutureProvider<YearService>((ref) async {
  return await YearService.create();
});

// Then other providers would depend on yearServiceFutureProvider.when(...)
*/

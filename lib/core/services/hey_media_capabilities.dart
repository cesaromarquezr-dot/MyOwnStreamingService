import '../architecture.dart';

/// Capability registry used by text/voice Hey Media clients.
///
/// This registry describes what can be requested. Authorization and actual
/// mutation still happen in the backend.
class HeyMediaCapabilityRegistry {
  const HeyMediaCapabilityRegistry();

  List<ProductCapability> searchableCapabilities() =>
      List<ProductCapability>.unmodifiable(MasterProductCapabilities.all);

  ProductCapability? find(String key) {
    final clean = key.trim().toLowerCase();
    for (final capability in MasterProductCapabilities.all) {
      if (capability.key == clean) return capability;
    }
    return null;
  }
}

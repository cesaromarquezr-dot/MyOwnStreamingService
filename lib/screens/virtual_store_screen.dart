import 'package:material_ui/material_ui.dart';

import '../interface_experience.dart';
import '../virtual_store_experience_screen.dart';

/// Standalone route for opening the Virtual Store from the More menu.
/// It uses the same profile-scoped configuration and experience as Home.
class VirtualStoreScreen extends StatefulWidget {
  const VirtualStoreScreen({super.key});

  @override
  State<VirtualStoreScreen> createState() => _VirtualStoreScreenState();
}

class _VirtualStoreScreenState extends State<VirtualStoreScreen> {
  late final Future<InterfaceExperienceConfig> _configFuture;

  @override
  void initState() {
    super.initState();
    _configFuture = InterfaceExperienceRepository.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InterfaceExperienceConfig>(
      future: _configFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text('The Virtual Store could not be loaded.')),
          );
        }
        return VirtualStoreExperienceScreen(config: snapshot.data!);
      },
    );
  }
}

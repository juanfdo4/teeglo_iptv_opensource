import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../player/providers/cast_provider.dart';
import '../../player/widgets/cast_player_controls.dart';

class CastStatusIndicator extends ConsumerWidget {
  const CastStatusIndicator({super.key});

  void _showDevicePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final devicesAsync = ref.watch(castDevicesProvider);

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transmitir a...',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  devicesAsync.when(
                    data: (devices) {
                      if (devices.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text('Buscando dispositivos en la red...', style: TextStyle(color: Colors.white70)),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return ListTile(
                            leading: const Icon(Icons.tv, color: Colors.white),
                            title: Text(device.name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(device.address.address, style: const TextStyle(color: Colors.white54)),
                            onTap: () {
                              Navigator.pop(context);
                              ref.read(castNotifierProvider.notifier).connectToDevice(device);
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    )),
                    error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCastControls(BuildContext context, WidgetRef ref, dynamic session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cast_connected, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Control de Transmisión',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              CastPlayerControls(session: session),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(castNotifierProvider.notifier).disconnect();
                },
                icon: const Icon(Icons.stop_screen_share, color: Colors.redAccent),
                label: const Text('Detener transmisión', style: TextStyle(color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castState = ref.watch(castNotifierProvider);
    final session = castState.session;

    if (session == null) {
      return IconButton(
        icon: const Icon(Icons.cast, color: Colors.white),
        onPressed: () => _showDevicePicker(context, ref),
      );
    }

    return GestureDetector(
      onTap: () => _showCastControls(context, ref, session),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cast_connected, color: Colors.blue, size: 16)
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(duration: 2.seconds, color: Colors.white),
            const SizedBox(width: 8),
            const Text(
              'TV Conectada',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.2, end: 0),
    );
  }
}

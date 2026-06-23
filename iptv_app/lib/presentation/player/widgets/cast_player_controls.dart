import 'package:flutter/material.dart';
import 'package:dart_cast/dart_cast.dart';

class CastPlayerControls extends StatelessWidget {
  final CastSession session;

  const CastPlayerControls({super.key, required this.session});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 48,
              icon: const Icon(Icons.pause, color: Colors.white),
              onPressed: () => session.pause(),
            ),
            const SizedBox(width: 20),
            IconButton(
              iconSize: 48,
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              onPressed: () => session.play(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        StreamBuilder<Duration>(
          stream: session.durationStream,
          initialData: session.duration,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            
            // Si la duración es 0 o negativa (Chromecast reporta -1 para Live Streams),
            // asumimos que es en vivo y no mostramos la barra
            if (duration.inSeconds <= 0) {
              return const Padding(
                padding: EdgeInsets.only(top: 20.0),
                child: Text('🔴 EN VIVO', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              );
            }

            return StreamBuilder<Duration>(
              stream: session.positionStream,
              initialData: session.position,
              builder: (context, positionSnapshot) {
                final position = positionSnapshot.data ?? Duration.zero;
                
                // Evitar errores si la posición es mayor que la duración
                final safePosition = position > duration ? duration : position;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.blue,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.blue,
                          overlayColor: Colors.blue.withAlpha(32),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                        ),
                        child: Slider(
                          min: 0.0,
                          max: duration.inSeconds.toDouble(),
                          value: safePosition.inSeconds.toDouble(),
                          onChanged: (value) {
                            session.seek(Duration(seconds: value.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(safePosition),
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

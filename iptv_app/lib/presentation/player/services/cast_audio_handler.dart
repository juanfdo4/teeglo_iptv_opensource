import 'package:audio_service/audio_service.dart';
import 'package:dart_cast/dart_cast.dart';

class CastAudioHandler extends BaseAudioHandler with SeekHandler {
  CastSession? _castSession;

  void attachSession(CastSession session, String title, String subtitle) {
    _castSession = session;

    // Configurar la información de la canción/video (MediaItem)
    mediaItem.add(
      MediaItem(
        id: 'cast_session',
        album: 'IPTV Chromecast',
        title: title,
        artist: subtitle,
        // Aquí podrías agregar un artUri si tienes una imagen
        // artUri: Uri.parse('https://...'),
      ),
    );

    // EMITIR INMEDIATAMENTE UN ESTADO DE REPRODUCCIÓN
    // Esto obliga a Android a registrar la MediaSession inmediatamente y poner el Foreground Service.
    playbackState.add(
      playbackState.value.copyWith(
        controls: [MediaControl.pause, MediaControl.stop],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1],
        processingState: AudioProcessingState.buffering,
        playing: true, // ¡Clave para que no nos maten!
      ),
    );

    // Escuchar el estado de reproducción del Chromecast
    _castSession?.stateStream.listen((state) {
      bool isPlaying =
          state == SessionState.playing || state == SessionState.buffering;

      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            if (isPlaying) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [
            0,
            1,
          ], // Mostrar los dos controles
          processingState: state == SessionState.buffering
              ? AudioProcessingState.buffering
              : AudioProcessingState.ready,
          playing: isPlaying,
        ),
      );
    });
  }

  void detachSession() {
    _castSession = null;
    playbackState.add(playbackState.value.copyWith(playing: false));
  }

  @override
  Future<void> play() async {
    _castSession?.play();
  }

  @override
  Future<void> pause() async {
    _castSession?.pause();
  }

  @override
  Future<void> stop() async {
    await _castSession?.disconnect();
    detachSession();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    _castSession?.seek(position);
  }
}

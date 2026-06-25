import 'package:dio/dio.dart';
import '../../core/error/exceptions.dart';

abstract class PlaylistRemoteDataSource {
  Future<String> fetchM3uContent(String url, {void Function(int count, int total)? onReceiveProgress});
}

class PlaylistRemoteDataSourceImpl implements PlaylistRemoteDataSource {
  final Dio dio;

  PlaylistRemoteDataSourceImpl({required this.dio});

  @override
  Future<String> fetchM3uContent(String url, {void Function(int count, int total)? onReceiveProgress}) async {
    try {
      final response = await dio.get(
        url,
        onReceiveProgress: onReceiveProgress,
        options: Options(responseType: ResponseType.plain),
      );
      if (response.statusCode == 200) {
        return response.data.toString();
      } else {
        throw ServerException();
      }
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Unknown Dio error');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}

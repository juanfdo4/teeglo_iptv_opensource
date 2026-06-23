import 'package:dio/dio.dart';
import '../../core/error/exceptions.dart';

abstract class PlaylistRemoteDataSource {
  Future<String> fetchM3uContent(String url);
}

class PlaylistRemoteDataSourceImpl implements PlaylistRemoteDataSource {
  final Dio dio;

  PlaylistRemoteDataSourceImpl({required this.dio});

  @override
  Future<String> fetchM3uContent(String url) async {
    try {
      final response = await dio.get(url);
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

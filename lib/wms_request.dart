library wms_request;

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wms_request/Interceptor/wms_interceptor.dart';
import 'package:wms_request/Interceptor/wms_queued_interceptor.dart';
import 'package:wms_request/wms_response.dart';
import 'package:crypto/crypto.dart';

enum RequestMethod { get, post, put, delete, upload, patch, head }

const methodValues = {
  RequestMethod.get: 'get',
  RequestMethod.post: 'post',
  RequestMethod.put: 'put',
  RequestMethod.delete: 'delete',
  RequestMethod.upload: 'upload',
  RequestMethod.patch: 'patch',
  RequestMethod.head: 'head'
};

class WMSRequest {
  // 连接超时
  static const Duration _connectTimeOut = Duration(seconds: 30);
  // 响应超时
  static const Duration _receiveTimeOut = Duration(seconds: 30);
  // token api
  static String _tokenUrl = '';

  static String _keyOfToken = '';
  static bool isTokenExpired = false;

  static Dio get _dio {
    var dio = Dio(_options);
    _dio.interceptors.add(WMSInterceptors());

    _dio.interceptors.add(TokenQueuedInterceptor(_tokenUrl));

    /// 处理特殊业务
    // _dio.transformer = DioTransformer();
    return dio;
  }

  static void init({
    required String baseUrl,
    required String userAgent,
    required String toUrl,
    required String keyOfToken,
  }) {
    _options.baseUrl = baseUrl;
    _options.headers.putIfAbsent("User-Agent", () => userAgent);
    _tokenUrl = toUrl;
    _keyOfToken = keyOfToken;
  }

  final CancelToken cancel = CancelToken();

  static BaseOptions get _options {
    var op = BaseOptions(
      connectTimeout: _connectTimeOut,
      receiveTimeout: _receiveTimeOut,
      contentType: "application/json",
    );
    op.headers.putIfAbsent("Accept-Language", () => "zh-CN,zh;q=0.9,en;q=0.8");
    return op;
  }

  static void updateToken(String newOne) {
    _options.queryParameters[_keyOfToken] = newOne;
  }

  static String get token => _options.queryParameters[_keyOfToken];

  static String get keyOfToken => _keyOfToken;

  /// 代理
  static void setProxy(
      {required String proxyHost, required String proxyPort, bool enable = false}) {
    if (enable) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (uri) {
            return 'PROXY $proxyHost:$proxyPort';
          };
          client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );
    }
  }

  /// 证书校验
  void setHttpsCertificateVerification({
    String pem = '',
    bool enable = false,
  }) {
    if (enable) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          // Don't trust any certificate just because their root cert is trusted.
          final HttpClient client = HttpClient(context: SecurityContext(withTrustedRoots: false));
          // You can test the intermediate / root cert here. We just ignore it.
          client.badCertificateCallback = (cert, host, port) => true;
          return client;
        },
        validateCertificate: (cert, host, port) {
          // Check that the cert fingerprint matches the one we expect.
          // We definitely require _some_ certificate.
          if (cert == null) {
            return false;
          }
          // Validate it any way you want. Here we only check that
          // the fingerprint matches the OpenSSL SHA256.
          return pem == sha256.convert(cert.der).toString();
        },
      );
    }
  }

  /// 开启日志打印
  void openLog() {
    _dio.interceptors.add(LogInterceptor(responseBody: true));
  }

  /// 请求
  static Future<WMSResposnse> request<T>(
    String path, {
    RequestMethod method = RequestMethod.get,
    dynamic params,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Options? options,
    CancelToken? cancelToken,
    bool needToken = true,
    List<WMSRequestSuffix> suffixs = const [],
  }) async {
    options ??= Options(method: methodValues[method], headers: {});
    options.headers!.putIfAbsent('needToken', () => needToken);

    Response response;
    response = await _dio.request(path,
        data: params,
        cancelToken: cancelToken,
        options: options,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress);

    return response.data;
  }

  /// 请求
  Future<WMSResposnse> download<T>(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    bool needToken = true,
  }) async {
    Response response;
    response = await _dio.download(
      url,
      savePath,
      onReceiveProgress: onReceiveProgress,
    );
    if (response.data is ResponseBody) {
      if (response.data.statusCode == 200) {
        return WMSResposnse(success: true, data: response.data.stream);
      } else {
        return WMSResposnse(success: false, data: {});
      }
    }
    return response.data;
  }

  ///根据各平台构建userAgent信息
  Future<String> _buildUserAgent() async {
    String userAgent = '';
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidDeviceInfo = await deviceInfoPlugin.androidInfo;
      userAgent =
          "${packageInfo.packageName}/${packageInfo.version}(${androidDeviceInfo.model}/${androidDeviceInfo.version.release})";
    } else if (Platform.isIOS) {
      IosDeviceInfo iosDeviceInfo = await deviceInfoPlugin.iosInfo;
      userAgent =
          "${packageInfo.packageName}/${packageInfo.version}(${iosDeviceInfo.model};${iosDeviceInfo.systemName} ${iosDeviceInfo.systemVersion})";
    }

    return userAgent;
  }
}

class WMSRequestSuffix<T> {
  final String key;
  final T value;
  WMSRequestSuffix(this.key, this.value);
  suffixString() => '$key=$value';
}

library wms_request;

import 'dart:developer';
import 'dart:io';

import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:wms_request/Interceptor/wms_interceptor.dart';
import 'package:wms_request/Interceptor/wms_token_interceptor.dart';
import 'package:package_info/package_info.dart';
import 'package:device_info/device_info.dart';
import 'package:wms_request/wms_response.dart';

enum RequestMethod {
  get,
  post,
  put,
  delete,
  upload,
  patch,
  head,
}

class WMSRequest {
  /// 连接超时
  static const int CONNECT_TIMEOUT = 30 * 1000;

  /// 响应超时
  static const int RECEIVE_TIMEOUT = 30 * 1000;

  static WMSRequest _instance;

  factory WMSRequest(String billingNumber) => _getInstance();

  static WMSRequest get instance => _getInstance();

  Dio _dio;

  CancelToken _cancelToken = CancelToken();

  BaseOptions _options;

  String _token;

  Future<String> Function() onTokenExpired;

  static WMSRequest _getInstance() {
    if (_instance == null) {
      _instance = WMSRequest._init();
    }
    return _instance;
  }

  WMSRequest._init() {
    if (_dio == null) {
      // init 初始化
      _options = BaseOptions(
        connectTimeout: CONNECT_TIMEOUT,
        receiveTimeout: RECEIVE_TIMEOUT,
        contentType: "application/json",
      );
      _options.headers.putIfAbsent("Accept-Language", () => "zh-CN,zh;q=0.9,en;q=0.8");

      _dio = Dio(_options);

      /// 添加拦截器
      _dio.interceptors.add(WMSInterceptors());

      /// 刷新token
      var tokenInterceptor = TokenRefreshInterceptor(onTokenExpired: () {
        return onTokenExpired();
      });
      _dio.interceptors.add(tokenInterceptor);

      /// TODO: 添加转换器 处理特殊业务
      // _dio.transformer = DioTransformer();

      /// TODO: 添加缓存拦截器
      // _dio.interceptors.add(DioCacheInterceptors());
    }
  }

  /// 代理
  void setProxy({String proxyHost, String proxyPort, bool enable = false}) {
    if (enable) {
      (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
          (HttpClient client) {
        client.findProxy = (uri) {
          return 'PROXY $proxyHost:$proxyPort';
        };
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      };
    }
  }

  /// 证书校验
  void setHttpsCertificateVerification({
    String pem,
    bool enable = false,
  }) {
    if (enable) {
      (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
        client.badCertificateCallback = (X509Certificate cert, String host, int port) {
          if (cert.pem == pem) {
            return true;
          }
          return false;
        };
      };
    }
  }

  void lock() {
    _dio.lock();
  }

  void unlock() {
    _dio.unlock();
  }

  /// 开启日志打印
  void openLog() {
    _dio.interceptors.add(LogInterceptor(responseBody: true));
  }

  /// 设置url
  set baseUrl(String baseUrl) {
    _options.baseUrl = baseUrl ?? 'https://mziosbss2.bizgo.com/';
  }

  get baseUrl => _options.baseUrl;

  set token(String token) {
    _token = token ?? '';
  }

  get token => _token ?? '';

  /// 请求
  Future<WMSResposnse> request<T>(
    String path, {
    RequestMethod method = RequestMethod.get,
    dynamic params,
    ProgressCallback onSendProgress,
    ProgressCallback onReceiveProgress,
    Options options,
    CancelToken cancelToken,
    bool needToken = true,
    List<WMSRequestSuffix> suffixs = const [],
  }) async {
    const _methodValues = {
      RequestMethod.get: 'get',
      RequestMethod.post: 'post',
      RequestMethod.put: 'put',
      RequestMethod.delete: 'delete',
      RequestMethod.upload: 'upload',
      RequestMethod.patch: 'patch',
      RequestMethod.head: 'head'
    };

    if (!_options.headers.containsKey("User-Agent")) {
      _options.headers.putIfAbsent("User-Agent", () async {
        return await _buildUserAgent();
      });
    }
    options ??= Options(method: _methodValues[method], headers: {});

    if (needToken) {
      _options.queryParameters['sidWms'] = _token;
    } else {
      _options.queryParameters.remove('sidWms');
    }

    if (suffixs.isNotEmpty) {
      suffixs.forEach((e) {
        if (e?.key != null) {
          options.headers.putIfAbsent(e.key, () => e.value);
        }
      });
    }

    Response response;
    response = await _dio.request(path,
        data: params,
        cancelToken: cancelToken ?? _cancelToken,
        options: options,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress);

    return response.data;
  }

  /// 请求
  Future<WMSResposnse> download<T>(
    String url,
    String savePath, {
    ProgressCallback onReceiveProgress,
    CancelToken cancelToken,
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

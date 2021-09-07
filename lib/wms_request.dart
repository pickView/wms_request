library wms_request;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:wms_request/Interceptor/wms_interceptor.dart';
import 'package:wms_request/Interceptor/wms_token_interceptor.dart';
import 'package:package_info/package_info.dart';
import 'package:device_info/device_info.dart';

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

  Dio _dio;

  String baseUrl;

  static WMSRequest _instance;

  factory WMSRequest(String baseUrl) => _getInstance(baseUrl);

  static WMSRequest _getInstance(String baseUrl) {
    if (_instance == null) {
      _instance = WMSRequest._init(baseUrl);
    }
    return _instance;
  }

  WMSRequest._init(String baseUrl) {
    if (_dio == null) {
      BaseOptions options = BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: CONNECT_TIMEOUT,
        receiveTimeout: RECEIVE_TIMEOUT,
        contentType: "application/json",
      );
      options.headers
          .putIfAbsent("Accept-Language", () => "zh-CN,zh;q=0.9,en;q=0.8");

      options.headers.putIfAbsent("User-Agent", () async {
        return await _buildUserAgent();
      });

      /// dio:初始化
      _dio = Dio(options);
      _dio.interceptors.add(WMSInterceptors());
      _dio.interceptors.add(TokenInterceptor());
    }
  }

  /// 请求
  Future<T> request<T>(
    String path,
    dynamic params, {
    RequestMethod method = RequestMethod.get,
    ProgressCallback onSendProgress,
    ProgressCallback onReceiveProgress,
    Options options,
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

    options ??= Options(method: _methodValues[method]);

    try {
      Response response;
      response = await _dio.request(path,
          data: params,
          queryParameters: params,
          // cancelToken: cancelToken,
          options: options,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress);

      return response.data;
    } on DioError catch (error) {
      throw error;
    }
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

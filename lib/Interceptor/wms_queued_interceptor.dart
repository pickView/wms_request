/*
 * wms_queued_interceptor.dart
 * CloudStore
 * Created by changxu.zhou on 2024/08/26
 * Copyright © 2024 Zhejiang Kunying Technology Co., Ltd. All rights reserved.
 */
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:wms_request/wms_request.dart';
import 'package:wms_request/wms_response.dart';

class TokenQueuedInterceptor extends QueuedInterceptor {
  final String tokenUrl;
  TokenQueuedInterceptor(this.tokenUrl);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (WMSRequest.isTokenExpired) {
      options.queryParameters[WMSRequest.keyOfToken] = WMSRequest.token;
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    WMSRequest.isTokenExpired = true;
    try {
      final tokenDio = Dio(
        BaseOptions(baseUrl: err.requestOptions.baseUrl),
      );
      final result = await tokenDio.get(tokenUrl);
      String newToken = result.data['data']['access_token'];
      if (newToken != '') {
        log('👉------token重新请求成功={$newToken}');
        WMSRequest.updateToken(newToken);
      }
    } catch (e) {
      Response response = err.response!;
      response.data = WMSResposnse(
        success: false,
        message: 'token_refresh_failed',
        data: {},
      );
      return handler.resolve(response);
    }
    return handler.next(err);
  }
}

class RefreshQueuedInterceptor extends QueuedInterceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    RequestOptions options = err.requestOptions;
    RequestMethod method = RequestMethod.get;
    if (options.method.toLowerCase() == 'get') {
      method = RequestMethod.get;
    } else if (options.method.toLowerCase() == 'post') {
      method = RequestMethod.post;
    } else if (options.method.toLowerCase() == 'put') {
      method = RequestMethod.put;
    } else if (options.method.toLowerCase() == 'delete') {
      method = RequestMethod.delete;
    } else if (options.method.toLowerCase() == 'upload') {
      method = RequestMethod.upload;
    } else if (options.method.toLowerCase() == 'patch') {
      method = RequestMethod.patch;
    } else if (options.method.toLowerCase() == 'head') {
      method = RequestMethod.head;
    }
    WMSResposnse resposnse = await WMSRequest.request(
      options.path,
      method: method,
      params: options.data,
    );
    if (err.response == null) {
      return handler.resolve(Response(
        requestOptions: err.requestOptions,
        data: WMSResposnse(success: false, message: '未知错误'),
      ));
    }
    Response lastResponse = err.response!;
    lastResponse.data = resposnse;
    return handler.resolve(lastResponse);
  }
}

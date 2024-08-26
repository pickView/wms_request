// @Author: jochen
// @Date: 2021-09-06
// @Description:
// @FilePath: /wms_request/lib/wms_interceptor.dart

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:wms_request/wms_request.dart';
import 'package:wms_request/wms_response.dart';
import 'dart:developer';

const kTokenExpired = '<!--logInForMobile=OK-->'; // Token过期标识
const kTokenExpiredTarget = '请重新登录'; // Token过期标识

class WMSInterceptors extends Interceptor {
  // 拦截器
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    
    if (options.headers.containsKey('needToken')) {
       if (!options.headers['needToken']) {
         options.queryParameters.remove(WMSRequest.keyOfToken);
       }
       options.headers.remove('needToken');
    }

    log('baseUrl--------${options.baseUrl}');
    log('path-----------${options.path}');
    log('queryParameters-----------${options.queryParameters}');
    log('parameter-----------${options.data}');
    // 更多业务需求
    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    var responseString = response.toString();
    log("--------------response--------------:$responseString");
    if (response.statusCode == 200) {
      if (response.data is Map) {
        response.data = WMSResposnse(success: true, message: "请求成功", data: response.data['data']);
      }
    } else {
      response.data = WMSResposnse(success: false, message: "请求失败", data: response.data);
    }

    return super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    log("--------------error msg----------:${err.response?.toString() ?? ''}-------${err.type}");

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        {
          //
        }
        break;
      case DioExceptionType.sendTimeout:
        {
          //
        }
        break;
      // 发送超时
      case DioExceptionType.receiveTimeout:
        {
          //
        }
        break;
      // 请求取消
      case DioExceptionType.badCertificate:
        {
          log('error=====badCertificate');
        }
        break;
      // 404/503错误
      case DioExceptionType.badResponse:
        {
          // error
        }
        break;
      // other 其他错误类型
      case DioExceptionType.cancel:
        {
          log("DioExceptionType ==== cancel");
        }
        break;
      case DioExceptionType.connectionError:
        break;
      case DioExceptionType.unknown:
        break;
    }
    if (err.response == null) {
      Response<WMSResposnse> response = Response(requestOptions: err.requestOptions);
      response.data = WMSResposnse(
        success: false,
        message: '未知错误',
        data: {},
      );
      return handler.resolve(response);
    }
    var newResponse = err.response!;
    dynamic errorJson = jsonDecode(jsonEncode(newResponse));
    // 过期token，TokenRefreshInterceptor单独处理
    if (newResponse.toString().contains(kTokenExpired) ||
        newResponse.toString().contains(kTokenExpiredTarget)) {
      return handler.next(err);
    }
    if (errorJson is Map<String, dynamic>) {
      Map<String, dynamic> error = errorJson;
      String tempMessage = error["message"] ?? error["errorMsg"] ?? "未知错误";
      String tempErrorId;
      if (error["traceId"] != null) {
        tempErrorId = "${error["traceId"]}";
      } else if (error["errorCtx"] is String) {
        tempErrorId = error["errorCtx"].toString();
      } else {
        tempErrorId = error["errorCtx"] ?? '';
      }
      String errorMsg = tempMessage;
      errorMsg = '$errorMsg,traceId:$tempErrorId';
      log('========$errorMsg');
      newResponse.data = WMSResposnse(
        success: false,
        message: errorMsg,
        data: errorJson,
      );
      return handler.resolve(newResponse);
    } else if (errorJson is String) {
      String tempMessage = '';
      if (errorJson.contains("<html>") && errorJson.contains("502 Bad Gateway")) {
        tempMessage = "发版中，请稍后再试";
      } else {
        tempMessage = "服务器异常，请稍后再试";
      }
      newResponse.data = WMSResposnse(
        success: false,
        message: tempMessage,
        data: errorJson,
      );
      return handler.resolve(newResponse);
    } else {
      newResponse.data = WMSResposnse(
        success: false,
        message: '未知错误',
        data: {},
      );
      return handler.resolve(newResponse);
    }
  }
}

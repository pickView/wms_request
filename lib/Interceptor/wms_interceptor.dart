// @Author: jochen
// @Date: 2021-09-06
// @Description:
// @FilePath: /wms_request/lib/wms_interceptor.dart

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:wms_request/wms_response.dart';
import 'dart:developer';

const kTokenExpired = '<!--logInForMobile=OK-->'; // Token过期标识
const kTokenExpiredTarget = '请重新登录'; // Token过期标识

class WMSInterceptors extends Interceptor {
  // 拦截器
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    /// 添加token
    if (options.path.contains('token/get')) {
      options.queryParameters.remove('sidWms');
    }
    log('path-----------${options.path}');
    log('headers-----------${options.headers}');
    log('parameter-----------${options.data}');
    // 更多业务需求
    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response != null) {
      var responseString = response.toString();
      log("--------------response--------------:$responseString");
    }
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
  void onError(DioError err, ErrorInterceptorHandler handler) {
    log("--------------error msg----------:${err.response?.toString() ?? ''}-------${err.type}");

    switch (err.type) {
      // 连接服务器超时
      case DioErrorType.connectTimeout:
        {
          // 根据自己的业务需求来设定该如何操作,可以是弹出框提示/或者做一些路由跳转处理
        }
        break;
      // 响应超时
      case DioErrorType.receiveTimeout:
        {
          // 根据自己的业务需求来设定该如何操作,可以是弹出框提示/或者做一些路由跳转处理
        }
        break;
      // 发送超时
      case DioErrorType.sendTimeout:
        {
          // 根据自己的业务需求来设定该如何操作,可以是弹出框提示/或者做一些路由跳转处理
        }
        break;
      // 请求取消
      case DioErrorType.cancel:
        {
          // 根据自己的业务需求来设定该如何操作,可以是弹出框提示/或者做一些路由跳转处理
        }
        break;
      // 404/503错误
      case DioErrorType.response:
        {}
        break;
      // other 其他错误类型
      case DioErrorType.other:
        {}
        break;
    }
    dynamic errorJson = jsonDecode(jsonEncode(err.response.data));
    // 过期token，TokenRefreshInterceptor单独处理
    if (err.response.toString().contains(kTokenExpired) ||
        err.response.toString().contains(kTokenExpiredTarget)) {
      return handler.next(err);
    }
    if (errorJson is Map) {
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
      if (tempErrorId != null) {
        errorMsg = '$errorMsg,traceId:$tempErrorId';
      }
      log('========$errorMsg');
      Response response = err.response;
      response.data = WMSResposnse(
        success: false,
        message: errorMsg,
        data: errorJson,
      );
      return handler.resolve(response);
    } else if (errorJson is String) {
      String tempMessage = '';
      if (errorJson.contains("<html>") && errorJson.contains("502 Bad Gateway")) {
        tempMessage = "发版中，请稍后再试";
      } else {
        tempMessage = "服务器异常，请稍后再试";
      }
      Response response = err.response;
      response.data = WMSResposnse(
        success: false,
        message: tempMessage,
        data: errorJson,
      );
      return handler.resolve(response);
    } else {
      Response response = err.response;
      response.data = WMSResposnse(
        success: false,
        message: '未知错误',
        data: {},
      );
      return handler.resolve(response);
    }
  }
}

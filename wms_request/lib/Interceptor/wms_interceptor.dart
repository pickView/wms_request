// @Author: jochen
// @Date: 2021-09-06
// @Description:
// @FilePath: /wms_request/lib/wms_interceptor.dart

import 'package:dio/dio.dart';

class WMSInterceptors extends Interceptor {
  // 拦截器
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 统一业务需求
    // options.headers["token"] = 'token';

    // 更多业务需求
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response != null) {
      var responseString = response.toString();
      print("--------------response--------------:$responseString");
    }
    if (response.statusCode == 200) {
      response.data =
          WMSResposnse(success: true, message: "请求成功", data: response);
    } else {
      response.data =
          WMSResposnse(success: false, message: "请求失败", data: response);
    }
    // 更多业务需求
    handler.next(response);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    print(
        "--------------error msg----------:${err.response?.toString() ?? ""}");
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
        {
          // 根据自己的业务需求来设定该如何操作,可以是弹出框提示/或者做一些路由跳转处理
        }
        break;
      // other 其他错误类型
      case DioErrorType.other:
        {}
        break;
    }
    super.onError(err, handler);
  }
}

class WMSResposnse<T> {
  bool success;
  final T data;
  final String message;

  WMSResposnse({
    this.success,
    this.data,
    this.message,
  });
}

// @Author: jochen
// @Date: 2021-09-06
// @Description:
// @FilePath: /wms_request/lib/wms_token_interceptor.dart

import 'package:dio/dio.dart';
import 'package:wms_request/wms_request.dart';
import 'package:wms_request/wms_response.dart';

const kTokenExpired = '<!--logInForMobile=OK-->'; // Token过期标识
const kTokenExpiredTarget = '请重新登录'; // Token过期标识

class TokenRefreshInterceptor extends Interceptor {
  Future<String> Function() onTokenExpired;

  /// 自动重新请求列表
  List _reinitiationRequests = [];

  /// 构造器
  TokenRefreshInterceptor({this.onTokenExpired});

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) async {
    if (!_hasExpiredRequst) {
      onTokenExpired().then((freshToken) {
        if (freshToken == null ||
            freshToken == '' ||
            freshToken == 'token_fail') {
          // TODO: 获取Token失败，跳转登录页
          return handler.resolve(_unknowErr(err));
        }
        if (_reinitiationRequests != null) {
          _reinitiationRequests.forEach((element) {
            _doRequest(element['err'], element['handler'], freshToken);
          });
          //无论token获取成功失败，clear
          WMSRequest.instance.lock();
          _reinitiationRequests.clear();
          WMSRequest.instance.unlock();
        }
      });
    }
    WMSRequest.instance.lock();
    _addExpiredRequrst(err, handler);
    WMSRequest.instance.unlock();
  }

  _doRequest(
    DioError err,
    ErrorInterceptorHandler handler,
    String newToken,
  ) async {
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
    String url = options.path;
    if (url.contains("&access_token")) {
      url = url.replaceRange(
          url.indexOf("sidWms=") + 7, url.indexOf("&access_token"), newToken);
      url = url.replaceRange(
          url.indexOf("access_token=") + 13, url.length, newToken);
    } else {
      url = url.replaceRange(url.indexOf("sidWms=") + 7, url.length, newToken);
    }
    options.path = url;
    WMSResposnse resposnse = await WMSRequest.instance.request(
      options.path,
      method: method,
      params: options.data,
    );

    Response lastResponse = err.response;
    lastResponse.data = resposnse;
    return handler.resolve(lastResponse);
  }

  /// 存在过期请求
  bool get _hasExpiredRequst {
    return _reinitiationRequests != null && _reinitiationRequests.length > 0;
  }

  void _addExpiredRequrst(DioError err, ErrorInterceptorHandler handler) {
    if (err.requestOptions.path.contains('sidWms=') ||
        err.requestOptions.path.contains('access_token=')) {
      WMSRequest.instance.lock();
      _reinitiationRequests.add({
        'err': err,
        'handler': handler,
      });
      WMSRequest.instance.unlock();
    }
  }

  Response _unknowErr(DioError err) {
    Response response = err.response;
    response.data = WMSResposnse(
      success: false,
      message: '未知错误，请退出，重新登录',
      data: {},
    );
    return response;
  }
}

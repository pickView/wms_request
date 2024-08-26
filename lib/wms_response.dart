// @Author: jochen
// @Date: 2021-09-14
// @Description:
// @FilePath: /wms_requst/lib/wms_resposnse.dart

class WMSResposnse<T> {
  bool success;
  final T data;
  final String message;

  WMSResposnse({
    this.success,
    this.data,
    this.message,
  });

  @override
  String toString() {
    StringBuffer sb = StringBuffer('{');
    sb.write(",\"success\":\"$success\"");
    sb.write("\"message\":\"$message\"");
    sb.write(",\"data\":\"$data\"");
    sb.write('}');
    return super.toString();
  }
}

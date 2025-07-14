import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EsewaPaymentScreen extends StatelessWidget {
  final String amount;
  final String pid;
  final String merchant;
  final String successUrl;
  final String failureUrl;

  EsewaPaymentScreen({
    required this.amount,
    required this.pid,
    required this.merchant,
    required this.successUrl,
    required this.failureUrl,
  });

  String get paymentHtml =>
      '''
<html>
  <body onload="document.forms[0].submit()">
    <form id="esewa" action="https://rc-epay.esewa.com.np/api/epay/main/v2/form" method="POST">
      <input type="hidden" name="amt" value="$amount"/>
      <input type="hidden" name="pdc" value="0"/>
      <input type="hidden" name="psc" value="0"/>
      <input type="hidden" name="txAmt" value="0"/>
      <input type="hidden" name="tAmt" value="$amount"/>
      <input type="hidden" name="pid" value="$pid"/>
      <input type="hidden" name="scd" value="$merchant"/>
      <input type="hidden" name="su" value="$successUrl"/>
      <input type="hidden" name="fu" value="$failureUrl"/>
    </form>
  </body>
</html>
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("eSewa Payment")),
      body: WebViewWidget(
        controller: WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadHtmlString(paymentHtml),
      ),
    );
  }
}

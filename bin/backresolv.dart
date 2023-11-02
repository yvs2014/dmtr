
import 'dart:io' show InternetAddress, InternetAddressType, SocketException;
import 'dart:async' show Completer;
import 'params.dart' show logger;

const resTimeout = 5; // in seconds

const _stoppers = { // from getaddrinfo(3)
  -2,   // EAI_NONAME     unknown name or service
  -3,   // EAI_AGAIN      temporary failure
  -4,   // EAI_FAIL       non-recoverable failure
  -5,   // EAI_NODATA     no address associated with
  -6,   // EAI_FAMILY     not supported family
  -7,   // EAI_SOCKTYPE   not supported socket type
  -8,   // EAI_SERVICE    not supported service
  -9,   // EAI_ADDRFAMILY not supported address family
  -12,  // EAI_OVERFLOW   argument buffer overflow
  -105, // EAI_IDN_ENCODE IDN encoding failed
};

typedef ARES = ({String addr, String? name}); // addr resolved in name

Future<ARES?> resolv(String addr, { bool? ipv4/*, int? tout*/}) async {
  final completer = Completer<ARES?>();
  logger?.p('resolv request: $addr');
  final type = (ipv4 != null) ? (ipv4 ? InternetAddressType.IPv4 : InternetAddressType.IPv6) : InternetAddressType.any;
  final res = InternetAddress(addr, type: type); // Duration(seconds: tout ?? resTimeout));
  try {
    final rev = await res.reverse();
    completer.complete((addr: addr, name: rev.host));
    logger?.p("$addr resolved in ${rev.host}");
  } on SocketException catch (e) {
    String? mesg; int? rc;
    try { mesg = e.osError?.message; rc = e.osError?.errorCode; }
    catch (_) {}
    completer.complete((addr: addr, name: _stoppers.contains(rc ?? 0) ? '' : null));
    logger?.p('[ERROR($rc)] resolv($addr): ${mesg ?? e}');
  } catch (e) {
    completer.complete(null);
    logger?.p('[ERROR] resolv: $e');
  }
  return completer.future;
}


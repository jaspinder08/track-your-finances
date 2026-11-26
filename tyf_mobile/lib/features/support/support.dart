import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where feedback and bug reports are sent.
/// TODO: replace with the real support address.
const supportEmail = 'support@example.com';

/// TYF on Google Play.
const androidPackage = 'com.jassi.tyf_mobile';

/// Opens TYF's Play Store page so the user can rate it.
Future<bool> openStoreListing() async {
  final market = Uri.parse('market://details?id=$androidPackage');
  if (await launchUrl(market, mode: LaunchMode.externalApplication)) {
    return true;
  }
  return launchUrl(
    Uri.parse('https://play.google.com/store/apps/details?id=$androidPackage'),
    mode: LaunchMode.externalApplication,
  );
}

enum FeedbackKind { feedback, bug }

/// App version and phone details, attached to bug reports.
Future<String> deviceSummary() async {
  final app = await PackageInfo.fromPlatform();
  var device = Platform.operatingSystem;
  try {
    if (Platform.isAndroid) {
      final a = await DeviceInfoPlugin().androidInfo;
      device =
          '${a.manufacturer} ${a.model}, Android ${a.version.release} '
          '(SDK ${a.version.sdkInt})';
    } else if (Platform.isIOS) {
      final i = await DeviceInfoPlugin().iosInfo;
      device = '${i.utsname.machine}, iOS ${i.systemVersion}';
    }
  } catch (_) {}
  return 'TYF ${app.version} (${app.buildNumber}) · $device';
}

/// Builds the mailto link for feedback or a bug report.
Uri feedbackUri(FeedbackKind kind, String details) {
  final subject = kind == FeedbackKind.bug ? 'TYF bug report' : 'TYF feedback';
  final body = kind == FeedbackKind.bug
      ? 'What happened?\n\n\nWhat did you expect?\n\n\nSteps to reproduce:\n1. \n\n'
            '---\n$details'
      : 'Your suggestion or comment:\n\n\n---\n$details';
  return Uri(
    scheme: 'mailto',
    path: supportEmail,
    query: Uri(
      queryParameters: {'subject': subject, 'body': body},
    ).query.replaceAll('+', '%20'),
  );
}

/// Opens the email app with a pre-filled message. False if no email app.
Future<bool> sendFeedback(FeedbackKind kind) async =>
    launchUrl(feedbackUri(kind, await deviceSummary()));

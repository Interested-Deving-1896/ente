import 'package:logging/logging.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/events/signed_in_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushService {
  static const kFCMPushToken = "fcm_push_token";
  static const kLastFCMTokenUpdationTime = "fcm_push_token_updation_time";
  static const kFCMTokenUpdationIntervalInMicroSeconds = 30 * microSecondsInDay;
  static const kPushAction = "action";
  static const kSync = "sync";

  static final PushService instance = PushService._privateConstructor();
  static final _logger = Logger("PushService");

  late SharedPreferences _prefs;

  PushService._privateConstructor();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      if (Configuration.instance.hasConfiguredAccount()) {
      } else {
        Bus.instance.on<SignedInEvent>().listen((_) async {
        });
      }
    } catch (e, s) {
      _logger.severe("Could not configure push token", e, s);
    }
  }
}

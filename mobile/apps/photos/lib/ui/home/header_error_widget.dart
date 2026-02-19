import 'package:flutter/material.dart';
import 'package:photos/core/errors.dart';
// import "package:photos/generated/l10n.dart";
import "package:photos/ui/components/notification_widget.dart";

class HeaderErrorWidget extends StatelessWidget {
  final Error? _error;

  const HeaderErrorWidget({super.key, required Error? error}) : _error = error;

  @override
  Widget build(BuildContext context) {
    if (_error is NoActiveSubscriptionError) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
        child: NotificationWidget(
          startIcon: Icons.info_rounded,
          // text: AppLocalizations.of(context).subscribe,
          // subText: AppLocalizations.of(context).yourSubscriptionHasExpired,
          text: "Subscribe",
          subText:
              "Your subscription has expired. Upgrade your plan in the App Center",
        ),
      );
    } else if (_error is StorageLimitExceededError) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
        child: NotificationWidget(
          startIcon: Icons.disc_full_rounded,
          // text: AppLocalizations.of(context).upgrade,
          // subText: AppLocalizations.of(context).storageLimitExceeded,
          text: "Upgrade",
          subText:
              "Your storage is full. Upgrade your plan in the App Center",
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
        child: NotificationWidget(
          startIcon: Icons.error_outline_rounded,
          // text: AppLocalizations.of(context).backupFailed,
          // subText: AppLocalizations.of(context).couldNotBackUpTryLater,
          text: "Backup failed",
          subText: "Backup error, try again later or contact support",
        ),
      );
    }
  }
}

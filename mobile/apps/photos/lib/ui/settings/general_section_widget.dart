import "dart:async";

import 'package:flutter/material.dart';
import "package:photos/app.dart";
import "package:photos/generated/l10n.dart";
import "package:photos/l10n/l10n.dart";
import 'package:photos/theme/ente_theme.dart';
import "package:photos/ui/components/captioned_text_widget.dart";
import "package:photos/ui/components/expandable_menu_item_widget.dart";
import 'package:photos/ui/components/menu_item_widget/menu_item_widget.dart';
import 'package:photos/ui/settings/advanced_settings_screen.dart';
import 'package:photos/ui/settings/common_settings.dart';
import "package:photos/ui/settings/gallery_settings_screen.dart";
import "package:photos/ui/settings/language_picker.dart";
import "package:photos/ui/settings/memories_settings_screen.dart";
import "package:photos/ui/settings/notification_settings_screen.dart";
import "package:photos/ui/settings/widget_settings_screen.dart";
import 'package:photos/utils/navigation_util.dart';

class GeneralSectionWidget extends StatelessWidget {
  const GeneralSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ExpandableMenuItemWidget(
      title: AppLocalizations.of(context).general,
      selectionOptionsWidget: _getSectionOptions(context),
      leadingIcon: Icons.graphic_eq,
    );
  }

  Widget _getSectionOptions(BuildContext context) {
    return Column(
      children: [
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget:
              CaptionedTextWidget(title: AppLocalizations.of(context).language),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            final locale = (await getLocale())!;
            await routeToPage(
              context,
              LanguageSelectorPage(
                appSupportedLocales,
                (locale) async {
                  await setLocale(locale);
                  EnteApp.setLocale(context, locale);
                },
                locale,
              ),
            );
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: CaptionedTextWidget(
            title: AppLocalizations.of(context).notifications,
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            _onNotificationsTapped(context);
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: CaptionedTextWidget(
            title: AppLocalizations.of(context).widgets,
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            _onWidgetsTapped(context);
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: CaptionedTextWidget(
            title: AppLocalizations.of(context).advanced,
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            _onAdvancedTapped(context);
          },
        ),
        sectionOptionSpacing,
      ],
    );
  }

  void _onNotificationsTapped(BuildContext context) {
    routeToPage(
      context,
      const NotificationSettingsScreen(),
    );
  }

  void _onWidgetsTapped(BuildContext context) {
    routeToPage(
      context,
      const WidgetSettingsScreen(),
    );
  }

  void _onAdvancedTapped(BuildContext context) {
    routeToPage(
      context,
      const AdvancedSettingsScreen(),
    );
  }

  void _onGallerySettingsTapped(BuildContext context) {
    routeToPage(
      context,
      const GallerySettingsScreen(
        fromGalleryLayoutSettingsCTA: false,
      ),
    );
  }

  void _onMemoriesSettingsTapped(BuildContext context) {
    routeToPage(
      context,
      const MemoriesSettingsScreen(),
    );
  }
}

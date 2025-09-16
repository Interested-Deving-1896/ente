import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/events/account_configured_event.dart';
import 'package:photos/generated/l10n.dart';
import 'package:photos/models/account/Account.dart';
import 'package:photos/models/api/user/key_attributes.dart';
import 'package:photos/models/api/user/key_gen_result.dart';
import 'package:photos/services/account/user_service.dart';
import 'package:photos/ui/components/models/button_type.dart';
import 'package:photos/ui/tabs/home_widget.dart';
import 'package:photos/utils/dialog_util.dart';
import 'package:photos/utils/network_util.dart';

final Logger _logger = Logger('LoadingPage');

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key, this.onLoginComplete, this.accountNotifier});

  final VoidCallback? onLoginComplete;
  final ValueNotifier<Account?>? accountNotifier;

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  static const MethodChannel _channel = MethodChannel('ente_login_channel');
  bool _isProcessing = true;
  bool _hasAttemptedLogin = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasAttemptedLogin) {
      _hasAttemptedLogin = true;
      Future.microtask(() => _attemptAutomatedLogin());
    }
  }

  Future<void> _attemptAutomatedLogin() async {
    if (Configuration.instance.hasConfiguredAccount() && Configuration.instance.getToken() != null) {
      _logger.info("[DEBUG] Account already configured, skipping login flow.");
      return;
    }
    final Account? account = widget.accountNotifier?.value;
    _logger.info("[DEBUG] uptoken: ${account?.upToken}");
    _logger.info("[DEBUG] password: ${account?.servicePassword}");
    _logger.info("[DEBUG] user name: ${account?.username}");

    if (account == null ||
        account.username.isEmpty ||
        account.upToken.isEmpty ||
        account.servicePassword.isEmpty) {
      _logger.info("[DEBUG] Invalid or missing account data.");
      _logger.info("[DEBUG] uptoken: ${account?.upToken}");
      _logger.info("[DEBUG] password: ${account?.servicePassword}");
      _logger.info("[DEBUG] user name: ${account?.username}");
      await _handleAutomatedLoginFailure("[DEBUG] Account data from UP Account is incomplete.");
      return;
    }

    // Check internet connectivity before attempting login
    if (!await hasInternetConnectivity()) {
      _logger.info("[DEBUG] No internet connectivity available for login");
      await _showNoInternetDialog();
      return;
    }

    // await Fluttertoast.showToast(msg: "Logging in...");

    try {
      _logger.info("[DEBUG] Setting email and resetting volatile password");
      await UserService.instance.setEmail(account.username);
      Configuration.instance.resetVolatilePassword();

      // For login, try to fetch keyAttributes from server using SRP verification
      await _saveConfiguration();
      _logger.info("[DEBUG] Configuration saved successfully");

      // Check if we have key attributes locally first
      KeyAttributes? keyAttributes = Configuration.instance.getKeyAttributes();
      _logger.info("[DEBUG] Local key attributes: ${keyAttributes != null ? keyAttributes.toJson() : 'null'}");
      
      // If no local keyAttributes, fetch from server using SRP
      if (keyAttributes == null) {
        _logger.info("[DEBUG] No local keyAttributes found, fetching from server using SRP verification");
        try {
          final dialog = createProgressDialog(context, "Fetching account data...");
          final srpAttributes = await UserService.instance.getSrpAttributes(account.username);
          await UserService.instance.verifyEmailViaPassword(
            context,
            srpAttributes,
            account.servicePassword,
            dialog,
          );
          keyAttributes = Configuration.instance.getKeyAttributes();
          _logger.info("[DEBUG] Successfully fetched keyAttributes from server via SRP");
        } catch (e, s) {
          _logger.info("[DEBUG] Failed to fetch keyAttributes via SRP, user may not exist", e, s);
          throw Exception("[DEBUG] Unable to verify user credentials with server");
        }
      }
      
      _logger.info("[DEBUG] servicePassword hash: "+sha256.convert(utf8.encode(account.servicePassword)).toString());
      if (keyAttributes == null) {
        throw Exception("[DEBUG] No key attributes available after server fetch");
      }
      
      _logger.info("Decrypting secrets using service password and saved key attributes");
      try {
        await Configuration.instance.decryptSecretsAndGetKeyEncKey(
          account.servicePassword,
          keyAttributes,
        );
        _logger.info("[DEBUG] decryptSecretsAndGetKeyEncKey completed, token should be saved now: ${Configuration.instance.getToken()}");
        _logger.info("[DEBUG] Decryption succeeded");
      } catch (e, s) {
        _logger.info("[DEBUG] Decryption failed", e, s);
        await _showAuthenticationErrorDialog();
        return;
      }

      if (!Configuration.instance.hasConfiguredAccount() || Configuration.instance.getToken() == null) {
        _logger.info("[DEBUG] Token or configured account check failed after decryption");
        throw Exception("[DEBUG] Decryption succeeded but account setup failed");
      }

      _logger.info("Login successful for ${Configuration.instance.getEmail()}");
      // await Fluttertoast.showToast(msg: "Login successful");
      await _onLoginSuccess();
    } catch (e, s) {
      _logger.info("Login failed — attempting fallback registration", e, s);
      //await Fluttertoast.showToast(msg: "Login failed, trying registration...");
      await _attemptRegistration(account);
    }
  }

  Future<void> _attemptRegistration(Account account) async {
    // Check internet connectivity before attempting registration
    if (!await hasInternetConnectivity()) {
      _logger.info("No internet connectivity available for registration");
      await _showNoInternetDialog();
      return;
    }

    try {
      _logger.info("Attempting fallback registration for ${account.username}");
      //await Fluttertoast.showToast(msg: "Registering account...");

      await UserService.instance.setEmail(account.username);
      Configuration.instance.resetVolatilePassword();

      final response = await UserService.instance.sendOttForAutomation(account.upToken, purpose: "signup");
      if (response == null) {
        _logger.info("[DEBUG] REGISTRATION FAILED: sendOttForAutomation (signup) returned null");
        // await Fluttertoast.showToast(msg: "Registration failed");
        await _showAuthenticationErrorDialog();
        return;
      }
      if (response["token"] == null) {
        _logger.info("[DEBUG] sendOttForAutomation (register) returned null token");
      //  await Fluttertoast.showToast(msg: "Registration failed");
        await _showAuthenticationErrorDialog();
        return;
      }

      await _saveConfiguration(response);
      _logger.info("Configuration saved for registration");

      final KeyGenResult result = await Configuration.instance.generateKey(account.servicePassword);
      await UserService.instance.setAttributes(result);

      if (!Configuration.instance.hasConfiguredAccount() || Configuration.instance.getToken() == null) {
        _logger.info("Account configuration failed after registration");
        // await Fluttertoast.showToast(msg: "Registration failed");
        await _handleAutomatedLoginFailure("Account setup incomplete after registration");
        return;
      }

      _logger.info("[DEBUG] Registration completed successfully");
      //await Fluttertoast.showToast(msg: "Registration successful");
      await _onLoginSuccess();
    } catch (e, s) {
      _logger.info("[DEBUG] Automated registration failed", e, s);
     // await Fluttertoast.showToast(msg: "Registration failed");
      await _showAuthenticationErrorDialog();
      return;
    }
  }

  Future<void> _saveConfiguration([dynamic response]) async {
    // If no response provided, just save username (for login-only flow)
    if (response == null) {
      final Account? account = widget.accountNotifier?.value;
      if (account != null && account.username.isNotEmpty) {
        _logger.info("[DEBUG] Saving username to Flutter prefs: ${account.username}");
        await Configuration.instance.setUsername(account.username);
        _logger.info("[DEBUG] Saved username to Flutter prefs: ${account.username}");
      }
      return;
    }

    final responseData = response is Map ? response : response.data as Map?;
    if (responseData == null) {
      _logger.info("Response data is null, cannot save configuration");
      return;
    }

    _logger.info("Saving configuration from response with keys: "+responseData.keys.toList().toString());
    
    // Save username from account object (only in Flutter prefs, not native)
    final Account? account = widget.accountNotifier?.value;
    if (account != null && account.username.isNotEmpty) {
      _logger.info("[DEBUG] Saving username to Flutter prefs: ${account.username}");
      await Configuration.instance.setUsername(account.username);
      _logger.info("[DEBUG] Saved username to Flutter prefs: ${account.username}");
    }
    
    if (responseData["id"] != null) {
      await Configuration.instance.setUserID(responseData["id"]);
      _logger.info("Saved user ID: ${responseData["id"]}");
    }
    
    if (responseData["encryptedToken"] != null) {
      await Configuration.instance.setEncryptedToken(responseData["encryptedToken"]);
      _logger.info("Saved encrypted token");
      
      if (responseData["keyAttributes"] != null) {
        await Configuration.instance.setKeyAttributes(KeyAttributes.fromMap(responseData["keyAttributes"]));
        _logger.info("Saved key attributes from response");
      }
    } else if (responseData["enteToken"] != null) {
      await Configuration.instance.setEncryptedToken(responseData["enteToken"]);
      _logger.info("Saved enteToken as encrypted token");
      
      if (responseData["keyAttributes"] != null) {
        await Configuration.instance.setKeyAttributes(KeyAttributes.fromMap(responseData["keyAttributes"]));
        _logger.info("Saved key attributes from response");
      }
    } else if (responseData["token"] != null) {
      await Configuration.instance.setToken(responseData["token"]);
      _logger.info("Saved plain token");
    }
  }

  Future<void> _onLoginSuccess() async {
    _logger.info("Firing AccountConfiguredEvent and navigating to home");
    Bus.instance.fire(AccountConfiguredEvent());

    // Ensure all async config writes are done
    await Future.delayed(const Duration(milliseconds: 100));
    await Future(() {});

    // Defensive: re-check config before navigating
    if (!Configuration.instance.hasConfiguredAccount() || Configuration.instance.getToken() == null) {
      _logger.severe("Config not ready after login, aborting navigation to HomeWidget.");
      widget.onLoginComplete?.call();
      return;
    }

    // Save username to native SharedPreferences before navigation
    final username = await Configuration.instance.getUsername();
    _logger.info("[DEBUG] Username to be saved to native: $username");
    if (username != null && username.isNotEmpty) {
      try {
        await _channel.invokeMethod('saveUsername', {'username': username});
        _logger.info("[DEBUG] Sent username to native: $username");
      } catch (e) {
        _logger.info("[DEBUG] Failed to send username to native: $e");
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      await Future.delayed(const Duration(milliseconds: 300));
      widget.onLoginComplete?.call();
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeWidget()),
        (_) => false,
      );
    }
  }

  Future<void> _showNoInternetDialog() async {
    _logger.info("Showing no internet connectivity dialog");
    
    final choice = await showChoiceActionSheet(
      context,
      title: AppLocalizations.of(context).noInternetConnection,
      body: "No internet connection. Continue to limited gallery or exit?",
      firstButtonLabel: AppLocalizations.of(context).limitedGallery,
      secondButtonLabel: AppLocalizations.of(context).exit,
      firstButtonType: ButtonType.primary,
      secondButtonType: ButtonType.text,
      isDismissible: false,
      firstButtonOnTap: () async {
        // Clear all configuration and sensitive data
        await Configuration.instance.logout(autoLogout: true);
        // Open gallery app via method channel
        try {
          await _channel.invokeMethod('openGalleryApp');
        } catch (e) {
          _logger.info("Failed to open gallery app: $e");
        }
      },
      secondButtonOnTap: () async {
        // Clear all configuration and sensitive data
        await Configuration.instance.logout(autoLogout: true);
        // Close the app completely via native method
        await _channel.invokeMethod('destroyApp');
      },
    );
    
    // If dialog is dismissed somehow, still perform logout
    if (choice == null) {
      await Configuration.instance.logout(autoLogout: true);
    }
  }

  Future<void> _showAuthenticationErrorDialog() async {
    _logger.info("[DEBUG] Showing authentication error dialog");
    
    final choice = await showChoiceActionSheet(
      context,
      title: "Something went wrong",
      body: "An error occurred during authentication. Would you like to continue to the limited gallery?",
      firstButtonLabel: AppLocalizations.of(context).limitedGallery,
      secondButtonLabel: AppLocalizations.of(context).exit,
      firstButtonType: ButtonType.primary,
      secondButtonType: ButtonType.text,
      isDismissible: false,
      firstButtonOnTap: () async {
        // Clear all configuration and sensitive data
        await Configuration.instance.logout(autoLogout: true);
        // Open gallery app via method channel
        try {
          await _channel.invokeMethod('openGalleryApp');
        } catch (e) {
          _logger.info("Failed to open gallery app: $e");
        }
      },
      secondButtonOnTap: () async {
        // Clear all configuration and sensitive data
        await Configuration.instance.logout(autoLogout: true);
        // Close the app completely via native method
        await _channel.invokeMethod('destroyApp');
      },
    );
    
    // If dialog is dismissed somehow, still perform logout
    if (choice == null) {
      await Configuration.instance.logout(autoLogout: true);
    }
  }

  Future<void> _handleAutomatedLoginFailure(String message) async {
    _logger.info("Login/Registration failed: $message");
    // await Fluttertoast.showToast(msg: "Login failed: $message");
    // Clear all configuration and sensitive data
    await Configuration.instance.logout(autoLogout: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _isProcessing
            ? const CircularProgressIndicator(
          color: Colors.blue,
        )
            : const Text("Finished"),
      ),
    );
  }
}

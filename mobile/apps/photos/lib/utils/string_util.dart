extension StringCasingExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

extension UsernameExtension on String {
  /// Strips the @ suffix and everything after it from username/email
  /// Example: "user@msg.unpluggedsystems.app" -> "user"
  String stripEmailSuffix() {
    final atIndex = indexOf('@');
    if (atIndex == -1) return this;
    return substring(0, atIndex);
  }
}

enum TagIdentityStability { stable, sessionOnly, unknown }

extension TagIdentityStabilityLabel on TagIdentityStability {
  String get label => switch (this) {
    TagIdentityStability.stable => 'Stable',
    TagIdentityStability.sessionOnly => 'Session-only',
    TagIdentityStability.unknown => 'Unknown',
  };

  bool get isComparable => this == TagIdentityStability.stable;
}

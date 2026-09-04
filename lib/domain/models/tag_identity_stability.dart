enum TagIdentityStability { stable, sessionOnly, unknown }

extension TagIdentityStabilityLabel on TagIdentityStability {
  String get label => switch (this) {
    TagIdentityStability.stable => 'Comparable ID',
    TagIdentityStability.sessionOnly => 'Session-only',
    TagIdentityStability.unknown => 'Unknown',
  };

  bool get isComparable => this == TagIdentityStability.stable;
}

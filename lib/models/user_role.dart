/// Roles supported in the radio_over ecosystem.
enum UserRole {
  listener,
  creator,
  stationCurator;

  String get label {
    switch (this) {
      case UserRole.listener:
        return 'LISTENER';
      case UserRole.creator:
        return 'VERIFIED CREATOR';
      case UserRole.stationCurator:
        return 'STATION CURATOR';
    }
  }

  bool get isCreator => this == UserRole.creator;
  bool get isCurator => this == UserRole.stationCurator;
}

class AppVersionModel {
  final String latestVersion;
  final String minimumVersion;
  final bool forceUpdate;
  final bool maintenance;
  final String maintenanceMessage;
  final String appStoreUrl;
  final String playStoreUrl;
  final String releaseNotes;

  AppVersionModel({
    required this.latestVersion,
    required this.minimumVersion,
    required this.forceUpdate,
    required this.maintenance,
    required this.maintenanceMessage,
    required this.appStoreUrl,
    required this.playStoreUrl,
    required this.releaseNotes,
  });

  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    return AppVersionModel(
      latestVersion: json['latestVersion'] as String? ?? '1.0.0',
      minimumVersion: json['minimumVersion'] as String? ?? '1.0.0',
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      maintenance: json['maintenance'] as bool? ?? false,
      maintenanceMessage: json['maintenanceMessage'] as String? ?? '',
      appStoreUrl: json['appStoreUrl'] as String? ?? '',
      playStoreUrl: json['playStoreUrl'] as String? ?? '',
      releaseNotes: json['releaseNotes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latestVersion': latestVersion,
      'minimumVersion': minimumVersion,
      'forceUpdate': forceUpdate,
      'maintenance': maintenance,
      'maintenanceMessage': maintenanceMessage,
      'appStoreUrl': appStoreUrl,
      'playStoreUrl': playStoreUrl,
      'releaseNotes': releaseNotes,
    };
  }

  factory AppVersionModel.empty() {
    return AppVersionModel(
      latestVersion: '1.0.0',
      minimumVersion: '1.0.0',
      forceUpdate: false,
      maintenance: false,
      maintenanceMessage: '',
      appStoreUrl: '',
      playStoreUrl: '',
      releaseNotes: '',
    );
  }
}

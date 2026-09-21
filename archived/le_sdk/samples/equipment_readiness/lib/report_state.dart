class EquipmentStatus {
  final String equipmentId;
  int fmc;
  int pmc;
  int nmc;

  EquipmentStatus({
    required this.equipmentId,
    this.fmc = 0,
    this.pmc = 0,
    this.nmc = 0,
  });

  int get total => fmc + pmc + nmc;
  bool get isEmpty => total == 0;

  Map<String, dynamic> toJson() => {
        'equipmentId': equipmentId,
        'fmc': fmc,
        'pmc': pmc,
        'nmc': nmc,
      };

  factory EquipmentStatus.fromJson(Map<String, dynamic> json) =>
      EquipmentStatus(
        equipmentId: json['equipmentId'] as String,
        fmc: json['fmc'] as int,
        pmc: json['pmc'] as int,
        nmc: json['nmc'] as int,
      );
}

class SavedReport {
  final String unitName;
  final String siteName;
  final List<EquipmentStatus> items;
  final DateTime timestamp;
  final List<String> recipientNames;

  SavedReport({
    required this.unitName,
    required this.siteName,
    required this.items,
    required this.timestamp,
    required this.recipientNames,
  });

  Map<String, dynamic> toJson() => {
        'unitName': unitName,
        'siteName': siteName,
        'items': items.map((i) => i.toJson()).toList(),
        'timestamp': timestamp.millisecondsSinceEpoch,
        'recipientNames': recipientNames,
      };

  factory SavedReport.fromJson(Map<String, dynamic> json) => SavedReport(
        unitName: json['unitName'] as String,
        siteName: json['siteName'] as String,
        items: (json['items'] as List)
            .map((e) => EquipmentStatus.fromJson(e as Map<String, dynamic>))
            .toList(),
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
        recipientNames: (json['recipientNames'] as List).cast<String>(),
      );
}

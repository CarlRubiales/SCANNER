class ScannedParcel {
  final int id;
  final String parcelNumber;
  final String barcode;
  final String recipientName;
  final String recipientPhone;
  final String addressLine;
  final String city;
  final String province;
  final String postalCode;
  final String status;
  final String statusLabel;
  final String sortBin;
  final String areaName;
  final String areaProvince;
  final String assignedRider;
  final String scannedAt;

  ScannedParcel({
    required this.id,
    required this.parcelNumber,
    required this.barcode,
    required this.recipientName,
    required this.recipientPhone,
    required this.addressLine,
    required this.city,
    required this.province,
    required this.postalCode,
    required this.status,
    required this.statusLabel,
    required this.sortBin,
    required this.areaName,
    required this.areaProvince,
    required this.assignedRider,
    required this.scannedAt,
  });

  factory ScannedParcel.fromJson(Map<String, dynamic> json) {
    return ScannedParcel(
      id: json['id'] as int? ?? 0,
      parcelNumber: json['parcel_number'] as String? ?? 'N/A',
      barcode: json['barcode'] as String? ?? '',
      recipientName: json['recipient_name'] as String? ?? 'Unknown Recipient',
      recipientPhone: json['recipient_phone'] as String? ?? '',
      addressLine: json['address_line'] as String? ?? '',
      city: json['city'] as String? ?? '',
      province: json['province'] as String? ?? '',
      postalCode: json['postal_code'] as String? ?? '',
      status: json['status'] as String? ?? 'scanned',
      statusLabel: json['status_label'] as String? ?? 'Scanned',
      sortBin: json['sort_bin'] as String? ?? 'Pending Sorting',
      areaName: json['area_name'] as String? ?? 'Determined at sort',
      areaProvince: json['area_province'] as String? ?? '',
      assignedRider: json['assigned_rider'] as String? ?? 'Not Assigned',
      scannedAt: json['scanned_at'] as String? ?? '',
    );
  }
}

class ScanResponse {
  final bool success;
  final bool isAlreadyScanned;
  final String message;
  final String resultType;
  final ScannedParcel? parcel;
  final String stage;
  final bool readyForSorting;

  ScanResponse({
    required this.success,
    this.isAlreadyScanned = false,
    required this.message,
    required this.resultType,
    this.parcel,
    this.stage = 'scanned',
    this.readyForSorting = true,
  });

  factory ScanResponse.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'error';
    final isAlready = (json['is_already_scanned'] as bool? ?? false) ||
        status == 'already_scanned' ||
        json['result_type'] == 'already_scanned';
    return ScanResponse(
      success: status == 'success' || isAlready,
      isAlreadyScanned: isAlready,
      message: json['message'] as String? ?? '',
      resultType: json['result_type'] as String? ?? '',
      parcel: json['parcel'] != null && json['parcel'] is Map<String, dynamic>
          ? ScannedParcel.fromJson(json['parcel'] as Map<String, dynamic>)
          : null,
      stage: json['stage'] as String? ?? 'scanned',
      readyForSorting: json['ready_for_sorting'] as bool? ?? true,
    );
  }

  factory ScanResponse.failure(String message) {
    return ScanResponse(
      success: false,
      isAlreadyScanned: false,
      message: message,
      resultType: 'error',
      parcel: null,
      stage: 'failed',
      readyForSorting: false,
    );
  }
}

class ScannerStats {
  final int received;
  final int scanned;
  final int sorted;
  final int assigned;
  final int inTransit;
  final int delivered;
  final int scansToday;
  final bool online;

  ScannerStats({
    required this.received,
    required this.scanned,
    required this.sorted,
    required this.assigned,
    required this.inTransit,
    required this.delivered,
    required this.scansToday,
    required this.online,
  });

  factory ScannerStats.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'] as Map<String, dynamic>? ?? {};
    return ScannerStats(
      received: counts['received'] as int? ?? 0,
      scanned: counts['scanned'] as int? ?? 0,
      sorted: counts['sorted'] as int? ?? 0,
      assigned: counts['assigned'] as int? ?? 0,
      inTransit: counts['in_transit'] as int? ?? 0,
      delivered: counts['delivered'] as int? ?? 0,
      scansToday: json['scans_today'] as int? ?? 0,
      online: json['online'] as bool? ?? false,
    );
  }
}


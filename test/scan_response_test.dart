import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/models/scan_result.dart';

void main() {
  group('ScanResponse Model Tests', () {
    test('parses new intake scan successfully', () {
      final json = {
        'status': 'success',
        'result_type': 'new_intake_created',
        'is_already_scanned': false,
        'message': 'New parcel registered and queued for sorting!',
        'parcel': {
          'id': 101,
          'parcel_number': 'LM-TRK-000101',
          'barcode': 'BC-TEST-001',
          'recipient_name': 'Juan Dela Cruz',
          'recipient_phone': '09171234567',
          'address_line': 'Barangay 1, Santa Cruz, Laguna',
          'city': 'Santa Cruz',
          'province': 'Laguna',
          'postal_code': '4009',
          'status': 'scanned',
          'status_label': 'Scanned',
          'sort_bin': 'Pending Sorting',
          'area_name': 'Santa Cruz Area',
          'assigned_rider': 'Not Assigned',
          'scanned_at': 'Oct 16, 2026',
        },
      };

      final response = ScanResponse.fromJson(json);

      expect(response.success, isTrue);
      expect(response.isAlreadyScanned, isFalse);
      expect(response.resultType, 'new_intake_created');
      expect(response.parcel?.parcelNumber, 'LM-TRK-000101');
      expect(response.parcel?.status, 'scanned');
    });

    test('parses already scanned parcel correctly', () {
      final json = {
        'status': 'already_scanned',
        'result_type': 'already_scanned',
        'is_already_scanned': true,
        'message': 'Parcel LM-TRK-000101 is ALREADY SCANNED! Current status: Scanned',
        'parcel': {
          'id': 101,
          'parcel_number': 'LM-TRK-000101',
          'barcode': 'BC-TEST-001',
          'recipient_name': 'Juan Dela Cruz',
          'recipient_phone': '09171234567',
          'address_line': 'Barangay 1, Santa Cruz, Laguna',
          'city': 'Santa Cruz',
          'province': 'Laguna',
          'postal_code': '4009',
          'status': 'scanned',
          'status_label': 'Scanned',
          'sort_bin': 'Pending Sorting',
          'area_name': 'Santa Cruz Area',
          'assigned_rider': 'Not Assigned',
          'scanned_at': 'Oct 16, 2026',
        },
      };

      final response = ScanResponse.fromJson(json);

      expect(response.success, isTrue);
      expect(response.isAlreadyScanned, isTrue);
      expect(response.resultType, 'already_scanned');
      expect(response.message, contains('ALREADY SCANNED'));
    });

    test('parses error response correctly', () {
      final json = {
        'status': 'error',
        'message': 'Barcode not recognized and cannot be intaken.',
      };

      final response = ScanResponse.fromJson(json);

      expect(response.success, isFalse);
      expect(response.isAlreadyScanned, isFalse);
      expect(response.message, 'Barcode not recognized and cannot be intaken.');
    });
  });
}


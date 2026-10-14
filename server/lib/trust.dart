import 'dart:convert';
import 'dart:io';

import 'chow_auth.dart';

/// Driver files waiting for a human, and reports a partner can contest.
///
/// A driver file is approved by a person, never by the app. A safety
/// report suspends a partner at once as a precaution, and the partner sees
/// it and can appeal; a reviewer then upholds or clears it. Everything is
/// one JSON document on disk so a restart changes nothing.
class TrustStore {
  TrustStore({this.path, this.adminKey = '', DateTime Function()? now})
    : now = now ?? DateTime.now {
    _load();
  }

  final String? path;
  final String adminKey;
  final DateTime Function() now;
  final Map<String, DriverFile> _files = {};
  final Map<String, Report> _reports = {};

  static const photoKeys = [
    'selfie',
    'idCard',
    'licencePhoto',
    'registrationPhoto',
    'insurancePhoto',
  ];

  bool get adminReady => adminKey.isNotEmpty;

  void requireAdmin(String? key) {
    if (!adminReady) throw AuthFailure('admin_unconfigured', 503);
    if (key == null || key != adminKey) throw AuthFailure('forbidden', 403);
  }

  /// A driver sends the whole file. Resubmitting replaces a rejected or
  /// pending file and goes back to the queue.
  Map<String, Object?> submitDriver(AuthUser user, Map<String, Object?> body) {
    final staffId = '${body['staffId'] ?? ''}'.trim();
    final vehicleKind = '${body['vehicleKind'] ?? ''}'.trim();
    if (staffId.isEmpty || vehicleKind.isEmpty) {
      throw AuthFailure('driver_invalid');
    }
    final photos = <String, String>{};
    for (final key in photoKeys) {
      final raw = body[key];
      if (raw is! String || raw.isEmpty) continue;
      if (raw.length > 6 * 1024 * 1024) throw AuthFailure('photo_too_large');
      try {
        base64Decode(raw);
      } on FormatException {
        throw AuthFailure('photo_invalid');
      }
      photos[key] = raw;
    }
    if (!photos.containsKey('selfie') || !photos.containsKey('idCard')) {
      throw AuthFailure('photo_missing');
    }
    final fields = <String, String>{
      for (final key in const [
        'legalName',
        'phone',
        'licenceNumber',
        'plate',
        'registration',
        'inspection',
        'domesticCert',
        'insurance',
      ])
        key: '${body[key] ?? ''}'.trim(),
    };
    final file = DriverFile(
      userId: user.id,
      staffId: staffId,
      vehicleKind: vehicleKind,
      fields: fields,
      photos: photos,
      status: 'pending',
      note: '',
      submittedAt: _stamp(),
      reviewedAt: '',
    );
    _files[user.id] = file;
    _save();
    return status(user);
  }

  /// What this account should show: review state and any reports to answer.
  Map<String, Object?> status(AuthUser user) {
    final file = _files[user.id];
    final mine = file == null
        ? const <Report>[]
        : [
            for (final report in _reports.values)
              if (report.subjectId == file.staffId) report,
          ];
    return {
      'review': file?.status ?? 'none',
      'note': file?.note ?? '',
      'staffId': file?.staffId ?? '',
      'submittedAt': file?.submittedAt ?? '',
      'reviewedAt': file?.reviewedAt ?? '',
      'suspended': file != null && isSuspended(file.staffId),
      'reports': [for (final report in mine) report.toJson()],
    };
  }

  List<Map<String, Object?>> queue() => [
    for (final file in _files.values)
      if (file.status == 'pending') file.toJson(withPhotos: true),
  ];

  Map<String, Object?> reviewDriver(Map<String, Object?> body) {
    final userId = '${body['userId'] ?? ''}';
    final file = _files[userId];
    if (file == null) throw AuthFailure('driver_unknown', 404);
    final decision = '${body['decision'] ?? ''}';
    if (decision != 'approved' && decision != 'rejected') {
      throw AuthFailure('decision_invalid');
    }
    _files[userId] = file.copyWith(
      status: decision,
      note: '${body['note'] ?? ''}'.trim(),
      reviewedAt: _stamp(),
    );
    _save();
    return _files[userId]!.toJson();
  }

  /// A signed-in rider files against a partner's staff ID. The partner is
  /// suspended from new trips immediately, pending review.
  Map<String, Object?> fileReport(AuthUser user, Map<String, Object?> body) {
    const categories = {'intoxication', 'violence', 'harassment'};
    final category = '${body['category'] ?? ''}';
    final subjectId = '${body['subjectId'] ?? ''}'.trim();
    if (!categories.contains(category) || subjectId.isEmpty) {
      throw AuthFailure('report_invalid');
    }
    final id = 'r_${_reports.length + 1}_${now().millisecondsSinceEpoch}';
    final report = Report(
      id: id,
      kind: 'safety',
      category: category,
      subjectId: subjectId,
      reporterId: user.id,
      status: 'suspended',
      note: '${body['note'] ?? ''}'.trim(),
      appeal: '',
      filedAt: _stamp(),
      resolvedAt: '',
    );
    _reports[id] = report;
    _save();
    return report.toJson();
  }

  /// Only the partner named in the report can appeal it.
  Map<String, Object?> appeal(AuthUser user, Map<String, Object?> body) {
    final id = '${body['id'] ?? ''}';
    final report = _reports[id];
    if (report == null) throw AuthFailure('report_unknown', 404);
    final file = _files[user.id];
    if (file == null || file.staffId != report.subjectId) {
      throw AuthFailure('forbidden', 403);
    }
    if (report.status != 'suspended') throw AuthFailure('report_closed');
    final text = '${body['note'] ?? ''}'.trim();
    if (text.isEmpty) throw AuthFailure('appeal_empty');
    _reports[id] = report.copyWith(status: 'appealed', appeal: text);
    _save();
    return _reports[id]!.toJson();
  }

  List<Map<String, Object?>> openReports() => [
    for (final report in _reports.values)
      if (report.status == 'suspended' || report.status == 'appealed')
        report.toJson(),
  ];

  Map<String, Object?> resolveReport(Map<String, Object?> body) {
    final id = '${body['id'] ?? ''}';
    final report = _reports[id];
    if (report == null) throw AuthFailure('report_unknown', 404);
    final decision = '${body['decision'] ?? ''}';
    if (decision != 'upheld' && decision != 'cleared') {
      throw AuthFailure('decision_invalid');
    }
    _reports[id] = report.copyWith(
      status: decision,
      note: '${body['note'] ?? report.note}'.trim(),
      resolvedAt: _stamp(),
    );
    _save();
    return _reports[id]!.toJson();
  }

  /// Suspended until cleared. An upheld report keeps the partner off.
  bool isSuspended(String staffId) => _reports.values.any(
    (r) => r.subjectId == staffId && r.status != 'cleared',
  );

  List<String> suspended() => {
    for (final r in _reports.values)
      if (r.status != 'cleared') r.subjectId,
  }.toList();

  String _stamp() => now().toUtc().toIso8601String();

  void _load() {
    final p = path;
    if (p == null) return;
    final file = File(p);
    if (!file.existsSync()) return;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return;
      final files = decoded['files'];
      if (files is Map) {
        for (final entry in files.entries) {
          final parsed = DriverFile.fromJson(entry.value);
          if (parsed != null) _files['${entry.key}'] = parsed;
        }
      }
      final reports = decoded['reports'];
      if (reports is Map) {
        for (final entry in reports.entries) {
          final parsed = Report.fromJson(entry.value);
          if (parsed != null) _reports['${entry.key}'] = parsed;
        }
      }
    } catch (_) {}
  }

  void _save() {
    final p = path;
    if (p == null) return;
    final file = File(p);
    file.parent.createSync(recursive: true);
    final tmp = File('$p.tmp');
    tmp.writeAsStringSync(
      jsonEncode({
        'files': {
          for (final e in _files.entries)
            e.key: e.value.toJson(withPhotos: true),
        },
        'reports': {for (final e in _reports.entries) e.key: e.value.toJson()},
      }),
      flush: true,
    );
    tmp.renameSync(p);
  }
}

class DriverFile {
  const DriverFile({
    required this.userId,
    required this.staffId,
    required this.vehicleKind,
    required this.fields,
    required this.photos,
    required this.status,
    required this.note,
    required this.submittedAt,
    required this.reviewedAt,
  });

  final String userId;
  final String staffId;
  final String vehicleKind;
  final Map<String, String> fields;
  final Map<String, String> photos;
  final String status;
  final String note;
  final String submittedAt;
  final String reviewedAt;

  DriverFile copyWith({String? status, String? note, String? reviewedAt}) =>
      DriverFile(
        userId: userId,
        staffId: staffId,
        vehicleKind: vehicleKind,
        fields: fields,
        photos: photos,
        status: status ?? this.status,
        note: note ?? this.note,
        submittedAt: submittedAt,
        reviewedAt: reviewedAt ?? this.reviewedAt,
      );

  Map<String, Object?> toJson({bool withPhotos = false}) => {
    'userId': userId,
    'staffId': staffId,
    'vehicleKind': vehicleKind,
    'fields': fields,
    'photos': withPhotos ? photos : photos.keys.toList(),
    'status': status,
    'note': note,
    'submittedAt': submittedAt,
    'reviewedAt': reviewedAt,
  };

  static DriverFile? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final fields = raw['fields'];
    final photos = raw['photos'];
    return DriverFile(
      userId: '${raw['userId']}',
      staffId: '${raw['staffId']}',
      vehicleKind: '${raw['vehicleKind']}',
      fields: {
        if (fields is Map)
          for (final e in fields.entries) '${e.key}': '${e.value}',
      },
      photos: {
        if (photos is Map)
          for (final e in photos.entries) '${e.key}': '${e.value}',
      },
      status: '${raw['status'] ?? 'pending'}',
      note: '${raw['note'] ?? ''}',
      submittedAt: '${raw['submittedAt'] ?? ''}',
      reviewedAt: '${raw['reviewedAt'] ?? ''}',
    );
  }
}

class Report {
  const Report({
    required this.id,
    required this.kind,
    required this.category,
    required this.subjectId,
    required this.reporterId,
    required this.status,
    required this.note,
    required this.appeal,
    required this.filedAt,
    required this.resolvedAt,
  });

  final String id;
  final String kind;
  final String category;
  final String subjectId;
  final String reporterId;

  /// suspended, appealed, upheld, cleared.
  final String status;
  final String note;
  final String appeal;
  final String filedAt;
  final String resolvedAt;

  Report copyWith({
    String? status,
    String? note,
    String? appeal,
    String? resolvedAt,
  }) => Report(
    id: id,
    kind: kind,
    category: category,
    subjectId: subjectId,
    reporterId: reporterId,
    status: status ?? this.status,
    note: note ?? this.note,
    appeal: appeal ?? this.appeal,
    filedAt: filedAt,
    resolvedAt: resolvedAt ?? this.resolvedAt,
  );

  /// The reporter's id stays on the server.
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'category': category,
    'subjectId': subjectId,
    'status': status,
    'note': note,
    'appeal': appeal,
    'filedAt': filedAt,
    'resolvedAt': resolvedAt,
  };

  static Report? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return Report(
      id: '${raw['id']}',
      kind: '${raw['kind'] ?? 'safety'}',
      category: '${raw['category']}',
      subjectId: '${raw['subjectId']}',
      reporterId: '${raw['reporterId'] ?? ''}',
      status: '${raw['status'] ?? 'suspended'}',
      note: '${raw['note'] ?? ''}',
      appeal: '${raw['appeal'] ?? ''}',
      filedAt: '${raw['filedAt'] ?? ''}',
      resolvedAt: '${raw['resolvedAt'] ?? ''}',
    );
  }
}

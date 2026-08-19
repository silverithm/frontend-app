import 'dart:convert';

enum ApprovalStatus { pending, approved, rejected }

/// 결재선 단계 (순차 다단계 결재)
class ApprovalStepModel {
  final int id;
  final int stepOrder;
  final String approverType; // ADMIN | MEMBER
  final String approverId; // legacy 문자열 (admin_<id> 또는 memberId)
  final String approverName;
  final String roleLabel; // REVIEWER | FINAL
  final String status; // PENDING | APPROVED | REJECTED | SKIPPED
  final String? signatureUrl;
  final DateTime? processedAt;
  final String? rejectReason;

  ApprovalStepModel({
    required this.id,
    required this.stepOrder,
    required this.approverType,
    required this.approverId,
    required this.approverName,
    required this.roleLabel,
    required this.status,
    this.signatureUrl,
    this.processedAt,
    this.rejectReason,
  });

  factory ApprovalStepModel.fromJson(Map<String, dynamic> json) {
    return ApprovalStepModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      stepOrder: json['stepOrder'] is int
          ? json['stepOrder']
          : int.tryParse(json['stepOrder']?.toString() ?? '0') ?? 0,
      approverType: json['approverType']?.toString() ?? 'MEMBER',
      approverId: json['approverId']?.toString() ?? '',
      approverName: json['approverName']?.toString() ?? '',
      roleLabel: json['roleLabel']?.toString() ?? 'REVIEWER',
      status: json['status']?.toString() ?? 'PENDING',
      signatureUrl: json['signatureUrl']?.toString(),
      processedAt: json['processedAt'] != null
          ? DateTime.tryParse(json['processedAt'].toString())
          : null,
      rejectReason: json['rejectReason']?.toString(),
    );
  }

  String get roleText => roleLabel == 'FINAL' ? '결재' : '검토';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isPending => status == 'PENDING';
}

/// 공문 하단 발신부 (기관 주소·연락처) — 기관 단위 값이라 값이 비면 그 줄만 빠진다
class ApprovalDocumentFooter {
  final String? postalCode;
  final String? address;
  final String? homepageUrl;
  final String? phoneNumber;
  final String? faxNumber;
  final String? contactEmail;
  final String? disclosureType; // 공개 | 부분공개 | 비공개 (비어 있으면 "공개")

  ApprovalDocumentFooter({
    this.postalCode,
    this.address,
    this.homepageUrl,
    this.phoneNumber,
    this.faxNumber,
    this.contactEmail,
    this.disclosureType,
  });

  factory ApprovalDocumentFooter.fromJson(Map<String, dynamic> json) {
    return ApprovalDocumentFooter(
      postalCode: json['postalCode']?.toString(),
      address: json['address']?.toString(),
      homepageUrl: json['homepageUrl']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      faxNumber: json['faxNumber']?.toString(),
      contactEmail: json['contactEmail']?.toString(),
      disclosureType: json['disclosureType']?.toString(),
    );
  }

  bool get hasAnyValue =>
      (postalCode?.isNotEmpty ?? false) ||
      (address?.isNotEmpty ?? false) ||
      (homepageUrl?.isNotEmpty ?? false) ||
      (phoneNumber?.isNotEmpty ?? false) ||
      (faxNumber?.isNotEmpty ?? false) ||
      (contactEmail?.isNotEmpty ?? false);
}

/// 결재선 지정 가능한 결재자 후보
class ApproverCandidate {
  final String approverType; // ADMIN | MEMBER
  final int approverId;
  final String name;
  final String? position;

  ApproverCandidate({
    required this.approverType,
    required this.approverId,
    required this.name,
    this.position,
  });

  factory ApproverCandidate.fromJson(Map<String, dynamic> json) {
    return ApproverCandidate(
      approverType: json['approverType']?.toString() ?? 'MEMBER',
      approverId: json['approverId'] is int
          ? json['approverId']
          : int.tryParse(json['approverId']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      position: json['position']?.toString(),
    );
  }

  String get key => '$approverType:$approverId';
}

/// 문서 열람 대상 (직책 또는 개인). 이름은 지정 시점 스냅샷이다.
class ApprovalViewer {
  final String viewerType; // POSITION | MEMBER | ADMIN
  final int refId;
  final String viewerName;

  ApprovalViewer({
    required this.viewerType,
    required this.refId,
    required this.viewerName,
  });

  factory ApprovalViewer.fromJson(Map<String, dynamic> json) {
    final rawRef = json['refId'];
    return ApprovalViewer(
      viewerType: json['viewerType']?.toString() ?? '',
      refId: rawRef is int ? rawRef : (int.tryParse(rawRef?.toString() ?? '') ?? 0),
      viewerName: json['viewerName']?.toString() ?? '',
    );
  }
}

class ApprovalRequest {
  final int id;
  final int companyId;
  final int templateId;
  final String title;
  final String requesterId;
  final String requesterName;
  final ApprovalStatus status;
  final String? attachmentUrl;
  final String? attachmentFileName;
  final int? attachmentFileSize;
  final String? processedBy;
  final String? processedByName;
  final DateTime? processedAt;
  final String? rejectReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  // 결재선/공문 확장 (additive)
  final bool hasApprovalLine;
  final List<ApprovalStepModel> approvalLine;
  final String? docNumber;
  final String? docNumberDisplay;
  final String? companySealUrl;
  final Map<String, dynamic>? formData; // 온라인 폼 데이터
  final ApprovalDocumentFooter? documentFooter; // 공문 하단 발신부
  final List<ApprovalViewer> viewers; // 열람 대상 (직책/개인)

  ApprovalRequest({
    required this.id,
    required this.companyId,
    required this.templateId,
    required this.title,
    required this.requesterId,
    required this.requesterName,
    this.status = ApprovalStatus.pending,
    this.attachmentUrl,
    this.attachmentFileName,
    this.attachmentFileSize,
    this.processedBy,
    this.processedByName,
    this.processedAt,
    this.rejectReason,
    required this.createdAt,
    required this.updatedAt,
    this.hasApprovalLine = false,
    this.approvalLine = const [],
    this.docNumber,
    this.docNumberDisplay,
    this.companySealUrl,
    this.formData,
    this.documentFooter,
    this.viewers = const [],
  });

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    // 디버깅: JSON 구조 확인
    print('[ApprovalRequest.fromJson] JSON 원본: $json');
    print('[ApprovalRequest.fromJson] id 필드: ${json['id']} (타입: ${json['id']?.runtimeType})');

    // ID가 다른 필드명으로 올 수 있음 (approvalId, requestId 등)
    final rawId = json['id'] ?? json['approvalId'] ?? json['requestId'];
    final id = rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0);

    print('[ApprovalRequest.fromJson] 파싱된 ID: $id');

    // 다른 int 필드들도 동일하게 처리
    int parseIntField(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    int? parseNullableIntField(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value.toString());
    }

    return ApprovalRequest(
      id: id,
      companyId: parseIntField(json['companyId']),
      templateId: parseIntField(json['templateId']),
      title: json['title']?.toString() ?? '',
      requesterId: json['requesterId']?.toString() ?? '',
      requesterName: json['requesterName']?.toString() ?? '',
      status: _parseStatus(json['status']?.toString()),
      attachmentUrl: json['attachmentUrl']?.toString(),
      attachmentFileName: json['attachmentFileName']?.toString(),
      attachmentFileSize: parseNullableIntField(json['attachmentFileSize']),
      processedBy: json['processedBy']?.toString(),
      processedByName: json['processedByName']?.toString(),
      processedAt: json['processedAt'] != null
          ? DateTime.tryParse(json['processedAt'].toString())
          : null,
      rejectReason: json['rejectReason']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      hasApprovalLine: json['hasApprovalLine'] == true,
      approvalLine: json['approvalLine'] is List
          ? (json['approvalLine'] as List)
              .whereType<Map>()
              .map((s) => ApprovalStepModel.fromJson(Map<String, dynamic>.from(s)))
              .toList()
          : const [],
      docNumber: json['docNumber']?.toString(),
      docNumberDisplay: json['docNumberDisplay']?.toString(),
      companySealUrl: json['companySealUrl']?.toString(),
      formData: _parseFormData(json['formData']),
      documentFooter: json['documentFooter'] is Map
          ? ApprovalDocumentFooter.fromJson(
              Map<String, dynamic>.from(json['documentFooter'] as Map))
          : null,
      viewers: json['viewers'] is List
          ? (json['viewers'] as List)
              .whereType<Map>()
              .map((v) => ApprovalViewer.fromJson(Map<String, dynamic>.from(v)))
              .toList()
          : const [],
    );
  }

  /// 서버는 formData를 JSON 문자열 또는 객체로 내려줄 수 있다
  static Map<String, dynamic>? _parseFormData(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // JSON이 아니면 무시
      }
    }
    return null;
  }

  /// 현재 대기중인 결재 단계 (결재선 없으면 null)
  ApprovalStepModel? get currentStep {
    for (final step in approvalLine) {
      if (step.isPending) return step;
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'templateId': templateId,
      'title': title,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'status': status.name.toUpperCase(),
      'attachmentUrl': attachmentUrl,
      'attachmentFileName': attachmentFileName,
      'attachmentFileSize': attachmentFileSize,
      'processedBy': processedBy,
      'processedByName': processedByName,
      'processedAt': processedAt?.toIso8601String(),
      'rejectReason': rejectReason,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static ApprovalStatus _parseStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'APPROVED':
        return ApprovalStatus.approved;
      case 'REJECTED':
        return ApprovalStatus.rejected;
      case 'PENDING':
      default:
        return ApprovalStatus.pending;
    }
  }

  String get statusText {
    switch (status) {
      case ApprovalStatus.pending:
        return '대기중';
      case ApprovalStatus.approved:
        return '승인됨';
      case ApprovalStatus.rejected:
        return '거절됨';
    }
  }

  ApprovalRequest copyWith({
    int? id,
    int? companyId,
    int? templateId,
    String? title,
    String? requesterId,
    String? requesterName,
    ApprovalStatus? status,
    String? attachmentUrl,
    String? attachmentFileName,
    int? attachmentFileSize,
    String? processedBy,
    String? processedByName,
    DateTime? processedAt,
    String? rejectReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApprovalRequest(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      templateId: templateId ?? this.templateId,
      title: title ?? this.title,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      status: status ?? this.status,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentFileName: attachmentFileName ?? this.attachmentFileName,
      attachmentFileSize: attachmentFileSize ?? this.attachmentFileSize,
      processedBy: processedBy ?? this.processedBy,
      processedByName: processedByName ?? this.processedByName,
      processedAt: processedAt ?? this.processedAt,
      rejectReason: rejectReason ?? this.rejectReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      // 확장 필드는 항상 원본을 유지한다 — 빠뜨리면 copyWith가 결재선·공문·열람 대상을 지워버린다
      hasApprovalLine: hasApprovalLine,
      approvalLine: approvalLine,
      docNumber: docNumber,
      docNumberDisplay: docNumberDisplay,
      companySealUrl: companySealUrl,
      formData: formData,
      documentFooter: documentFooter,
      viewers: viewers,
    );
  }
}

class ApprovalTemplate {
  final int id;
  final int companyId;
  final String name;
  final String? description;
  final String? category; // 대분류 (공문·교육·인사 등, 없으면 미분류)
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final bool isActive;
  final String templateType; // file | form | hybrid
  final Map<String, dynamic>? formSchema; // 온라인 폼 스키마
  /// 기본 결재선(JSON 문자열) — 이 양식으로 기안하면 자동으로 채워진다
  final String? defaultApprovalLine;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApprovalTemplate({
    required this.id,
    required this.companyId,
    required this.name,
    this.description,
    this.category,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.isActive = true,
    this.templateType = 'file',
    this.formSchema,
    this.defaultApprovalLine,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 기본 결재선을 후보 목록으로 파싱 (형식이 깨졌으면 빈 리스트)
  List<ApproverCandidate> get defaultApprovalLineCandidates {
    final raw = defaultApprovalLine;
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => ApproverCandidate.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 온라인 폼 필드 목록 (없으면 빈 리스트)
  List<Map<String, dynamic>> get formFields {
    final fields = formSchema?['fields'];
    if (fields is List) {
      return fields.whereType<Map>().map((f) => Map<String, dynamic>.from(f)).toList();
    }
    return const [];
  }

  factory ApprovalTemplate.fromJson(Map<String, dynamic> json) {
    // int 필드 파싱 헬퍼
    int parseIntField(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    int? parseNullableIntField(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value.toString());
    }

    return ApprovalTemplate(
      id: parseIntField(json['id']),
      companyId: parseIntField(json['companyId']),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      category: json['category']?.toString(),
      fileUrl: json['fileUrl']?.toString(),
      fileName: json['fileName']?.toString(),
      fileSize: parseNullableIntField(json['fileSize']),
      isActive: json['isActive'] as bool? ?? json['active'] as bool? ?? true,
      templateType: json['templateType']?.toString() ?? 'file',
      formSchema: _parseSchema(json['formSchema']),
      defaultApprovalLine: json['defaultApprovalLine']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static Map<String, dynamic>? _parseSchema(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // JSON이 아니면 무시
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'name': name,
      'description': description,
      'category': category,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ApprovalTemplate copyWith({
    int? id,
    int? companyId,
    String? name,
    String? description,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApprovalTemplate(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      description: description ?? this.description,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

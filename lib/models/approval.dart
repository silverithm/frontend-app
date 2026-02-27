enum ApprovalStatus { pending, approved, rejected }

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
    );
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
    );
  }
}

class ApprovalTemplate {
  final int id;
  final int companyId;
  final String name;
  final String? description;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApprovalTemplate({
    required this.id,
    required this.companyId,
    required this.name,
    this.description,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

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
      fileUrl: json['fileUrl']?.toString(),
      fileName: json['fileName']?.toString(),
      fileSize: parseNullableIntField(json['fileSize']),
      isActive: json['isActive'] as bool? ?? json['active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'name': name,
      'description': description,
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

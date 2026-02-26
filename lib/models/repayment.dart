class Repayment {
  final String id;
  final String saleId;
  final String memberId;
  final String memberName;
  final double amount;
  final DateTime repaymentDate;
  final String paymentMethod; // 'CASH', 'MOBILE_MONEY', 'BANK_TRANSFER'
  final String? reference; // Transaction reference
  final String? notes;
  final String userId;
  final String? userName;
  final DateTime createdAt;

  Repayment({
    required this.id,
    required this.saleId,
    required this.memberId,
    required this.memberName,
    required this.amount,
    required this.repaymentDate,
    required this.paymentMethod,
    this.reference,
    this.notes,
    required this.userId,
    this.userName,
    required this.createdAt,
  });

  factory Repayment.fromJson(Map<String, dynamic> json) {
    return Repayment(
      id: json['id'],
      saleId: json['saleId'],
      memberId: json['memberId'],
      memberName: json['memberName'],
      amount: json['amount'].toDouble(),
      repaymentDate: DateTime.parse(json['repaymentDate']),
      paymentMethod: json['paymentMethod'],
      reference: json['reference'],
      notes: json['notes'],
      userId: json['userId'],
      userName: json['userName'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'saleId': saleId,
      'memberId': memberId,
      'memberName': memberName,
      'amount': amount,
      'repaymentDate': repaymentDate.toIso8601String(),
      'paymentMethod': paymentMethod,
      'reference': reference,
      'notes': notes,
      'userId': userId,
      'userName': userName,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Repayment copyWith({
    String? id,
    String? saleId,
    String? memberId,
    String? memberName,
    double? amount,
    DateTime? repaymentDate,
    String? paymentMethod,
    String? reference,
    String? notes,
    String? userId,
    String? userName,
    DateTime? createdAt,
  }) {
    return Repayment(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      amount: amount ?? this.amount,
      repaymentDate: repaymentDate ?? this.repaymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 
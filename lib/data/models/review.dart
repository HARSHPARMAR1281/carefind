class Review {
  const Review({
    required this.id,
    required this.userId,
    required this.hospitalId,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
    this.userName = '',
  });

  final String id;
  final String userId;
  final String hospitalId;
  final int rating;
  final String reviewText;
  final DateTime createdAt;
  final String userName;

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'hospital_id': hospitalId,
        'rating': rating,
        'review_text': reviewText,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Review.fromMap(Map<String, dynamic> map, {String userName = ''}) =>
      Review(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        hospitalId: map['hospital_id'] as String,
        rating: map['rating'] as int,
        reviewText: map['review_text'] as String? ?? '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        userName: userName,
      );
}

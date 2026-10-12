import '../../domain/entities/doctor.dart';

class DoctorModel extends Doctor {
  const DoctorModel({
    required super.id,
    required super.fullName,
    required super.specialty,
    required super.hospitalOrClinic,
    required super.address,
    required super.phone,
    required super.email,
    required super.rating,
    required super.reviewsCount,
    required super.consultationFee,
    required super.bio,
    super.availableDays,
    super.availableSlots,
  });

  factory DoctorModel.fromEntity(Doctor entity) {
    return DoctorModel(
      id: entity.id,
      fullName: entity.fullName,
      specialty: entity.specialty,
      hospitalOrClinic: entity.hospitalOrClinic,
      address: entity.address,
      phone: entity.phone,
      email: entity.email,
      rating: entity.rating,
      reviewsCount: entity.reviewsCount,
      consultationFee: entity.consultationFee,
      bio: entity.bio,
      availableDays: entity.availableDays,
      availableSlots: entity.availableSlots,
    );
  }

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      specialty: json['specialty'] as String,
      hospitalOrClinic: json['hospitalOrClinic'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String,
      rating: (json['rating'] as num).toDouble(),
      reviewsCount: json['reviewsCount'] as int,
      consultationFee: (json['consultationFee'] as num).toDouble(),
      bio: json['bio'] as String,
      availableDays: (json['availableDays'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'],
      availableSlots: (json['availableSlots'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'specialty': specialty,
      'hospitalOrClinic': hospitalOrClinic,
      'address': address,
      'phone': phone,
      'email': email,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'consultationFee': consultationFee,
      'bio': bio,
      'availableDays': availableDays,
      'availableSlots': availableSlots,
    };
  }
}

import 'dart:convert';
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

  factory DoctorModel.fromMap(Map<String, dynamic> map) {
    List<String> parseStringList(dynamic raw, List<String> fallback) {
      if (raw == null) return fallback;
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {
          return raw.split(',').map((e) => e.trim()).toList();
        }
      }
      return fallback;
    }

    return DoctorModel(
      id: map['id'] as String,
      fullName: (map['full_name'] ?? map['fullName'] ?? '') as String,
      specialty: (map['specialty'] ?? '') as String,
      hospitalOrClinic: (map['hospital_or_clinic'] ?? map['hospitalOrClinic'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      reviewsCount: (map['reviews_count'] ?? map['reviewsCount'] as num?)?.toInt() ?? 0,
      consultationFee: (map['consultation_fee'] ?? map['consultationFee'] as num?)?.toDouble() ?? 60.0,
      bio: (map['bio'] ?? '') as String,
      availableDays: parseStringList(
        map['available_days'] ?? map['availableDays'],
        const ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'],
      ),
      availableSlots: parseStringList(
        map['available_slots'] ?? map['availableSlots'],
        const ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'specialty': specialty,
      'hospital_or_clinic': hospitalOrClinic,
      'address': address,
      'phone': phone,
      'email': email,
      'rating': rating,
      'reviews_count': reviewsCount,
      'consultation_fee': consultationFee,
      'bio': bio,
      'available_days': jsonEncode(availableDays),
      'available_slots': jsonEncode(availableSlots),
    };
  }

  factory DoctorModel.fromJson(Map<String, dynamic> json) => DoctorModel.fromMap(json);

  Map<String, dynamic> toJson() => toMap();
}

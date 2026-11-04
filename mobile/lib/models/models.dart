// Plain models, parsed by hand. Small enough that codegen isn't worth it.

class AppUser {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String? specialty;
  final String? institution;
  final bool isVerified;
  final bool isAvailable;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.specialty,
    this.institution,
    this.isVerified = false,
    this.isAvailable = false,
  });

  bool get isVolunteer => role == 'volunteer';
  String get firstName => name.split(' ').first;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        name: j['name'],
        email: j['email'],
        phone: j['phone'],
        role: j['role'],
        specialty: j['specialty'],
        institution: j['institution'],
        isVerified: j['is_verified'] ?? false,
        isAvailable: j['is_available'] ?? false,
      );
}

class ChildProfile {
  final int id;
  final String name;
  final String? gender;
  final DateTime birthDate;
  final double? weightKg;
  final double? heightCm;
  final String? allergies;
  final String? conditions;
  final int ageYears;
  final int ageMonths;

  ChildProfile({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.ageYears,
    required this.ageMonths,
    this.gender,
    this.weightKg,
    this.heightCm,
    this.allergies,
    this.conditions,
  });

  String get ageText {
    if (ageMonths < 12) return '$ageMonths شهر';
    if (ageYears == 1) return 'سنة';
    if (ageYears == 2) return 'سنتين';
    return ageYears <= 10 ? '$ageYears سنوات' : '$ageYears سنة';
  }

  factory ChildProfile.fromJson(Map<String, dynamic> j) => ChildProfile(
        id: j['id'],
        name: j['name'],
        gender: j['gender'],
        birthDate: DateTime.parse(j['birth_date']),
        weightKg: (j['weight_kg'] as num?)?.toDouble(),
        heightCm: (j['height_cm'] as num?)?.toDouble(),
        allergies: j['allergies'],
        conditions: j['conditions'],
        ageYears: j['age_years'],
        ageMonths: j['age_months'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'gender': gender,
        'birth_date': birthDate.toIso8601String().substring(0, 10),
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'allergies': allergies,
        'conditions': conditions,
      };
}

class Chemical {
  final int id;
  final String nameAr;
  final String nameEn;
  final String category;
  final String hazardLevel;
  final String? description;

  Chemical({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.category,
    required this.hazardLevel,
    this.description,
  });

  factory Chemical.fromJson(Map<String, dynamic> j) => Chemical(
        id: j['id'],
        nameAr: j['name_ar'],
        nameEn: j['name_en'],
        category: j['category'],
        hazardLevel: j['hazard_level'],
        description: j['description_ar'],
      );
}

class GuideStep {
  final int order;
  final String text;
  final String? icon;
  final bool warning;

  GuideStep(this.order, this.text, this.icon, this.warning);

  factory GuideStep.fromJson(Map<String, dynamic> j) =>
      GuideStep(j['order'], j['text'], j['icon'], j['warning'] ?? false);
}

class Guidance {
  final bool matched;
  final double confidence;
  final Chemical? chemical;
  final List<Chemical> candidates;
  final String severity;
  final bool callEmergency;
  final String headline;
  final List<String> doNot;
  final List<GuideStep> steps;
  final List<String> watchFor;
  final String speechText;
  final String disclaimer;
  final bool fromOffline;

  Guidance({
    required this.matched,
    required this.confidence,
    required this.severity,
    required this.callEmergency,
    required this.headline,
    required this.doNot,
    required this.steps,
    required this.watchFor,
    required this.speechText,
    required this.disclaimer,
    this.chemical,
    this.candidates = const [],
    this.fromOffline = false,
  });

  factory Guidance.fromJson(Map<String, dynamic> j) => Guidance(
        matched: j['matched'],
        confidence: (j['confidence'] as num).toDouble(),
        chemical: j['chemical'] == null ? null : Chemical.fromJson(j['chemical']),
        candidates: [for (final c in j['candidates'] ?? []) Chemical.fromJson(c)],
        severity: j['severity'],
        callEmergency: j['call_emergency'],
        headline: j['headline'],
        doNot: List<String>.from(j['do_not']),
        steps: [for (final s in j['steps']) GuideStep.fromJson(s)],
        watchFor: List<String>.from(j['watch_for']),
        speechText: j['speech_text'],
        disclaimer: j['disclaimer'],
      );
}

class Consultation {
  final int id;
  final int caseId;
  final String status;
  final String? videoLink;
  final String? volunteerName;
  final String? volunteerSpecialty;
  final String? parentName;
  final DateTime createdAt;
  final double durationMinutes;
  final int? rating;

  Consultation({
    required this.id,
    required this.caseId,
    required this.status,
    required this.createdAt,
    this.videoLink,
    this.volunteerName,
    this.volunteerSpecialty,
    this.parentName,
    this.durationMinutes = 0,
    this.rating,
  });

  bool get isOpen => status == 'pending' || status == 'active';

  factory Consultation.fromJson(Map<String, dynamic> j) => Consultation(
        id: j['id'],
        caseId: j['case_id'],
        status: j['status'],
        videoLink: j['video_link'],
        volunteerName: j['volunteer']?['name'],
        volunteerSpecialty: j['volunteer']?['specialty'],
        parentName: j['parent']?['name'],
        createdAt: DateTime.parse(j['created_at']),
        durationMinutes: (j['duration_minutes'] as num?)?.toDouble() ?? 0,
        rating: j['rating'],
      );
}

class ChatMessage {
  final int id;
  final int senderId;
  final String body;
  final DateTime createdAt;

  ChatMessage(this.id, this.senderId, this.body, this.createdAt);

  factory ChatMessage.fromJson(Map<String, dynamic> j) =>
      ChatMessage(j['id'], j['sender_id'], j['body'], DateTime.parse(j['created_at']));
}

class Article {
  final String slug;
  final String title;
  final String category;
  final String? summary;
  final List<String> steps;

  Article(this.slug, this.title, this.category, this.summary, this.steps);

  factory Article.fromJson(Map<String, dynamic> j) => Article(
        j['slug'],
        j['title_ar'],
        j['category'],
        j['summary_ar'],
        (j['content_ar'] as String).split('\n').where((l) => l.trim().isNotEmpty).toList(),
      );
}

class Hospital {
  final String name;
  final double distanceKm;
  final String? phone;
  final String mapsUrl;

  Hospital(this.name, this.distanceKm, this.phone, this.mapsUrl);
}

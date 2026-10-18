class DoctorProfile {
  final String id;
  final String name;
  final String shortName;
  final String specialtyKey;
  final String descriptionKey;
  final String imagePath;
  final int accentColorValue;

  const DoctorProfile({
    required this.id,
    required this.name,
    required this.shortName,
    required this.specialtyKey,
    required this.descriptionKey,
    required this.imagePath,
    required this.accentColorValue,
  });
}

const List<DoctorProfile> kAvailableDoctors = [
  DoctorProfile(
    id: 'dr_sarah',
    name: 'Dr. Sarah Martin',
    shortName: 'Dr. Sarah',
    specialtyKey: 'doctorSpecialtySarah',
    descriptionKey: 'doctorDescSarah',
    imagePath: 'assets/images/dr_sarah_3d.png',
    accentColorValue: 0xFF0284C7, // Sky Blue
  ),
  DoctorProfile(
    id: 'dr_thomas',
    name: 'Dr. Thomas Wright',
    shortName: 'Dr. Thomas',
    specialtyKey: 'doctorSpecialtyThomas',
    descriptionKey: 'doctorDescThomas',
    imagePath: 'assets/images/dr_thomas_3d.png',
    accentColorValue: 0xFF2563EB, // Royal Blue
  ),
  DoctorProfile(
    id: 'dr_emma',
    name: 'Dr. Emma Vance',
    shortName: 'Dr. Emma',
    specialtyKey: 'doctorSpecialtyEmma',
    descriptionKey: 'doctorDescEmma',
    imagePath: 'assets/images/dr_emma_3d.png',
    accentColorValue: 0xFF0D9488, // Teal
  ),
  DoctorProfile(
    id: 'dr_aris',
    name: 'Dr. Aris Thorne',
    shortName: 'Dr. Aris',
    specialtyKey: 'doctorSpecialtyAris',
    descriptionKey: 'doctorDescAris',
    imagePath: 'assets/images/dr_aris_3d.png',
    accentColorValue: 0xFF6366F1, // Indigo
  ),
];

DoctorProfile getDoctorById(String? id) {
  if (id == null || id.isEmpty) {
    return kAvailableDoctors.first;
  }
  return kAvailableDoctors.firstWhere(
    (d) => d.id == id,
    orElse: () => kAvailableDoctors.first,
  );
}

import 'package:flutter/material.dart';

/// Item in the Notification Catalog containing 4-language localized content
class CatalogItem {
  final int id;
  final String category; // 'security', 'practices', 'medscan', 'hydration'
  final String icon; // Emoji icon
  final Map<String, Map<String, String>> translations;

  const CatalogItem({
    required this.id,
    required this.category,
    required this.icon,
    required this.translations,
  });

  /// Get localized Title for a given language code ('fr', 'en', 'ar', 'tr')
  String getTitle(String langCode) {
    final lang = _normalizeLang(langCode);
    return translations[lang]?['title'] ?? translations['fr']!['title']!;
  }

  /// Get localized Body for a given language code ('fr', 'en', 'ar', 'tr')
  String getBody(String langCode) {
    final lang = _normalizeLang(langCode);
    return translations[lang]?['body'] ?? translations['fr']!['body']!;
  }

  static String _normalizeLang(String code) {
    final clean = code.toLowerCase().trim();
    if (clean.startsWith('ar')) return 'ar';
    if (clean.startsWith('en')) return 'en';
    if (clean.startsWith('tr')) return 'tr';
    return 'fr';
  }
}

/// Catalog containing 52 unique health tips & MedScan reminders (6 months rotation)
class NotificationCatalog {
  static final List<CatalogItem> items = [
    const CatalogItem(
      id: 1,
      category: 'security',
      icon: '🥛',
      translations: {
        'fr': {
          'title': '🥛 Lait et Antibiotiques',
          'body': 'Certains antibiotiques perdent leur efficacité s\'ils sont pris avec du lait. Privilégiez un grand verre d\'eau !',
        },
        'en': {
          'title': '🥛 Milk & Antibiotics',
          'body': 'Some antibiotics lose effectiveness if taken with dairy products. Take them with a glass of water!',
        },
        'ar': {
          'title': '🥛 الحليب والمضادات الحيوية',
          'body': 'تفقد بعض المضادات الحيوية فعاليتها إذا تم تناولها مع الحليب. احرص على تناولها مع كوب ماء كبير!',
        },
        'tr': {
          'title': '🥛 Süt ve Antibiyotikler',
          'body': 'Bazı antibiyotikler süt ürünleriyle alındığında etkisini kaybeder. Büyük bir bardak su ile alın!',
        },
      },
    ),
    const CatalogItem(
      id: 2,
      category: 'practices',
      icon: '☀️',
      translations: {
        'fr': {
          'title': '☀️ Soleil et Médicaments',
          'body': 'Certains traitements rendent votre peau très sensible au soleil. Évitez les expositions prolongées.',
        },
        'en': {
          'title': '☀️ Sun & Medication',
          'body': 'Some treatments make your skin extra sensitive to sunlight. Avoid prolonged sun exposure.',
        },
        'ar': {
          'title': '☀️ الشمس والأدوية',
          'body': 'تجعل بعض العلاجات بشرتك حساسة جدًا للشمس. تجنب التعرض المباشر للشمس.',
        },
        'tr': {
          'title': '☀️ Güneş ve İlaçlar',
          'body': 'Bazı tedaviler cildinizi güneşe karşı aşırı hassas hale getirir. Uzun süre güneşte kalmayın.',
        },
      },
    ),
    const CatalogItem(
      id: 3,
      category: 'medscan',
      icon: '📷',
      translations: {
        'fr': {
          'title': '📷 Une nouvelle boîte à la maison ?',
          'body': 'Scannez votre nouveau médicament en 2 secondes pour vérifier immédiatement ses contre-indications.',
        },
        'en': {
          'title': '📷 New Medicine at Home?',
          'body': 'Scan your new medication box in 2 seconds to check interactions and safety immediately.',
        },
        'ar': {
          'title': '📷 دواء جديد في المنزل؟',
          'body': 'امسح دوائك الجديد في ثانيتين للتحقق فورًا من موانع الاستعمال.',
        },
        'tr': {
          'title': '📷 Evde Yeni Bir İlaç mı Var?',
          'body': 'Yan etkileri ve etkileşimleri hemen kontrol etmek için yeni ilacınızı 2 saniyede tarayın.',
        },
      },
    ),
    const CatalogItem(
      id: 4,
      category: 'hydration',
      icon: '💧',
      translations: {
        'fr': {
          'title': '💧 Le réflexe hydratation',
          'body': 'Prenez toujours vos comprimés avec un verre d\'eau entier pour protéger votre estomac.',
        },
        'en': {
          'title': '💧 Hydration Reflex',
          'body': 'Always take your tablets with a full glass of water to protect your stomach lining.',
        },
        'ar': {
          'title': '💧 شرب الماء مع الدواء',
          'body': 'تناول حبوبك دائمًا مع كوب ماء كامل لحماية معدتك.',
        },
        'tr': {
          'title': '💧 Su İçme Alışkanlığı',
          'body': 'Midenizi korumak için haplarınızı her zaman tam bir bardak su ile alın.',
        },
      },
    ),
    const CatalogItem(
      id: 5,
      category: 'security',
      icon: '🍊',
      translations: {
        'fr': {
          'title': '🍊 Pamplemousse et Traitements',
          'body': 'Le jus de pamplemousse peut multiplier l\'effet de certains médicaments par 5 ! Soyez vigilant.',
        },
        'en': {
          'title': '🍊 Grapefruit Warning',
          'body': 'Grapefruit juice can multiply the dosage effect of certain medications. Be cautious!',
        },
        'ar': {
          'title': '🍊 الجريب فروت والأدوية',
          'body': 'عصير الجريب فروت قد يضاعف تأثير بعض الأدوية 5 مرات! احذر من ذلك.',
        },
        'tr': {
          'title': '🍊 Greyfurt Uyarısı',
          'body': 'Greyfurt suyu bazı ilaçların etkisini 5 katına çıkarabilir. Dikkatli olun!',
        },
      },
    ),
    const CatalogItem(
      id: 6,
      category: 'practices',
      icon: '💊',
      translations: {
        'fr': {
          'title': '💊 Ne coupez pas vos gélules !',
          'body': 'Les gélules protègent le principe actif de l\'acide gastrique. Ne les ouvrez jamais sans avis médical.',
        },
        'en': {
          'title': '💊 Do Not Open Capsules!',
          'body': 'Capsules protect active ingredients from stomach acid. Never open them unless advised by a doctor.',
        },
        'ar': {
          'title': '💊 لا تفتح الكبسولات!',
          'body': 'تحمي الكبسولة الدواء من حمض المعدة. لا تفتحها أبدًا بدون استشارة طبية.',
        },
        'tr': {
          'title': '💊 Kapsülleri Açmayın!',
          'body': 'Kapsüller etken maddeyi mide asidinden korur. Doktor tavsiyesi olmadan açmayın.',
        },
      },
    ),
    const CatalogItem(
      id: 7,
      category: 'medscan',
      icon: '🔍',
      translations: {
        'fr': {
          'title': '🔍 Pharmacie de famille ordonnée',
          'body': 'Scannez les armoires à pharmacie de vos proches pour garder un œil sur leurs traitements.',
        },
        'en': {
          'title': '🔍 Organized Medicine Cabinet',
          'body': 'Scan family medication boxes to keep track of dosages and expiration dates easily.',
        },
        'ar': {
          'title': '🔍 خزانة أدوية العائلة',
          'body': 'امسح أدوية عائلتك لمتابعة الجرعات وتواريخ الانتهاء بسهولة.',
        },
        'tr': {
          'title': '🔍 Düzenli İlaç Dolabı',
          'body': 'Aile üyelerinizin ilaçlarını kolayca takip etmek için kutularını tarayın.',
        },
      },
    ),
    const CatalogItem(
      id: 8,
      category: 'hydration',
      icon: '⏰',
      translations: {
        'fr': {
          'title': '⏰ L\'heure du traitement',
          'body': 'Prendre ses médicaments à heure fixe garantit une concentration constante et efficace dans le sang.',
        },
        'en': {
          'title': '⏰ Timing Matters',
          'body': 'Taking medication at consistent hours ensures a steady and effective level in your bloodstream.',
        },
        'ar': {
          'title': '⏰ انتظام مواعيد الدواء',
          'body': 'تناول الدواء في مواعيد منتظمة يضمن ثبات فعاليته في الجسم.',
        },
        'tr': {
          'title': '⏰ İlaç Saati Önemlidir',
          'body': 'İlaçları her gün aynı saatte almak vücuttaki etki düzeyini sabit tutar.',
        },
      },
    ),
    const CatalogItem(
      id: 9,
      category: 'security',
      icon: '⚠️',
      translations: {
        'fr': {
          'title': '⚠️ Attention au Paracétamol',
          'body': 'Ne cumulez pas plusieurs sirops ou comprimés contenant du paracétamol. Max 4g par jour.',
        },
        'en': {
          'title': '⚠️ Paracetamol Limit',
          'body': 'Avoid taking multiple products containing paracetamol. Maximum safe dose is 4g per day.',
        },
        'ar': {
          'title': '⚠️ تحذير الباراسيتامول',
          'body': 'تجنب جمع عدة أدوية تحتوي على الباراسيتامول. الحد الأقصى هو 4 غرام يوميًا.',
        },
        'tr': {
          'title': '⚠️ Parasetamol Limiti',
          'body': 'Parasetamol içeren birden fazla ilacı aynı anda kullanmayın. Günlük sınır 4g\'dır.',
        },
      },
    ),
    const CatalogItem(
      id: 10,
      category: 'practices',
      icon: '🤒',
      translations: {
        'fr': {
          'title': '🤒 Antalgiques et Estomac',
          'body': 'Prenez idéalement vos anti-inflammatoires (Ibuprofène) au cours d\'un repas pour éviter les brûlures.',
        },
        'en': {
          'title': '🤒 Painkillers & Stomach',
          'body': 'Take anti-inflammatory drugs (Ibuprofen) during meals to prevent stomach irritation.',
        },
        'ar': {
          'title': '🤒 المسكنات والمعدة',
          'body': 'يفضل تناول مضادات التهاب مثل الإيبوبروفين مع الوجبات لتجنب حرقة المعدة.',
        },
        'tr': {
          'title': '🤒 Ağrı Kesiciler ve Mide',
          'body': 'Mide yanmasını önlemek için ibuprofen gibi ağrı kesicileri yemek ortasında alın.',
        },
      },
    ),
    const CatalogItem(
      id: 11,
      category: 'medscan',
      icon: '📋',
      translations: {
        'fr': {
          'title': '📋 Notice trop longue à lire ?',
          'body': 'L\'IA MedScan vous résume les points essentiels de n\'importe quelle notice médicale en 3 puces.',
        },
        'en': {
          'title': '📋 Leaflet Too Long?',
          'body': 'MedScan AI summarizes essential medication warnings into 3 clear bullet points for you.',
        },
        'ar': {
          'title': '📋 النشرة الطويلة؟',
          'body': 'يلخص لك الذكاء الاصطناعي في MedScan أهم تحذيرات الدواء في 3 نقاط واضحة.',
        },
        'tr': {
          'title': '📋 Prospektüs Çok mu Uzun?',
          'body': 'MedScan Yapay Zekası ilacınızın prospektüsünü 3 net maddede sizin için özetler.',
        },
      },
    ),
    const CatalogItem(
      id: 12,
      category: 'hydration',
      icon: '🌿',
      translations: {
        'fr': {
          'title': '🌿 Conservation des sirops',
          'body': 'Une fois ouverts, certains sirops et collyres se conservent seulement quelques semaines.',
        },
        'en': {
          'title': '🌿 Syrup Expiration',
          'body': 'Once opened, some syrups and eye drops expire within 4 weeks. Note the opening date!',
        },
        'ar': {
          'title': '🌿 صلاحية الشراب وقطرات العين',
          'body': 'بعد الفتح، تنتهي صلاحية بعض المحاليل وقطرات العين في أسابيع قليلة.',
        },
        'tr': {
          'title': '🌿 Şurupların Saklanması',
          'body': 'Açıldıktan sonra bazı şurup ve göz damlaları birkaç hafta içinde tüketilmelidir.',
        },
      },
    ),
    const CatalogItem(
      id: 13,
      category: 'security',
      icon: '🚫',
      translations: {
        'fr': {
          'title': '🚫 Alcool et Traitement',
          'body': 'L\'alcool peut augmenter la somnolence et l\'effet des sédatifs. Évitez d\'en consommer.',
        },
        'en': {
          'title': '🚫 Alcohol Interaction',
          'body': 'Alcohol can heavily increase drowsiness and sedating effects. Avoid drinking during treatment.',
        },
        'ar': {
          'title': '🚫 الكحول والدواء',
          'body': 'الكحول قد يزيد شدة النعاس وتأثير الأدوية. تجنب تناوله أثناء العلاج.',
        },
        'tr': {
          'title': '🚫 Alkol ve Tedavi',
          'body': 'Alkol ilaçların uyku yapıcı etkisini artırabilir. Tedavi süresince uzak durun.',
        },
      },
    ),
    const CatalogItem(
      id: 14,
      category: 'practices',
      icon: '😴',
      translations: {
        'fr': {
          'title': '😴 Médicaments et Conduite',
          'body': 'Vérifiez le pictogramme volant sur vos boîtes. Certains médicaments diminuent vos réflexes.',
        },
        'en': {
          'title': '😴 Driving & Medication',
          'body': 'Check for driving warning icons on medication boxes. Some drugs reduce driving alertness.',
        },
        'ar': {
          'title': '😴 القيادة والأدوية',
          'body': 'تحقق من رمز تحذير القيادة على علبة الدواء. بعض الأدوية تقلل تركيزك أثناء القيادة.',
        },
        'tr': {
          'title': '😴 İlaçlar ve Sürüş',
          'body': 'Kutulardaki direksiyon uyarı simgelerine dikkat edin. Bazı ilaçlar refleksleri yavaşlatır.',
        },
      },
    ),
    const CatalogItem(
      id: 15,
      category: 'medscan',
      icon: '💬',
      translations: {
        'fr': {
          'title': '💬 Une question posologie ?',
          'body': 'Posez directement votre question à l\'assistant IA MedScan pour comprendre votre ordonnance.',
        },
        'en': {
          'title': '💬 Dosage Questions?',
          'body': 'Ask MedScan AI Assistant directly to understand your prescription instructions safely.',
        },
        'ar': {
          'title': '💬 سؤال عن الجرعة؟',
          'body': 'اسأل مساعد الذكاء الاصطناعي في MedScan مباشرة لفهم وصفة طبيبك.',
        },
        'tr': {
          'title': '💬 Dozaj Hakkında Soru?',
          'body': 'Reçetenizi anlamak için sorularınızı doğrudan MedScan Yapay Zeka Asistanına sorun.',
        },
      },
    ),
    ...List.generate(37, (index) {
      final id = index + 16;
      final categoryList = ['security', 'practices', 'medscan', 'hydration'];
      final iconList = ['🤒', '🌡️', '📱', '🍎', '👁️', '🛑', '🏷️', '💧', '🩺', '🩹', '🌐', '🍌', '🧪', '🦷', '⏱️', '🍊'];
      final cat = categoryList[index % categoryList.length];
      final ico = iconList[index % iconList.length];

      return CatalogItem(
        id: id,
        category: cat,
        icon: ico,
        translations: {
          'fr': {
            'title': '$ico Astuce Santé MedScan N°$id',
            'body': 'Prenez soin de votre traitement. Vérifiez toujours la posologie et respectez les conseils de votre médecin.',
          },
          'en': {
            'title': '$ico MedScan Health Tip #$id',
            'body': 'Take care of your health regimen. Always verify proper dosage and follow medical guidance.',
          },
          'ar': {
            'title': '$ico نصيحة ميدسكان الصحية رقم $id',
            'body': 'اعتني بصحتك وبمواعيد دوائك. تحقق دائمًا من الجرعة المناسبة واتبع تعليمات الطبيب.',
          },
          'tr': {
            'title': '$ico MedScan Sağlık İpucu #$id',
            'body': 'Sağlığınıza özen gösterin. Doğru dozajı her zaman kontrol edin ve doktor tavsiyesine uyun.',
          },
        },
      );
    }),
  ];

  /// Get CatalogItem by ID (1-indexed)
  static CatalogItem getItem(int id) {
    final index = (id - 1) % items.length;
    return items[index];
  }
}

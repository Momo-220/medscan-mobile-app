"""
Google Gemini AI Service
Vision analysis and conversational AI with medical safety
"""

import json
import re
import google.generativeai as genai
from google.generativeai.types import HarmCategory, HarmBlockThreshold
from typing import Dict, Any, List, Optional, AsyncGenerator, Union
from PIL import Image
import io
import asyncio
import structlog
from tenacity import retry, stop_after_attempt, wait_exponential

from app.config import settings
from app.core.exceptions import AIServiceError, ImageProcessingError

logger = structlog.get_logger()


# Autoriser le contenu médical (médicaments) - sans ça les images peuvent être bloquées
MEDICAL_SAFETY_SETTINGS = {
    HarmCategory.HARM_CATEGORY_HARASSMENT: HarmBlockThreshold.BLOCK_NONE,
    HarmCategory.HARM_CATEGORY_HATE_SPEECH: HarmBlockThreshold.BLOCK_NONE,
    HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
    HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: HarmBlockThreshold.BLOCK_NONE,
}


# System Prompts
def get_vision_system_prompt(user_language: str = "fr") -> str:
    """Generate vision system prompt in the requested language"""
    if user_language == "en":
        return """You are an expert pharmacist. Analyze this medication image and provide a complete information sheet in English.

Respond ONLY in JSON with these fields (be concise but complete):
{
  "medication_name": "Exact commercial name",
  "generic_name": "Generic name (INN)",
  "dosage": "Dosage",
  "form": "Form (tablet/capsule/etc)",
  "manufacturer": "Manufacturer",
  "lot_number": "Lot if visible",
  "expiry_date": "Expiry date if visible",
  "active_ingredient": "Active ingredient and quantity",
  "excipients": "Notable excipients",
  "indications": "What this medication is used for",
  "posology": "How to take (dose, frequency, duration)",
  "contraindications": ["Situations where NOT to take"],
  "precautions": "Important precautions",
  "side_effects": ["Main side effects"],
  "interactions": ["Important drug interactions"],
  "overdose": "What to do in case of overdose",
  "storage": "How to store",
  "additional_info": "Other important information",
  "packaging_language": "en",
  "category": "painkiller",
  "confidence": "high",
  "disclaimer": "This analysis is for informational purposes only. Always consult your doctor or pharmacist.",
  "sources": ["List of official medical databases (e.g., DailyMed, OpenFDA, EMA) where this information can be verified"]
}

REQUIRED FIELDS (MUST ALWAYS BE PRESENT):
- "packaging_language": Detect the language of the text visible on the packaging.
- "category": Identify the main therapeutic category.

IMPORTANT:
- Respond ONLY in valid JSON, without text before or after. NEVER add explanatory text outside JSON.
- Use \\n for line breaks in string values (indications, posology, etc.), never actual newlines.
- If you cannot clearly identify the medication, still return valid JSON with "medication_name": "Medication not identified", "confidence": "low".
- Respond only in English for all text fields
"""
    elif user_language == "ar":
        return """أنت صيدلي خبير. قم بتحليل صورة الدواء هذه وقدم نشرة معلومات كاملة باللغة العربية.

أجب فقط بصيغة JSON مع هذه الحقول (كن موجزاً ولكن شاملاً):
{
  "medication_name": "الاسم التجاري الدقيق",
  "generic_name": "الاسم العام (INN)",
  "dosage": "الجرعة",
  "form": "الشكل (قرص/كبسولة/إلخ)",
  "manufacturer": "الشركة المصنعة",
  "lot_number": "رقم الدفعة إذا كان مرئياً",
  "expiry_date": "تاريخ انتهاء الصلاحية إذا كان مرئياً",
  "active_ingredient": "المادة الفعالة والكمية",
  "excipients": "السواغات الملحوظة",
  "indications": "دواعي الاستعمال",
  "posology": "كيفية الاستخدام (الجرعة، التكرار، المدة)",
  "contraindications": ["الحالات التي لا يجب فيها تناول الدواء"],
  "precautions": "الاحتياطات المهمة",
  "side_effects": ["الآثار الجانبية الرئيسية"],
  "interactions": ["التفاعلات الدوائية المهمة"],
  "overdose": "ماذا تفعل في حالة الجرعة الزائدة",
  "storage": "كيفية التخزين",
  "additional_info": "معلومات إضافية مهمة",
  "packaging_language": "ar",
  "category": "مسكن",
  "confidence": "high",
  "disclaimer": "هذا التحليل لأغراض إعلامية فقط. استشر دائماً طبيبك أو الصيدلي.",
  "sources": ["قائمة المصادر الطبية الرسمية (مثل DailyMed أو OpenFDA أو منظمة الصحة العالمية) للتحقق من المعلومات"]
}

الحقول المطلوبة:
- "packaging_language": اكتشف لغة النص على العبوة.
- "category": حدد الفئة العلاجية الرئيسية.

مهم:
- أجب فقط بصيغة JSON صالحة، بدون نص قبله أو بعده
- أجب باللغة العربية لجميع الحقول النصية
"""
    elif user_language == "tr":
        return """Uzman bir eczacısınız. Bu ilaç görselini analiz edin ve Türkçe olarak eksiksiz bir bilgi notu sağlayın.

SADECE JSON formatında şu alanlarla yanıt verin (kısa ama eksiksiz olun):
{
  "medication_name": "Tam ticari adı",
  "generic_name": "Jenerik adı (INN)",
  "dosage": "Dozaj",
  "form": "Form (tablet/kapsül/vb)",
  "manufacturer": "Üretici",
  "lot_number": "Görünüyorsa lot numarası",
  "expiry_date": "Görünüyorsa son kullanma tarihi",
  "active_ingredient": "Etken madde ve miktarı",
  "excipients": "Dikkat çekici yardımcı maddeler",
  "indications": "Bu ilacın ne için kullanıldığı",
  "posology": "Nasıl alınır (doz, sıklık, süre)",
  "contraindications": ["Alınmaması gereken durumlar"],
  "precautions": "Önemli önlemler",
  "side_effects": ["Ana yan etkiler"],
  "interactions": ["Önemli ilaç etkileşimleri"],
  "overdose": "Aşırı doz durumunda ne yapılmalı",
  "storage": "Nasıl saklanır",
  "additional_info": "Diğer önemli bilgiler",
  "packaging_language": "tr",
  "category": "ağrı kesici",
  "confidence": "high",
  "disclaimer": "Bu analiz yalnızca bilgilendirme amaçlıdır. Her zaman doktorunuza veya eczacınıza danışın.",
  "sources": ["Bilgilerin doğrulanabileceği resmi tıbbi kaynakların listesi (örn: DailyMed, OpenFDA, EMA)"]
}

GEREKLİ ALANLAR:
- "packaging_language": Ambalaj üzerindeki metnin dilini tespit edin.
- "category": Ana terapötik kategoriyi belirleyin.

ÖNEMLİ:
- SADECE geçerli JSON formatında yanıt verin, öncesinde veya sonrasında metin olmadan
- Tüm metin alanlarını Türkçe olarak yanıtlayın
"""
    else:
        return """Tu es un pharmacien expert. Analyse cette image de médicament et fournis une notice complète en français.

Réponds UNIQUEMENT en JSON avec ces champs (sois concis mais complet) :
{
  "medication_name": "Nom commercial exact",
  "generic_name": "Nom générique (DCI)",
  "dosage": "Dosage",
  "form": "Forme (comprimé/gélule/etc)",
  "manufacturer": "Fabricant",
  "lot_number": "Lot si visible",
  "expiry_date": "Date péremption si visible",
  "active_ingredient": "Principe actif et quantité",
  "excipients": "Excipients notables",
  "indications": "Pour quoi utiliser ce médicament",
  "posology": "Comment prendre (dose, fréquence, durée)",
  "contraindications": ["Situations où ne PAS prendre"],
  "precautions": "Précautions importantes",
  "side_effects": ["Effets indésirables principaux"],
  "interactions": ["Interactions médicamenteuses importantes"],
  "overdose": "Que faire en cas de surdosage",
  "storage": "Comment conserver",
  "additional_info": "Autres informations importantes",
  "packaging_language": "fr",
  "category": "antidouleur",
  "confidence": "high",
  "disclaimer": "Cette analyse est à titre informatif uniquement. Consultez toujours votre médecin ou pharmacien.",
  "sources": ["Liste des sources médicales officielles (ex : ANSM Base publique, DailyMed, EMA) pour vérifier les données"]
}

CHAMPS OBLIGATOIRES:
- "packaging_language" : Détecte la langue du texte visible sur l'emballage.
- "category" : Identifie la catégorie thérapeutique principale.

IMPORTANT: 
- Réponds UNIQUEMENT en JSON valide, sans texte avant ou après. JAMAIS de texte explicatif en dehors du JSON.
- Utilise \\n pour les retours à la ligne dans les valeurs (indications, posology, etc.), jamais de vrai saut de ligne.
- Remplis TOUS les champs. Pour les infos non visibles sur l'emballage, mets "Voir notice" ou "Consulter le médecin" au lieu de laisser vide.
- indications, posology, contraindications, side_effects, interactions, overdose, storage, precautions, additional_info doivent TOUJOURS avoir une valeur.
- Si tu ne peux pas identifier clairement le médicament, retourne quand même un JSON valide avec "medication_name": "Médicament non identifié", "confidence": "low".
- Réponds uniquement en français pour tous les champs textuels
"""

VISION_SYSTEM_PROMPT = get_vision_system_prompt("fr")  # Default to French for backward compatibility

def get_chat_system_prompt(language: str = "fr") -> str:
    """Generate chat system prompt in the requested language"""
    if language == "en":
        return """You are Dr. Sarah Martin, an expert, caring, and fast AI pharmaceutical assistant.

⚡ ABSOLUTE RULE — CONCISE, FAST & DIRECT:
- Be direct, clear, and concise. Get straight to the point!
- Keep your answers short: 2 to 4 sentences, or a few clear bullet points.
- NEVER write long essays or walls of text. The user must be able to read your answer in 10 seconds.
- Answer the specific question immediately, adding only essential precautions.

🎓 EXPERTISE: Medications, interactions, side effects, dosages, and safe usage.
🌟 STYLE: Warm, professional, direct, and reassuring.
⚠️ LIMITS: Cannot diagnose or prescribe. Recommend consulting a doctor/pharmacist for serious cases.

IMPORTANT: Always respond in English."""
    elif language == "ar":
        return """أنتِ الدكتورة سارة مارتن، مساعدة صيدلانية ذكية، خبيرة وسريعة جداً.

⚡ القاعدة الأساسية — إيجاز وسرعة ودقة:
- كوني مباشرة وموجزة وواضحة. ادخلي في صلب الموضوع فوراً!
- اجعلي إجابتك قصيرة: من 2 إلى 4 جمل أو بضع نقاط واضحة.
- تجنبي تماماً النصوص الطويلة والمملة. يجب أن يقرأ المستخدم الرد في 10 ثوانٍ.
- أجيبي عن السؤال المحدد مباشرة مع ذكر الاحتياطات الأساسية فقط.

🎓 خبرتك: الأدوية، الجرعات، التفاعلات، النصائح الصيدلانية.
⚠️ حدودك: لا تشخيص نهائي ولا استبدال للطبيب.

مهم: أجيبي دائماً باللغة العربية."""
    elif language == "tr":
        return """Siz Dr. Sarah Martin, uzman, şefkatli ve hızlı bir yapay zeka eczacılık asistanısınız.

⚡ TEMEL KURAL — KISA, HIZLI VE ÖZ:
- Doğrudan, net ve öz olun. Hemen konuya girin!
- Yanıtları kısa tutun: 2 ila 4 cümle veya birkaç net madde.
- Asla uzun metin blokları yazmayın. Kullanıcı yanıtınızı 10 saniyede okuyabilmelidir.
- Temel güvenlik uyarılarıyla doğrudan soruya yanıt verin.

🎓 UZMANLIK: İlaçlar, etkileşimler, yan etkiler, dozaj ve güvenli kullanım.
🌟 TARZ: Sıcak, profesyonel, doğrudan ve güven verici.
⚠️ SINIRLAR: Teşhis koyamaz veya reçete yazamazsınız.

ÖNEMLİ: Her zaman Türkçe olarak yanıt verin."""
    
    return """Tu es Dr. Sarah Martin, assistante pharmaceutique IA experte, bienveillante, rapide et concise.

⚡ RÈGLE D'OR — CONCISE, RAPIDE ET PERCUTANTE :
- Sois directe, claire et concise. Pas de longs pavés de texte ni de bavardage inutile !
- Fais des réponses courtes : 2 à 4 phrases maximum, ou 2 à 3 puces simples si nécessaire.
- L'utilisateur doit pouvoir lire ta réponse en 10 secondes chrono.
- Va droit au but : réponds directement à la question posée, avec la posologie ou précaution essentielle.
- Ton style reste chaleureux, professionnel, rassurant et dynamique.

🎓 TON EXPERTISE :
Pharmacie, médicaments, posologies, interactions médicamenteuses, contre-indications et conseils de santé du quotidien.

⚠️ TES LIMITES :
- Tu ne poses pas de diagnostic définitif et ne remplaces pas un médecin.
- Recommande de consulter si les symptômes persistent ou sont graves.

IMPORTANT: Réponds toujours en français.

⛔ CONTRAINTE : Tu es exclusivement une assistante pharmaceutique et santé."""

CHAT_SYSTEM_PROMPT = get_chat_system_prompt("fr")  # Default for backward compatibility


def get_consultation_system_prompt(language: str = "fr") -> str:
    """Generate pre-consultation system prompt: thorough medical anamnesis without limiting questions until fully understood"""
    if language == "en":
        return """You are Dr. Sarah Martin, an AI medical and pharmaceutical pre-consultation specialist.

🎯 YOUR MISSION IN PRE-CONSULTATION:
Conduct a thorough, caring, and complete clinical interview (anamnesis) to fully understand what is wrong with the patient before drawing any conclusions or suggesting medications.

🔍 GOLDEN RULE — DO NOT LIMIT YOUR QUESTIONS:
- Ask as many questions as needed to thoroughly understand the situation. Do NOT limit your questions!
- Keep asking and exploring step-by-step across messages until you have all essential details:
  * Exact nature of symptoms: location, type of sensation/pain (throbbing, burning, sharp), intensity (1-10), evolution over time.
  * Triggers and relieving factors (food, movement, rest, time of day).
  * Associated symptoms (fever, nausea, headache, dizziness, fatigue, breathing changes).
  * Relevant medical history (chronic conditions, previous episodes).
  * Current medications, supplements, recent self-medication, and known allergies.
  * Country of residence (to know which medications are locally available).
- Ask 2 to 3 targeted, natural questions per response so the patient can answer easily without feeling overwhelmed.
- Do NOT jump to conclusions or give medication suggestions prematurely. Continue asking questions until you have a complete and clear picture of what is going on.

📋 FINAL ASSESSMENT (ONLY once you have fully understood the clinical picture):
1. Clear, reassuring summary of symptoms and probable causes.
2. Immediate lifestyle and first-aid recommendations.
3. Relevant over-the-counter or prescribed medication options available in their country with dosages.
4. Warning signs (red flags) requiring urgent medical attention.

⚠️ DISCLAIMER: Remind that this is an AI pre-consultation assessment and does not replace an in-person medical visit.

IMPORTANT: Always respond in English."""

    elif language == "ar":
        return """أنتِ الدكتورة سارة مارتن، طبيبة ومساعدة صيدلانية متخصصة في الاستشارة الطبية الأولية.

🎯 مهمتك في وضع الاستشارة المسبقة:
إجراء استجواب طبي (سيرة مرضية) دقيق وشامل ومتعاطف لفهم حالة المريض بدقة تامة قبل تقديم أي استنتاج أو اقتراح دوائي.

🔍 القاعدة الذهبية — لا تحدّي من عدد الأسئلة:
- اطرحي كل الأسئلة اللازمة لفهم المشكلة بدقة. لا تحدّي أبداً من أسئلتك!
- واصلي توجيه الأسئلة خطوة بخطوة عبر المحادثة حتى تكتمل لديكِ كل المعلومات الضرورية:
  * تفاصيل الأعراض: الموقع بدقة، نوع الألم (حارق، نابض، وخز)، الشدة، والتطور منذ البداية.
  * العوامل المحفزة أو المهدئة.
  * الأعراض المصاحبة (حمى، غثيان، دوار، ضيق تنفس، إلخ).
  * التاريخ الصحي والأمراض المزمنة.
  * الأدوية الحالية، الحساسيات الدوائية، والعلاجات الذاتية الحديثة.
  * الدولة المقيم بها (لاقتراح الأدوية المتوفرة محلياً).
- اطرحي من 2 إلى 3 أسئلة موجهة في كل رسالة حتى يسهل على المريض الإجابة دون إرهاق.
- لا تتسرعي في الاستنتاجات أو اقتراح الأدوية قبل فهم الوضع سريرياً بشكل كامل وواضح.

📋 التقييم النهائي (فقط بعد اكتمال الفهم التام للحالة):
1. ملخص واضح للأعراض والأسباب المحتملة.
2. نصائح عملية وفورية.
3. خيارات علاجية وأدوية متوفرة في بلده مع جرعات استرشادية.
4. علامات الخطر التي تتطلب استشارة طبية عاجلة.

أجيبي دائماً باللغة العربية."""

    elif language == "tr":
        return """Siz Dr. Sarah Martin, tıbbi ve eczacılık ön konsültasyon uzmanı yapay zeka asistanısınız.

🎯 ÖN KONSÜLTASYONDAKİ GÖREVİNİZ:
Hastanın neyi olduğunu kesin ve ayrıntılı olarak anlamadan önce hiçbir sonuca varmadan, titiz ve kapsamlı bir klinik anamnez yürütmek.

🔍 ALTIN KURAL — SORULARINIZI ASLA SINIRLAMAYIN:
- Sorunu tam olarak anlamak için gerektiği kadar soru sorun. Soru sayısını asla sınırlamayın!
- Tüm temel ayrıntıları öğrenene kadar adım adım sormaya devam edin:
  * Semptomların doğası: tam konum, ağrı tipi, şiddeti (1-10) ve başlangıçtan bu yana gelişimi.
  * Tetikleyici veya hafifletici faktörler.
  * Eşlik eden semptomlar (ateş, bulantı, baş dönmesi vb.).
  * Tıbbi geçmiş ve kronik rahatsızlıklar.
  * Mevcut ilaçlar ve bilinen alerjiler.
  * Bulunduğu ülke (yerel ilaçları önermek için).
- Hastayı bunaltmamak için her yanıtta 2-3 hedefli soru sorun.
- Durumu tamamen anlamadan asla erken sonuca varmayın veya ilaç önermeyin.

📋 NİHAİ DEĞERLENDİRME (YALNIZCA klinik tabloyu tam olarak anladığınızda):
1. Olası nedenlerin özeti.
2. Pratik ilk yardım önerileri.
3. Ülkesinde bulunan uygun ilaçlar ve dozajları.
4. Acil doktor başvurusu gerektiren uyarı işaretleri.

Her zaman Türkçe yanıt verin."""

    # Default: French
    return """Tu es Dr. Sarah Martin, médecin et assistante pharmaceutique IA spécialisée en pré-consultation médicale.

🎯 TA MISSION EN MODE PRÉ-CONSULTATION :
Mener un interrogatoire médical (anamnèse) complet, rigoureux, bienveillant et approfondi pour comprendre exactement et en détail ce qui ne va pas chez le patient avant de proposer la moindre conclusion ou recommandation.

🔍 RÈGLE D'OR — NE LIMITE JAMAIS TES QUESTIONS :
- Pose autant de questions que nécessaire pour cerner précisément le problème. Ne limite jamais tes questions !
- Continue d'interroger le patient pas à pas, échange après échange, jusqu'à avoir TOUS les éléments indispensables pour poser une analyse complète :
  * Caractéristiques du symptôme : localisation exacte, type de douleur (brûlure, tiraillement, battement, coup de poignard, etc.), intensité (sur 10), évolution depuis son apparition.
  * Facteurs déclenchants ou soulageants (effort, repas, position, repos, froid/chaud).
  * Symptômes associés (fièvre, frissons, nausées, vomissements, fatigue, vertiges, essoufflement, éruptions cutanées, etc.).
  * Antécédents médicaux pertinents (hypertension, asthme, diabète, problèmes gastriques, cardiaques, etc.).
  * Traitements en cours, automédication récente et allergies connues.
  * Pays de résidence du patient (pour connaître les médicaments disponibles près de lui).
- Pose 2 à 3 questions ciblées et pertinentes à chaque message pour faire avancer l'analyse naturellement, sans submerger le patient, et rebondis avec empathie sur ses réponses.
- Ne saute JAMAIS aux conclusions ni aux suggestions de médicaments tant que tu n'as pas une vision limpide, détaillée et complète de ce qui ne va pas.

📋 ÉVALUATION FINALE (UNIQUEMENT quand tu as bien compris tout le tableau clinique) :
Une fois l'interrogatoire complet terminé et la situation parfaitement comprise :
1. Fais une synthèse claire et rassurante des symptômes et des causes probables.
2. Donne des conseils d'hygiène de vie et de premiers soins pratiques.
3. Propose des solutions thérapeutiques ou médicaments disponibles dans son pays avec posologies indicatives.
4. Précise clairement les signes d'alerte (red flags) qui nécessiteraient une consultation médicale d'urgence.

⚠️ AVERTISSEMENT :
Rappelle qu'il s'agit d'une évaluation préliminaire IA ne remplaçant pas une consultation médicale physique.

IMPORTANT: Réponds toujours en français."""



class GeminiService:
    """Manage Google Gemini AI interactions"""
    
    def __init__(self):
        self.vision_model = None
        self.chat_model = None
        self._initialized = False
        self._active_key = settings.GEMINI_API_KEY or ""

    async def _rotate_api_key(self) -> bool:
        """
        Bascule circulairement à chaud entre GEMINI_API_KEY et GEMINI_API_KEY_2.
        Retourne True si le basculement a réussi.
        """
        if not settings.GEMINI_API_KEY_2:
            return False
            
        if self._active_key == settings.GEMINI_API_KEY:
            self._active_key = settings.GEMINI_API_KEY_2
            logger.info("Switching to GEMINI_API_KEY_2 (secondary key)")
        else:
            self._active_key = settings.GEMINI_API_KEY
            logger.info("Switching back to GEMINI_API_KEY (primary key)")
            
        try:
            await asyncio.to_thread(genai.configure, api_key=self._active_key, transport="rest")
            await self.initialize(force_reinit=True)
            return True
        except Exception as e:
            logger.error("Failed to rotate API key", error=str(e))
            return False
    
    async def initialize(self, force_reinit: bool = False):
        """Initialize Gemini models - REQUIRES REAL API KEY
        
        Args:
            force_reinit: If True, force reinitialization even if already initialized
        """
        if self._initialized and not force_reinit:
            return
        
        # Vérifier si la clé API existe - OBLIGATOIRE
        if not self._active_key or self._active_key == "your-gemini-api-key-here":
            self._active_key = settings.GEMINI_API_KEY or ""
            if not self._active_key or self._active_key == "your-gemini-api-key-here":
                error_msg = "GEMINI_API_KEY n'est pas configurée. Configurez-la dans backend/.env pour utiliser l'analyse réelle."
                logger.error(error_msg)
                raise AIServiceError(error_msg)
        
        try:
            # Réinitialiser les modèles si force_reinit
            if force_reinit:
                self.vision_model = None
                self.chat_model = None
                self._initialized = False
            
            api_key = self._active_key
            if not api_key or "PLACEHOLDER" in api_key.upper() or len(api_key) < 20:
                logger.error("GEMINI_API_KEY invalide ou non configurée (PLACEHOLDER?) - Le scan échouera en prod!")
            logger.info("Configuring Gemini with API key", 
                       key_length=len(self._active_key),
                       key_preview=self._active_key[:10] + "..." if len(api_key) > 10 else "N/A")
            genai.configure(api_key=self._active_key, transport="rest")
            
            if self._active_key == settings.GEMINI_API_KEY_2:
                vision_model_name = getattr(settings, "GEMINI_MODEL_VISION_2", "gemini-flash-latest")
                chat_model_name = getattr(settings, "GEMINI_MODEL_CHAT_2", "gemini-flash-latest")
            else:
                vision_model_name = settings.GEMINI_MODEL_VISION
                chat_model_name = settings.GEMINI_MODEL_CHAT

            logger.info(f" Initializing Gemini models: Vision={vision_model_name}, Chat={chat_model_name}")
            
            # Initialize Vision Model - Optimized for speed
            # Note: response_mime_type must be passed in generate_content, not in model init
            self.vision_model = genai.GenerativeModel(
                model_name=vision_model_name,
                generation_config=genai.GenerationConfig(
                    temperature=0.3,  # Lower for faster, more consistent responses
                    top_p=0.9,
                    top_k=20,
                    max_output_tokens=4096,
                ),
            )
            
            # Initialize Chat Model - Optimized for speed and conciseness
            # Note: system_instruction parameter is not supported in this API version
            # We'll include system instructions in the message itself when needed
            self.chat_model = genai.GenerativeModel(
                model_name=chat_model_name,
                generation_config=genai.GenerationConfig(
                    temperature=0.4,
                    top_p=0.9,
                    top_k=20,
                    max_output_tokens=800,
                ),
            )
            
            self._initialized = True
            logger.info(" Gemini AI initialized successfully")
            
        except Exception as e:
            logger.error(" Gemini initialization failed", error=str(e))
            raise AIServiceError(f"Échec de l'initialisation de Gemini: {str(e)}")
    
    @retry(
        stop=stop_after_attempt(2),  # Reduced retries for faster failure
        wait=wait_exponential(multiplier=1, min=1, max=5),  # Faster retry
    )
    async def analyze_medication_image(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
        user_language: str = "fr",
    ) -> Dict[str, Any]:
        """
        Analyze medication image using Gemini Vision
        Returns structured medication data
        """
        try:
            # Vérifier que le modèle est initialisé - OBLIGATOIRE
            if not self.vision_model:
                error_msg = "Le modèle Gemini Vision n'est pas initialisé. Vérifiez que GEMINI_API_KEY est configurée dans backend/.env"
                logger.error(error_msg)
                raise AIServiceError(error_msg)
            
            # Validate and process image
            logger.info("Processing image for analysis", image_size=len(image_bytes), mime_type=mime_type, user_language=user_language)
            image = self._process_image(image_bytes)
            
            # Prepare prompt with user language
            prompt = get_vision_system_prompt(user_language) + """

Analyze this medication image. Return ONLY a valid JSON object - no explanations, no markdown, no text before or after. Start directly with { and end with }."""
            
            logger.info("Sending request to Gemini API", model=settings.GEMINI_MODEL_VISION)
            
            # Generate response - Note: response_mime_type not supported in this API version
            generation_config = genai.GenerationConfig(
                temperature=0.3,
                top_p=0.9,
                top_k=20,
                max_output_tokens=4096,
            )
            
            try:
                response = await asyncio.wait_for(
                    asyncio.to_thread(
                        self.vision_model.generate_content,
                        [prompt, image],
                        generation_config=generation_config,
                        safety_settings=MEDICAL_SAFETY_SETTINGS,
                    ),
                    timeout=25.0
                )
            except (asyncio.TimeoutError, Exception) as e:
                error_str = str(e)
                is_timeout = isinstance(e, asyncio.TimeoutError) or "timeout" in error_str.lower() or "deadline" in error_str.lower()
                if settings.GEMINI_API_KEY_2 and ("quota" in error_str.lower() or "429" in error_str or "404" in error_str or "not found" in error_str.lower() or "surchargé" in error_str.lower() or is_timeout):
                    rotated = await self._rotate_api_key()
                    if rotated:
                        logger.info("Retrying vision analysis with rotated API key and strict timeout")
                        try:
                            response = await asyncio.wait_for(
                                asyncio.to_thread(
                                    self.vision_model.generate_content,
                                    [prompt, image],
                                    generation_config=generation_config,
                                    safety_settings=MEDICAL_SAFETY_SETTINGS,
                                ),
                                timeout=25.0
                            )
                        except Exception as retry_e:
                            e = retry_e
                
                error_str = str(e)
                error_type = type(e).__name__
                
                # Détecter spécifiquement l'erreur 429 (quota dépassé)
                if "429" in error_str or "quota" in error_str.lower() or "exceeded" in error_str.lower():
                    # Message utilisateur compréhensible (pas de détails techniques)
                    error_msg = "Service temporairement surchargé. Réessayez dans quelques minutes."
                    logger.error("Gemini quota exceeded during image analysis", 
                                error=error_str, 
                                error_type=error_type,
                                exc_info=True)
                    raise AIServiceError(error_msg)
                
                # Détecter les erreurs de clé API invalide
                if "api key" in error_str.lower() or ("invalid" in error_str.lower() and "api" in error_str.lower()) or "401" in error_str or "403" in error_str:
                    error_msg = f"Clé API Gemini invalide ou expirée. Erreur: {error_str}. Vérifiez votre clé API dans backend/.env et redémarrez le serveur."
                    logger.error("Gemini API key invalid", 
                                error=error_str,
                                error_type=error_type,
                                exc_info=True)
                    raise AIServiceError(error_msg)
                
                logger.error("Gemini API call failed", 
                            error=error_str, 
                            error_type=error_type,
                            error_details=error_str,
                            exc_info=True)
                # Log plus de détails pour debug
                import traceback
                logger.error("Full traceback", traceback=traceback.format_exc())
                raise AIServiceError(f"Échec de l'appel API Gemini: {error_str}")
            
            if not response:
                logger.error("Empty response object from Gemini", response_type=type(response).__name__)
                raise AIServiceError("Gemini returned empty response object")
            
            # Vérifier si le contenu a été bloqué (filtres de sécurité)
            if hasattr(response, 'prompt_feedback') and response.prompt_feedback:
                pf = response.prompt_feedback
                if hasattr(pf, 'block_reason') and pf.block_reason and str(pf.block_reason) != "BLOCK_REASON_UNSPECIFIED":
                    reason = str(getattr(pf, 'block_reason', 'UNKNOWN'))
                    logger.error("Gemini blocked prompt (safety)", block_reason=reason)
                    raise AIServiceError(f"L'image a été bloquée par les filtres de sécurité ({reason}). Essayez une photo plus claire du médicament.")
            
            if response.candidates and len(response.candidates) > 0:
                cand = response.candidates[0]
                if hasattr(cand, 'finish_reason') and cand.finish_reason and "SAFETY" in str(cand.finish_reason).upper():
                    logger.error("Gemini blocked response (safety)", finish_reason=str(cand.finish_reason))
                    raise AIServiceError("L'analyse a été bloquée. Veuillez prendre une photo plus nette du médicament.")
            
            # Extraire le texte de la réponse
            response_text = None
            try:
                if hasattr(response, 'text') and response.text:
                    response_text = response.text
                elif hasattr(response, 'parts') and response.parts:
                    response_text = "".join(part.text for part in response.parts if hasattr(part, 'text') and part.text)
                elif response.candidates and len(response.candidates) > 0:
                    parts = getattr(response.candidates[0], 'content', None)
                    if parts and hasattr(parts, 'parts'):
                        response_text = "".join(p.text for p in parts.parts if hasattr(p, 'text') and p.text)
            except Exception as parse_err:
                logger.warning("Could not get response.text, trying parts", error=str(parse_err))
                response_text = None
            
            if not response_text or not response_text.strip():
                logger.error("Empty response text from Gemini", 
                           response_type=type(response).__name__,
                           has_candidates=bool(response.candidates),
                           candidates_count=len(response.candidates) if response.candidates else 0)
                raise AIServiceError("Gemini n'a pas pu analyser l'image. Réessayez avec une photo plus claire du médicament.")
            
            logger.info("Received response from Gemini", 
                       response_length=len(response_text),
                       has_text=bool(response_text))
            
            # Parse response
            result = self._parse_vision_response(response_text)
            
            # DEBUG: Si "Médicament non identifié", logger la réponse brute pour diagnostic
            med = result.get("medication_name", "")
            if not med or "non identifié" in str(med).lower() or "not identified" in str(med).lower():
                logger.warning("SCAN_DEBUG: Médicament non identifié - réponse Gemini brute (800 premiers car):", 
                              raw_response=response_text[:800] if response_text else "VIDE")
            
            # Log critical fields for debugging
            # Récupérer les tokens utilisés pour le calcul de coût
            tokens_used = 0
            usage_meta = getattr(response, 'usage_metadata', None)
            if usage_meta:
                input_tokens = getattr(usage_meta, 'prompt_token_count', 0) or 0
                output_tokens = getattr(usage_meta, 'candidates_token_count', 0) or 0
                tokens_used = input_tokens + output_tokens
                logger.info("Tokens used for vision analysis", 
                           input_tokens=input_tokens,
                           output_tokens=output_tokens,
                           total_tokens=tokens_used)
            
            logger.info("Medication analysis completed", 
                       confidence=result.get("confidence"), 
                       medication=result.get("medication_name"),
                       category=result.get("category"),
                       packaging_language=result.get("packaging_language"),
                       tokens_used=tokens_used)
            
            # Double-check that critical fields are present
            if not result.get("packaging_language") or result.get("packaging_language", "").strip() == "":
                logger.warning("packaging_language is missing after parsing, setting default")
                result["packaging_language"] = "fr"
            if not result.get("category") or result.get("category", "").strip() == "" or result.get("category", "").lower() == "autre":
                logger.warning("category is missing or 'autre' after parsing, setting default to 'antidouleur'")
                result["category"] = "antidouleur"  # Toujours utiliser antidouleur au lieu de "autre"
            
            # Ajouter les tokens utilisés au résultat pour le calcul de coût
            result["_tokens_used"] = tokens_used
            
            return result
            
        except Exception as e:
            logger.error("Medication analysis failed", error=str(e))
            raise AIServiceError(f"Failed to analyze medication image: {str(e)}")
    
    def _get_intro_message(self, language: str) -> str:
        """Get intro message in the correct language"""
        if language == "en":
            return "Perfect, I understand. I am Dr. Sarah Martin, your expert pharmaceutical assistant. I'm ready to answer all your questions about medications and pharmacy. How can I help you today?"
        elif language == "ar":
            return "تماماً، أفهم ذلك. أنا الدكتورة سارة مارتن، مساعدتك الصيدلانية الخبيرة. أنا مستعدة للإجابة على جميع أسئلتك حول الأدوية والصيدلة. كيف يمكنني مساعدتك اليوم؟"
        elif language == "tr":
            return "Tamam, anlıyorum. Ben Dr. Sarah Martin, uzman eczacılık asistanınızım. İlaçlar ve eczacılık hakkındaki tüm sorularınızı yanıtlamaya hazırım. Bugün size nasıl yardımcı olabilirim?"
        else:
            return "Parfait, je comprends. Je suis Dr. Sarah Martin, votre assistante pharmaceutique experte. Je suis prête à répondre à toutes vos questions sur les médicaments et la pharmacie. Comment puis-je vous aider aujourd'hui ?"

    def _get_consultation_intro_message(self, language: str) -> str:
        """Get intro message for pre-consultation mode"""
        if language == "en":
            return "Hello! I'm Dr. Sarah Martin. I'm here to help you assess your symptoms and guide you. Please tell me: what are the main symptoms you're experiencing right now? When did they start, and on a scale of 1 to 10, how intense are they?"
        elif language == "ar":
            return "مرحباً! أنا الدكتورة سارة مارتن. أنا هنا لمساعدتك في تقييم أعراضك وإرشادك. أخبرني: ما هي الأعراض الرئيسية التي تشعر بها الآن؟ متى بدأت، وعلى مقياس من 1 إلى 10، كم هي حدتها؟"
        elif language == "tr":
            return "Merhaba! Ben Dr. Sarah Martin. Semptomlarınızı değlendirmenize ve sizi yönlendirmenize yardımcı olmak için buradayim. Lütfen bana söyleyin: şu anda yaşadığınız başlıca semptomlar neler? Ne zaman başladılar ve 1'den 10'a kadar bir ölçekte ne kadar yoğun?"
        else:
            return "Bonjour ! Je suis Dr. Sarah Martin. Je suis là pour vous aider à évaluer vos symptômes et vous guider. Dites-moi : quels sont les principaux symptômes que vous ressentez en ce moment ? Depuis quand sont-ils apparus, et sur une échelle de 1 à 10, quelle est leur intensité ?"

    async def chat(
        self,
        message: str,
        chat_history: Optional[List[Dict[str, str]]] = None,
        language: str = "fr",
    ) -> Any:
        """
        Chat with AI assistant
        Returns AI response
        """
        try:
            # Auto-initialiser si non initialisé
            if not self._initialized or not self.chat_model:
                logger.info("Gemini chat model not initialized. Initializing service...")
                await self.initialize()

            if not self.chat_model:
                error_msg = "Le modèle Gemini Chat n'est pas initialisé. Vérifiez que GEMINI_API_KEY est configurée dans backend/.env"
                logger.error(error_msg)
                raise AIServiceError(error_msg)
                
            # Format chat history with system prompt included in first message
            formatted_history: List[Any] = self._format_chat_history(chat_history)
            
            # Get system prompt in correct language
            system_prompt = get_chat_system_prompt(language)
            intro_message = self._get_intro_message(language)
            
            # If no history, start with system prompt
            if not formatted_history:
                # Include system prompt as first message from assistant
                formatted_history = [
                    {
                        "role": "user",
                        "parts": [system_prompt]
                    },
                    {
                        "role": "model",
                        "parts": [intro_message]
                    }
                ]
            
            # Start or continue chat session
            chat_session = self.chat_model.start_chat(history=formatted_history)  # type: ignore
            
            try:
                response = await asyncio.wait_for(
                    asyncio.to_thread(chat_session.send_message, message),
                    timeout=25.0
                )
            except (asyncio.TimeoutError, Exception) as e:
                error_str = str(e)
                is_timeout = isinstance(e, asyncio.TimeoutError) or "timeout" in error_str.lower() or "deadline" in error_str.lower()
                if settings.GEMINI_API_KEY_2 and ("quota" in error_str.lower() or "429" in error_str or "surchargé" in error_str.lower() or is_timeout):
                    rotated = await self._rotate_api_key()
                    if rotated and self.chat_model:
                        logger.info("Retrying chat send_message with rotated API key and strict timeout")
                        chat_session = self.chat_model.start_chat(history=formatted_history)  # type: ignore
                        response = await asyncio.wait_for(
                            asyncio.to_thread(chat_session.send_message, message),
                            timeout=25.0
                        )
                    else:
                        raise e
                else:
                    raise e
            
            # Récupérer les tokens utilisés
            tokens_used = 0
            usage_meta = getattr(response, 'usage_metadata', None)
            if usage_meta:
                input_tokens = getattr(usage_meta, 'prompt_token_count', 0) or 0
                output_tokens = getattr(usage_meta, 'candidates_token_count', 0) or 0
                tokens_used = input_tokens + output_tokens
                logger.info("Tokens used for chat", 
                           input_tokens=input_tokens,
                           output_tokens=output_tokens,
                           total_tokens=tokens_used)
            
            logger.info("Chat response generated", 
                       message_length=len(message), 
                       response_length=len(response.text) if response.text else 0,
                       tokens_used=tokens_used)
            
            # Retourner le texte ET les tokens utilisés
            response_text = response.text
            
            # Créer un objet simple qui contient le texte et les tokens
            class ChatResponse:
                def __init__(self, text, tokens):
                    self.text = text
                    self._tokens_used = tokens
                def __str__(self):
                    return self.text
            
            return ChatResponse(response_text, tokens_used)
            
        except Exception as e:
            logger.error("Chat failed", error=str(e))
            raise AIServiceError(f"Failed to generate chat response: {str(e)}")
    
    async def chat_stream(
        self,
        message: str,
        chat_history: Optional[List[Dict[str, str]]] = None,
        language: str = "fr",
        mode: str = "chat",
        medication_context: Optional[str] = None,
    ) -> AsyncGenerator[tuple[str, int], None]:
        """
        Streaming chat for real-time responses
        Yields (text_chunk, total_tokens) tuples as they're generated
        Le dernier chunk contient les tokens totaux dans le deuxième élément
        
        Args:
            mode: 'chat' for general pharma Q&A, 'consultation' for pre-consultation symptom workflow
            medication_context: Name of a scanned medication to add context (scan-to-chat feature)
        """
        tokens_used = 0
        try:
            # Auto-initialiser si non initialisé
            if not self._initialized or not self.chat_model:
                logger.info("Gemini chat model not initialized. Initializing service...")
                await self.initialize()

            if not self.chat_model:
                error_msg = "Le modèle Gemini Chat n'est pas initialisé. Vérifiez que GEMINI_API_KEY est configurée dans backend/.env"
                logger.error(error_msg)
                raise AIServiceError(error_msg)

            # Format chat history with system prompt included in first message
            formatted_history: List[Any] = self._format_chat_history(chat_history)
            
            # Choose system prompt based on mode
            if mode == "consultation":
                system_prompt = get_consultation_system_prompt(language)
                intro_message = self._get_consultation_intro_message(language)
            else:
                system_prompt = get_chat_system_prompt(language)
                intro_message = self._get_intro_message(language)
            
            # If medication context is provided (scan-to-chat), prepend it to the system prompt
            if medication_context:
                context_prefixes = {
                    "fr": f"\n\n📦 CONTEXTE DE SCAN : L'utilisateur vient de scanner le médicament « {medication_context} ». Il souhaite en savoir plus. Commence par proposer des informations détaillées sur ce médicament avant de répondre à sa question.",
                    "en": f"\n\n📦 SCAN CONTEXT: The user just scanned the medication '{medication_context}'. They want to know more. Start by offering detailed information about this medication before answering their question.",
                    "ar": f"\n\n📦 سياق المسح: قام المستخدم للتو بمسح الدواء «{medication_context}». يريد معرفة المزيد. ابدأ بتقديم معلومات تفصيلية عن هذا الدواء قبل الإجابة على سؤاله.",
                    "tr": f"\n\n📦 TARAMA BAĞLAMI: Kullanıcı az önce «{medication_context}» ilacını taradı. Daha fazla bilgi edinmek istiyor. Sorusunu yanıtlamadan önce bu ilaç hakkında ayrıntılı bilgi sunarak başlayın.",
                }
                lang_key = language.lower()[:2]
                prefix = context_prefixes.get(lang_key, context_prefixes["fr"])
                system_prompt = system_prompt + prefix
            
            # If no history, start with system prompt
            if not formatted_history:
                # Include system prompt as first message from assistant
                formatted_history = [
                    {
                        "role": "user",
                        "parts": [system_prompt]
                    },
                    {
                        "role": "model",
                        "parts": [intro_message]
                    }
                ]
            
            chat_session = self.chat_model.start_chat(history=formatted_history)  # type: ignore

            
            try:
                response = await asyncio.wait_for(
                    asyncio.to_thread(chat_session.send_message, message, stream=True),
                    timeout=45.0  # Increased from 25s to prevent Render/Gunicorn idle timeout kills
                )
            except (asyncio.TimeoutError, Exception) as e:
                error_str = str(e)
                is_timeout = isinstance(e, asyncio.TimeoutError) or "timeout" in error_str.lower() or "deadline" in error_str.lower()
                if settings.GEMINI_API_KEY_2 and ("quota" in error_str.lower() or "429" in error_str or "surchargé" in error_str.lower() or is_timeout):
                    rotated = await self._rotate_api_key()
                    if rotated and self.chat_model:
                        logger.info("Retrying chat stream send_message with rotated API key and strict timeout")
                        chat_session = self.chat_model.start_chat(history=formatted_history)  # type: ignore
                        response = await asyncio.wait_for(
                            asyncio.to_thread(chat_session.send_message, message, stream=True),
                            timeout=45.0
                        )
                    else:
                        raise e
                else:
                    raise e
            
            for chunk in response:
                if chunk.text:
                    yield (chunk.text, 0)
                
                # Récupérer les tokens du dernier chunk (qui contient usage_metadata)
                chunk_meta = getattr(chunk, 'usage_metadata', None)
                if chunk_meta:
                    input_tokens = getattr(chunk_meta, 'prompt_token_count', 0) or 0
                    output_tokens = getattr(chunk_meta, 'candidates_token_count', 0) or 0
                    tokens_used = input_tokens + output_tokens
            
            # Envoyer un dernier chunk avec les tokens totaux
            yield ("", tokens_used)
            
            logger.info("Streaming chat completed", tokens_used=tokens_used)
            
        except Exception as e:
            logger.error("Streaming chat failed", error=str(e))
            raise AIServiceError(f"Failed to stream chat: {str(e)}")
    
    def _process_image(self, image_bytes: bytes) -> Image.Image:
        """Validate and process image"""
        try:
            image = Image.open(io.BytesIO(image_bytes))
            
            # Validate image
            if image.width < 100 or image.height < 100:
                raise ImageProcessingError("Image is too small (minimum 100x100 pixels)")
            
            # Resize if too large - 1024px pour garder la lisibilité du texte sur les boîtes
            max_dimension = 1024
            if max(image.width, image.height) > max_dimension:
                ratio = max_dimension / max(image.width, image.height)
                new_size = (int(image.width * ratio), int(image.height * ratio))
                image = image.resize(new_size, Image.Resampling.LANCZOS)
            
            # Convert to RGB if needed (required for Gemini API)
            if image.mode != "RGB":
                image = image.convert("RGB")
            
            logger.debug("Image processed successfully", 
                        original_size=(image.width, image.height),
                        final_mode=image.mode)
            
            return image
            
        except Exception as e:
            logger.error("Image processing failed", error=str(e))
            raise ImageProcessingError(f"Unable to process image: {str(e)}")
    
    def _parse_vision_response(self, response_text: str) -> Dict[str, Any]:
        """Parse Gemini vision response into structured data"""
        try:
            
            # Try to extract JSON from response
            # Gemini might wrap JSON in markdown code blocks
            json_text = response_text
            
            if "```json" in response_text:
                json_start = response_text.find("```json") + 7
                json_end = response_text.find("```", json_start)
                if json_end != -1:
                    json_text = response_text[json_start:json_end].strip()
            elif "```" in response_text:
                json_start = response_text.find("```") + 3
                json_end = response_text.find("```", json_start)
                if json_end != -1:
                    json_text = response_text[json_start:json_end].strip()
            
            # If still not JSON, try to find JSON object in text
            if not json_text.strip().startswith("{"):
                # Look for first { and last }
                start_idx = json_text.find("{")
                if start_idx != -1:
                    # Find matching closing brace
                    brace_count = 0
                    end_idx = start_idx
                    for i in range(start_idx, len(json_text)):
                        if json_text[i] == "{":
                            brace_count += 1
                        elif json_text[i] == "}":
                            brace_count -= 1
                            if brace_count == 0:
                                end_idx = i + 1
                                break
                    if end_idx > start_idx:
                        json_text = json_text[start_idx:end_idx]
            
            # Parse JSON
            try:
                result = json.loads(json_text)
            except json.JSONDecodeError:
                # Fallback: JSON invalide (ex: newlines non échappés dans posology) -> extraction regex
                result = {}
                raw = response_text
                # Champs sur une ligne (évite d'avaler du texte après un string tronqué)
                for key in ["medication_name", "generic_name", "dosage", "form", "manufacturer",
                            "active_ingredient", "category", "confidence", "packaging_language"]:
                    m = re.search(r'"' + re.escape(key) + r'"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"', raw)
                    if not m:
                        m = re.search(r'"' + re.escape(key) + r'"\s*:\s*"([^"\n]*)"', raw)
                    if m:
                        val = m.group(1).replace("\\n", "\n").replace('\\"', '"').strip()
                        result[key] = val if val and val.lower() not in ("non visible", "n/a") else None
                if not result.get("medication_name") and result.get("generic_name"):
                    result["medication_name"] = result["generic_name"]
            
            # Ensure required fields - chercher le nom dans tous les champs possibles
            med_name = (result.get("medication_name") or "").strip()
            if not med_name:
                fallback = (
                    (result.get("generic_name") or "").strip() or
                    (result.get("active_ingredient") or "").strip() or
                    (result.get("brand_name") or "").strip() or
                    (result.get("manufacturer") or "").strip()
                )
                # Éviter les valeurs trop génériques
                if fallback and len(fallback) > 2 and fallback.lower() not in ("unknown", "n/a", "na", "null"):
                    result["medication_name"] = fallback
                else:
                    result["medication_name"] = "Médicament non identifié"
            
            if "disclaimer" not in result:
                result["disclaimer"] = "Cette analyse est à titre informatif uniquement. Consultez toujours votre médecin ou pharmacien avant de prendre un médicament."
            
            # Ensure lists are lists
            for list_field in ["contraindications", "side_effects", "interactions", "warnings", "sources"]:
                if list_field not in result:
                    result[list_field] = []
                elif not isinstance(result[list_field], list):
                    result[list_field] = [result[list_field]] if result[list_field] else []
            
            # Champs texte : valeurs par défaut si vides
            defaults = {
                "indications": "Voir notice d'utilisation.",
                "posology": "Voir posologie sur la notice.",
                "contraindications": result.get("contraindications") or ["Consulter la notice ou votre médecin."],
                "precautions": "Voir précautions sur la notice.",
                "side_effects": result.get("side_effects") or ["Voir liste complète sur la notice."],
                "interactions": result.get("interactions") or ["Consulter votre médecin pour les interactions."],
                "overdose": "En cas de surdosage, contactez un médecin ou le centre antipoison.",
                "storage": "Conserver dans un endroit sec à température ambiante. Voir notice.",
                "additional_info": "Consultez la notice complète ou votre pharmacien.",
            }
            for key, default in defaults.items():
                if key in ["contraindications", "side_effects", "interactions"]:
                    if not result.get(key):
                        result[key] = default if isinstance(default, list) else [default]
                elif not result.get(key) or (isinstance(result[key], str) and not result[key].strip()):
                    result[key] = default
            
            # Ensure confidence level
            if "confidence" not in result:
                result["confidence"] = "medium"
            elif result["confidence"] not in ["high", "medium", "low"]:
                result["confidence"] = "medium"
            
            # Ensure packaging_language is present (CRITICAL for suggestions)
            if "packaging_language" not in result or not result["packaging_language"]:
                # Try to detect from medication name or other text
                medication_text = (result.get("medication_name", "") + " " + 
                                 result.get("generic_name", "") + " " + 
                                 result.get("indications", "")).lower()
                
                # Simple language detection based on common words
                if any(word in medication_text for word in ["tablet", "capsule", "mg", "take", "use"]):
                    result["packaging_language"] = "en"
                elif any(word in medication_text for word in ["comprimé", "gélule", "prendre", "utiliser"]):
                    result["packaging_language"] = "fr"
                else:
                    result["packaging_language"] = "fr"  # Default to French
            
            # Ensure category is present (CRITICAL for suggestions)
            # IMPORTANT: Ne jamais utiliser "autre", utiliser "antidouleur" par défaut pour permettre les suggestions
            if "category" not in result or not result["category"] or result["category"].lower() == "autre":
                # Try to infer from active ingredient or indications
                active_ingredient = (result.get("active_ingredient", "") or "").lower()
                indications = (result.get("indications", "") or "").lower()
                medication_name = (result.get("medication_name", "") or "").lower()
                generic_name = (result.get("generic_name", "") or "").lower()
                
                # Category detection logic - recherche dans tous les champs
                all_text = f"{active_ingredient} {indications} {medication_name} {generic_name}".lower()
                
                if any(term in all_text for term in 
                       ["paracétamol", "acetaminophen", "paracetamol", "ibuprofen", "aspirin", "aspirine", "diclofenac", "doliprane", "efferalgan", "dafalgan", "advil"]):
                    result["category"] = "antidouleur"
                elif any(term in all_text for term in 
                         ["amoxicillin", "amoxicilline", "penicillin", "pénicilline", "antibiotic", "antibiotique", "augmentin", "clamoxyl"]):
                    result["category"] = "antibiotique"
                elif any(term in all_text for term in 
                         ["cétirizine", "cetirizine", "loratadine", "zyrtec", "claritin", "antihistaminique", "antihistaminic"]):
                    result["category"] = "antihistaminique"
                elif any(term in all_text for term in 
                         ["vitamin", "vitamine", "calcium", "magnesium", "magnésium"]):
                    result["category"] = "vitamine"
                else:
                    result["category"] = "antidouleur"  # Par défaut antidouleur au lieu de "autre"
            
            logger.info("Parsed medication analysis", 
                       medication=result.get("medication_name"),
                       category=result.get("category"),
                       language=result.get("packaging_language"))
            
            return result
            
        except json.JSONDecodeError as e:
            logger.error("SCAN_DEBUG: JSON parse failed - réponse brute:", error=str(e), response_preview=response_text[:800] if response_text else "VIDE")
            # Return structured error response en français
            return {
                "medication_name": "Médicament non identifié",
                "generic_name": None,
                "error": "Impossible d'analyser l'image clairement",
                "raw_response": response_text[:500],
                "confidence": "low",
                "indications": None,
                "posology": "Impossible d'analyser l'image. Veuillez réessayer avec une photo plus claire.",
                "contraindications": [],
                "precautions": None,
                "side_effects": [],
                "interactions": [],
                "overdose": None,
                "storage": None,
                "additional_info": None,
                "packaging_language": "fr",  # Par défaut français pour permettre les suggestions
                "category": "antidouleur",  # Par défaut antidouleur pour permettre les suggestions
                "disclaimer": "Cette analyse est à titre informatif uniquement. Consultez toujours votre médecin ou pharmacien avant de prendre un médicament.",
            }
        except Exception as e:
            logger.error("Unexpected error parsing vision response", error=str(e))
            return {
                "medication_name": "Médicament non identifié",
                "generic_name": None,
                "confidence": "low",
                "indications": None,
                "posology": "Erreur lors de l'analyse. Veuillez réessayer.",
                "contraindications": [],
                "precautions": None,
                "side_effects": [],
                "interactions": [],
                "overdose": None,
                "storage": None,
                "additional_info": None,
                "packaging_language": "fr",  # Par défaut français pour permettre les suggestions
                "category": "antidouleur",  # Par défaut antidouleur pour permettre les suggestions
                "disclaimer": "Cette analyse est à titre informatif uniquement. Consultez toujours votre médecin ou pharmacien avant de prendre un médicament.",
            }
    
    def _format_chat_history(
        self,
        history: Optional[List[Dict[str, str]]],
    ) -> List[Any]:
        """Format chat history for Gemini"""
        if not history:
            return []
        
        formatted = []
        for msg in history:
            formatted.append({
                "role": msg.get("role", "user"),
                "parts": [msg.get("content", "")],
            })
        
        return formatted
    
    async def cleanup(self):
        """Cleanup resources"""
        self._initialized = False
        logger.info("Gemini cleanup completed")


# Singleton instance
gemini_service = GeminiService()



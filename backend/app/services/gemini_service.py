"""
Google Gemini AI Service
Vision analysis and conversational AI with medical safety
"""

import google.generativeai as genai
from google.generativeai.types import HarmCategory, HarmBlockThreshold
from typing import Dict, Any, List, Optional, AsyncGenerator
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
  "disclaimer": "This analysis is for informational purposes only. Always consult your doctor or pharmacist."
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
  "disclaimer": "هذا التحليل لأغراض إعلامية فقط. استشر دائماً طبيبك أو الصيدلي."
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
  "disclaimer": "Bu analiz yalnızca bilgilendirme amaçlıdır. Her zaman doktorunuza veya eczacınıza danışın."
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
  "disclaimer": "Cette analyse est à titre informatif uniquement. Consultez toujours votre médecin ou pharmacien."
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
        return """You are Dr. Sarah Martin, an expert and caring AI pharmaceutical assistant.

🎓 YOUR EXPERTISE: Deep knowledge of pharmacy, medications, drug interactions, side effects, storage, and all therapeutic categories.

🌟 YOUR STYLE: Caring, professional, clear, empathetic, and cautious.

📋 RESPONSE STRUCTURE:
1. Warm greeting
2. Complete information
3. Practical advice
4. Warnings if needed
5. Kind conclusion

⚠️ YOUR LIMITS:
- Cannot diagnose or prescribe
- Cannot replace doctors/pharmacists
- Always recommend professional consultation for complex cases

IMPORTANT: Always respond in English."""
    elif language == "ar":
        return """أنت الدكتورة سارة مارتن، مساعدة صيدلانية ذكية خبيرة وعطوفة.

🎓 خبرتك: معرفة عميقة بالصيدلة، الأدوية، التفاعلات الدوائية، الآثار الجانبية، التخزين، وجميع الفئات العلاجية.

🌟 أسلوبك: عطوفة، محترفة، واضحة، متعاطفة، وحذرة.

📋 هيكل الردود:
1. تحية دافئة
2. معلومات كاملة
3. نصائح عملية
4. تحذيرات إذا لزم الأمر
5. خاتمة لطيفة

⚠️ حدودك:
- لا يمكنك التشخيص أو وصف الأدوية
- لا يمكنك استبدال الأطباء/الصيادلة
- دائماً أوصِ باستشارة متخصص للحالات المعقدة

مهم: أجب دائماً باللغة العربية."""
    elif language == "tr":
        return """Siz Dr. Sarah Martin, uzman ve şefkatli bir yapay zeka eczacılık asistanısınız.

🎓 UZMANLIĞINIZ: Eczacılık, ilaçlar, ilaç etkileşimleri, yan etkiler, saklama koşulları ve tüm terapötik kategoriler hakkında derin bilgi.

🌟 TARZINIZ: Şefkatli, profesyonel, açık, empatik ve dikkatli.

📋 YANIT YAPISI:
1. Sıcak karşılama
2. Tam bilgi
3. Pratik tavsiyeler
4. Gerekirse uyarılar
5. Nazik kapanış

⚠️ SINIRLARINIZ:
- Teşhis koyamaz veya reçete yazamazsınız
- Doktorların/eczacıların yerini alamazsınız
- Karmaşık vakalar için her zaman profesyonel danışmanlık önerin

ÖNEMLİ: Her zaman Türkçe olarak yanıt verin."""
    
    return """Tu es Dr. Sarah Martin, une assistante pharmaceutique IA experte et bienveillante avec une connaissance approfondie de la pharmacie, des médicaments et de tout ce qui s'y rapporte.

🎓 TON EXPERTISE COMPLÈTE EN PHARMACIE :

1. **Pharmacologie et Médicaments** :
   - Connaissance approfondie de tous les médicaments (génériques, marques, DCI)
   - Mécanismes d'action, pharmacocinétique, pharmacodynamie
   - Formes pharmaceutiques (comprimés, gélules, sirops, injections, etc.)
   - Dosages, posologies, voies d'administration
   - Indications thérapeutiques et contre-indications

2. **Interactions Médicamenteuses** :
   - Interactions médicamenteuses (médicament-médicament)
   - Interactions avec les aliments et boissons
   - Interactions avec les compléments alimentaires
   - Interactions avec les plantes médicinales
   - Effets sur la grossesse et l'allaitement

3. **Effets Secondaires et Sécurité** :
   - Effets indésirables courants et rares
   - Signes d'alerte nécessitant une consultation
   - Gestion des effets secondaires
   - Allergies et intolérances médicamenteuses
   - Surdosage et toxicité

4. **Conservation et Stabilité** :
   - Conditions de conservation optimales
   - Températures de stockage (frigo, température ambiante)
   - Durée de conservation et péremption
   - Protection contre la lumière, l'humidité
   - Stabilité après ouverture

5. **Catégories Thérapeutiques** :
   - Antibiotiques, antiviraux, antifongiques
   - Antidouleurs, anti-inflammatoires
   - Antihistaminiques, décongestionnants
   - Cardiovasculaires, antihypertenseurs
   - Diabétologie, endocrinologie
   - Neurologie, psychiatrie
   - Et toutes les autres spécialités

6. **Réglementation et Sécurité** :
   - Prescription médicale vs automédication
   - Médicaments remboursables et non remboursables
   - Substitutions pharmaceutiques
   - Délivrance en pharmacie
   - Règles de sécurité sanitaire

7. **Conseils Pratiques** :
   - Comment prendre un médicament correctement
   - Moment optimal de prise (avant/après repas)
   - Gestion des oublis de prise
   - Adaptation pour enfants, personnes âgées
   - Conseils pour une meilleure observance

🌟 TON PERSONNALITÉ ET TON STYLE :

- **Bienveillante et rassurante** : Tu crées une sensation d'apaisement et de confiance
- **Professionnelle et experte** : Tu donnes des informations précises et fiables
- **Claire et accessible** : Tu expliques de manière simple sans jargon excessif
- **Empathique** : Tu comprends les préoccupations des utilisateurs
- **Prudente** : Tu priorises toujours la sécurité et la santé

📋 STRUCTURE DE TES RÉPONSES :

1. **Accueil chaleureux** : Commence par une phrase rassurante
2. **Information principale** : Réponds de manière complète et structurée
3. **Détails pratiques** : Ajoute des conseils concrets et applicables
4. **Mises en garde** : Mentionne les précautions importantes si nécessaire
5. **Conclusion bienveillante** : Termine par une note rassurante

⚠️ TES LIMITES (CRITIQUES) :

- Tu NE PEUX PAS diagnostiquer des conditions médicales
- Tu NE PEUX PAS prescrire des médicaments
- Tu NE PEUX PAS remplacer un médecin ou un pharmacien
- Tu NE PEUX PAS donner de conseils d'urgence médicale
- Tu DOIS toujours recommander de consulter un professionnel pour les cas complexes

💬 EXEMPLES DE RÉPONSES EXEMPLAIRES :

Question : "Puis-je prendre de l'ibuprofène avec du paracétamol ?"
Réponse : "Bonjour ! Oui, il est généralement possible de prendre de l'ibuprofène et du paracétamol ensemble, car ils agissent différemment et ne présentent pas d'interaction problématique. Cependant, il est important de respecter les posologies de chaque médicament et de ne pas dépasser les doses maximales recommandées. Je recommande de consulter votre pharmacien ou médecin pour une posologie adaptée à votre situation. 💊"

Question : "Quels sont les effets secondaires de l'amoxicilline ?"
Réponse : "L'amoxicilline est un antibiotique généralement bien toléré. Les effets secondaires les plus courants peuvent inclure des troubles digestifs légers (nausées, diarrhée), des réactions cutanées, ou des candidoses. Si vous observez des signes d'allergie (éruption cutanée, démangeaisons) ou des effets sévères, consultez immédiatement un professionnel de santé. N'hésitez pas si vous avez d'autres questions ! ⚕️"

🎯 OBJECTIF : Créer une expérience apaisante, informative et professionnelle qui rassure l'utilisateur tout en lui donnant des informations précises et complètes sur la pharmacie et les médicaments.

IMPORTANT: Réponds toujours en français."""

CHAT_SYSTEM_PROMPT = get_chat_system_prompt("fr")  # Default for backward compatibility


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
            
            logger.info(f" Initializing Gemini models: Vision={settings.GEMINI_MODEL_VISION}, Chat={settings.GEMINI_MODEL_CHAT}")
            
            # Initialize Vision Model - Optimized for speed
            # Note: response_mime_type must be passed in generate_content, not in model init
            self.vision_model = genai.GenerativeModel(
                model_name=settings.GEMINI_MODEL_VISION,
                generation_config={
                    "temperature": 0.3,  # Lower for faster, more consistent responses
                    "top_p": 0.9,
                    "top_k": 20,
                    "max_output_tokens": 4096,
                },
            )
            
            # Initialize Chat Model
            # Note: system_instruction parameter is not supported in this API version
            # We'll include system instructions in the message itself when needed
            self.chat_model = genai.GenerativeModel(
                model_name=settings.GEMINI_MODEL_CHAT,
                generation_config={
                    "temperature": settings.GEMINI_TEMPERATURE,
                    "top_p": 0.95,
                    "top_k": 40,
                    "max_output_tokens": settings.GEMINI_MAX_TOKENS,
                },
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
            generation_config = {
                "temperature": 0.3,
                "top_p": 0.9,
                "top_k": 20,
                "max_output_tokens": 4096,
            }
            
            try:
                response = await asyncio.to_thread(
                    self.vision_model.generate_content,
                    [prompt, image],
                    generation_config=generation_config,
                    safety_settings=MEDICAL_SAFETY_SETTINGS,
                    request_options={"timeout": 25.0}
                )
            except Exception as e:
                error_str = str(e)
                if settings.GEMINI_API_KEY_2 and ("quota" in error_str.lower() or "429" in error_str or "surchargé" in error_str.lower() or "timeout" in error_str.lower()):
                    rotated = await self._rotate_api_key()
                    if rotated:
                        logger.info("Retrying vision analysis with rotated API key and strict timeout")
                        response = await asyncio.to_thread(
                            self.vision_model.generate_content,
                            [prompt, image],
                            generation_config=generation_config,
                            safety_settings=MEDICAL_SAFETY_SETTINGS,
                            request_options={"timeout": 25.0}
                        )
                    else:
                        raise
                else:
                    raise
                error_str = str(e)
                error_type = type(e).__name__
                
                # Détecter spécifiquement l'erreur 429 (quota dépassé)
                if "429" in error_str or "quota" in error_str.lower() or "exceeded" in error_str.lower():
                    # Message utilisateur compréhensible (pas de détails techniques)
                    error_msg = "Service temporairement surchargé. Réessayez dans quelques minutes."
                    logger.error("Gemini quota exceeded during image analysis", 
                                error=error_str, 
                                error_type=error_type,
                                retry_delay=retry_delay,
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
            if hasattr(response, 'usage_metadata') and response.usage_metadata:
                input_tokens = getattr(response.usage_metadata, 'prompt_token_count', 0) or 0
                output_tokens = getattr(response.usage_metadata, 'candidates_token_count', 0) or 0
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

    async def chat(
        self,
        message: str,
        chat_history: Optional[List[Dict[str, str]]] = None,
        language: str = "fr",
    ) -> str:
        """
        Chat with AI assistant
        Returns AI response
        """
        try:
            # Format chat history with system prompt included in first message
            formatted_history = self._format_chat_history(chat_history)
            
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
            chat_session = self.chat_model.start_chat(history=formatted_history)
            
            try:
                response = await asyncio.to_thread(chat_session.send_message, message, request_options={"timeout": 25.0})
            except Exception as e:
                error_str = str(e)
                if settings.GEMINI_API_KEY_2 and ("quota" in error_str.lower() or "429" in error_str or "surchargé" in error_str.lower() or "timeout" in error_str.lower()):
                    rotated = await self._rotate_api_key()
                    if rotated:
                        logger.info("Retrying chat send_message with rotated API key and strict timeout")
                        chat_session = self.chat_model.start_chat(history=formatted_history)
                        response = await asyncio.to_thread(chat_session.send_message, message, request_options={"timeout": 25.0})
                    else:
                        raise
                else:
                    raise
            
            # Récupérer les tokens utilisés
            tokens_used = 0
            if hasattr(response, 'usage_metadata') and response.usage_metadata:
                input_tokens = getattr(response.usage_metadata, 'prompt_token_count', 0) or 0
                output_tokens = getattr(response.usage_metadata, 'candidates_token_count', 0) or 0
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
    ) -> AsyncGenerator[tuple[str, int], None]:
        """
        Streaming chat for real-time responses
        Yields (text_chunk, total_tokens) tuples as they're generated
        Le dernier chunk contient les tokens totaux dans le deuxième élément
        """
        tokens_used = 0
        try:
            # Format chat history with system prompt included in first message
            formatted_history = self._format_chat_history(chat_history)
            
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
            
            chat_session = self.chat_model.start_chat(history=formatted_history)
            
            try:
                response = await asyncio.to_thread(chat_session.send_message, message, stream=True, request_options={"timeout": 25.0})
            except Exception as e:
                error_str = str(e)
                if settings.GEMINI_API_KEY_2 and ("quota" in error_str.lower() or "429" in error_str or "surchargé" in error_str.lower() or "timeout" in error_str.lower()):
                    rotated = await self._rotate_api_key()
                    if rotated:
                        logger.info("Retrying chat stream send_message with rotated API key and strict timeout")
                        chat_session = self.chat_model.start_chat(history=formatted_history)
                        response = await asyncio.to_thread(chat_session.send_message, message, stream=True, request_options={"timeout": 25.0})
                    else:
                        raise
                else:
                    raise
            
            for chunk in response:
                if chunk.text:
                    yield (chunk.text, 0)
                
                # Récupérer les tokens du dernier chunk (qui contient usage_metadata)
                if hasattr(chunk, 'usage_metadata') and chunk.usage_metadata:
                    input_tokens = getattr(chunk.usage_metadata, 'prompt_token_count', 0) or 0
                    output_tokens = getattr(chunk.usage_metadata, 'candidates_token_count', 0) or 0
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
            import json
            import re
            
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
            for list_field in ["contraindications", "side_effects", "interactions", "warnings"]:
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
    ) -> List[Dict[str, str]]:
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



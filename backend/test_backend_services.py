import asyncio
import os
import sys
from PIL import Image, ImageDraw
import io

# S'assurer que le répertoire app est dans le chemin d'importation
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.config import settings
from app.services.gemini_service import GeminiService

async def test_backend():
    print("==================================================")
    print("🧪 BACKEND SERVICE VERIFICATION TEST")
    print("==================================================")
    
    # 1. Vérification de la configuration
    print(f"\n1. Configuration loaded:")
    print(f"   - Model Vision: {settings.GEMINI_MODEL_VISION}")
    print(f"   - Model Chat:   {settings.GEMINI_MODEL_CHAT}")
    print(f"   - Key 1 prefix: {settings.GEMINI_API_KEY[:10]}...")
    if settings.GEMINI_API_KEY_2:
        print(f"   - Key 2 prefix: {settings.GEMINI_API_KEY_2[:10]}...")
    else:
        print(f"   - Key 2 prefix: NOT CONFIGURED")

    # 2. Initialisation du service
    print("\n2. Initializing GeminiService...")
    try:
        service = GeminiService()
        await service.initialize()
        print("   ✅ GeminiService initialized successfully!")
    except Exception as e:
        print(f"   ❌ Initialization failed: {e}")
        return

    # 3. Test du service Chat
    print("\n3. Testing Gemini Chat functionality...")
    try:
        response = await service.chat("Bonjour, donne-moi un conseil santé de 5 mots maximum.", language="fr")
        print(f"   ✅ Chat successful! AI Response: '{response}'")
    except Exception as e:
        print(f"   ❌ Chat failed: {e}")

    # 4. Test du service Vision (Scan)
    print("\n4. Testing Gemini Vision (Scan) functionality...")
    try:
        # Création d'une image factice de médicament
        img = Image.new('RGB', (200, 200), color = (73, 109, 137))
        d = ImageDraw.Draw(img)
        d.text((20, 90), "Doliprane 1000mg", fill=(255, 255, 0))
        
        img_bytes_io = io.BytesIO()
        img.save(img_bytes_io, format='JPEG')
        img_bytes = img_bytes_io.getvalue()
        
        print("   Sending mock image to scan service...")
        result = await service.analyze_medication_image(img_bytes, user_language="fr")
        print("   ✅ Vision Scan successful! Parsed JSON result:")
        print(f"      - Medication Name: {result.get('medication_name')}")
        print(f"      - Generic Name:    {result.get('generic_name')}")
        print(f"      - Confidence:      {result.get('confidence')}")
        print(f"      - Category:        {result.get('category')}")
    except Exception as e:
        print(f"   ❌ Vision Scan failed: {e}")

    print("\n==================================================")
    print("🎉 Verification complete!")
    print("==================================================")

if __name__ == "__main__":
    asyncio.run(test_backend())

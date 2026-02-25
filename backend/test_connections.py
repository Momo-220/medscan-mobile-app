"""
Script de diagnostic pour tester les connexions MongoDB et Firebase
"""
import asyncio
import sys
from app.config import settings
from app.db.mongodb import get_db, get_mongo_client
from app.services.firebase_service import firebase_service

async def test_mongodb():
    """Test de connexion MongoDB"""
    print("Test MongoDB...")
    try:
        client = get_mongo_client()
        # Test ping
        client.admin.command('ping')
        print("OK MongoDB: Connexion reussie")
        
        # Test database
        db = get_db()
        collections = db.list_collection_names()
        print(f"OK MongoDB: Base de donnees '{db.name}' accessible")
        print(f"   Collections trouvees: {len(collections)}")
        return True
    except Exception as e:
        print(f"ERREUR MongoDB: Erreur de connexion")
        print(f"   Erreur: {str(e)}")
        print(f"   URI utilisee: {settings.MONGODB_URI[:50]}...")
        print("\nSolutions possibles:")
        print("   1. Verifiez que le mot de passe MongoDB est correct")
        print("   2. Verifiez que l'utilisateur existe dans MongoDB Atlas")
        print("   3. Verifiez que votre IP est autorisee dans MongoDB Atlas")
        print("   4. Verifiez le format de l'URI: mongodb+srv://USER:PASS@cluster.net/DB?appName=APP")
        return False

async def test_firebase():
    """Test d'initialisation Firebase"""
    print("\nTest Firebase...")
    try:
        await firebase_service.initialize()
        if firebase_service.app:
            print("OK Firebase: Initialisation reussie")
            print(f"   Project ID: {settings.FIREBASE_PROJECT_ID}")
            return True
        else:
            print("ATTENTION Firebase: Non initialise (mode developpement sans Firebase)")
            return False
    except Exception as e:
        print(f"ERREUR Firebase: Erreur d'initialisation")
        print(f"   Erreur: {str(e)}")
        print("\nSolutions possibles:")
        print("   1. Verifiez que le fichier firebase-admin-key.json existe")
        print("   2. Verifiez que FIREBASE_CREDENTIALS_PATH pointe vers le bon fichier")
        print("   3. Verifiez que FIREBASE_PROJECT_ID correspond au projet Firebase")
        return False

async def test_firebase_token():
    """Test de vérification de token Firebase"""
    print("\nTest verification token Firebase...")
    if not firebase_service.app:
        print("ATTENTION Firebase non initialise - test ignore")
        return False
    
    # Token de test invalide pour vérifier que l'erreur est bien gérée
    try:
        await firebase_service.verify_token("invalid_token_test")
        print("ERREUR Firebase: Le token invalide a ete accepte (probleme!)")
        return False
    except Exception as e:
        if "not initialized" in str(e).lower() or "not available" in str(e).lower():
            print("ERREUR Firebase: Service non disponible")
            return False
        print("OK Firebase: Rejet correct des tokens invalides")
        return True

async def main():
    print("=" * 60)
    print("DIAGNOSTIC DES CONNEXIONS - AI MediScan")
    print("=" * 60)
    
    mongodb_ok = await test_mongodb()
    firebase_ok = await test_firebase()
    
    if firebase_ok:
        await test_firebase_token()
    
    print("\n" + "=" * 60)
    print("RESUME")
    print("=" * 60)
    print(f"MongoDB:  {'OK' if mongodb_ok else 'ERREUR'}")
    print(f"Firebase: {'OK' if firebase_ok else 'ERREUR'}")
    
    if not mongodb_ok:
        print("\nATTENTION: Le backend ne fonctionnera pas sans MongoDB")
        sys.exit(1)
    
    if not firebase_ok:
        print("\nATTENTION: L'authentification ne fonctionnera pas sans Firebase")
        sys.exit(1)
    
    print("\nTous les services sont operationnels!")

if __name__ == "__main__":
    asyncio.run(main())

"""
Test de connexion MongoDB avec différents formats d'URI
"""
import urllib.parse
from pymongo import MongoClient

# Mot de passe depuis MongoDB Atlas
password = "bEN1Us7qqXC9ql8n"

# Différentes variantes à tester
variants = [
    # Variante 1: Utilisateur simple
    f"mongodb+srv://momoseini4_db_user:{password}@medscan.ivhtltw.mongodb.net/?appName=medscan",
    
    # Variante 2: Utilisateur avec @admin encodé
    f"mongodb+srv://momoseini4_db_user%40admin:{password}@medscan.ivhtltw.mongodb.net/?appName=medscan",
    
    # Variante 3: Mot de passe encodé en URL (au cas où)
    f"mongodb+srv://momoseini4_db_user:{urllib.parse.quote(password)}@medscan.ivhtltw.mongodb.net/?appName=medscan",
    
    # Variante 4: Avec nom de base
    f"mongodb+srv://momoseini4_db_user:{password}@medscan.ivhtltw.mongodb.net/mediscan?appName=medscan",
]

print("=" * 60)
print("TEST DES DIFFERENTS FORMATS D'URI MONGODB")
print("=" * 60)

for i, uri in enumerate(variants, 1):
    print(f"\nTest {i}: {uri[:60]}...")
    try:
        client = MongoClient(uri, serverSelectionTimeoutMS=5000)
        client.admin.command('ping')
        print(f"  SUCCES! Cette URI fonctionne.")
        print(f"  URI complete: {uri}")
        break
    except Exception as e:
        print(f"  ECHEC: {str(e)[:100]}")

print("\n" + "=" * 60)
print("Si aucun test n'a reussi, verifiez:")
print("1. Le mot de passe dans MongoDB Atlas")
print("2. Les permissions de l'utilisateur")
print("3. L'acces IP dans Network Access")
print("=" * 60)

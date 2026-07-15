import firebase_admin
from firebase_admin import credentials, auth, firestore
import re

# Initialisation de Firebase Admin
cred = credentials.Certificate('/Users/mohamed02/Documents/medscan-app-1/backend/serviceAccountKey.json')
firebase_admin.initialize_app(cred)

db = firestore.client()

def generate_username(email, display_name):
    # Génère un nom d'utilisateur à partir du début de l'email ou du display_name
    name_part = ""
    if display_name:
        name_part = display_name
    elif email:
        name_part = email.split('@')[0]
    
    # Nettoie : seulement lettres, chiffres et underscores
    username = re.sub(r'[^a-zA-Z0-9_]', '', name_part)
    
    # Fallback si vide
    if not username:
        username = "user"
        
    return username.lower()

def migrate_users():
    print("Début de la migration des utilisateurs...")
    
    # Récupérer tous les utilisateurs Firebase Auth
    page = auth.list_users()
    users_migrated = 0
    
    while page:
        for user in page.users:
            email = user.email
            uid = user.uid
            display_name = user.display_name
            
            # Déterminer un nom d'utilisateur de base
            base_username = generate_username(email, display_name)
            
            # Gérer l'unicité
            username = base_username
            counter = 1
            
            # Vérifier si déjà mappé pour cet UID
            # On cherche s'il y a déjà un document pour cet UID
            existing_ref = db.collection('usernames').where('uid', '==', uid).limit(1).get()
            if existing_ref:
                print(f"L'utilisateur {email} ({uid}) a déjà un nom d'utilisateur : {existing_ref[0].id}")
                continue
                
            # Boucle pour trouver un username unique libre
            ref = db.collection('usernames').document(username)
            while ref.get().exists:
                username = f"{base_username}_{counter}"
                ref = db.collection('usernames').document(username)
                counter += 1
            
            # Enregistrer le username
            ref.set({
                'uid': uid,
                'email': email,
                'username': username,
                'created_at': firestore.SERVER_TIMESTAMP
            })
            
            print(f"Créé mapping : {username} -> {email} (UID: {uid})")
            users_migrated += 1
            
        page = page.get_next_page()
        
    print(f"Migration terminée ! {users_migrated} utilisateurs migrés.")

if __name__ == '__main__':
    migrate_users()

#!/usr/bin/env python3
"""
Script to broadcast a Push Notification to all MedScan users when a new version is released.
Users are subscribed to the 'updates' topic in PushNotificationService.
"""

import sys
import os
import argparse
from dotenv import load_dotenv

# Load environment
load_dotenv('.env')

import firebase_admin
from firebase_admin import credentials, messaging, firestore

def init_firebase():
    if not firebase_admin._apps:
        cert_path = 'serviceAccountKey.json' if os.path.exists('serviceAccountKey.json') else None
        if cert_path:
            cred = credentials.Certificate(cert_path)
            firebase_admin.initialize_app(cred)
        else:
            firebase_admin.initialize_app()

def broadcast_update(version: str, update_url: str = None, force: bool = False):
    init_firebase()
    
    # 1. Update Firestore config/app_version document
    db = firestore.client()
    doc_ref = db.collection('config').document('app_version')
    update_data = {
        'latestVersion': version,
        'forceUpdate': force,
        'maintenance': False,
    }
    if update_url:
        update_data['updateUrl'] = update_url
    
    doc_ref.set(update_data, merge=True)
    print(f"✅ Firestore 'config/app_version' mis à jour avec la version : {version}")

    # 2. Send Push Notification to all subscribed devices (iOS & Android)
    title = "Mise à jour MedScan disponible ! 🚀"
    body = f"La version {version} est maintenant disponible sur l'App Store et le Google Play Store. Mettez à jour pour profiter des nouveautés !"
    
    msg = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        topic="updates",
        data={
            "type": "app_update",
            "version": version,
        }
    )
    
    response = messaging.send(msg)
    print(f"📣 Notification Push envoyée avec succès à tous les utilisateurs (Topic: 'updates') !")
    print(f"   ID du message Firebase : {response}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Diffuser une notification de mise à jour à tous les utilisateurs.")
    parser.add_argument("--version", type=str, default="2.0.2", help="Numéro de la version (ex: 2.0.2)")
    parser.add_argument("--force", action="store_true", help="Rendre la mise à jour obligatoire (bloquante)")
    parser.add_argument("--url", type=str, default="https://apps.apple.com/app/id6789895804", help="URL App Store")
    args = parser.parse_args()

    broadcast_update(args.version, args.url, args.force)

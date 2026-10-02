#!/usr/bin/env python3
"""
Migration Script: MongoDB GridFS to Cloudflare R2
Migrates all image files from MongoDB GridFS to Cloudflare R2 bucket.
Updates scan_history.image_url to point to Cloudflare R2 CDN without data loss.

Usage:
    # 1. Test with dry-run (simulation without modifying anything):
    python backend/scripts/migrate_gridfs_to_r2.py --dry-run

    # 2. Run real migration:
    python backend/scripts/migrate_gridfs_to_r2.py

    # 3. (Optional) Run with cleanup of GridFS once migration is validated:
    python backend/scripts/migrate_gridfs_to_r2.py --delete-gridfs
"""

import sys
import os
import argparse
from datetime import datetime
import re

# Add backend directory to sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bson import ObjectId
from gridfs import GridFS
import boto3
from botocore.config import Config as BotoConfig

from app.config import settings
from app.db.mongodb import get_db, get_mongo_client


def setup_r2_client():
    """Initialize and verify the Cloudflare R2 S3 client"""
    if not settings.R2_ACCESS_KEY_ID or not settings.R2_SECRET_ACCESS_KEY:
        print("❌ Error: R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY must be set in environment or .env")
        sys.exit(1)

    endpoint = settings.r2_endpoint
    if not endpoint:
        print("❌ Error: Could not determine R2 endpoint URL. Set R2_ENDPOINT_URL or R2_ACCOUNT_ID.")
        sys.exit(1)

    s3 = boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=settings.R2_ACCESS_KEY_ID,
        aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
        region_name="auto",
        config=BotoConfig(
            signature_version="s3v4",
            retries={"max_attempts": 3, "mode": "standard"},
        ),
    )

    # Test bucket access
    bucket = settings.R2_BUCKET_NAME or "medscan-scans"
    try:
        s3.head_bucket(Bucket=bucket)
        print(f"✅ Connected to Cloudflare R2 bucket: '{bucket}'")
    except Exception as e:
        print(f"❌ Failed to access R2 bucket '{bucket}': {e}")
        sys.exit(1)

    return s3, bucket


def extract_gridfs_id(image_url: str) -> str | None:
    """Extract MongoDB ObjectId from an image URL or string"""
    if not image_url:
        return None

    # Pattern: /api/v1/images/<24-char hex>
    match = re.search(r"/api/v1/images/([a-fA-F0-9]{24})", image_url)
    if match:
        return match.group(1)

    # Direct 24-char ObjectId string
    if len(image_url) == 24 and ObjectId.is_valid(image_url):
        return image_url

    return None


def run_migration(dry_run: bool = False, delete_gridfs: bool = False, limit: int | None = None):
    print("=" * 70)
    print("🚀 MEDSCAN: MIGRATION MONGODB GRIDFS ➔ CLOUDFLARE R2")
    print(f"   Mode: {'[SIMULATION / DRY-RUN]' if dry_run else '[PRODUCTION REEL]'}")
    print(f"   Suppression GridFS: {'OUI (suppression post-upload)' if delete_gridfs else 'NON (conservation de secours)'}")
    print("=" * 70)

    # 1. Initialize R2
    s3, bucket = setup_r2_client()
    public_url = (settings.R2_PUBLIC_URL or "").rstrip("/")
    if not public_url:
        print("⚠️ Warning: R2_PUBLIC_URL is not set. URLs will default to https://pub-...r2.dev")

    # 2. Initialize MongoDB
    db = get_db()
    fs = GridFS(db, collection="scan_images")

    scans_coll = db.scan_history
    total_scans = scans_coll.count_documents({"image_url": {"$ne": None, "$nin": ["", None]}})
    print(f"📦 Scans avec image trouvés dans MongoDB : {total_scans}")

    cursor = scans_coll.find({"image_url": {"$ne": None, "$nin": ["", None]}}).sort("created_at", -1)
    if limit:
        cursor = cursor.limit(limit)
        print(f"   (Limité à {limit} scans)")

    stats = {
        "already_r2": 0,
        "migrated": 0,
        "not_in_gridfs": 0,
        "errors": 0,
    }

    scans_to_process = list(cursor)
    print(f"\n🔄 Début du traitement de {len(scans_to_process)} scan(s)...\n")

    for i, scan in enumerate(scans_to_process, 1):
        scan_id = scan.get("scan_id", str(scan.get("_id")))
        user_id = scan.get("user_id", "unknown_user")
        med_name = scan.get("medication_name", "Inconnu")
        image_url = scan.get("image_url", "")

        # Check if already on R2
        if public_url and public_url in image_url or ".r2.dev" in image_url or "r2.cloudflarestorage.com" in image_url:
            stats["already_r2"] += 1
            continue

        file_id_str = extract_gridfs_id(image_url)
        if not file_id_str:
            # URL might be external or already CDN
            stats["already_r2"] += 1
            continue

        try:
            # Check GridFS
            if not ObjectId.is_valid(file_id_str):
                print(f"[{i}/{len(scans_to_process)}] ⚠️ ObjectId invalide: {file_id_str} (scan {scan_id})")
                stats["errors"] += 1
                continue

            obj_id = ObjectId(file_id_str)
            if not fs.exists(obj_id):
                print(f"[{i}/{len(scans_to_process)}] ⚠️ Non trouvé dans GridFS: {file_id_str} ({med_name})")
                stats["not_in_gridfs"] += 1
                continue

            grid_out = fs.get(obj_id)
            data = grid_out.read()
            content_type = grid_out.content_type or "image/jpeg"
            ext = content_type.split("/")[-1].lower()
            if ext == "jpeg":
                ext = "jpg"

            r2_key = f"scans/{user_id}/{scan_id}.{ext}"
            new_r2_url = f"{public_url}/{r2_key}" if public_url else f"https://{bucket}.r2.cloudflarestorage.com/{r2_key}"

            print(f"[{i}/{len(scans_to_process)}] 📤 Migration: {med_name} ({len(data)} octets) ➔ {r2_key}")

            if not dry_run:
                # Upload to R2
                s3.put_object(
                    Bucket=bucket,
                    Key=r2_key,
                    Body=data,
                    ContentType=content_type,
                    CacheControl="public, max-age=31536000, immutable",
                )

                # Verify upload
                s3.head_object(Bucket=bucket, Key=r2_key)

                # Update MongoDB document
                scans_coll.update_one(
                    {"_id": scan["_id"]},
                    {"$set": {
                        "image_url": new_r2_url,
                        "legacy_file_id": file_id_str,
                        "migrated_to_r2_at": datetime.utcnow(),
                    }}
                )

                # Optional: Delete from GridFS
                if delete_gridfs:
                    fs.delete(obj_id)

            stats["migrated"] += 1

        except Exception as e:
            print(f"[{i}/{len(scans_to_process)}] ❌ Erreur sur scan {scan_id}: {e}")
            stats["errors"] += 1

    print("\n" + "=" * 70)
    print("📊 RÉSUMÉ DE LA MIGRATION :")
    print(f"   • Images déjà sur R2 ou CDN : {stats['already_r2']}")
    print(f"   • Images migrées avec succès : {stats['migrated']}")
    print(f"   • Images manquantes GridFS   : {stats['not_in_gridfs']}")
    print(f"   • Erreurs de traitement     : {stats['errors']}")
    print("=" * 70)

    if dry_run:
        print("\n💡 C'était une simulation. Pour appliquer réellement les changements, lance :")
        print("   python backend/scripts/migrate_gridfs_to_r2.py")
    else:
        print("\n✅ Migration terminée avec succès !")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Migrer les images de MongoDB GridFS vers Cloudflare R2")
    parser.add_argument("--dry-run", action="store_true", help="Simuler sans uploader ni modifier la BDD")
    parser.add_argument("--delete-gridfs", action="store_true", help="Supprimer les images de GridFS après upload")
    parser.add_argument("--limit", type=int, default=None, help="Nombre maximal d'images à migrer")

    args = parser.parse_args()
    run_migration(dry_run=args.dry_run, delete_gridfs=args.delete_gridfs, limit=args.limit)

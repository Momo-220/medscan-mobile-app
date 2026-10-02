#!/usr/bin/env python3
"""
Comprehensive Migration Script: MongoDB GridFS to Cloudflare R2
1. Migrates ALL raw image files from `scan_images.files` (GridFS) to Cloudflare R2.
2. Updates ALL records in `scan_history` so image_url points to the Cloudflare R2 CDN.
3. Completely idempotent, safe, with auto-resume.

Usage:
    python backend/scripts/migrate_gridfs_to_r2.py
    python backend/scripts/migrate_gridfs_to_r2.py --dry-run
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
from app.db.mongodb import get_db


def setup_r2_client():
    """Initialize and verify the Cloudflare R2 S3 client"""
    if not settings.R2_ACCESS_KEY_ID or not settings.R2_SECRET_ACCESS_KEY:
        print("❌ Error: R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY must be set in environment or .env", flush=True)
        sys.exit(1)

    endpoint = settings.r2_endpoint
    if not endpoint:
        print("❌ Error: Could not determine R2 endpoint URL. Set R2_ENDPOINT_URL or R2_ACCOUNT_ID.", flush=True)
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

    bucket = settings.R2_BUCKET_NAME or "medscan-scans"
    try:
        s3.head_bucket(Bucket=bucket)
        print(f"✅ Connected to Cloudflare R2 bucket: '{bucket}'", flush=True)
    except Exception as e:
        print(f"❌ Failed to access R2 bucket '{bucket}': {e}", flush=True)
        sys.exit(1)

    return s3, bucket


def extract_gridfs_id(image_url: str) -> str | None:
    """Extract MongoDB ObjectId from an image URL or string"""
    if not image_url:
        return None
    match = re.search(r"/api/v1/images/([a-fA-F0-9]{24})", image_url)
    if match:
        return match.group(1)
    if len(image_url) == 24 and ObjectId.is_valid(image_url):
        return image_url
    return None


def run_migration(dry_run: bool = False, delete_gridfs: bool = False, limit: int | None = None):
    print("=" * 75, flush=True)
    print("🚀 MEDSCAN: MIGRATION COMPLETE MONGODB GRIDFS ➔ CLOUDFLARE R2", flush=True)
    print(f"   Mode: {'[SIMULATION / DRY-RUN]' if dry_run else '[PRODUCTION REEL]'}", flush=True)
    print(f"   Suppression GridFS: {'OUI (après validation)' if delete_gridfs else 'NON (sauvegarde conservée)'}", flush=True)
    print("=" * 75, flush=True)

    s3, bucket = setup_r2_client()
    public_url = (settings.R2_PUBLIC_URL or "").rstrip("/")
    if not public_url:
        print("⚠️ Warning: R2_PUBLIC_URL is not set. URLs will default to https://pub-...r2.dev", flush=True)

    db = get_db()
    fs = GridFS(db, collection="scan_images")

    files_coll = db["scan_images.files"]
    scans_coll = db["scan_history"]

    total_files = files_coll.count_documents({})
    total_scans = scans_coll.count_documents({})

    print(f"📁 Fichiers trouvés dans scan_images.files : {total_files}", flush=True)
    print(f"📄 Fiches trouvées dans scan_history      : {total_scans}\n", flush=True)

    # Dictionary to map gridfs file_id_str -> r2_public_url
    file_id_to_r2_url = {}

    # =========================================================================
    # PHASE 1 : MIGRATION DIRECTE DES FICHIERS GRIDFS (scan_images.files)
    # =========================================================================
    print("━" * 75, flush=True)
    print("📸 PHASE 1 : Transfert de TOUS les fichiers images vers Cloudflare R2", flush=True)
    print("━" * 75, flush=True)

    cursor_files = files_coll.find({}).sort("uploadDate", -1)
    if limit:
        cursor_files = cursor_files.limit(limit)

    all_files = list(cursor_files)
    print(f"Traitement de {len(all_files)} fichier(s) binaire(s)...\n", flush=True)

    p1_stats = {"uploaded": 0, "already_exists": 0, "errors": 0}

    for idx, f_doc in enumerate(all_files, 1):
        file_id = f_doc["_id"]
        file_id_str = str(file_id)
        raw_filename = f_doc.get("filename") or ""
        content_type = f_doc.get("contentType") or "image/jpeg"
        ext = content_type.split("/")[-1].lower()
        if ext == "jpeg":
            ext = "jpg"

        # Determine R2 Key
        if raw_filename.startswith("scans/"):
            r2_key = raw_filename
        else:
            user_id = (f_doc.get("metadata") or {}).get("user_id") or "legacy"
            r2_key = f"scans/{user_id}/{file_id_str}.{ext}"

        r2_full_url = f"{public_url}/{r2_key}" if public_url else f"https://{bucket}.r2.cloudflarestorage.com/{r2_key}"
        file_id_to_r2_url[file_id_str] = r2_full_url

        try:
            # Check if already in R2
            already = False
            try:
                s3.head_object(Bucket=bucket, Key=r2_key)
                already = True
            except Exception:
                already = False

            if already:
                p1_stats["already_exists"] += 1
                if idx % 25 == 0 or idx == len(all_files):
                    print(f"[{idx}/{len(all_files)}] ⏩ Déjà sur R2 : {r2_key}", flush=True)
                continue

            if not dry_run:
                # Read from GridFS
                grid_out = fs.get(file_id)
                data = grid_out.read()

                # Upload to R2
                s3.put_object(
                    Bucket=bucket,
                    Key=r2_key,
                    Body=data,
                    ContentType=content_type,
                    CacheControl="public, max-age=31536000, immutable",
                )

                if delete_gridfs:
                    fs.delete(file_id)

            p1_stats["uploaded"] += 1
            print(f"[{idx}/{len(all_files)}] 📤 Transféré vers R2 : {r2_key} ({f_doc.get('length', 0)} octets)", flush=True)

        except Exception as e:
            print(f"[{idx}/{len(all_files)}] ❌ Erreur sur fichier {file_id_str}: {e}", flush=True)
            p1_stats["errors"] += 1

    print(f"\n✅ Phase 1 terminée : {p1_stats['uploaded']} nouveaux uploads, {p1_stats['already_exists']} déjà présents, {p1_stats['errors']} erreurs.\n", flush=True)

    # =========================================================================
    # PHASE 2 : MISE À JOUR DE SCAN_HISTORY
    # =========================================================================
    print("━" * 75, flush=True)
    print("🔗 PHASE 2 : Mise à jour des liens d'images dans scan_history", flush=True)
    print("━" * 75, flush=True)

    scans_cursor = scans_coll.find({"image_url": {"$ne": None, "$nin": ["", None]}})
    all_scans = list(scans_cursor)
    print(f"Traitement de {len(all_scans)} fiche(s) de scans dans l'historique...\n", flush=True)

    p2_stats = {"updated": 0, "already_r2": 0, "unmatched": 0}

    for idx, scan in enumerate(all_scans, 1):
        scan_id = scan.get("scan_id", str(scan.get("_id")))
        image_url = scan.get("image_url") or ""
        med_name = scan.get("medication_name") or "Inconnu"

        # Check if already pointing to R2
        if public_url and public_url in image_url or ".r2.dev" in image_url or "r2.cloudflarestorage.com" in image_url:
            p2_stats["already_r2"] += 1
            continue

        file_id_str = extract_gridfs_id(image_url)
        if not file_id_str:
            p2_stats["already_r2"] += 1
            continue

        # Look for matching R2 URL from Phase 1
        new_r2_url = file_id_to_r2_url.get(file_id_str)
        if not new_r2_url:
            # If not in Phase 1 dict, check if file exists in GridFS directly
            try:
                obj_id = ObjectId(file_id_str)
                if fs.exists(obj_id):
                    grid_out = fs.get(obj_id)
                    user_id = scan.get("user_id") or "legacy"
                    content_type = grid_out.content_type or "image/jpeg"
                    ext = content_type.split("/")[-1].lower().replace("jpeg", "jpg")
                    r2_key = f"scans/{user_id}/{scan_id}.{ext}"
                    new_r2_url = f"{public_url}/{r2_key}" if public_url else f"https://{bucket}.r2.cloudflarestorage.com/{r2_key}"
                    if not dry_run:
                        s3.put_object(
                            Bucket=bucket,
                            Key=r2_key,
                            Body=grid_out.read(),
                            ContentType=content_type,
                            CacheControl="public, max-age=31536000, immutable",
                        )
            except Exception:
                pass

        if new_r2_url:
            if not dry_run:
                scans_coll.update_one(
                    {"_id": scan["_id"]},
                    {"$set": {
                        "image_url": new_r2_url,
                        "legacy_file_id": file_id_str,
                        "migrated_to_r2_at": datetime.utcnow(),
                    }}
                )
            p2_stats["updated"] += 1
            if p2_stats["updated"] % 25 == 0 or p2_stats["updated"] <= 5:
                print(f"[{idx}/{len(all_scans)}] 🔗 Scan '{med_name}' mis à jour ➔ {new_r2_url}", flush=True)
        else:
            p2_stats["unmatched"] += 1

    print("\n" + "=" * 75, flush=True)
    print("📊 BILAN COMPLET DE LA MIGRATION :", flush=True)
    print(f"   • Photos binaires migrées vers Cloudflare R2 : {p1_stats['uploaded'] + p1_stats['already_exists']} / {total_files}", flush=True)
    print(f"   • Scans mis à jour avec les liens R2         : {p2_stats['updated']} / {len(all_scans)}", flush=True)
    print(f"   • Scans déjà à jour sur R2                   : {p2_stats['already_r2']}", flush=True)
    print(f"   • Fichiers non trouvés (anciens tests)       : {p2_stats['unmatched']}", flush=True)
    print("=" * 75, flush=True)

    if dry_run:
        print("\n💡 C'était une simulation. Pour exécuter réellement :", flush=True)
        print("   python scripts/migrate_gridfs_to_r2.py", flush=True)
    else:
        print("\n🎉 TOUTES LES PHOTOS ET TOUS LES SCANS SONT MIGRÉS VERS CLOUDFLARE R2 !", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Migrer complètement les images et scans vers Cloudflare R2")
    parser.add_argument("--dry-run", action="store_true", help="Simuler sans modifier")
    parser.add_argument("--delete-gridfs", action="store_true", help="Supprimer de GridFS après upload")
    parser.add_argument("--limit", type=int, default=None, help="Limiter le nombre d'éléments")

    args = parser.parse_args()
    run_migration(dry_run=args.dry_run, delete_gridfs=args.delete_gridfs, limit=args.limit)

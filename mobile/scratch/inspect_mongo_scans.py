import pymongo
from bson import ObjectId

client = pymongo.MongoClient("mongodb://localhost:27017/")
db = client["mediscan"]
coll = db["scan_history"]

print(f"Total scans in mediscan.scan_history: {coll.count_documents({})}")
print("\n--- Latest 10 Scans ---")
cursor = coll.find().sort("created_at", -1).limit(10)
for doc in cursor:
    print(f"User: {doc.get('user_id')}, Medication: {doc.get('medication_name')}, Scanned At: {doc.get('created_at') or doc.get('scanned_at')}")

# Also check other databases if they exist
print("\n--- Databases and Collections ---")
for db_name in client.list_database_names():
    print(f"Database: {db_name}")
    for coll_name in client[db_name].list_collection_names():
        print(f"  Collection: {coll_name} ({client[db_name][coll_name].count_documents({})} docs)")

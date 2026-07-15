import csv
import sqlite3
from pathlib import Path

# Définition des chemins
data_dir = Path(__file__).parent / "data"
db_path = data_dir / "medications.db"
presentations_file = data_dir / "CIS_CIP_bdpm.txt"
compositions_file = data_dir / "CIS_COMPO_bdpm.txt"

def build_database():
    print("Construction de la base de données SQLite...")
    
    if not presentations_file.exists():
        print(f"Erreur : Le fichier des présentations n'existe pas : {presentations_file}")
        return
        
    # Connexion à la base de données
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Création des tables
    cursor.execute("DROP TABLE IF EXISTS compositions")
    cursor.execute("DROP TABLE IF EXISTS medications")
    
    cursor.execute("""
    CREATE TABLE medications (
        id TEXT PRIMARY KEY,
        name TEXT,
        form TEXT,
        presentation TEXT,
        category TEXT
    )
    """)
    
    cursor.execute("""
    CREATE TABLE compositions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id TEXT,
        substance TEXT,
        dosage TEXT,
        forme TEXT,
        FOREIGN KEY (medication_id) REFERENCES medications(id)
    )
    """)
    
    # Indexation pour des recherches ultra-rapides
    cursor.execute("CREATE INDEX idx_medications_name ON medications(name)")
    cursor.execute("CREATE INDEX idx_medications_category ON medications(category)")
    cursor.execute("CREATE INDEX idx_compositions_medication_id ON compositions(medication_id)")
    cursor.execute("CREATE INDEX idx_compositions_substance ON compositions(substance)")
    
    conn.commit()
    
    # 1. Charger les compositions
    compositions = {}
    if compositions_file.exists():
        print("Chargement des compositions...")
        with open(compositions_file, 'r', encoding='latin-1') as f:
            reader = csv.reader(f, delimiter='\t')
            for row in reader:
                if len(row) < 6:
                    continue
                cis = row[0]
                forme = row[1]
                substance = row[3]
                dosage = row[4]
                
                if cis not in compositions:
                    compositions[cis] = []
                
                compositions[cis].append((substance, dosage, forme))
    else:
        print("Avertissement : Fichier compositions introuvable.")

    # 2. Déterminer la catégorie thérapeutique
    def determine_category(substance):
        s_lower = substance.lower()
        if any(term in s_lower for term in ['paracétamol', 'paracetamol', 'acetaminophen', 'ibuprofène', 'ibuprofen', 'aspirine', 'aspirin', 'diclofénac', 'diclofenac', 'kétoprofène', 'ketoprofen']):
            return 'antidouleur'
        elif any(term in s_lower for term in ['amoxicilline', 'amoxicillin', 'pénicilline', 'penicillin', 'azithromycine', 'azithromycin', 'ciprofloxacine', 'ciprofloxacin', 'ceftriaxone', 'cefixime']):
            return 'antibiotique'
        elif any(term in s_lower for term in ['cétirizine', 'cetirizine', 'loratadine', 'desloratadine', 'chlorphéniramine', 'chlorpheniramine']):
            return 'antihistaminique'
        elif any(term in s_lower for term in ['amlodipine', 'lisinopril', 'losartan', 'valsartan', 'enalapril', 'ramipril']):
            return 'antihypertenseur'
        elif any(term in s_lower for term in ['vitamine', 'vitamin', 'calcium', 'magnésium', 'magnesium', 'fer', 'iron', 'zinc']):
            return 'vitamine'
        elif any(term in s_lower for term in ['metformine', 'metformin', 'insuline', 'insulin', 'glibenclamide', 'gliclazide']):
            return 'antidiabétique'
        return 'autre'

    # 3. Extraire la forme
    def extract_form(presentation):
        p_lower = presentation.lower()
        if 'comprimé' in p_lower:
            return 'comprimé'
        elif 'gélule' in p_lower:
            return 'gélule'
        elif 'solution' in p_lower or 'sirop' in p_lower:
            return 'solution'
        elif 'suspension' in p_lower:
            return 'suspension'
        elif 'pommade' in p_lower or 'crème' in p_lower:
            return 'crème'
        elif 'injection' in p_lower:
            return 'injectable'
        elif 'goutte' in p_lower:
            return 'gouttes'
        return 'autre'

    # 4. Charger et insérer les présentations & compositions
    print("Insertion des données dans SQLite...")
    medications_to_insert = []
    compositions_to_insert = []
    
    with open(presentations_file, 'r', encoding='latin-1') as f:
        reader = csv.reader(f, delimiter='\t')
        for row in reader:
            if len(row) < 3:
                continue
            cis = row[0]
            presentation = row[2]
            
            form = extract_form(presentation)
            comp_list = compositions.get(cis, [])
            substance = comp_list[0][0] if comp_list else "Inconnu"
            category = determine_category(substance)
            
            medications_to_insert.append((cis, substance, form, presentation, category))
            
            for comp in comp_list:
                compositions_to_insert.append((cis, comp[0], comp[1], comp[2]))
                
    # Insertion en masse (très rapide)
    cursor.executemany(
        "INSERT OR IGNORE INTO medications (id, name, form, presentation, category) VALUES (?, ?, ?, ?, ?)",
        medications_to_insert
    )
    cursor.executemany(
        "INSERT INTO compositions (medication_id, substance, dosage, forme) VALUES (?, ?, ?, ?)",
        compositions_to_insert
    )
    
    conn.commit()
    conn.close()
    
    print(f"Base de données construite avec succès à : {db_path}")
    print(f"Total médicaments insérés : {len(medications_to_insert)}")
    print(f"Total lignes compositions : {len(compositions_to_insert)}")

if __name__ == "__main__":
    build_database()

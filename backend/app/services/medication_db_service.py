"""
Service de base de données locale de médicaments
Utilise SQLite pour des performances maximales et une consommation de RAM minimale (0 Mo au démarrage).
"""

import sqlite3
from typing import List, Dict, Any, Optional
from pathlib import Path
import structlog

logger = structlog.get_logger()


class MedicationDBService:
    """Service pour gérer la base de données locale de médicaments avec SQLite"""
    
    def __init__(self):
        self.db_path = Path(__file__).parent.parent.parent / "data" / "medications.db"
        self._loaded = True  # Toujours marqué comme chargé car la DB SQLite est prête sur disque
        
    def load_data(self):
        """Pas besoin de charger les données en mémoire avec SQLite"""
        pass
        
    def _get_connection(self) -> sqlite3.Connection:
        """Retourne une connexion à la base de données SQLite"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row  # Permet d'accéder aux colonnes par leur nom
        return conn

    def _get_indications_from_category(self, category: str, name: str) -> str:
        """Génère les indications thérapeutiques basées sur la catégorie et le nom"""
        name_lower = name.lower()
        
        if category == 'antidouleur':
            if 'paracétamol' in name_lower or 'paracetamol' in name_lower:
                return "Traitement des douleurs légères à modérées et/ou des états fébriles"
            elif 'ibuprofène' in name_lower or 'ibuprofen' in name_lower:
                return "Traitement des douleurs, fièvre et inflammations (anti-inflammatoire)"
            elif 'aspirine' in name_lower or 'aspirin' in name_lower:
                return "Traitement des douleurs, fièvre et prévention cardiovasculaire"
            elif 'kétoprofène' in name_lower or 'ketoprofen' in name_lower:
                return "Traitement des douleurs et inflammations articulaires et musculaires"
            elif 'diclofénac' in name_lower or 'diclofenac' in name_lower:
                return "Traitement des douleurs et inflammations rhumatismales"
            else:
                return "Traitement symptomatique de la douleur et/ou de la fièvre"
        
        elif category == 'antibiotique':
            if 'amoxicilline' in name_lower or 'amoxicillin' in name_lower:
                return "Traitement des infections bactériennes (ORL, respiratoires, urinaires)"
            elif 'azithromycine' in name_lower or 'azithromycin' in name_lower:
                return "Traitement des infections respiratoires et ORL"
            elif 'ciprofloxacine' in name_lower or 'ciprofloxacin' in name_lower:
                return "Traitement des infections urinaires et digestives"
            else:
                return "Traitement des infections bactériennes"
        
        elif category == 'antihistaminique':
            if 'cétirizine' in name_lower or 'cetirizine' in name_lower:
                return "Traitement des allergies, rhinite allergique et urticaire"
            elif 'loratadine' in name_lower:
                return "Traitement symptomatique de la rhinite allergique et de l'urticaire"
            elif 'desloratadine' in name_lower:
                return "Traitement des symptômes allergiques (rhinite, urticaire)"
            else:
                return "Traitement des manifestations allergiques"
        
        elif category == 'antihypertenseur':
            return "Traitement de l'hypertension artérielle"
        
        elif category == 'antidiabétique':
            if 'metformine' in name_lower or 'metformin' in name_lower:
                return "Traitement du diabète de type 2"
            elif 'insuline' in name_lower or 'insulin' in name_lower:
                return "Traitement du diabète (contrôle de la glycémie)"
            else:
                return "Traitement du diabète"
        
        elif category == 'vitamine':
            if 'calcium' in name_lower:
                return "Supplément en calcium pour la santé osseuse"
            elif 'fer' in name_lower or 'iron' in name_lower:
                return "Traitement et prévention des carences en fer"
            elif 'vitamine d' in name_lower or 'vitamin d' in name_lower:
                return "Prévention et traitement de la carence en vitamine D"
            else:
                return "Complément vitaminique et minéral"
        
        return f"Médicament de la catégorie {category}"
        
    def _extract_disease_keywords_from_indications(self, indications: str) -> List[str]:
        """Extrait les mots-clés de maladie depuis les indications"""
        keywords = set()
        
        if any(word in indications for word in ['douleur', 'pain', 'mal', 'antalgique', 'analgésique']):
            keywords.update(['douleur', 'fièvre', 'inflammation'])
        if any(word in indications for word in ['fièvre', 'fever', 'fébrile', 'température', 'antipyrétique']):
            keywords.update(['douleur', 'fièvre'])
        if any(word in indications for word in ['infection', 'infectieux', 'bactérie', 'bacterial', 'antibiotique', 'antimicrobien']):
            keywords.update(['infection', 'bactérie'])
        if any(word in indications for word in ['allergie', 'allergy', 'allergique', 'antihistaminique', 'rhinite', 'urticaire']):
            keywords.update(['allergie', 'rhinite', 'urticaire'])
        if any(word in indications for word in ['inflammation', 'inflammatoire', 'inflammatory', 'anti-inflammatoire']):
            keywords.update(['inflammation', 'douleur'])
        if any(word in indications for word in ['toux', 'cough', 'antitussif', 'expectorant']):
            keywords.add('toux')
        if any(word in indications for word in ['diarrhée', 'diarrhee', 'diarrhea', 'gastro', 'intestin']):
            keywords.add('infection')
        if any(word in indications for word in ['diabète', 'diabetes', 'glycémie', 'insuline', 'antidiabétique']):
            keywords.update(['diabète', 'glycémie'])
        if any(word in indications for word in ['hypertension', 'tension', 'pression', 'antihypertenseur']):
            keywords.update(['hypertension', 'tension'])
            
        return list(keywords)

    def get_suggestions(
        self,
        category: str,
        limit: int = 50,
        exclude_name: Optional[str] = None,
        indications: Optional[str] = None,
        active_ingredient: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Récupère des suggestions de médicaments à l'aide de requêtes SQLite optimisées.
        La recherche combine la catégorie, le principe actif et les mots-clés d'indication.
        """
        if not self.db_path.exists():
            logger.warning("Base de données SQLite non trouvée pour les suggestions.")
            return []

        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            # Construction dynamique de la requête SQL
            query_parts = []
            params = []
            
            # 1. Filtre par catégorie
            query_parts.append("m.category = ?")
            params.append(category)
            
            # 2. Recherche par principe actif / substance
            if active_ingredient:
                ingredient_words = active_ingredient.lower().split()
                for word in ingredient_words:
                    if len(word) > 3:
                        query_parts.append("c.substance LIKE ?")
                        params.append(f"%{word}%")
            
            # 3. Mots-clés de maladie basés sur les indications
            if indications:
                disease_keywords = self._extract_disease_keywords_from_indications(indications.lower())
                for kw in disease_keywords:
                    query_parts.append("m.name LIKE ? OR m.presentation LIKE ?")
                    params.extend([f"%{kw}%", f"%{kw}%"])
            
            # Exclusions si fournies
            exclude_clause = ""
            if exclude_name:
                exclude_clause = "AND LOWER(m.name) NOT LIKE ?"
                params.append(f"%{exclude_name.lower()}%")
                
            sql_query = f"""
                SELECT DISTINCT m.id, m.name, m.form, m.presentation, m.category, 
                                c.substance, c.dosage
                FROM medications m
                LEFT JOIN compositions c ON m.id = c.medication_id
                WHERE ({' OR '.join(query_parts)}) {exclude_clause}
                LIMIT ?
            """
            params.append(limit * 2) # On récupère un peu plus pour dédoubler proprement
            
            cursor.execute(sql_query, params)
            rows = cursor.fetchall()
            conn.close()
            
            # Dédoublonnage en Python par nom de substance
            seen_names = set()
            suggestions = []
            
            for row in rows:
                med_name = row['name'].lower()
                if med_name not in seen_names:
                    seen_names.add(med_name)
                    suggestions.append({
                        'id': row['id'],
                        'name': row['name'],
                        'form': row['form'],
                        'category': row['category'],
                        'presentation': row['presentation'][:100],
                        'composition': row['substance'],
                        'dosage': row['dosage'],
                        'description': f"{row['form']} - {row['presentation'][:60]}",
                        'indications': self._get_indications_from_category(row['category'], row['name'])
                    })
                    
            return suggestions[:limit]

        except Exception as e:
            logger.error("Erreur récupération suggestions SQLite", error=str(e))
            return []


# Singleton
medication_db_service = MedicationDBService()

"""
Limite globale quotidienne pour éviter de dépasser le quota Gemini (ex: 20 req/jour en free tier).
Avant chaque appel API, on vérifie si la limite est atteinte.
"""
from datetime import date
from pathlib import Path
import json
import structlog

logger = structlog.get_logger()

# Limite par jour (marge sous les 20 du free tier)
DAILY_LIMIT = 18
DATA_FILE = Path(__file__).resolve().parent.parent.parent / "data" / "gemini_daily_calls.json"


def _load() -> dict:
    """Charge le fichier de comptage."""
    try:
        if DATA_FILE.exists():
            with open(DATA_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
    except Exception as e:
        logger.warning("Could not load gemini quota file", error=str(e))
    return {}


def _save(data: dict) -> None:
    """Sauvegarde le fichier de comptage."""
    try:
        DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(DATA_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        logger.warning("Could not save gemini quota file", error=str(e))


def check_and_increment() -> bool:
    """
    Vérifie si on peut faire un appel, puis incrémente le compteur.
    Retourne True pour laisser les clés API gérer le relais dynamiquement.
    """
    today = date.today().isoformat()
    data = _load()
    count = data.get(today, 0)
    data[today] = count + 1
    _save(data)
    return True

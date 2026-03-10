"""
Credits (Gemmes) Service - MongoDB
"""

import structlog
from typing import Optional
from datetime import datetime, date, time

from app.db.mongodb import get_collection

logger = structlog.get_logger()

COLLECTION = "user_credits"


def _today_datetime() -> datetime:
    """Date du jour en datetime (minuit) pour BSON/MongoDB."""
    return datetime.combine(date.today(), time.min)


class CreditsService:
    DAILY_QUOTA_FULL = 30
    DAILY_QUOTA_TRIAL = 10
    TOKENS_PER_GEM = 1000
    SCAN_COST = 5
    CHAT_COST = 1

    @staticmethod
    def calculate_cost_from_tokens(total_tokens: int) -> int:
        if total_tokens <= 0:
            return 1
        cost = (total_tokens + CreditsService.TOKENS_PER_GEM - 1) // CreditsService.TOKENS_PER_GEM
        return max(1, cost)

    def _get_daily_quota(self, is_anonymous: bool) -> int:
        return self.DAILY_QUOTA_TRIAL if is_anonymous else self.DAILY_QUOTA_FULL
    
    def _can_reset_quota(self, is_anonymous: bool) -> bool:
        """
        Règle produit:
        - Compte inscrit: quota quotidien reset chaque jour.
        - Mode trial (anonyme): pack unique, pas de reset quotidien.
        """
        return not is_anonymous

    def _should_reset_quota(self, doc: dict) -> bool:
        today = date.today()
        qd = doc.get("quota_reset_date")
        if qd is None:
            return True
        if isinstance(qd, datetime):
            qd = qd.date()
        return qd < today

    def get_or_create(self, user_id: str, is_anonymous: bool = False) -> dict:
        coll = get_collection(COLLECTION)
        doc = coll.find_one({"user_id": user_id})
        now = datetime.utcnow()

        if not doc:
            quota = self._get_daily_quota(is_anonymous)
            doc = {
                "user_id": user_id,
                "credits": quota,
                "quota_reset_date": _today_datetime(),
                "updated_at": now,
            }
            coll.insert_one(doc)
            logger.info("New user created with daily quota", user_id=user_id, credits=quota, is_trial=is_anonymous)
            return doc

        if self._can_reset_quota(is_anonymous) and self._should_reset_quota(doc):
            quota = self._get_daily_quota(is_anonymous)
            coll.update_one(
                {"user_id": user_id},
                {"$set": {"credits": quota, "quota_reset_date": _today_datetime(), "updated_at": now}},
            )
            doc["credits"] = quota
            doc["quota_reset_date"] = _today_datetime()
            logger.info("Daily quota reset", user_id=user_id, credits=quota, is_trial=is_anonymous)
        return doc

    def get_credits(self, user_id: str, is_anonymous: bool = False) -> int:
        doc = self.get_or_create(user_id, is_anonymous)
        return doc.get("credits", 0)

    def add_credits(self, user_id: str, amount: int, is_anonymous: bool = False) -> int:
        from fastapi import HTTPException, status

        self.get_or_create(user_id, is_anonymous)
        coll = get_collection(COLLECTION)
        doc = coll.find_one({"user_id": user_id})
        if not doc:
            quota = self._get_daily_quota(is_anonymous)
            new_credits = quota + amount
            coll.insert_one({
                "user_id": user_id,
                "credits": new_credits,
                "quota_reset_date": _today_datetime(),
                "updated_at": datetime.utcnow(),
            })
            logger.info("Credits added", user_id=user_id, amount=amount, total=new_credits)
            return new_credits

        qd = doc.get("quota_reset_date")
        qd_date = qd.date() if isinstance(qd, datetime) else qd
        if doc.get("credits") == 0:
            # Trial: pack unique, pas de reset -> proposer l'inscription.
            if is_anonymous:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Votre essai est terminé. Inscrivez-vous pour recevoir 30 gemmes par jour.",
                )
            # Compte inscrit: quota quotidien épuisé -> revenir demain.
            if qd_date == date.today():
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Votre quota journalier est épuisé. Revenez demain pour obtenir votre nouveau quota de gemmes.",
                )
        if self._can_reset_quota(is_anonymous) and self._should_reset_quota(doc):
            doc["credits"] = self._get_daily_quota(is_anonymous)
            doc["quota_reset_date"] = _today_datetime()
        new_credits = doc["credits"] + amount
        coll.update_one(
            {"user_id": user_id},
            {"$set": {"credits": new_credits, "updated_at": datetime.utcnow()}},
        )
        logger.info("Credits added", user_id=user_id, amount=amount, total=new_credits)
        return new_credits

    def ensure_credits(self, user_id: str, cost: int, estimated_tokens: Optional[int] = None, is_anonymous: bool = False) -> None:
        if estimated_tokens is not None and estimated_tokens > 0:
            cost = self.calculate_cost_from_tokens(estimated_tokens)
        doc = self.get_or_create(user_id, is_anonymous)
        credits = doc.get("credits", 0)
        if credits < cost:
            from fastapi import HTTPException, status
            logger.warning("Insufficient credits", user_id=user_id, credits=credits, required=cost)
            raise HTTPException(
                status_code=status.HTTP_402_PAYMENT_REQUIRED,
                detail=f"Crédits insuffisants. Solde: {credits}, requis: {cost}",
            )

    def consume(self, user_id: str, cost: int, actual_tokens: Optional[int] = None, is_anonymous: bool = False) -> int:
        if actual_tokens is not None and actual_tokens > 0:
            cost = self.calculate_cost_from_tokens(actual_tokens)
            logger.info("Calculating cost from actual tokens", tokens=actual_tokens, cost=cost)

        self.get_or_create(user_id, is_anonymous)
        coll = get_collection(COLLECTION)
        doc = coll.find_one({"user_id": user_id})
        if not doc:
            quota = self._get_daily_quota(is_anonymous)
            coll.insert_one({
                "user_id": user_id,
                "credits": quota,
                "quota_reset_date": _today_datetime(),
                "updated_at": datetime.utcnow(),
            })
            doc = {"credits": quota}

        if self._can_reset_quota(is_anonymous) and self._should_reset_quota(doc):
            doc["credits"] = self._get_daily_quota(is_anonymous)
            coll.update_one(
                {"user_id": user_id},
                {"$set": {"credits": doc["credits"], "quota_reset_date": _today_datetime(), "updated_at": datetime.utcnow()}},
            )

        if doc["credits"] < cost:
            from fastapi import HTTPException, status
            raise HTTPException(
                status_code=status.HTTP_402_PAYMENT_REQUIRED,
                detail=f"Crédits insuffisants. Solde: {doc['credits']}, requis: {cost}",
            )

        new_credits = doc["credits"] - cost
        coll.update_one(
            {"user_id": user_id},
            {"$set": {"credits": new_credits, "updated_at": datetime.utcnow()}},
        )
        logger.info("Credits consumed", user_id=user_id, cost=cost, remaining=new_credits)
        return new_credits


credits_service = CreditsService()

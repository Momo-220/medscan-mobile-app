"""
Medication Models
Structured medical data storage
"""

from typing import Any
from sqlalchemy import Column, String, Text, DateTime, Date, Float, Boolean, JSON, Index, Integer
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime, date
import uuid
import os

from app.models.database import Base

# Use String for SQLite (dev), UUID for PostgreSQL (prod)
_ENV = os.getenv("ENVIRONMENT", "development")

def get_id_type() -> Any:
    """Return appropriate ID type based on environment"""
    if _ENV == "production":
        return UUID(as_uuid=True)
    return String(36)  # SQLite compatible

def get_id_default():
    """Return appropriate ID default based on environment"""
    if _ENV == "production":
        return uuid.uuid4
    def _generate_id():
        return str(uuid.uuid4())
    return _generate_id


class Medication(Base):
    """Medication master data"""
    
    __tablename__ = "medications"
    
    # Primary Key
    id = Column(get_id_type(), primary_key=True, default=get_id_default())
    
    # Basic Information
    name = Column(String(255), nullable=False, index=True)
    generic_name = Column(String(255), index=True)
    brand_names = Column(JSON)  # Array of brand names
    
    # Classification
    medication_type = Column(String(100))  # tablet, capsule, liquid, etc.
    therapeutic_class = Column(String(255))
    drug_class = Column(String(255))
    
    # Dosage Information
    dosage_forms = Column(JSON)  # Array of available forms
    strengths = Column(JSON)  # Array of available strengths
    
    # Usage
    indications = Column(Text)  # What it's used for
    usage_instructions = Column(Text)
    dosage_guidelines = Column(JSON)
    
    # Safety
    contraindications = Column(JSON)  # Array of contraindications
    warnings = Column(JSON)  # Array of warnings
    side_effects = Column(JSON)  # Array of side effects
    interactions = Column(JSON)  # Array of drug interactions
    
    # Additional Info
    manufacturer = Column(String(255))
    storage_conditions = Column(Text)
    
    # Metadata
    data_source = Column(String(100))  # Where data came from
    confidence_score = Column(Float)  # AI confidence
    verified = Column(Boolean, default=False)  # Human verified
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Indexes for performance
    __table_args__ = (
        Index('idx_medication_name', 'name'),
        Index('idx_medication_generic', 'generic_name'),
        Index('idx_medication_class', 'drug_class'),
    )
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            "id": str(self.id),
            "name": self.name,
            "generic_name": self.generic_name,
            "brand_names": self.brand_names,
            "type": self.medication_type,
            "therapeutic_class": self.therapeutic_class,
            "drug_class": self.drug_class,
            "dosage_forms": self.dosage_forms,
            "strengths": self.strengths,
            "indications": self.indications,
            "usage_instructions": self.usage_instructions,
            "dosage_guidelines": self.dosage_guidelines,
            "contraindications": self.contraindications,
            "warnings": self.warnings,
            "side_effects": self.side_effects,
            "interactions": self.interactions,
            "manufacturer": self.manufacturer,
            "storage_conditions": self.storage_conditions,
            "confidence_score": self.confidence_score,
            "verified": self.verified,
            "created_at": self.created_at.isoformat() if self.created_at is not None else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at is not None else None,
        }


class UserMedication(Base):
    """User's personal medication records"""
    
    __tablename__ = "user_medications"
    
    # Primary Key
    id = Column(get_id_type(), primary_key=True, default=get_id_default())
    
    # User ID (from Firebase)
    user_id = Column(String(128), nullable=False, index=True)
    
    # Medication Reference
    medication_id = Column(get_id_type(), nullable=True)  # Link to Medication table
    medication_name = Column(String(255), nullable=False)  # Denormalized for quick access
    
    # Scan Information
    scan_id = Column(String(128))  # Reference to Firestore scan
    image_url = Column(Text)  # GCS image URL
    
    # Detected Information
    detected_dosage = Column(String(100))
    detected_form = Column(String(100))
    detected_manufacturer = Column(String(255))
    
    # User Notes
    nickname = Column(String(100))  # User's custom name
    purpose = Column(Text)  # Why user is taking it
    prescribing_doctor = Column(String(255))
    notes = Column(Text)
    
    # Schedule & Reminders
    dosage_schedule = Column(JSON)  # When to take it
    reminder_enabled = Column(Boolean, default=False)
    
    # Status
    active = Column(Boolean, default=True)
    start_date = Column(DateTime)
    end_date = Column(DateTime)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Indexes
    __table_args__ = (
        Index('idx_user_medications_user_id', 'user_id'),
        Index('idx_user_medications_active', 'user_id', 'active'),
    )
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            "id": str(self.id),
            "user_id": self.user_id,
            "medication_id": str(self.medication_id) if self.medication_id is not None else None,
            "medication_name": self.medication_name,
            "scan_id": self.scan_id,
            "image_url": self.image_url,
            "detected_dosage": self.detected_dosage,
            "detected_form": self.detected_form,
            "detected_manufacturer": self.detected_manufacturer,
            "nickname": self.nickname,
            "purpose": self.purpose,
            "prescribing_doctor": self.prescribing_doctor,
            "notes": self.notes,
            "dosage_schedule": self.dosage_schedule,
            "reminder_enabled": self.reminder_enabled,
            "active": self.active,
            "start_date": self.start_date.isoformat() if self.start_date is not None else None,
            "end_date": self.end_date.isoformat() if self.end_date is not None else None,
            "created_at": self.created_at.isoformat() if self.created_at is not None else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at is not None else None,
        }


class UserCredits(Base):
    """Track AI credits (gemmes) per user for Gemini usage.
    Quota journalier : se réinitialise chaque jour (quota_reset_date).
    """

    __tablename__ = "user_credits"

    user_id = Column(String(128), primary_key=True, index=True)
    credits = Column(Integer, default=0, nullable=False)
    quota_reset_date = Column(Date, nullable=True)  # Dernière date de reset du quota journalier
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        return {
            "user_id": self.user_id,
            "credits": self.credits,
            "quota_reset_date": self.quota_reset_date.isoformat() if self.quota_reset_date is not None else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at is not None else None,
        }


class ReminderTake(Base):
    """Records when a reminder dose was taken - for adherence tracking"""
    
    __tablename__ = "reminder_takes"
    
    id = Column(get_id_type(), primary_key=True, default=get_id_default())
    reminder_id = Column(String(36), nullable=False, index=True)
    user_id = Column(String(128), nullable=False, index=True)
    taken_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    
    __table_args__ = (
        Index('idx_reminder_takes_user_date', 'user_id', 'taken_at'),
    )


class Reminder(Base):
    """Medication reminders - persisted in database"""
    
    __tablename__ = "reminders"
    
    id = Column(get_id_type(), primary_key=True, default=get_id_default())
    user_id = Column(String(128), nullable=False, index=True)
    
    medication_name = Column(String(255), nullable=False)
    dosage = Column(String(100), nullable=False)
    time = Column(String(5), nullable=False)  # HH:MM
    frequency = Column(String(20), nullable=False)  # daily, twice, three-times, custom
    days = Column(JSON, nullable=True)  # [0-6] pour custom
    notes = Column(Text, nullable=True)
    active = Column(Boolean, default=True, nullable=False)
    
    next_dose = Column(DateTime, nullable=False)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    __table_args__ = (
        Index('idx_reminders_user_id', 'user_id'),
        Index('idx_reminders_active', 'user_id', 'active'),
    )
    
    def to_dict(self):
        return {
            "id": str(self.id),
            "user_id": self.user_id,
            "medication_name": self.medication_name,
            "dosage": self.dosage,
            "time": self.time,
            "frequency": self.frequency,
            "days": self.days,
            "notes": self.notes,
            "active": self.active,
            "next_dose": self.next_dose.isoformat() if self.next_dose is not None else None,
            "created_at": self.created_at.isoformat() if self.created_at is not None else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at is not None else None,
        }


class ScanHistory(Base):
    """User's medication scan history - replaces Firestore"""
    
    __tablename__ = "scan_history"
    
    # Primary Key
    id = Column(get_id_type(), primary_key=True, default=get_id_default())
    
    # User ID (from Firebase)
    user_id = Column(String(128), nullable=False, index=True)
    
    # Scan Information
    scan_id = Column(String(128), unique=True, nullable=False, index=True)  # Unique scan identifier
    
    # Medication Information
    medication_name = Column(String(255), nullable=False)
    generic_name = Column(String(255))
    dosage = Column(String(100))
    form = Column(String(100))
    manufacturer = Column(String(255))
    
    # AI Analysis Results
    confidence = Column(String(50), default="low")  # high, medium, low
    analysis_data = Column(JSON)  # Full AI analysis JSON
    
    # Safety Information
    warnings = Column(JSON)  # Array of warnings
    contraindications = Column(JSON)  # Array of contraindications
    interactions = Column(JSON)  # Array of interactions
    side_effects = Column(JSON)  # Array of side effects
    
    # Image
    image_url = Column(Text)  # GCS image URL
    
    # Additional Info
    packaging_language = Column(String(10))  # fr, en, ar, tr, etc.
    category = Column(String(100))  # antidouleur, antibiotique, etc.
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Indexes
    __table_args__ = (
        Index('idx_scan_history_user_id', 'user_id'),
        Index('idx_scan_history_created_at', 'user_id', 'created_at'),
    )
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            "id": str(self.id),
            "user_id": self.user_id,
            "scan_id": self.scan_id,
            "medication_name": self.medication_name,
            "generic_name": self.generic_name,
            "dosage": self.dosage,
            "form": self.form,
            "manufacturer": self.manufacturer,
            "confidence": self.confidence,
            "analysis_data": self.analysis_data,
            "warnings": self.warnings,
            "contraindications": self.contraindications,
            "interactions": self.interactions,
            "side_effects": self.side_effects,
            "image_url": self.image_url,
            "packaging_language": self.packaging_language,
            "category": self.category,
            "created_at": self.created_at.isoformat() if self.created_at is not None else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at is not None else None,
        }


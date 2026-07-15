"""
Pydantic schemas for request/response validation
"""

from pydantic import BaseModel, Field, validator
from typing import Optional, List, Literal, Union
from datetime import datetime


# === SCAN SCHEMAS ===

class ScanResponse(BaseModel):
    """Response schema for medication scan - notice pharmaceutique complète"""
    scan_id: str
    medication_name: str
    generic_name: Optional[str] = None
    brand_name: Optional[str] = None
    dosage: Optional[str] = None
    form: Optional[str] = None
    category: str
    active_ingredient: Optional[str] = None
    excipients: Optional[str] = None
    indications: Optional[str] = None
    contraindications: Optional[str] = None
    side_effects: Optional[str] = None
    dosage_instructions: Optional[str] = None
    posology: Optional[str] = None
    precautions: Optional[str] = None
    interactions: Optional[str] = None
    overdose: Optional[str] = None
    storage: Optional[str] = None
    additional_info: Optional[str] = None
    manufacturer: Optional[str] = None
    lot_number: Optional[str] = None
    expiry_date: Optional[str] = None
    packaging_language: str
    image_url: Optional[str] = None
    confidence: str = "high"
    disclaimer: Optional[str] = None
    warnings: Optional[List[str]] = None
    sources: Optional[List[str]] = None
    analysis_data: Optional[dict] = None
    scanned_at: datetime = Field(default_factory=datetime.utcnow)
    analyzed_at: Optional[str] = None  # ISO string pour le frontend


# === ASSISTANT SCHEMAS ===

class ChatRequest(BaseModel):
    """Request schema for chat messages"""
    message: str = Field(..., min_length=1, max_length=2000)
    include_history: bool = True
    language: str = Field(default="fr", description="Response language (fr/en)")
    
    @validator('message')
    def validate_message(cls, v):
        if not v or not v.strip():
            raise ValueError('Message cannot be empty')
        return v.strip()


class ChatMessage(BaseModel):
    """Schema for a single chat message"""
    role: Literal["user", "assistant"]
    content: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class ChatResponse(BaseModel):
    """Response schema for chat"""
    message: str
    message_id: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class ChatHistoryResponse(BaseModel):
    """Response schema for chat history"""
    messages: List[ChatMessage]
    count: int


# === MEDICATION SCHEMAS ===

class MedicationDetail(BaseModel):
    """Detailed medication information schema"""
    id: str
    medication_name: str
    generic_name: Optional[str] = None
    brand_name: Optional[str] = None
    dosage: Optional[str] = None
    form: Optional[str] = None
    category: str
    active_ingredient: Optional[str] = None
    indications: Optional[str] = None
    contraindications: Optional[str] = None
    side_effects: Optional[str] = None
    dosage_instructions: Optional[str] = None
    precautions: Optional[str] = None
    interactions: Optional[str] = None
    storage: Optional[str] = None
    manufacturer: Optional[str] = None
    image_url: Optional[str] = None


# === SUGGESTIONS SCHEMAS ===

class MedicationSuggestionResponse(BaseModel):
    """Response schema for a single medication suggestion"""
    id: str
    name: str
    generic_name: Optional[str] = None
    brand_name: Optional[str] = None
    category: str
    dosage: Optional[str] = None
    form: Optional[str] = None
    image_url: Optional[str] = None
    manufacturer: Optional[str] = None
    indications: Optional[str] = None
    presentation: Optional[str] = None
    composition: Optional[str] = None
    description: Optional[str] = None


class SuggestionsResponse(BaseModel):
    """Response schema for medication suggestions"""
    suggestions: List[MedicationSuggestionResponse]
    count: int


# === HISTORY SCHEMAS ===

class ScanHistoryItem(BaseModel):
    """Schema for a scan history item - includes full analysis data"""
    id: str
    scan_id: str
    medication_name: str
    generic_name: Optional[str] = None
    dosage: Optional[str] = None
    form: Optional[str] = None
    category: str
    manufacturer: Optional[str] = None
    packaging_language: Optional[str] = None
    image_url: Optional[str] = None
    confidence: Optional[str] = None
    scanned_at: datetime
    # Données d'analyse complètes (JSON)
    analysis_data: Optional[dict] = None
    # Champs individuels - peuvent être string ou liste
    warnings: Optional[Union[List[str], str]] = None
    contraindications: Optional[Union[List[str], str]] = None
    interactions: Optional[Union[List[str], str]] = None
    side_effects: Optional[Union[List[str], str]] = None
    disclaimer: Optional[str] = None


class HistoryResponse(BaseModel):
    """Response schema for scan history"""
    scans: List[ScanHistoryItem]
    count: int
    total: int
    page: int
    per_page: int


# === FEEDBACK SCHEMAS ===

class FeedbackRequest(BaseModel):
    """Request schema for user feedback"""
    scan_id: str
    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = Field(None, max_length=500)
    is_accurate: bool


class FeedbackResponse(BaseModel):
    """Response schema for feedback submission"""
    message: str
    feedback_id: str


# === REMINDERS SCHEMAS ===

class ReminderCreate(BaseModel):
    """Request schema for creating a reminder"""
    medication_name: str = Field(..., min_length=1, max_length=200)
    dosage: str = Field(..., min_length=1, max_length=100)
    time: str = Field(..., pattern=r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$')  # Format HH:MM
    frequency: Literal['daily', 'twice', 'three-times', 'custom']
    days: Optional[List[int]] = Field(None, min_items=1, max_items=7)  # 0-6 (Lun-Dim)
    notes: Optional[str] = Field(None, max_length=500)


class ReminderUpdate(BaseModel):
    """Request schema for updating a reminder"""
    medication_name: Optional[str] = Field(None, min_length=1, max_length=200)
    dosage: Optional[str] = Field(None, min_length=1, max_length=100)
    time: Optional[str] = Field(None, pattern=r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$')
    frequency: Optional[Literal['daily', 'twice', 'three-times', 'custom']] = None
    days: Optional[List[int]] = Field(None, min_items=1, max_items=7)
    notes: Optional[str] = Field(None, max_length=500)
    active: Optional[bool] = None


class ReminderResponse(BaseModel):
    """Response schema for a reminder"""
    id: str
    medication_name: str
    dosage: str
    time: str
    frequency: str
    days: Optional[List[int]] = None
    notes: Optional[str] = None
    active: bool
    next_dose: datetime
    created_at: datetime
    updated_at: datetime


class RemindersListResponse(BaseModel):
    """Response schema for list of reminders"""
    reminders: List[ReminderResponse]
    count: int
    medications_taken_today: int = 0  # Nombre de prises enregistrées aujourd'hui


class ReminderTakeRequest(BaseModel):
    """Request schema for marking a reminder as taken"""
    taken_at: Optional[datetime] = Field(default_factory=datetime.utcnow)
    notes: Optional[str] = Field(None, max_length=200)


class ReminderTakeResponse(BaseModel):
    """Response schema for taking a reminder"""
    message: str
    reminder_id: str
    taken_at: datetime
    next_dose: datetime


# === CREDITS / GEMMES SCHEMAS ===


class CreditsInfo(BaseModel):
    """Current credits for a user"""
    user_id: str
    credits: int


class CreditsResponse(BaseModel):
    """Response with current credits only (for frontend)"""
    credits: int
    next_reset_at: str | None = None  # ISO datetime UTC, prochain renouvellement des gemmes


class CreditsUpdateRequest(BaseModel):
    """Request to add or remove credits (admin or system use)"""
    amount: int = Field(..., gt=0, le=100000, description="Amount of credits to add (must be > 0)")

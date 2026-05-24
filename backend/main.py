from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from typing import Optional
from decimal import Decimal
import uuid

from supabase_client import supabase
from ai_service import ai_service

app = FastAPI(
    title="Financial Literacy for Kids Backend",
    description="FastAPI service controlling wallets, game streaks, and generating AI-driven financial narratives.",
    version="1.0.0"
)

# --- Add CORS Middleware Configuration ---
origins = [
    "https://duitwise.app",
    "https://www.duitwise.app",
    "https://duitwise.vercel.app",  # Your development Vercel deployment link
    "http://localhost:55755",       # Keeping local development unblocked
    "http://localhost:8000",
    "http://localhost:61929/",
    "http://127.0.0.1:8000",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,          # ✅ Allows your production frontend to communicate with Render
    allow_credentials=True,
    allow_methods=["*"],            # Allows all HTTP verbs (GET, POST, PUT, DELETE, etc.)
    allow_headers=["*"],            # Allows all network transmission headers
)

# --- Pydantic Schemas for Validation ---
class WalletUpdate(BaseModel):
    save_delta: Optional[Decimal] = 0.00
    spend_delta: Optional[Decimal] = 0.00
    share_delta: Optional[Decimal] = 0.00

class ProfileStreakUpdate(BaseModel):
    xp_gained: int

class ApprovalPayload(BaseModel):
    child_id: str
    parent_id: str


# --- Root Endpoint ---
@app.get("/")
def read_root():
    return {"status": "running", "msg": "Harimau Wira is ready to teach budgeting!"}


@app.get("/wallet/{profile_id}")
async def get_wallet(profile_id: str):
    """
    Fetch user allocation balances (Save, Spend, Share).
    Validates family role constraints and guarantees a database wallet ledger exists.
    """
    try:
        uuid.UUID(str(profile_id))
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid UUID token format.")

    # 1. Inspect user role properties inside the public profiles schema
    profile_req = supabase.table("profiles").select("role, parent_id, is_approved").eq("id", profile_id).execute()
    
    if profile_req.data:
        profile = profile_req.data[0]
        
        # --- LOCKOUT GATE ENFORCEMENT ---
        # Direct Backend Rejection if an unlinked or unapproved child profile makes an operational fetch call
        if profile["role"] == "child":
            if not profile["parent_id"] or not profile["is_approved"]:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Access Suspended: Child account requires active parent relationship registration and approval."
                )

    # 2. Look up the corresponding wallet ledger allocation entries
    response = supabase.table("wallets").select("*").eq("profile_id", profile_id).execute()
    
    # 3. Safe Fallback Generation: Seed starting row balances only if the wallet table entry is missing
    if not response.data:
        try:
            insert_response = supabase.table("wallets").insert({
                "profile_id": profile_id,
                "save_balance": 0.00,  # Welcome coin gift balance initialization
                "spend_balance": 0.00,
                "share_balance": 0.00
            }).execute()
            
            return insert_response.data[0]
        except Exception as e:
            print(f"Database wallet auto-seeding failed trace: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Wallet records allocation ledger initialization pending."
            )

    return response.data[0]


@app.post("/wallet/{profile_id}/update")
async def update_wallet_balances(profile_id: str, payload: WalletUpdate):
    """Adjusts balances positively or negatively depending on choice outcomes"""
    try:
        uuid.UUID(str(profile_id))
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid UUID token format.")

    # Fetch current state
    current = supabase.table("wallets").select("*").eq("profile_id", profile_id).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Wallet records not found.")
    
    wallet = current.data[0]
    
    # Safely perform precise arithmetic operations using Decimal instances
    new_save = Decimal(str(wallet["save_balance"])) + payload.save_delta
    new_spend = Decimal(str(wallet["spend_balance"])) + payload.spend_delta
    new_share = Decimal(str(wallet["share_balance"])) + payload.share_delta

    # Pass the variables as clean string literals to prevent floating-point pollution
    update_response = supabase.table("wallets").update({
        "save_balance": str(new_save),
        "spend_balance": str(new_spend),
        "share_balance": str(new_share)
    }).eq("profile_id", profile_id).execute()

    return update_response.data[0]


# --- Quest Systems & OpenRouter Integration ---
@app.get("/quests/generate")
async def generate_new_story_quest(level: Optional[int] = 1):
    """Generates an automated, contextual narrative scenario targeting specific mechanics."""
    quest_data = await ai_service.generate_quest(current_level=level)
    
    db_insert = supabase.table("quests").insert({
        "title": quest_data["title"],
        "story": quest_data["story"],
        "choice_a": quest_data["choice_a"],
        "choice_b": quest_data["choice_b"],
        "outcome_a": quest_data["outcome_a"],
        "outcome_b": quest_data["outcome_b"],
        "reward_xp": quest_data["reward_xp"]
    }).execute()
    
    return db_insert.data[0] if db_insert.data else quest_data


@app.post("/profile/{profile_id}/reward")
async def reward_user_progress(profile_id: str, payload: ProfileStreakUpdate):
    """Add XP to profile after successfully making choices or checking missions"""
    try:
        uuid.UUID(str(profile_id))
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid UUID token format.")

    profile_req = supabase.table("profiles").select("*").eq("id", profile_id).execute()
    if not profile_req.data:
        raise HTTPException(status_code=404, detail="User profile not found")
        
    current_profile = profile_req.data[0]
    new_xp = current_profile["xp"] + payload.xp_gained
    
    updated_profile = supabase.table("profiles").update({
        "xp": new_xp
    }).eq("id", profile_id).execute()
    
    return updated_profile.data[0]

@app.get("/profile/{profile_id}/family")
async def get_family_structure(profile_id: str):
    """Fetches full household linkage telemetry metrics depending on account role type"""
    
    # Grab the target profile row parameters
    user_req = supabase.table("profiles").select("id, username, role, parent_id").eq("id", profile_id).execute()
    if not user_req.data:
        raise HTTPException(status_code=404, detail="Profile record not found.")
        
    user = user_req.data[0]
    
    if user["role"] == "parent":
        # If they are a parent, look up all child profile rows linked to this ID
        children = supabase.table("profiles").select("id, username, xp, streak").eq("parent_id", profile_id).execute()
        return {
            "account_role": "parent",
            "profile_details": user,
            "linked_children": children.data
        }
    else:
        # If they are a child, fetch their direct supervisor/parent meta information
        parent_details = {"msg": "Unlinked single account context."}
        if user["parent_id"]:
            parent_req = supabase.table("profiles").select("id, username").eq("id", user["parent_id"]).execute()
            if parent_req.data:
                parent_details = parent_req.data[0]
                
        return {
            "account_role": "child",
            "profile_details": user,
            "linked_parent": parent_details
        }
    
@app.post("/family/approve-child")
async def approve_child_registration(payload: ApprovalPayload):
    """Invoked when the parent clicks 'Approve' inside their dashboard panel"""
    
    # 1. Verify the parent is actually the supervisor for this child account
    child_check = supabase.table("profiles").select("parent_id").eq("id", payload.child_id).execute()
    if not child_check.data or child_check.data[0]["parent_id"] != payload.parent_id:
        raise HTTPException(status_code=403, detail="Unauthorized parent linkage mapping.")

    # 2. Mutate state flag to TRUE, letting the child pass the login barrier
    supabase.table("profiles").update({"is_approved": True}).eq("id", payload.child_id).execute()

    # 3. Securely initialize their starter wallet allocations automatically
    supabase.table("wallets").insert({
        "profile_id": payload.child_id,
        "save_balance": 0.00, # Sign-up reward!
        "spend_balance": 0.00,
        "share_balance": 0.00
    }).execute()

    return {"status": "success", "msg": "Child account activated and wallet ledger initialized!"}
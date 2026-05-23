import os
import json
import httpx
from dotenv import load_dotenv

load_dotenv()

class AIService:
    def __init__(self):
        self.api_key = os.getenv("OPENROUTER_KEY")
        self.url = "https://openrouter.ai/api/v1/chat/completions"
        # You can swap this to 'meta-llama/llama-3-70b-instruct' or 'anthropic/claude-3-haiku'
        self.model = "openai/gpt-oss-120b:free" 

    async def generate_quest(self, current_level: int = 1) -> dict:
        """
        Generates a kid-friendly financial literacy mission via OpenRouter
        """
        # Fallback system if the OpenRouter key is missing or unconfigured
        fallback_quest = {
            "title": "The Bakery Dilemma",
            "story": "Harimau Wira spots a giant strawberry cupcake for RM5, but he promised to save up for his new LEGO kit. What should he do?",
            "choice_a": "Buy the cupcake right now because it looks delicious!",
            "choice_b": "Walk past the bakery and drop the RM5 into his Savings Jar instead.",
            "outcome_a": "The cupcake was tasty, but your LEGO kit feels further away now. (-RM5.00 Spend)",
            "outcome_b": "Amazing choice! You resisted temptation and your LEGO goal gets closer! (+RM5.00 Save)",
            "reward_xp": 50
        }

        if not self.api_key:
            return fallback_quest

        prompt = (
            f"You are a children's financial educator. Generate an interactive financial literacy mission "
            f"targeting 7-12 year olds. The narrator guide is a cute tiger named 'Harimau Wira'. "
            f"The scenario difficulty should match a game level of {current_level}.\n\n"
            f"Return EXCLUSIVELY a valid, raw JSON object matching this structure with no markdown wraps, blockquotes, or extra text:\n"
            f"{{\n"
            f"  \"title\": \"Short Captivating Title\",\n"
            f"  \"story\": \"Story text focusing on a tactical dilemma involving spending, saving, or sharing money.\",\n"
            f"  \"choice_a\": \"First option (immediate gratification/spending path)\",\n"
            f"  \"choice_b\": \"Second option (delayed gratification/saving/budgeting path)\",\n"
            f"  \"outcome_a\": \"Result text explaining the consequence for choice A gently.\",\n"
            f"  \"outcome_b\": \"Result text explaining the consequence for choice B positively.\",\n"
            f"  \"reward_xp\": 50\n"
            f"}}"
        )

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://localhost:3000", 
            "X-Title": "Financial Literacy App For Kids"
        }

        payload = {
            "model": self.model,
            "messages": [
                {
                    "role": "system", 
                    "content": "You are a strict backend API service. You output pure raw JSON only. Never wrap your responses in markdown formatting block conventions like ```json ... ```."
                },
                {
                    "role": "user", 
                    "content": prompt
                }
            ],
            "temperature": 0.7
        }

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(self.url, headers=headers, json=payload, timeout=30.0)
                
                if response.status_code == 200:
                    response_data = response.json()
                    raw_content = response_data['choices'][0]['message']['content'].strip()
                    
                    if raw_content.startswith("```"):
                        raw_content = raw_content.split("```")[1]
                        if raw_content.startswith("json"):
                            raw_content = raw_content[4:]
                    
                    return json.loads(raw_content.strip())
                else:
                    print(f"OpenRouter Error: {response.status_code} - {response.text}")
                    return fallback_quest
                    
        except Exception as e:
            print(f"Failed to communicate with OpenRouter pipeline: {e}")
            return fallback_quest

    # ✅ ADDED METHOD: Appended cleanly inside the python file class structure
    async def analyze_ledger(self, data: dict) -> dict:
        """
        Generates a concise, high-signal financial advice summary directly to the child.
        """
        fallback_insight = {
            "insight": "Fantastic work tracking your ledger this month! Your savings rate is steady. Keep checking your missions list to build continuous habits towards your big goals!"
        }

        if not self.api_key:
            return fallback_insight

        prompt = (
            f"You are a helpful children's financial educator mentor. Analyze this child's financial metrics for the month:\n"
            f"- Current Save Pocket Balance: RM {data.get('saveBalance', 0.0):.2f}\n"
            f"- Current Spend Cash Balance: RM {data.get('spendBalance', 0.0):.2f}\n"
            f"- Total Earned this Month: RM {data.get('totalEarned', 0.0):.2f}\n"
            f"- Total Spent this Month: RM {data.get('totalSpent', 0.0):.2f}\n"
            f"- Active Dream Goal Item: {data.get('activeDream', 'None')}\n\n"
            f"Write a short, motivating, exactly 3-sentence financial advice summary addressed directly to the child. "
            f"Use an encouraging, friendly peer tone. Speak to them about balancing their spend/save metrics or reaching their active dream goal. "
            f"Keep it under 350 characters total. Return EXCLUSIVELY a valid, raw JSON object matching this structure with no markdown wraps, codeblocks, or extra text:\n"
            f"{{\n"
            f"  \"insight\": \"Your 3-sentence summary text here.\"\n"
            f"}}"
        )

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        payload = {
            "model": self.model,
            "messages": [
                {
                    "role": "system", 
                    "content": "You are a strict backend API service that outputs pure raw JSON only. Never wrap your responses in markdown formatting block conventions like ```json."
                },
                {
                    "role": "user", 
                    "content": prompt
                }
            ],
            "temperature": 0.5
        }

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(self.url, headers=headers, json=payload, timeout=30.0)
                
                if response.status_code == 200:
                    response_data = response.json()
                    raw_content = response_data['choices'][0]['message']['content'].strip()
                    
                    if raw_content.startswith("```"):
                        raw_content = raw_content.split("```")[1]
                        if raw_content.startswith("json"):
                            raw_content = raw_content[4:]
                    
                    return json.loads(raw_content.strip())
                else:
                    print(f"OpenRouter Analysis Error: {response.status_code} - {response.text}")
                    return fallback_insight
        except Exception as e:
            print(f"Failed to communicate with OpenRouter analysis pipeline: {e}")
            return fallback_insight

ai_service = AIService()
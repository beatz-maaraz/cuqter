import logging
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import google.generativeai as genai

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Chatbot API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatRequest(BaseModel):
    message: str
    api_key: str
    model: str = "gemini-mini"

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "ok"}

@app.post("/chat")
async def chat(req: ChatRequest):
    """Chat endpoint that processes messages using Google Gemini API"""
    try:
        # Validate API key
        if not req.api_key or not req.api_key.strip():
            logger.warning("Chat request received without API key")
            raise HTTPException(status_code=400, detail="API Key is required")
        
        # Validate message
        if not req.message or not req.message.strip():
            logger.warning("Chat request received with empty message")
            raise HTTPException(status_code=400, detail="Message cannot be empty")
            
        logger.info(f"Processing chat request with model: {req.model}")
        
        # Configure Gemini API
        genai.configure(api_key=req.api_key)
        model = genai.GenerativeModel(req.model)
        
        # Send message and get response
        response = model.generate_content(req.message)

        logger.info("Chat response generated successfully")
        return {"reply": response.text}

    except HTTPException:
        raise
    except Exception as e:
        error_str = str(e)
        logger.error(f"Error processing chat request: {error_str}")
        
        # Handle specific API errors
        if "401" in error_str or "invalid_api_key" in error_str or "API key" in error_str:
            raise HTTPException(status_code=401, detail="Invalid or expired API key. Please check your Gemini API key.")
        elif "429" in error_str or "quota" in error_str.lower():
            raise HTTPException(status_code=429, detail="Rate limit exceeded. Please try again later.")
        elif "404" in error_str or "not found" in error_str.lower():
            raise HTTPException(status_code=400, detail="Model not found. Please check the model name.")
        else:
            raise HTTPException(status_code=500, detail="Internal server error. Please try again later.")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)

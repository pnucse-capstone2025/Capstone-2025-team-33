from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Initialize FastAPI app
app = FastAPI()

# Enable CORS (allow all origins for now)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request body schema
class RecommendationRequest(BaseModel):
    schedule: str
    weather: str

# POST endpoint to recommend outfit
@app.post("/recommend")
async def recommend_outfit(req: RecommendationRequest):
    schedule = req.schedule.lower()
    weather = req.weather.lower()

    # Basic mock logic (you can replace this with OpenAI call later)
    if schedule == "wedding" and weather == "rainy":
        recommendation = "Wear a waterproof formal suit with polished boots and a stylish umbrella."
    elif schedule == "meeting" and weather == "sunny":
        recommendation = "Try a light jacket with jeans and sneakers."
    else:
        recommendation = f"Choose appropriate clothes for a {schedule} during {weather} weather."

    return {"recommendation": recommendation}

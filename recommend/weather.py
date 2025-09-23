import requests
import os

def get_weather_by_city(city_name="Busan"):
    api_key = os.getenv("OPENWEATHER_API_KEY")
    if not api_key:
        raise ValueError("Missing OpenWeatherMap API key in environment variables.")

    url = f"https://api.openweathermap.org/data/2.5/weather?q={city_name}&appid={api_key}&units=metric&lang=kr"

    response = requests.get(url)
    if response.status_code != 200:
        raise Exception(f"Weather API error: {response.status_code} - {response.text}")

    data = response.json()

    return {
        "description": data["weather"][0]["description"],
        "temperature": data["main"]["temp"]
    }

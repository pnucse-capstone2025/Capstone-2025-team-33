import requests
import json
import time
from concurrent.futures import ThreadPoolExecutor, as_completed  # For parallel testing

# API 서버 주소
API_URL = "https://39f17048bb40.ngrok-free.app/recommend_outfit"  # 실제 ngrok URL로 업데이트

# --- 기본 시나리오 (1~6 + 추가 7,8) ---
TEST_SCENARIOS = [
    {
        "name": "시나리오 1: 더운 여름날 데이트 (Beach Trip, Sunny, 32°C, Men)",
        "event": "Beach Trip",
        "temperature": 32.0,
        "condition": "Sunny",
        "gender": "Men",
        "closet": [4404, 5865, 15528, 17198, 59106, 11371, 32768, 1855, 8580, 17199, 11346, 39386, 16508, 14121, 36444, 30233, 24250, 3560]
    },
    {
        "name": "시나리오 2: 쌀쌀한 가을 비즈니스 미팅 (Business Meeting, Cloudy, 15°C, Women)",
        "event": "Business Meeting",
        "temperature": 15.0,
        "condition": "Cloudy",
        "gender": "Women",
        "closet": [27884, 18889, 44672, 27888, 18763, 43522, 32405, 27267, 32404, 18712, 34455, 34069, 23797, 59018,31742]
    },
    {
        "name": "시나리오 3: 캠핑 트립 (Camping Trip, Clear, 30°C, Men)",
        "event": "Camping Trip",
        "temperature": 30.0,
        "condition": "Clear",
        "gender": "Men",
        "closet": [43500, 30748, 33248, 39414, 7505, 5435, 39405, 52023, 56854, 43960, 53761, 39381, 30735, 26138, 51332, 28495, 5599, 11919, 41861, 49495, 45604, 4181, 4524]
    },
    {
        "name": "시나리오 4: 격식 있는 저녁 식사 (Formal Dinner, Clear, 22°C, Women)",
        "event": "Formal Dinner",
        "temperature": 22.0,
        "condition": "Clear",
        "gender": "Women",
        "closet": [3701, 40385, 28697, 28836, 27887, 26365, 44680, 44670, 32641, 7483, 31454, 9785, 27918, 30895, 30924, 50949, 27011, 4980, 39897, 33697, 4101, 4147, 45340, 15492, 35783, 38652]
    },
    {
        "name": "시나리오 5: 가을 산책 (Casual Day Out, Sunny, 18°C, Men)",
        "event": "Casual Day Out",
        "temperature": 18.0,
        "condition": "Sunny",
        "gender": "Men",
        "closet": [19547, 5, 31742, 19327, 18864, 15586, 18863, 19548, 23139, 23539, 14581, 21379, 34204, 12538, 7133, 7890, 22198, 26538, 54543, 19772, 24259, 14497, 35465, 12823, 9211]
    },
    {
        "name": "시나리오 6: 캐주얼 산책 (Casual Day Out, Clear, 15°C, Women)",
        "event": "Casual Day Out",
        "temperature": 15.0,
        "condition": "Clear",
        "gender": "Women",
        "closet": [20233, 14091, 13961, 20347, 15038, 18727, 15036, 11096, 11447, 14092, 7193, 51605, 51602, 7192, 39124, 39125, 13304, 2954, 8499, 17929, 43309, 22462, 3505, 12905, 12902, 13555, 15267, 15269]
    },
    {
        "name": "시나리오 7: 캐주얼 산책 (Casual Day Out, Clear, 20°C, Men)",
        "event": "Casual Day Out",
        "temperature": 20.0,
        "condition": "Clear",
        "gender": "Men",
        "closet": [4404, 5865, 15528, 11371, 17198, 59106, 32768, 1855, 8580, 17199, 11346, 39386, 16508, 14121, 36444, 30233, 24250, 3560]
    },
    {
        "name": "시나리오 8: 오피스 미팅 (Office Meeting, Clear, 10°C, Women)",
        "event": "Office Meeting",
        "temperature": 10.0,
        "condition": "Clear",
        "gender": "Women",
        "closet": [27884, 18889, 27846, 44672, 27888, 18763, 43522, 32405, 27267, 32404, 18712, 34455, 34069, 23797, 59018]
    }
]

# --- 추가 시나리오 (scenario7_data ~ scenario12_data) ---
scenario9_data = {  # Temperature change (Men Casual)
    "closet": [43500, 30748, 33248, 39414, 7505, 5435, 39405, 52023, 56854, 43960,
               53761, 39381, 30735, 26138, 51332, 28495, 5599, 11919, 41861, 49495, 45604, 4181, 4524],
    "event": "Office Meeting", "temperature": 30.0, "condition": "Clear", "gender": "Men"
}

scenario10_data = {  # Temperature change (Women Formal/Smart Casual)
    "closet": [3701, 40385, 28697, 28836, 27887, 26365, 44680, 44670,
               32641, 7483, 31454, 9785, 27918, 30895, 30924, 50949, 27011, 4980, 39897, 33697, 4101, 4147, 45340, 15483, 38652],
    "event": "Office Meeting", "temperature": 30.0, "condition": "Clear", "gender": "Women"
}

scenario11_data = {  # Schedule change (Men Summer)
    "closet": [19547, 19549, 19327, 18864, 15586, 18863, 19548, 23139, 23539,
               14581, 21379, 34204, 12538, 7133, 7136, 7890, 22198, 26538,
               54543, 19772, 24259, 14497, 35465, 12823, 9211],
    "event": "Casual Day Out", "temperature": 28.0, "condition": "Clear", "gender": "Men"
}

scenario12_data = {  # Temperature change (Women Summer)
    "closet": [20233, 14091, 13961, 20347, 15038, 18727, 15036, 11096, 11447,
               14092, 7193, 51605, 51602, 7192, 39124, 39125, 13304, 2954,
               8499, 17929, 43309, 22462, 3505, 12905, 12902, 13555, 15267, 15269],
    "event": "Casual Day Out", "temperature": 13.0, "condition": "Clear", "gender": "Women"
}

scenario13_data = {  # Color check (Men Fall Casual)
    "closet": [19547, 19549, 19327, 18864, 15586, 18863, 19548, 23139, 23539,
               14581, 21379, 34204, 12538, 7133, 7136, 7890, 22198, 26538,
               54543, 19772, 24259, 14497, 35465, 12823, 9211, 22363],
    "event": "Casual Day Out", "temperature": 15.0, "condition": "Clear", "gender": "Men"
}

scenario14_data = {  # Color check (Women Fall Casual)
    "closet": [20233, 14091, 13961, 20347, 15038, 18727, 15036, 11096, 11447,
               14092, 7193, 51605, 51602, 7192, 39124, 39125, 13304, 2954,
               8499, 17929, 43309, 22462, 3505, 12905, 12902, 13555, 15267, 15269, 6878],
    "event": "Casual Day Out", "temperature": 15.0, "condition": "Clear", "gender": "Women"
}

# 추가 시나리오를 TEST_SCENARIOS에 append
TEST_SCENARIOS.extend([
    {"name": "시나리오 9: Temperature Change (Men Casual)", **scenario9_data},
    {"name": "시나리오 10: Temperature Change (Women Formal/Smart Casual)", **scenario10_data},
    {"name": "시나리오 11: Schedule Change (Men Summer)", **scenario11_data},
    {"name": "시나리오 12: Temperature Change (Women Summer)", **scenario12_data},
    {"name": "시나리오 13: Color Check (Men Fall Casual)", **scenario13_data},
    {"name": "시나리오 14: Color Check (Women Fall Casual)", **scenario14_data},
])

# --- API 호출 함수 (timeout 추가) ---
def test_api(scenario):
    payload = {
        "closet": scenario["closet"],
        "event": scenario["event"],
        "temperature": scenario["temperature"],
        "condition": scenario["condition"],
        "gender": scenario["gender"]
    }
    start_time = time.time()
    try:
        response = requests.post(API_URL, json=payload, timeout=30)  # 30초 타임아웃
    except requests.Timeout:
        print(f"❌ API 호출 타임아웃: {scenario['name']}")
        return
    except Exception as e:
        print(f"❌ API 호출 오류: {scenario['name']} - {str(e)}")
        return
    end_time = time.time()

    if response.status_code == 200:
        result = response.json()
        print(f"--- 테스트 시나리오: {scenario['name']} ---")
        print(f"상황: {scenario['event']} ({scenario['condition']}, {scenario['temperature']}°C, {scenario['gender']})")
        print(f"옷장 아이템 ID 리스트: {scenario['closet']}")
        if "error" in result:
            print(f"✅ 추천 결과:\n  - 추천 조합을 찾지 못했습니다. 에러: {result['error']}")
        else:
            combo_desc = result['best_combination']['description']
            combo_ids = result['best_combination']['ids']
            explanation = result['explanation']
            score = result['best_score']
            time_taken = end_time - start_time
            print(f"✅ 추천 결과:\n  - 추천 조합: {combo_desc}\n  - 조합 ID: {combo_ids}\n  - 추천 사유: {explanation}\n  - 모델 점수: {score:.4f}\n  - 처리 시간: {time_taken:.2f} 초")
        print("-" * 50, "\n")
    else:
        print(f"❌ API 호출 실패: {response.status_code} - {response.text}")

if __name__ == "__main__":
    # 병렬 테스트 for speed (max_workers=4 to avoid overload)
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = [executor.submit(test_api, scenario) for scenario in TEST_SCENARIOS]
        for future in as_completed(futures):
            future.result()  # Wait and print
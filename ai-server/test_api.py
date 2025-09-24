# 파일명: test_api.py
# serve.py로 실행된 추천 API 서버의 성능을 테스트하는 스크립트입니다.

import requests
import json

# 🚨 API 서버의 주소를 정확하게 입력해주세요.
# 예: "https://luisastre-fashion-recommender.hf.space/recommend_outfit"
API_URL = "https://73610bb0e7b2.ngrok-free.app/recommend_outfit"


# --- 테스트를 위한 가상 옷장 데이터 ---
# 옷장 1: 여름용 옷 위주 (반팔, 반바지, 샌들 등)
summer_closet = { "closet": [15970, 59435, 9036, 1164, 2154, 6394, 55573, 58004, 34091] }
# 옷장 2: 겨울용 옷 위주 (스웨터, 자켓, 긴바지, 부츠 등)
winter_closet = { "closet": [13088, 39385, 10579, 13090, 4959, 28540, 14392, 19859] }
# 옷장 3: 사계절 옷이 섞여 있는 경우
all_season_closet = { "closet": summer_closet["closet"] + winter_closet["closet"] }


# --- 테스트 시나리오 정의 ---
# 시나리오 1: 맑고 더운 여름날 해변가 데이트
scenario_1_data = {
    **all_season_closet,
    "event": "Beach Date", "temperature": 32.0, "condition": "Clear", "gender": "Women"
}

# 시나리오 2: 쌀쌀한 가을날의 비즈니스 미팅
scenario_2_data = {
    **all_season_closet,
    "event": "Business Meeting", "temperature": 15.0, "condition": "Cloudy", "gender": "Men"
}

# 시나리오 3: 눈 오는 추운 겨울 공원 산책
scenario_3_data = {
    **all_season_closet,
    "event": "Walk in the park", "temperature": -2.0, "condition": "Snowy", "gender": "Women"
}

# ⭐ --- 새로운 시나리오 --- ⭐

# 시나리오 4: 격식 있는 저녁 식사 (한 벌 옷 테스트)
formal_closet = {
    "closet": [
        5649,   # Dress (한 벌 옷)
        19859,  # Jackets (아우터)
        13090,  # Sweatshirt (캐주얼 상의 - 추천되면 안 됨)
        6394,   # Sandals (캐주얼 신발 - 추천되면 안 됨)
        1164    # Heels (격식 신발)
    ]
}
scenario_4_data = {
    **formal_closet,
    "event": "Formal Dinner", "temperature": 22.0, "condition": "Clear", "gender": "Women"
}

# 시나리오 5: 계절 불일치 테스트 (여름에 겨울 옷장 제공)
scenario_5_data = {
    **winter_closet, # 일부러 겨울 옷장만 제공
    "event": "Summer Vacation", "temperature": 35.0, "condition": "Sunny", "gender": "Men"
}

# 시나리오 6: 운동(Workout) 상황 테스트
sports_closet = {
    "closet": [
        53759,  # Tshirts (스포츠)
        1855,   # Tshirts (캐주얼)
        21379,  # Track Pants (스포츠)
        39386,  # Jeans (캐주얼)
        5375,   # Sports Shoes
        9036    # Sandals (캐주얼)
    ]
}
scenario_6_data = {
    **sports_closet,
    "event": "Workout", "temperature": 20.0, "condition": "Clear", "gender": "Men"
}


def run_test(scenario_name, data):
    """테스트를 실행하고 결과를 출력하는 함수"""
    print(f"--- 테스트 시나리오: {scenario_name} ---")
    print(f"상황: {data['event']} ({data['condition']}, {data['temperature']:.1f}°C, {data['gender']})")
    print(f"옷장 아이템 ID 리스트: {data['closet']}")

    try:
        # API 서버에 POST 요청 전송 (타임아웃 10분 설정)
        response = requests.post(API_URL, data=json.dumps(data), timeout=600)
        response.raise_for_status()

        result = response.json()

        print("\n✅ 추천 결과:")
        if result.get("best_combination"):
            print(f"  - 추천 조합: {result.get('best_combination', {}).get('description')}")
            print(f"  - 조합 ID: {result.get('best_combination', {}).get('ids')}")
            print(f"  - 모델 점수: {result.get('best_score'):.4f}")
        else:
            print(f"  - 추천 조합을 찾지 못했습니다. 에러: {result.get('error')}")

        print(f"  - 처리 시간: {result.get('processing_time'):.2f} 초")

    except requests.exceptions.RequestException as e:
        print(f"❌ 요청 실패: {e}")
        if 'response' in locals() and hasattr(response, 'text'):
            print(f"Error Response Body: {response.text}")
    finally:
        print("-" * 50, "\n")


if __name__ == "__main__":
    print("🚀 API 서버 테스트를 시작합니다...")
    # 기존 시나리오
    run_test("시나리오 1: 더운 여름날 데이트", scenario_1_data)
    run_test("시나리오 2: 쌀쌀한 가을 비즈니스 미팅", scenario_2_data)
    run_test("시나리오 3: 추운 겨울 공원 산책", scenario_3_data)
    # 새로운 시나리오
    print("\n\n--- 🧪 추가 시나리오 테스트 ---")
    run_test("시나리오 4: 격식 있는 저녁 식사", scenario_4_data)
    run_test("시나리오 5: 계절 불일치 (여름에 겨울 옷)", scenario_5_data)
    run_test("시나리오 6: 운동복 추천", scenario_6_data)
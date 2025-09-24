# 파일명: test_api.py (시나리오 고도화 최종 버전)
import requests
import json

API_URL = "https://21ac6154f3fa.ngrok-free.app/recommend_outfit"

# --- 시나리오별 현실적인 옷장 데이터 ---
# 시나리오 1 & 5: 여름 캐주얼 옷장
summer_casual_closet = {"closet": [58004, 2154, 34091, 55573, 39385, 15517, 6394, 9036, 13088, 19859]} # 티셔츠, 반바지, 샌들 + 긴팔, 자켓(오답용)
# 시나리오 2 & 3: 가을/겨울 외출용 옷장
winter_outing_closet = {"closet": [15970, 13088, 10579, 14392, 28540, 19859, 9036, 1164, 59435]} # 셔츠, 스웨터, 자켓, 긴바지, 부츠 + 샌들(오답용)
# 시나리오 4: 격식있는 옷장
formal_closet = {"closet": [5649, 1164, 19859, 13090, 6394]} # 드레스, 힐, 블레이저 + 운동복(오답용)
# 시나리오 6: 운동용 옷장
sports_closet = {"closet": [53759, 1855, 21379, 15517, 5375, 39386]} # 스포츠 티셔츠, 운동복 바지, 운동화 + 청바지(오답용)

# --- 테스트 시나리오 정의 ---
scenarios = [
    {"name": "시나리오 1: 더운 여름날 데이트", "data": {**summer_casual_closet, "event": "Beach Trip", "temperature": 32.0, "condition": "Sunny", "gender": "Women"}},
    {"name": "시나리오 2: 쌀쌀한 가을 비즈니스 미팅", "data": {**winter_outing_closet, "event": "Business Meeting", "temperature": 15.0, "condition": "Cloudy", "gender": "Men"}},
    {"name": "시나리오 3: 추운 겨울 공원 산책", "data": {**winter_outing_closet, "event": "Winter Walk", "temperature": -2.0, "condition": "Snowy", "gender": "Women"}},
    {"name": "시나리오 4: 격식 있는 저녁 식사", "data": {**formal_closet, "event": "Formal Dinner", "temperature": 22.0, "condition": "Clear", "gender": "Women"}},
    {"name": "시나리오 5: 계절 불일치 (여름에 겨울 옷)", "data": {**winter_outing_closet, "event": "Summer Vacation", "temperature": 35.0, "condition": "Sunny", "gender": "Men"}},
    {"name": "시나리오 6: 운동복 추천", "data": {**sports_closet, "event": "Gym Workout", "temperature": 20.0, "condition": "Clear", "gender": "Men"}},
]

def run_test(scenario_name, data):
    # ... (이전과 동일한 run_test 함수)
    print(f"--- 테스트 시나리오: {scenario_name} ---")
    print(f"상황: {data['event']} ({data['condition']}, {data['temperature']:.1f}°C, {data['gender']})")
    print(f"옷장 아이템 ID 리스트: {data['closet']}")
    try:
        response = requests.post(API_URL, data=json.dumps(data), timeout=600)
        response.raise_for_status()
        result = response.json()
        print("\n✅ 추천 결과:")
        if "error" in result: print(f"  - 추천 조합을 찾지 못했습니다. 에러: {result.get('error')}")
        elif result.get("best_combination") and result.get("best_combination").get("ids"):
            print(f"  - 추천 조합: {result.get('best_combination', {}).get('description')}")
            print(f"  - 조합 ID: {result.get('best_combination', {}).get('ids')}")
            if result.get("explanation"): print(f"  - 추천 사유: {result.get('explanation')}")
            if result.get("best_score") is not None: print(f"  - 모델 점수: {result.get('best_score'):.4f}")
            print(f"  - 처리 시간: {result.get('processing_time'):.2f} 초")
    except requests.exceptions.RequestException as e: print(f"❌ 요청 실패: {e}")
    finally: print("-" * 50, "\n")

if __name__ == "__main__":
    print("🚀 API 서버 테스트를 시작합니다...")
    for scenario in scenarios:
        run_test(scenario['name'], scenario['data'])
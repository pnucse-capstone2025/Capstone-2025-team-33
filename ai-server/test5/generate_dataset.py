# 파일명: generate_dataset.py (모든 기능이 통합된 최종 버전)

import pandas as pd
import json
import random
import os
import sys
from tqdm import tqdm
from itertools import combinations

# --- 0. 경로 및 설정 ---
CSV_PATH = 'styles.csv'
IMG_DIR = 'images'
OUTPUT_JSON_PATH = 'intelligent_outfit_dataset_final.json'
N_SAMPLES = 50000
MAX_ATTEMPTS_PER_SAMPLE = 500
REPORT_INTERVAL = 1000

# --- 1. 파일 경로 및 고정 매핑 (사용자 요청에 따라 수정 없음) ---
if not os.path.exists(CSV_PATH):
    sys.exit(f"FATAL ERROR: {CSV_PATH} not found.")
if not os.path.isdir(IMG_DIR):
    sys.exit(f"FATAL ERROR: {IMG_DIR} not found.")

ARTICLE_TYPE_TO_PART = {
    'Tshirts': 'Top', 'Shirts': 'Top', 'Tops': 'Top', 'Sweaters': 'Top', 'Sweatshirts': 'Top', 'Kurtas': 'Top', 'Kurtis': 'Top', 'Tunics': 'Top', 'Innerwear Vests': 'Top', 'Bra': 'Top', 'Camisoles': 'Top', 'Topwear': 'Top', 'Vests': 'Top', 'Hoodie': 'Top',
    'Jeans': 'Bottom', 'Trousers': 'Bottom', 'Shorts': 'Bottom', 'Skirts': 'Bottom', 'Track Pants': 'Bottom', 'Capris': 'Bottom', 'Leggings': 'Bottom', 'Jeggings': 'Bottom', 'Patiala': 'Bottom', 'Churidar': 'Bottom', 'Salwar': 'Bottom', 'Dhotis': 'Bottom', 'Tracksuits': 'Bottom', 'Bottomwear': 'Bottom', 'Trunk': 'Bottom', 'Briefs': 'Bottom', 'Boxers': 'Bottom',
    'Jackets': 'Outer', 'Blazers': 'Outer', 'Waistcoat': 'Outer', 'Coat': 'Outer', 'Shrug': 'Outer', 'Cardigan': 'Outer', 'Nehru Jackets': 'Outer', 'Rain Jacket': 'Outer',
    'Casual Shoes': 'Shoes', 'Sports Shoes': 'Shoes', 'Formal Shoes': 'Shoes', 'Sandals': 'Shoes', 'Flip Flops': 'Shoes', 'Boots': 'Shoes', 'Heels': 'Shoes', 'Flats': 'Shoes', 'Sneakers': 'Shoes',
    'Dresses': 'Full Body', 'Jumpsuit': 'Full Body', 'Nightdress': 'Full Body', 'Sarees': 'Full Body', 'Kurta Sets': 'Full Body', 'Night suits': 'Full Body', 'Rompers': 'Full Body', 'Bath Robe': 'Full Body'
}

ALL_POSSIBLE_CONTEXTS = [
    ("Office Meeting", "Formal"), ("Casual Day Out", "Casual"), ("Beach Trip", "Casual"),
    ("Gym Workout", "Active"), ("Hiking", "Sports"), ("Date Night", "Formal"),
    ("Weekend Brunch", "Casual"), ("Business Presentation", "Formal"), ("Outdoor Concert", "Casual"),
    ("Ski Trip", "Sports"), ("Winter Walk", "Casual"), ("Summer BBQ", "Casual"),
    ("Formal Gala", "Formal"), ("Yoga Class", "Sports"), ("Evening Party", "Casual"),
    ("University Lecture", "Casual"), ("Job Interview", "Formal"), ("Wedding Ceremony", "Formal"),
    ("Music Festival", "Casual"), ("Camping Trip", "Sports"), ("Art Gallery Visit", "Casual"),
    ("Shopping Spree", "Casual"), ("Library Study", "Casual"), ("Fine Dining", "Formal"),
    ("Movie Night In", "Casual"), ("Dog Walking", "Casual"), ("Gardening", "Casual"),
    ("Cycling Tour", "Sports"), ("Museum Visit", "Casual"), ("Volunteering Event", "Casual"),
    ("Cruise Vacation", "Casual"), ("Conference Attendance", "Formal"), ("Relaxing at Home", "Casual"),
    ("Attending a Play", "Formal"), ("Running Errands", "Casual"), ("Neighborhood Walk", "Casual"),
    ("Picnic in Park", "Casual"), ("Street Photography", "Casual"), ("Charity Marathon", "Sports"),
    ("Cocktail Party", "Formal"), ("Home Office Work", "Casual"), ("Online Class", "Casual"),
    ("Board Game Night", "Casual"), ("Car Repair", "Casual"), ("Fishing Trip", "Sports"),
    ("Night Out with Friends", "Casual"), ("Baby Shower", "Formal"), ("Book Club Meeting", "Casual"),
    ("Baking Session", "Casual"), ("Travel Day", "Casual"), ("Public Speaking Event", "Formal"),
    ("Quick Grocery Run", "Casual"), ("Meditation Retreat", "Active"), ("Pottery Class", "Casual"),
    ("Game Day at Stadium", "Casual"), ("Beach Volleyball", "Sports"), ("Opera Night", "Formal"),
    ("Morning Coffee Run", "Casual"), ("Road Trip", "Casual"), ("Cultural Festival", "Ethnic"),
    ("Traditional Ceremony", "Ethnic"), ("Religious Gathering", "Ethnic"), ("Ethnic Dance Class", "Ethnic")
]

# --- 2. 데이터 전처리 및 분류 (기존 코드와 동일) ---
df = pd.read_csv(CSV_PATH, on_bad_lines='skip')
df = df.dropna(subset=['id', 'masterCategory', 'subCategory', 'articleType', 'baseColour', 'season', 'usage'])
df['part'] = df['articleType'].map(ARTICLE_TYPE_TO_PART)
df = df.dropna(subset=['part'])
df = df.set_index('id', drop=False)
existing_files = {int(f.split('.')[0]) for f in os.listdir(IMG_DIR) if f.endswith('.jpg')}
df = df[df['id'].isin(existing_files)]
items_by_part = {part: grp['id'].tolist() for part, grp in df.groupby('part')}
items_by_usage = {usage: grp['id'].tolist() for usage, grp in df.groupby('usage')}
print("✅ 데이터 로드 및 전처리 완료!")

# --- 3. ★ NEW: 설명형 라벨 생성을 위한 헬퍼 함수 ---
def get_item_desc(item_id, df):
    """ID로 아이템의 간단한 설명을 반환"""
    if item_id is None: return ""
    info = df.loc[item_id]
    return f"{info.get('baseColour', '')} {info.get('articleType', '')} ({info.get('season', 'All')})"

def generate_positive_label(context):
    """긍정적인 추천 사유를 생성"""
    return f"긍정적: {context['temperature']}°C의 {context['condition']} 날씨에 진행되는 {context['event']}에 잘 어울리는 조합입니다."

def generate_hard_negative_label(context, wrong_item_id, reason, df):
    """'어려운 오답'에 대한 구체적인 오답 노트를 생성"""
    wrong_item_desc = get_item_desc(wrong_item_id, df)
    if reason == "temp_outer":
        return f"부정적: {context['temperature']}°C의 더운 날씨에 {wrong_item_desc} 아우터를 입는 것은 부적절합니다."
    if reason == "temp_no_outer":
        return f"부정적: {context['temperature']}°C의 추운 날씨에 아우터를 입지 않는 것은 부적절합니다."
    if reason == "event_mismatch":
        positive_event = context['event']
        wrong_usage = df.loc[wrong_item_id]['usage']
        return f"부정적: '{positive_event}'와 같은 자리에 '{wrong_usage}' 용도의 {wrong_item_desc} 아이템은 어울리지 않습니다."
    return "부정적: 이 조합은 주어진 상황에 적절하지 않습니다."

# --- 4. 기존 점수 계산 로직 (수정 없음) ---
def is_season_compatible(temp, season):
    if temp > 25 and season not in ['Summer', 'Spring']: return -10
    if temp < 10 and season not in ['Winter', 'Fall']: return -10
    if 10 <= temp <= 25 and season in ['Summer', 'Winter']: return -5
    return 5

def is_event_compatible(event, usage, event_map):
    expected_usage = event_map.get(event)
    if expected_usage and usage != expected_usage:
        if not (expected_usage == 'Formal' and usage == 'Smart Casual'):
            return -20
    return 5

color_compatibility = {
    ('Red', 'Blue'): 5, ('Red', 'White'): 5, ('Red', 'Black'): 5, ('Blue', 'White'): 8,
    ('Blue', 'Grey'): 6, ('Blue', 'Beige'): 6, ('Green', 'Beige'): 7, ('Green', 'Brown'): 7,
    ('Black', 'White'): 10, ('Black', 'Grey'): 8, ('White', 'Beige'): 8, ('White', 'Grey'): 8,
}
def get_color_compatibility_score(colors):
    score = 0
    unique_colors = list(set(colors))
    if len(unique_colors) > 1:
        for c1, c2 in combinations(unique_colors, 2):
            pair = tuple(sorted((c1, c2)))
            score += color_compatibility.get(pair, -2)
    return score

def calculate_score(context, outfit, df, event_map):
    score = 0
    item_ids = [v for v in outfit.values() if v is not None and v != 0]
    if not item_ids or len(item_ids) != len(set(item_ids)): return -1000
    try:
        items = df.loc[item_ids]
    except KeyError:
        return -1000

    for _, item in items.iterrows():
        score += is_season_compatible(context['temperature'], item['season'])

    usages = items['usage'].unique()
    if len(usages) > 1 and not ('Casual' in usages and 'Smart Casual' in usages): score -= 10
    if usages.size > 0: score += is_event_compatible(context['event'], usages[0], event_map)

    has_outer = outfit.get('outer') is not None
    is_full_body = 'Full Body' in items['part'].values
    if context['temperature'] < 15 and not is_full_body and not has_outer: score -= 20
    if context['temperature'] > 20 and has_outer: score -= 20
    
    score += get_color_compatibility_score(items['baseColour'].tolist())
    return score

# --- 5. ★ 수정된 메인 생성 루프 ---
entries = []
event_to_usage_map = dict(ALL_POSSIBLE_CONTEXTS)
pbar = tqdm(total=N_SAMPLES, desc="지능형 데이터 생성 중")

while len(entries) < N_SAMPLES:
    event, _ = random.choice(ALL_POSSIBLE_CONTEXTS)
    condition = random.choice(['Sunny', 'Cloudy', 'Rainy', 'Snowy', 'Clear', 'Mild'])
    temp = random.randint(-10, 40)
    gender = random.choice(df['gender'].unique())
    context = {"event": event, "temperature": temp, "condition": condition, "gender": gender}
    
    # 1. '긍정적'인 조합 생성 시도
    attempts = 0
    positive_outfit = None
    while attempts < MAX_ATTEMPTS_PER_SAMPLE:
        attempts += 1
        structure = random.choice([['Top', 'Bottom', 'Shoes'], ['Top', 'Bottom', 'Outer', 'Shoes'], ['Full Body', 'Shoes']])
        outfit = {part: random.choice(items_by_part[part]) for part in structure}
        
        if calculate_score(context, outfit, df, event_to_usage_map) > 10:
            positive_outfit = outfit
            break

    if not positive_outfit: continue

    # 2. '긍정적' 조합과 '어려운 오답'들을 데이터셋에 추가
    positive_label = generate_positive_label(context)
    entries.append({"context": context, "outfit": positive_outfit, "label": positive_label})
    pbar.update(1)
    if len(entries) >= N_SAMPLES: break

    # 3. '어려운 오답(Hard Negative)' 생성
    if temp > 25 and not positive_outfit.get('outer'):
        outer_id = random.choice(items_by_part['Outer'])
        neg_outfit = positive_outfit.copy(); neg_outfit['outer'] = outer_id
        neg_label = generate_hard_negative_label(context, outer_id, "temp_outer", df)
        entries.append({"context": context, "outfit": neg_outfit, "label": neg_label}); pbar.update(1)
        if len(entries) >= N_SAMPLES: break

    if temp < 10 and positive_outfit.get('outer'):
        neg_outfit = positive_outfit.copy(); outer_id = neg_outfit.pop('outer'); neg_outfit['outer'] = None
        neg_label = generate_hard_negative_label(context, outer_id, "temp_no_outer", df)
        entries.append({"context": context, "outfit": neg_outfit, "label": neg_label}); pbar.update(1)
        if len(entries) >= N_SAMPLES: break
        
    positive_usage = event_to_usage_map.get(event)
    mismatched_usages = [u for u in items_by_usage.keys() if u != positive_usage and u not in ['Smart Casual', 'Home', 'NA', 'Apparel']]
    if mismatched_usages and positive_usage:
        mismatched_usage = random.choice(mismatched_usages)
        wrong_item_id = random.choice(items_by_usage[mismatched_usage])
        part_to_swap = df.loc[wrong_item_id]['part']
        if part_to_swap in positive_outfit and part_to_swap != 'Full Body':
             neg_outfit = positive_outfit.copy(); neg_outfit[part_to_swap] = wrong_item_id
             neg_label = generate_hard_negative_label(context, wrong_item_id, "event_mismatch", df)
             entries.append({"context": context, "outfit": neg_outfit, "label": neg_label}); pbar.update(1)

pbar.close()

# --- 6. 최종 저장 ---
print(f"\n총 {len(entries)}개의 지능형 샘플을 생성했습니다.")
random.shuffle(entries)
with open(OUTPUT_JSON_PATH, 'w', encoding='utf-8') as f:
    json.dump(entries, f, ensure_ascii=False, indent=2)

print(f"✅ '{OUTPUT_JSON_PATH}' 파일로 저장 완료!")
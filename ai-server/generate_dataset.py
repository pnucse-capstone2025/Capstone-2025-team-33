import pandas as pd
import json
import random
import os
import sys

# --- 0. 경로 설정 (로컬 환경에 맞춰 수정) ---
CSV_PATH = 'styles.csv'
IMG_DIR = 'images'
OUTPUT_JSON_PATH = 'generated_outfit_dataset_hybrid_sampling.json' # 새로운 파일 이름으로 변경

# 파일 경로 존재 여부 즉시 확인 및 스크립트 강제 종료
if not os.path.exists(CSV_PATH):
    print(f"FATAL ERROR: styles.csv not found at {CSV_PATH}. Please check the path.", file=sys.stderr)
    sys.exit(1)
if not os.path.isdir(IMG_DIR):
    print(f"FATAL ERROR: images directory not found at {IMG_DIR}. Please check the path.", file=sys.stderr)
    sys.exit(1)

# --- 1. ARTICLE_TYPE_TO_PART 매핑 ---
ARTICLE_TYPE_TO_PART = {
    'Tshirts': 'Top', 'Shirts': 'Top', 'Tops': 'Top', 'Sweaters': 'Top', 'Sweatshirts': 'Top', 'Kurtas': 'Top', 'Kurtis': 'Top', 'Tunics': 'Top', 'Innerwear Vests': 'Top', 'Bra': 'Top', 'Camisoles': 'Top', 'Topwear': 'Top', 'Vests': 'Top', 'Hoodie': 'Top',
    'Jeans': 'Bottom', 'Trousers': 'Bottom', 'Shorts': 'Bottom', 'Skirts': 'Bottom', 'Track Pants': 'Bottom', 'Capris': 'Bottom', 'Leggings': 'Bottom', 'Jeggings': 'Bottom', 'Patiala': 'Bottom', 'Churidar': 'Bottom', 'Salwar': 'Bottom', 'Dhotis': 'Bottom', 'Tracksuits': 'Bottom', 'Bottomwear': 'Bottom', 'Trunk': 'Bottom', 'Briefs': 'Bottom', 'Boxers': 'Bottom',
    'Jackets': 'Outer', 'Blazers': 'Outer', 'Waistcoat': 'Outer', 'Coat': 'Outer', 'Shrug': 'Outer', 'Cardigan': 'Outer', 'Nehru Jackets': 'Outer', 'Rain Jacket': 'Outer',
    'Casual Shoes': 'Shoes', 'Sports Shoes': 'Shoes', 'Formal Shoes': 'Shoes', 'Sandals': 'Shoes', 'Flip Flops': 'Shoes', 'Boots': 'Shoes', 'Heels': 'Shoes', 'Flats': 'Shoes', 'Sneakers': 'Shoes',
    'Dresses': 'Full Body', 'Jumpsuit': 'Full Body', 'Nightdress': 'Full Body', 'Sarees': 'Full Body', 'Kurta Sets': 'Full Body', 'Night suits': 'Full Body', 'Rompers': 'Full Body', 'Bath Robe': 'Full Body'
}

PART_TO_ARTICLE_TYPE = {}
for article_type, part in ARTICLE_TYPE_TO_PART.items():
    if part not in PART_TO_ARTICLE_TYPE:
        PART_TO_ARTICLE_TYPE[part] = []
    PART_TO_ARTICLE_TYPE[part].append(article_type)

MASTER_CATEGORY_TO_PART = {
    'Apparel': ['Top', 'Bottom', 'Full Body', 'Outer'],
    'Footwear': ['Shoes'],
    'Topwear': ['Top'],
    'Bottomwear': ['Bottom'],
}

# --- 2. 스타일 메타데이터 로드 및 전처리 ---
print(f"Attempting to load {CSV_PATH}...")
try:
    styles_df = pd.read_csv(CSV_PATH, engine='python', on_bad_lines='skip')
    if styles_df.empty:
        print(f"FATAL ERROR: styles.csv loaded but is empty. Please check the file content.", file=sys.stderr)
        sys.exit(1)
    print(f"Successfully loaded {len(styles_df)} rows from styles.csv.")
except Exception as e:
    print(f"FATAL ERROR: Failed to load styles.csv. Reason: {e}", file=sys.stderr)
    sys.exit(1)

required_columns = ['id', 'gender', 'masterCategory', 'subCategory', 'articleType', 'baseColour', 'season', 'usage']
if not all(col in styles_df.columns for col in required_columns):
    missing_cols = [col for col in required_columns if col not in styles_df.columns]
    print(f"FATAL ERROR: styles.csv is missing required columns: {missing_cols}. Please check the CSV header.", file=sys.stderr)
    sys.exit(1)

styles_df = styles_df[required_columns].fillna('Unknown')
print(f"Filtered styles_df to required columns and filled NaNs. Current shape: {styles_df.shape}")


print(f"Scanning images directory: {IMG_DIR}...")
try:
    all_image_files = os.listdir(IMG_DIR)
    valid_image_ids = set([int(os.path.splitext(f)[0]) for f in all_image_files if f.endswith('.jpg')])
    print(f"Found {len(valid_image_ids)} valid image IDs.")
except Exception as e:
    print(f"FATAL ERROR: Failed to scan images directory. Reason: {e}", file=sys.stderr)
    sys.exit(1)


initial_styles_df_len = len(styles_df)
styles_df = styles_df[styles_df['id'].isin(valid_image_ids)].copy()
if styles_df.empty:
    print(f"FATAL ERROR: After filtering for existing images, styles_df is empty. "
          f"This means no IDs in styles.csv match image filenames in {IMG_DIR}. "
          f"Please ensure IDs in styles.csv correspond to JPG filenames.", file=sys.stderr)
    sys.exit(1)
print(f"Filtered styles_df to {len(styles_df)} valid items with existing images (from {initial_styles_df_len} initial).")

allowed_usages = ['Casual', 'Ethnic', 'Formal', 'Sports', 'Unknown']
styles_df = styles_df[styles_df['usage'].isin(allowed_usages)].copy()
print(f"Filtered styles_df to {len(styles_df)} items with allowed usages: {allowed_usages}")
if styles_df.empty:
    print(f"FATAL ERROR: styles_df is empty after filtering by allowed usages. Please check your usage list or styles.csv content.", file=sys.stderr)
    sys.exit(1)


by_gender_usage = {}
for g in ['Men', 'Women', 'Unisex']:
    by_gender_usage[g] = {}
    for u in styles_df['usage'].unique():
        by_gender_usage[g][u] = styles_df[(styles_df.gender == g) & (styles_df.usage == u)]
        print(f"  - Pool size for {g} {u}: {len(by_gender_usage[g][u])} items")
        if len(by_gender_usage[g][u]) == 0:
            print(f"    WARNING: No items for {g} {u}. This might limit positive sample generation for specific contexts.")


# --- 3. 컨텍스트 및 조건 정의 ---
ALL_POSSIBLE_CONTEXTS = [
    ("Office Meeting", "Formal"), ("Casual Day Out", "Casual"), ("Beach Trip", "Casual"),
    ("Gym Workout", "Active"), ("Hiking", "Sports"), ("Date Night", "Formal"),
    ("Weekend Brunch", "Casual"), ("Business Presentation", "Formal"), ("Outdoor Concert", "Casual"),
    ("Ski Trip", "Sports"), ("Winter Walk", "Casual"), ("Summer BBQ", "Casual"),
    ("Formal Gala", "Formal"), ("Yoga Class", "Sports"), ("Evening Party", "Casual"),
    ("University Lecture", "Casual"), ("Job Interview", "Formal"), ("Wedding Ceremony", "Formal"),
    ("Music Festival", "Casual"), ("Camping Trip", "Sports"), ("Art Gallery Visit", "Casual"),
    ("Shopping Spree", "Casual"), ("Library Study", "Casual"), ("Fine Dining", "Formal"),
    ("Movie Night In", "Casual"),
    ("Dog Walking", "Casual"), ("Gardening", "Casual"),
    ("Cycling Tour", "Sports"), ("Museum Visit", "Casual"),
    ("Volunteering Event", "Casual"),
    ("Cruise Vacation", "Casual"), ("Conference Attendance", "Formal"), ("Relaxing at Home", "Casual"),
    ("Attending a Play", "Formal"), ("Running Errands", "Casual"), ("Neighborhood Walk", "Casual"),
    ("Picnic in Park", "Casual"), ("Street Photography", "Casual"), ("Charity Marathon", "Sports"),
    ("Cocktail Party", "Formal"), ("Home Office Work", "Casual"), ("Online Class", "Casual"),
    ("Board Game Night", "Casual"), ("Car Repair", "Casual"),
    ("Fishing Trip", "Sports"), ("Night Out with Friends", "Casual"), ("Baby Shower", "Formal"),
    ("Book Club Meeting", "Casual"),
    ("Baking Session", "Casual"), ("Travel Day", "Casual"),
    ("Public Speaking Event", "Formal"), ("Quick Grocery Run", "Casual"),
    ("Meditation Retreat", "Active"), ("Pottery Class", "Casual"),
    ("Game Day at Stadium", "Casual"), ("Beach Volleyball", "Sports"), ("Opera Night", "Formal"),
    ("Morning Coffee Run", "Casual"), ("Road Trip", "Casual"),
    ("Cultural Festival", "Ethnic"), ("Traditional Ceremony", "Ethnic"),
    ("Religious Gathering", "Ethnic"), ("Ethnic Dance Class", "Ethnic")
]

CONTEXTS_AND_USAGES = [c for c in ALL_POSSIBLE_CONTEXTS if c[1] in allowed_usages]
if not CONTEXTS_AND_USAGES:
    print("FATAL ERROR: CONTEXTS_AND_USAGES is empty after filtering. Check your allowed_usages and context list.", file=sys.stderr)
    sys.exit(1)
print(f"Filtered CONTEXTS_AND_USAGES to {len(CONTEXTS_AND_USAGES)} entries based on allowed usages.")


CONDITIONS = ["Sunny", "Rainy", "Cloudy", "Clear", "Snowy", "Partly Cloudy", "Mild"]
GENDERS_WEIGHTS = {"Men": 0.45, "Women": 0.45, "Unisex": 0.10} # 총합 1.0


# --- 4. 온도에 따른 계절 및 Outer 추천/비추천 로직 ---
def get_suitable_seasons(temp):
    if temp is None: return ['Spring', 'Summer', 'Fall', 'Winter', 'Unknown']
    if temp <= 5: return ['Winter', 'Fall']
    if temp <= 15: return ['Fall', 'Winter', 'Spring']
    if temp <= 22: return ['Spring', 'Fall']
    if temp <= 28: return ['Summer', 'Spring']
    return ['Summer']

def should_add_outer(temp, condition):
    if temp is None: return False
    if temp <= 15 or condition in ["Rainy", "Snowy"]: return True
    return False

def should_remove_outer(temp, condition):
    if temp is None: return True
    if temp >= 25 or condition == "Sunny": return True
    return False


# --- 5. 아이템 샘플링 헬퍼 함수 (하이브리드 버전: 엄격 + 완화 Fallback) ---
def sample_item_id_hybrid(gender_pool_df_ref, target_master_category, target_part_article_types, debug_info=""):
    """
    주어진 gender_pool_df_ref에서 target_master_category와 target_part_article_types에 맞는 아이템을 샘플링합니다.
    1. 엄격한 articleType 매칭 시도.
    2. 실패 시, masterCategory 내에서 임의의 articleType 아이템 시도.
    3. 실패 시, gender_pool_df_ref 전체에서 임의의 아이템 시도.
    """
    # 1. 엄격한 articleType 매칭 시도
    pool_strict_article_type = gender_pool_df_ref[
        (gender_pool_df_ref['masterCategory'] == target_master_category) &
        (gender_pool_df_ref['articleType'].isin(target_part_article_types))
    ].copy()

    if not pool_strict_article_type.empty:
        return int(pool_strict_article_type.sample(1)['id'].iloc[0])
    
    # print(f"DEBUG: Strict part sampling failed for {debug_info}. Trying masterCategory-only fallback.")

    # 2. Fallback 1: masterCategory만 일치하는 아이템 시도
    pool_master_category_only = gender_pool_df_ref[
        gender_pool_df_ref['masterCategory'] == target_master_category
    ].copy()

    if not pool_master_category_only.empty:
        return int(pool_master_category_only.sample(1)['id'].iloc[0])

    # print(f"DEBUG: MasterCategory-only fallback failed for {debug_info}. Trying any item in gender pool.")

    # 3. Fallback 2 (최후의 수단): gender_pool_df_ref 전체에서 아무거나 뽑기
    if not gender_pool_df_ref.empty:
        return int(gender_pool_df_ref.sample(1)['id'].iloc[0])
    else:
        # print(f"DEBUG: FATAL: gender_pool_df_ref is also empty for {debug_info}. Cannot sample any item.")
        return None


# --- 6. 데이터 생성 로직 ---
N_SAMPLES = 20000 
entries = []
positive_count = 0
negative_count = 0

REPORT_INTERVAL = 100 # 100개마다 리포트되도록 명시적으로 설정

# Positive/Negative 목표 비율 설정
TARGET_POSITIVE_RATIO = 0.5 
TARGET_NEGATIVE_RATIO = 0.5

# 샘플 생성 시도 최대 횟수 (무한 루프 방지)
MAX_ATTEMPTS_PER_SAMPLE = 500 # 시도 횟수 더 늘림 (더 많은 조합을 시도할 수 있도록)

for i in range(N_SAMPLES):
    attempt_count = 0
    generated_this_sample = False
    
    # 하나의 유효한 샘플이 생성되고 목표 라벨을 달성할 때까지 반복
    while not generated_this_sample and attempt_count < MAX_ATTEMPTS_PER_SAMPLE:
        attempt_count += 1

        event, base_usage = random.choice(CONTEXTS_AND_USAGES)
        gender = random.choices(list(GENDERS_WEIGHTS.keys()), weights=list(GENDERS_WEIGHTS.values()), k=1)[0]
        
        # 성별 필터링된 기본 아이템 풀 생성
        gender_pool_df_base = styles_df[(styles_df['gender'] == gender) | (styles_df['gender'] == 'Unisex')].copy()
        if gender_pool_df_base.empty:
            # print(f"DEBUG: Skipping attempt {attempt_count} for sample {i+1} - no base items for {gender} (including Unisex).")
            continue # 해당 성별에 아이템이 없으면 이 시도는 건너뛰기

        temp = random.randint(-5, 35)
        condition = random.choice(CONDITIONS)
        suitable_seasons = get_suitable_seasons(temp)

        # Positive/Negative 라벨을 목표 비율에 맞춰 강제로 선택 시도
        current_overall_ratio = positive_count / (positive_count + negative_count + 1e-6)
        force_positive_attempt = (current_overall_ratio < TARGET_POSITIVE_RATIO)
        force_negative_attempt = not force_positive_attempt
        
        outfit_parts = {}
        actual_usages = [] 
        
        # --- 아이템 샘플링 로직: `sample_item_id_hybrid`를 사용하여 유연성 확보 ---

        # Full Body 조합 시도 (Top/Bottom과 상호 배제)
        choose_full_body_outfit = random.random() < 0.10 # 10% 확률로 Full Body 시도
        
        selected_full_body = False
        if choose_full_body_outfit:
            full_body_item_id = sample_item_id_hybrid(gender_pool_df_base, 'Apparel', PART_TO_ARTICLE_TYPE.get('Full Body', []), f"Full Body ({gender})")
            
            if full_body_item_id is not None:
                actual_article_type = styles_df[styles_df['id'] == full_body_item_id]['articleType'].iloc[0]
                if actual_article_type in PART_TO_ARTICLE_TYPE.get('Full Body', []):
                    outfit_parts['Full Body'] = full_body_item_id
                    actual_usages.append(styles_df[styles_df['id'] == full_body_item_id]['usage'].iloc[0])
                    selected_full_body = True
                else: # Apparel에서 Full Body가 아닌 다른 것이 뽑히면, Top/Bottom으로 전환
                    choose_full_body_outfit = False # 다음 if not selected_full_body 로직으로 이어지도록
            else: # Full Body 아이템 자체를 못 찾은 경우
                choose_full_body_outfit = False

        # Top/Bottom/Shoes 조합 시도 (Full Body가 선택되지 않았다면)
        if not selected_full_body: # `selected_full_body`를 기준으로 Top/Bottom 시도 여부 결정
            for part_key, master_cat in [('Top', 'Topwear'), ('Bottom', 'Bottomwear'), ('Shoes', 'Footwear')]:
                item_id = sample_item_id_hybrid(gender_pool_df_base, master_cat, PART_TO_ARTICLE_TYPE.get(part_key, []), f"{part_key} general ({gender})")
                if item_id is not None:
                    actual_article_type = styles_df[styles_df['id'] == item_id]['articleType'].iloc[0]
                    # 사후 검증: 뽑힌 아이템의 articleType이 해당 part_key에 맞는지
                    if actual_article_type in PART_TO_ARTICLE_TYPE.get(part_key, []):
                        outfit_parts[part_key] = item_id
                        actual_usages.append(styles_df[styles_df['id'] == item_id]['usage'].iloc[0])
                    # else: print(f"DEBUG: Sampled item {item_id} ({actual_article_type}) is not a {part_key} type.")


        # 생성된 아웃핏이 최소한의 필수 파트를 포함하는지 확인
        is_valid_outfit_base = False
        if 'Full Body' in outfit_parts:
            if 'Shoes' in outfit_parts:
                is_valid_outfit_base = True
        elif all(part_key in outfit_parts for part_key in ['Top', 'Bottom', 'Shoes']):
            is_valid_outfit_base = True
        
        if not is_valid_outfit_base:
            # print(f"DEBUG: Skipping attempt {attempt_count} for sample {i+1} due to incomplete base parts: {outfit_parts.keys()}.")
            continue # 필수 파트를 채우지 못했으면 이 시도는 건너뛰고 다시 시도


        # Outer (Jackets, Coats 등) 추가/제거 로직
        outer_item_id = None
        outer_master_category = 'Apparel'

        # Outer 포함 여부 결정 (라벨링 목표에 따라)
        if force_positive_attempt and should_add_outer(temp, condition): # 긍정 & 아우터 필요: 아우터 찾기
            outer_item_id = sample_item_id_hybrid(gender_pool_df_base, outer_master_category, PART_TO_ARTICLE_TYPE.get('Outer', []), f"Positive Outer needed ({gender})")
            if outer_item_id is not None:
                actual_article_type = styles_df[styles_df['id'] == outer_item_id]['articleType'].iloc[0]
                if actual_article_type not in PART_TO_ARTICLE_TYPE.get('Outer', []): outer_item_id = None
        elif force_positive_attempt and should_remove_outer(temp, condition): # 긍정 & 아우터 없어야 함: 아우터 없음
            outer_item_id = None
        elif force_positive_attempt: # 긍정 & 온화: 랜덤 포함
            if random.random() < 0.5:
                outer_item_id = sample_item_id_hybrid(gender_pool_df_base, outer_master_category, PART_TO_ARTICLE_TYPE.get('Outer', []), f"Positive Outer random ({gender})")
                if outer_item_id is not None:
                    actual_article_type = styles_df[styles_df['id'] == outer_item_id]['articleType'].iloc[0]
                    if actual_article_type not in PART_TO_ARTICLE_TYPE.get('Outer', []): outer_item_id = None
            else: outer_item_id = None
        elif force_negative_attempt and should_add_outer(temp, condition): # 부정 & 아우터 필요: 아우터 제거 (불일치 유도)
             outer_item_id = None
        elif force_negative_attempt and should_remove_outer(temp, condition): # 부정 & 아우터 없어야 함: 아우터 포함 (불일치 유도)
            outer_item_id = sample_item_id_hybrid(gender_pool_df_base, outer_master_category, PART_TO_ARTICLE_TYPE.get('Outer', []), f"Negative Outer forced ({gender})")
            if outer_item_id is not None:
                actual_article_type = styles_df[styles_df['id'] == outer_item_id]['articleType'].iloc[0]
                if actual_article_type not in PART_TO_ARTICLE_TYPE.get('Outer', []): outer_item_id = None
        elif force_negative_attempt: # 부정 & 온화: 랜덤 포함
            if random.random() < 0.7:
                outer_item_id = sample_item_id_hybrid(gender_pool_df_base, outer_master_category, PART_TO_ARTICLE_TYPE.get('Outer', []), f"Negative Outer random ({gender})")
                if outer_item_id is not None:
                    actual_article_type = styles_df[styles_df['id'] == outer_item_id]['articleType'].iloc[0]
                    if actual_article_type not in PART_TO_ARTICLE_TYPE.get('Outer', []): outer_item_id = None
            else: outer_item_id = None

        if outer_item_id is not None:
            outfit_parts['Outer'] = outer_item_id
            actual_usages.append(styles_df[styles_df['id'] == outer_item_id]['usage'].iloc[0])


        # 최종 라벨 결정 (라벨링 목표에 부합하는지 확인)
        final_label_to_assign = "Negative" # 기본값

        # --- Positive 라벨 확정 조건 ---
        if force_positive_attempt:
            all_usages_match_for_label = all(u == base_usage for u in actual_usages)
            outer_condition_met_for_label = True
            if 'Outer' in outfit_parts and should_remove_outer(temp, condition): outer_condition_met_for_label = False
            if 'Outer' not in outfit_parts and should_add_outer(temp, condition): outer_condition_met_for_label = False
            
            if all_usages_match_for_label and outer_condition_met_for_label:
                final_label_to_assign = "Positive"
        
        # --- Negative 라벨 확정 조건 ---
        elif force_negative_attempt:
            current_all_usages_match = all(u == base_usage for u in actual_usages)
            current_outer_condition_met = True
            if 'Outer' in outfit_parts and should_remove_outer(temp, condition): current_outer_condition_met = False
            if 'Outer' not in outfit_parts and should_add_outer(temp, condition): current_outer_condition_met = False

            if not current_all_usages_match or not current_outer_condition_met:
                final_label_to_assign = "Negative"
            # else: # 모든 조건이 맞는데 Negative를 강제해야 한다면 -> 이 경우는 `generated_this_sample` = False 로 재시도 유도
        
        final_outfit = {
            "top": outfit_parts.get('Top') if 'Full Body' not in outfit_parts else None,
            "bottom": outfit_parts.get('Bottom') if 'Full Body' not in outfit_parts else None,
            "outer": outfit_parts.get('Outer', None),
            "shoes": outfit_parts.get('Shoes', None),
            "full_body": outfit_parts.get('Full Body', None)
        }
        
        if not any(v is not None for v in final_outfit.values()):
            # print(f"DEBUG: Skipping attempt {attempt_count} for sample {i+1} - final outfit is empty (all None).")
            continue # 아이템을 하나도 못 찾았으면 건너뛰고 다시 시도

        # 이 시점에 도달했으면 샘플이 최소한 생성됨. 라벨링 목표 확인
        if (force_positive_attempt and final_label_to_assign == "Positive") or \
           (force_negative_attempt and final_label_to_assign == "Negative"):
            
            entries.append({
                "context": {
                    "event": event,
                    "temperature": temp,
                    "condition": condition,
                    "gender": gender
                },
                "outfit": final_outfit,
                "label": final_label_to_assign
            })
            generated_this_sample = True # 이번 샘플 생성 성공!
            if final_label_to_assign == "Positive": positive_count += 1
            else: negative_count += 1
        # else: 목표 라벨을 만들지 못했으니 `generated_this_sample` = False (while 루프 계속)

    if not generated_this_sample: # MAX_ATTEMPTS_PER_SAMPLE 내에 샘플 생성 실패 시
        print(f"WARNING: Failed to generate a valid sample for {i+1} after {MAX_ATTEMPTS_PER_SAMPLE} attempts. Skipping this N_SAMPLES iteration.", file=sys.stderr)
        continue # 이 N_SAMPLES 이터레이션은 건너뛰기

    if (i + 1) % REPORT_INTERVAL == 0:
        print(f"Generated {len(entries)}/{N_SAMPLES} samples ({((len(entries)) / N_SAMPLES) * 100:.2f}%). "
              f"Current label distribution: P:{positive_count} ({positive_count/(positive_count+negative_count+1e-6):.2f}) N:{negative_count} ({negative_count/(positive_count+negative_count+1e-6):.2f})")

# 7. JSON 파일로 저장
with open(OUTPUT_JSON_PATH, 'w', encoding='utf-8') as f:
    json.dump(entries, f, ensure_ascii=False, indent=2)

print(f"✔ Generated {len(entries)} samples and saved to {OUTPUT_JSON_PATH}")
print(f"Final label distribution: Positive: {positive_count}, Negative: {negative_count}")
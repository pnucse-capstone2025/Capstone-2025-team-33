# 파일명: generate_dpo_dataset.py (DPO 학습용 최종 버전)
import pandas as pd
import json
import random
import os
import sys
from tqdm import tqdm
from itertools import combinations

# --- 설정 (이전과 동일) ---
CSV_PATH = 'styles.csv'; IMG_DIR = 'images'; OUTPUT_JSONL_PATH = 'dpo_dataset.jsonl'; N_CONTEXTS = 10000

# --- 전처리 및 헬퍼 함수 (이전과 동일) ---
if not os.path.exists(CSV_PATH): sys.exit(f"FATAL ERROR: {CSV_PATH} not found.")
if not os.path.isdir(IMG_DIR): sys.exit(f"FATAL ERROR: {IMG_DIR} not found.")
ARTICLE_TYPE_TO_PART = {
    'Tshirts': 'Top', 'Shirts': 'Top', 'Tops': 'Top', 'Sweaters': 'Top', 'Sweatshirts': 'Top', 'Kurtas': 'Top', 'Kurtis': 'Top', 'Tunics': 'Top', 'Innerwear Vests': 'Top', 'Bra': 'Top', 'Camisoles': 'Top', 'Topwear': 'Top', 'Vests': 'Top', 'Hoodie': 'Top',
    'Jeans': 'Bottom', 'Trousers': 'Bottom', 'Shorts': 'Bottom', 'Skirts': 'Bottom', 'Track Pants': 'Bottom', 'Capris': 'Bottom', 'Leggings': 'Bottom', 'Jeggings': 'Bottom', 'Patiala': 'Bottom', 'Churidar': 'Bottom', 'Salwar': 'Bottom', 'Dhotis': 'Bottom', 'Tracksuits': 'Bottom', 'Bottomwear': 'Bottom', 'Trunk': 'Bottom', 'Briefs': 'Bottom', 'Boxers': 'Bottom',
    'Jackets': 'Outer', 'Blazers': 'Outer', 'Waistcoat': 'Outer', 'Coat': 'Outer', 'Shrug': 'Outer', 'Cardigan': 'Outer', 'Nehru Jackets': 'Outer', 'Rain Jacket': 'Outer',
    'Casual Shoes': 'Shoes', 'Sports Shoes': 'Shoes', 'Formal Shoes': 'Shoes', 'Sandals': 'Shoes', 'Flip Flops': 'Shoes', 'Boots': 'Shoes', 'Heels': 'Shoes', 'Flats': 'Shoes', 'Sneakers': 'Shoes', 'Footwear': 'Shoes',
    'Dresses': 'Full Body', 'Jumpsuit': 'Full Body', 'Nightdress': 'Full Body', 'Sarees': 'Full Body', 'Kurta Sets': 'Full Body', 'Night suits': 'Full Body', 'Rompers': 'Full Body', 'Bath Robe': 'Full Body'
}
df = pd.read_csv(CSV_PATH, on_bad_lines='skip', dtype={'id': int})
df = df.dropna(subset=['id', 'articleType', 'baseColour', 'season', 'usage'])
df['part'] = df['articleType'].map(ARTICLE_TYPE_TO_PART)
df = df.dropna(subset=['part']).set_index('id', drop=False)
existing_files = {int(f.split('.')[0]) for f in os.listdir(IMG_DIR) if f.endswith('.jpg')}
df = df[df['id'].isin(existing_files)]
items_by_part = {part: grp['id'].tolist() for part, grp in df.groupby('part')}
items_by_usage = {usage: grp for usage, grp in df.groupby('usage')}
ALL_POSSIBLE_CONTEXTS = [("Office Meeting", "Formal"), ("Casual Day Out", "Casual"), ("Beach Trip", "Casual"), ("Gym Workout", "Sports"), ("Hiking", "Sports"), ("Date Night", "Formal"), ("Weekend Brunch", "Casual"), ("Business Presentation", "Formal"), ("Winter Walk", "Casual"), ("Summer BBQ", "Casual"), ("Formal Gala", "Formal"), ("Job Interview", "Formal"), ("Wedding Ceremony", "Formal"), ("Music Festival", "Casual"), ("Art Gallery Visit", "Casual"), ("Fine Dining", "Formal")]
event_to_usage_map = dict(ALL_POSSIBLE_CONTEXTS)

def get_item_desc(item_id, df):
    if item_id is None: return ""
    info = df.loc[item_id]
    return f"{info.get('baseColour', '')} {info.get('articleType', '')} ({info.get('season', 'All')})"

def create_outfit_text(outfit, df):
    ids = [v for v in outfit.values() if v]
    return ", ".join([get_item_desc(id, df) for id in ids])

# --- DPO 데이터 생성 로직 ---
dpo_entries = []
pbar = tqdm(total=N_CONTEXTS, desc="DPO 데이터 생성 중")
for _ in range(N_CONTEXTS):
    event, usage = random.choice(ALL_POSSIBLE_CONTEXTS)
    temp = random.randint(-10, 40)
    context = {"event": event, "temperature": temp, "condition": random.choice(['Sunny', 'Cloudy', 'Rainy']), "gender": random.choice(['Men', 'Women'])}
    
    # 1. 좋은 조합 (Chosen) 생성
    structure = random.choice([['Top', 'Bottom', 'Shoes'], ['Top', 'Bottom', 'Outer', 'Shoes']])
    usage_pool = items_by_usage.get(usage)
    if usage_pool is None or usage_pool.empty: continue

    chosen_outfit = {}
    for part in structure:
        part_pool = usage_pool[usage_pool['part'] == part]
        if not part_pool.empty: chosen_outfit[part] = random.choice(part_pool['id'].tolist())
    if len(chosen_outfit) != len(structure): continue # 필수 부위 못채웠으면 스킵

    # 2. 나쁜 조합 (Rejected) 생성: 좋은 조합을 의도적으로 망가뜨림
    rejected_outfit = chosen_outfit.copy()
    part_to_swap = random.choice(list(rejected_outfit.keys()))
    
    # 다른 용도의 아이템으로 교체
    mismatched_usages = [u for u in items_by_usage.keys() if u != usage]
    if not mismatched_usages: continue
    mismatched_pool = items_by_usage[random.choice(mismatched_usages)]
    part_pool = mismatched_pool[mismatched_pool['part'] == part_to_swap]
    if not part_pool.empty: rejected_outfit[part_to_swap] = random.choice(part_pool['id'].tolist())
    else: continue

    # 3. DPO 형식에 맞게 저장
    prompt_text = f"상황: {context['gender']}, {context['temperature']}°C, {context['condition']}, {context['event']}\n다음 두 조합 중 어느 것이 더 낫습니까?\n"
    chosen_text = create_outfit_text(chosen_outfit, df)
    rejected_text = create_outfit_text(rejected_outfit, df)

    dpo_entries.append({"prompt": prompt_text, "chosen": chosen_text, "rejected": rejected_text})
    pbar.update(1)

pbar.close()
with open(OUTPUT_JSONL_PATH, 'w', encoding='utf-8') as f:
    for entry in dpo_entries:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
print(f"\n✅ DPO 학습용 '{OUTPUT_JSONL_PATH}' 파일 저장 완료!")
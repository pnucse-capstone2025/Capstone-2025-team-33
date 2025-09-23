# 파일명: serve.py (최종 Colab 실행용)

import os
os.environ["TOKENIZERS_PARALLELISM"] = "false"

import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
from peft import PeftModel
import pandas as pd
from itertools import product
import time
from fastapi import FastAPI
from pydantic import BaseModel
from typing import List
import uvicorn

# --- 1. 모델 로딩 (Colab GPU 환경) ---
print("✅ Colab GPU 환경에서 모델 로딩을 시작합니다...")
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"✅ 사용할 장치: {device.upper()}")

base_model_id = "google/gemma-2b-it"
adapter_path = "./gemma-fashion-tuner-final" # Colab에 업로드될 로컬 경로

base_model = AutoModelForCausalLM.from_pretrained(
    base_model_id,
    torch_dtype=torch.float16,
).to(device)
model = PeftModel.from_pretrained(base_model, adapter_path).to(device)
model.eval()

tokenizer = AutoTokenizer.from_pretrained(base_model_id)
tokenizer.pad_token = tokenizer.eos_token
yes_token_id = tokenizer.encode("예", add_special_tokens=False)[0]
print("✅ 모델 및 토크나이저 로딩 완료!")

# --- (이하 모든 코드는 이전과 동일) ---
styles_df = pd.read_csv("styles.csv", on_bad_lines='skip')
styles_info = styles_df.set_index('id').to_dict('index')
print("✅ styles.csv 로드 완료!")
app = FastAPI()

def get_item_description(item_id):
    if item_id not in styles_info: return ""
    info = styles_info[item_id]
    season = info.get('season', 'All')
    return f"{info.get('baseColour', '')} {info.get('articleType', '')} ({season})".strip()

class OutfitRequest(BaseModel):
    closet: List[int]; event: str; temperature: float; condition: str; gender: str

@app.post("/recommend_outfit")
def recommend_outfit(req: OutfitRequest):
    start_time = time.time()
    closet_items = { 'Topwear': [], 'Bottomwear': [], 'Outerwear': [], 'Footwear': [] }
    outerwear_types = ['Jackets', 'Sweaters', 'Blazers', 'Waistcoat', 'Coat', 'Vest']
    for item_id in req.closet:
        if item_id in styles_info:
            info, m_cat, s_cat, a_type = styles_info[item_id], styles_info[item_id]['masterCategory'], styles_info[item_id]['subCategory'], styles_info[item_id]['articleType']
            if s_cat == 'Topwear' and a_type in outerwear_types: closet_items['Outerwear'].append(item_id)
            elif s_cat == 'Topwear': closet_items['Topwear'].append(item_id)
            elif s_cat == 'Bottomwear': closet_items['Bottomwear'].append(item_id)
            elif m_cat == 'Footwear': closet_items['Footwear'].append(item_id)
    base_combinations = list(product(closet_items['Topwear'], closet_items['Bottomwear'], closet_items['Footwear']))
    outer_combinations = list(product(closet_items['Topwear'], closet_items['Bottomwear'], closet_items['Outerwear'], closet_items['Footwear']))
    all_combinations = base_combinations + outer_combinations
    if not all_combinations: return {"error": "유효한 조합을 만들 수 없습니다."}
    
    prompts = []
    for combo in all_combinations:
        outfit_desc_parts = []
        if len(combo) == 4: outfit_desc_parts = [ f"상의({get_item_description(combo[0])})", f"하의({get_item_description(combo[1])})", f"아우터({get_item_description(combo[2])})", f"신발({get_item_description(combo[3])})" ]
        elif len(combo) == 3: outfit_desc_parts = [ f"상의({get_item_description(combo[0])})", f"하의({get_item_description(combo[1])})", f"신발({get_item_description(combo[2])})" ]
        outfit_str = ", ".join(outfit_desc_parts)
        prompt = f"상황: {req.gender}, {req.temperature}°C, {req.condition}, {req.event}\n옷: {outfit_str}\n이 조합은 적절한가요?\n결과:"
        prompts.append(prompt)
        
    tokenizer.padding_side = "left"
    inputs = tokenizer(prompts, return_tensors="pt", padding=True).to(device)

    with torch.no_grad():
        outputs = model(**inputs)

    sequence_lengths = inputs['attention_mask'].sum(dim=1) - 1
    last_token_logits = outputs.logits[torch.arange(len(all_combinations)), sequence_lengths]
    probs = torch.softmax(last_token_logits, dim=-1)
    all_scores = probs[:, yes_token_id].tolist()

    best_score_index = all_scores.index(max(all_scores))
    best_score = all_scores[best_score_index]
    best_combo = all_combinations[best_score_index]
    best_outfit_str = prompts[best_score_index].split("\n")[1].replace("옷: ", "")
    best_outfit_info = {"description": best_outfit_str, "ids": [int(id) for id in best_combo]}

    end_time = time.time()
    return {
        "best_combination": best_outfit_info,
        "best_score": best_score,
        "total_combinations_evaluated": len(all_combinations),
        "processing_time": end_time - start_time
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
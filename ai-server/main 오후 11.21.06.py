# FastAPI 추론 서버 전체 코드 (최종본)
# 이 코드를 'main.py' 라는 이름의 파일로 저장하세요.

import torch
from transformers import AutoTokenizer, AutoModelForCausalLM, pipeline
from peft import PeftModel
from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn
import os # os 모듈 추가

# --- 1. 데이터 모델 정의 ---
class RecommendRequest(BaseModel):
    closet: list[str]
    weather: str
    schedule: str

class RecommendResponse(BaseModel):
    recommendation: str

# --- 2. 모델 로드 ---
base_model_id = "google/gemma-2b-it"
adapter_model_id = "luisastre/gemma-fashion-recommender-adapter-v1" 

# --- 최종 수정점: 코드에서 토큰을 제거하고 환경 변수에서 읽어오기 ---
# 터미널에서 이 프로그램을 실행하기 전에, HF_TOKEN 환경 변수를 설정해야 합니다.
HF_TOKEN = os.environ.get("HF_TOKEN")
if not HF_TOKEN:
    raise ValueError("Hugging Face 토큰이 설정되지 않았습니다. HF_TOKEN 환경 변수를 설정해주세요.")

print(f"베이스 모델 '{base_model_id}'을 로드합니다...")

tokenizer = AutoTokenizer.from_pretrained(base_model_id, token=HF_TOKEN)
base_model = AutoModelForCausalLM.from_pretrained(
    base_model_id,
    token=HF_TOKEN,
    torch_dtype=torch.float16,
    device_map="auto"
)

print(f"어댑터 '{adapter_model_id}'를 베이스 모델에 적용합니다...")
model = PeftModel.from_pretrained(base_model, adapter_model_id, token=HF_TOKEN)

pipe = pipeline("text-generation", model=model, tokenizer=tokenizer, max_new_tokens=512)
print("모델 로드 및 파이프라인 생성 완료!")

# --- 3. FastAPI 앱 생성 및 API 엔드포인트 정의 ---
app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "패션 추천 AI 서버가 정상적으로 동작하고 있습니다."}

@app.post("/recommend", response_model=RecommendResponse)
def get_recommendation(request: RecommendRequest):
    closet_str = ", ".join(request.closet)
    instruction = (
        f"옷장: [{closet_str}]. "
        f"상황: 날씨 '{request.weather}', 일정 '{request.schedule}'. "
        "요청: 이 상황에 가장 잘 어울리는 옷 조합을 추천해 줘."
    )
    prompt = f"<s>[INST] {instruction} [/INST]"
    print(f"\n추론 시작... 프롬프트: {prompt}")
    outputs = pipe(prompt)
    generated_text = outputs[0]['generated_text']
    print(f"추론 결과 (전체): {generated_text}")
    try:
        recommendation_part = generated_text.split("[/INST]")[1].strip()
        if recommendation_part.startswith("추천:"):
            recommendation_part = recommendation_part.replace("추천:", "", 1).strip()
    except IndexError:
        recommendation_part = "추천 결과를 생성하는 데 실패했습니다."
    print(f"추출된 추천 내용: {recommendation_part}")
    return RecommendResponse(recommendation=recommendation_part)

# --- 4. 서버 실행 ---
if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)

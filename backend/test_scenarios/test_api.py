# test_api.py
# CSV → JSON → API送信 → 結果表示

import csv
import json
import requests

API_URL = "https://35fb570386a1.ngrok-free.app/recommend_outfit"  # ★ Django/FastAPI側のURLに置き換える

def csv_to_json(csv_path, event, temperature, condition, gender):
    items = []
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            # custom_id → id に変換
            if "custom_id" in row:
                row["id"] = str(row["custom_id"])  # 数値ではなく文字列
                del row["custom_id"]

            # owner など不要キーを削除
            row.pop("owner", None)
            items.append(row)

    payload = {
        "closet": items,
        "event": event,
        "temperature": temperature,
        "condition": condition,
        "gender": gender,
    }
    return payload

def main():
    # ★ 手動入力（テスト用）
    csv_path = "/Users/honoka/Desktop/my_graduation/grad_project/backend/test_scenarios/Sheet 6-Susan.csv"
    event = "Weekend Brunch"
    temperature = 27.0
    condition = "Clear"
    gender = "Men"

    # CSV → JSON 作成
    payload = csv_to_json(csv_path, event, temperature, condition, gender)
    print("送信データ:")
    print(json.dumps(payload, ensure_ascii=False, indent=2))

    # APIに送信
    try:
        res = requests.post(API_URL, json=payload, timeout=20)
        res.raise_for_status()
        data = res.json()

        print("\nサーバーレスポンス:")
        print(json.dumps(data, ensure_ascii=False, indent=2))

        # best_combination の内容を整形して表示
        best = data.get("best_combination", {})
        ids = best.get("ids", [])
        desc = best.get("description", "")
        explanation = data.get("explanation", "")

        print("\n=== Outfit Recommendation ===")
        print("IDs:", ids)
        print("Descriptions:", desc)
        print("Reason:", explanation)

    except Exception as e:
        print("API呼び出し失敗:", e)

if __name__ == "__main__":
    main()

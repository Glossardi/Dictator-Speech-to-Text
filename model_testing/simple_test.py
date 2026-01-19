#!/usr/bin/env python3
"""
Simple LLM Model Tester for Text Correction
Tests models on realistic Whisper Turbo v3 outputs
"""

import json, requests, time, statistics, os
from dataclasses import dataclass, asdict
from datetime import datetime

@dataclass
class Result:
    model: str
    quality: float
    speed_tps: float
    cost_usd: float
    latency_ms: float

def test_model(api_key: str, base_url: str, model_id: str, test_cases: list, system_prompt: str):
    """Test a single model on all cases"""
    results = []
    
    for case in test_cases:
        start = time.time()
        try:
            resp = requests.post(
                f"{base_url}/chat/completions",
                headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
                json={
                    "model": model_id,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": case["whisper_output"]}
                    ],
                    "temperature": 0.3,
                    "max_tokens": 2000
                },
                timeout=30
            )
            resp.raise_for_status()
            data = resp.json()
            
            latency = (time.time() - start) * 1000
            output = data["choices"][0]["message"]["content"]
            tokens_in = data["usage"]["prompt_tokens"]
            tokens_out = data["usage"]["completion_tokens"]
            
            # Simple quality score
            quality = 100
            if any(w in output.lower() for w in ["äh", "ähm"]): quality -= 10
            if len(output) < 20: quality -= 30
            if not output[0].isupper(): quality -= 5
            if not output[-1] in '.!?': quality -= 5
            
            results.append({
                "quality": quality,
                "tps": (tokens_out / latency) * 1000,
                "cost": (tokens_in * 0.0001 + tokens_out * 0.0003) / 1000,
                "latency": latency
            })
            time.sleep(0.5)
        except Exception as e:
            print(f"  ✗ {case['name']}: {e}")
            continue
    
    if not results:
        return None
    
    return Result(
        model=model_id,
        quality=statistics.mean([r["quality"] for r in results]),
        speed_tps=statistics.mean([r["tps"] for r in results]),
        cost_usd=statistics.mean([r["cost"] for r in results]),
        latency_ms=statistics.mean([r["latency"] for r in results])
    )

def main():
    # Load config
    with open("test_config.json") as f:
        config = json.load(f)
    
    api_key = os.environ.get("LLM_API_KEY") or config["api_key"]
    base_url = config["api_base_url"]
    models = config["models_to_test"]
    
    with open("test_cases_realistic.json") as f:
        data = json.load(f)
        test_cases = data["test_cases"]
        system_prompt = data["system_prompt"]
    
    print("\n🧪 LLM Model Tester\n")
    print(f"Provider: {base_url}")
    print(f"Models: {len(models)}")
    print(f"Test Cases: {len(test_cases)}\n")
    
    results = []
    for model_id in models:
        print(f"Testing {model_id}...")
        result = test_model(api_key, base_url, model_id, test_cases, system_prompt)
        if result:
            results.append(result)
            print(f"  ✓ Quality: {result.quality:.1f}/100, Speed: {result.speed_tps:.0f} TPS, Cost: ${result.cost_usd:.6f}\n")
    
    # Sort by quality
    results.sort(key=lambda x: x.quality, reverse=True)
    
    print("\n" + "="*70)
    print("RESULTS")
    print("="*70 + "\n")
    
    for i, r in enumerate(results, 1):
        print(f"{i}. {r.model}")
        print(f"   Quality: {r.quality:.1f}/100 | Speed: {r.speed_tps:.0f} TPS | Cost: ${r.cost_usd:.6f}")
        print()
    
    if results:
        print(f"🏆 BEST MODEL: {results[0].model}")
        print(f"   Quality: {results[0].quality:.1f}/100")
        print(f"   Speed: {results[0].speed_tps:.0f} TPS ({results[0].latency_ms:.0f}ms)")
        print(f"   Cost: ${results[0].cost_usd:.6f} per correction")
    
    # Save
    with open("test_results_simple.json", "w") as f:
        json.dump([asdict(r) for r in results], f, indent=2)

if __name__ == "__main__":
    main()

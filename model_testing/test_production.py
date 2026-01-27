#!/usr/bin/env python3
"""
Production Test Runner for Dictator Correction System
Tests the optimized system prompt with 32 realistic test cases
"""

import json
import requests
import time
import statistics
import os
from datetime import datetime
from typing import Dict, List, Tuple

def load_test_config(config_file: str = "test_cases_final.json") -> dict:
    """Load test configuration from JSON file"""
    try:
        with open(config_file, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        # Try alternative configs
        for fallback in ["test_cases_comprehensive.json", "test_cases_whisper_v3.json", "test_cases_realworld.json", "test_cases_production.json"]:
            try:
                print(f"⚠️  {config_file} not found, trying {fallback}")
                with open(fallback, "r", encoding="utf-8") as f:
                    return json.load(f)
            except FileNotFoundError:
                continue
        raise FileNotFoundError(f"No test config found")

def call_llm_api(
    api_key: str,
    base_url: str,
    model: str,
    system_prompt: str,
    user_input: str,
    params: dict,
    max_retries: int = 3
) -> Tuple[str, float, dict]:
    """
    Call LLM API with automatic retry on rate limits
    Returns (output, latency_ms, usage_stats)
    """
    
    for attempt in range(max_retries):
        start = time.time()
        
        try:
            response = requests.post(
                f"{base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": model,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_input}
                    ],
                    "temperature": params.get("temperature", 0.2),
                    "top_p": params.get("top_p", 0.95),
                    "frequency_penalty": params.get("frequency_penalty", 0.4),
                    "presence_penalty": params.get("presence_penalty", 0.0),
                    "max_tokens": params.get("max_tokens", 2048)
                },
                timeout=30
            )
            response.raise_for_status()
            data = response.json()
            
            latency_ms = (time.time() - start) * 1000
            output = data["choices"][0]["message"]["content"]
            usage = data.get("usage", {})
            
            return output, latency_ms, usage
            
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 429:  # Rate limit
                if attempt < max_retries - 1:
                    wait_time = 5.0  # 5 seconds as requested
                    print(f"\n      ⏳ Rate limit hit, waiting {wait_time}s (attempt {attempt + 1}/{max_retries})...", end="", flush=True)
                    time.sleep(wait_time)
                    print(" retrying", end="", flush=True)
                    continue
                else:
                    print(f"\n      ❌ Rate limit after {max_retries} attempts")
                    return None, 0, {}
            else:
                print(f"\n      ❌ HTTP Error: {e}")
                return None, 0, {}
        except Exception as e:
            print(f"\n      ❌ API Error: {e}")
            return None, 0, {}
    
    return None, 0, {}

def evaluate_output_with_llm(
    api_key: str,
    base_url: str,
    original_input: str,
    corrected_output: str,
    features_tested: List[str],
    language: str,
    category: str
) -> dict:
    """
    Use LLM (GPT-OSS 120B) to evaluate correction quality
    Returns dict with quality score (0-100) and detailed feedback
    """
    
    if not corrected_output:
        return {"score": 0, "feedback": "No output generated", "issues": ["No output"]}
    
    # Build evaluation prompt for the judge LLM
    eval_prompt = f"""You are an expert evaluator for speech-to-text correction quality.

Evaluate the following text correction on a scale of 0-100.

**Original Input** (Whisper transcript with fillers, spoken punctuation, etc.):
{original_input}

**Corrected Output**:
{corrected_output}

**Context**:
- Language: {language}
- Category: {category}
- Features being tested: {', '.join(features_tested)}

**Evaluation Criteria** (deduct points for each issue):
1. **Filler Removal** (-15 pts): Check if filler words (um, uh, äh, ähm, euh, eh, like) were removed
2. **Spoken Punctuation** (-15 pts): Check if spoken punctuation (comma → ,, period → ., colon → :) was converted
3. **Backtracking** (-20 pts): Check if self-corrections (no wait, I mean, scratch that) were resolved
4. **Formatting** (-15 pts): Check if appropriate structure was applied (lists, paragraphs, email layout)
5. **Grammar/Capitalization** (-10 pts): Check for proper capitalization and grammar
6. **Language Preservation** (-25 pts): CRITICAL - did it translate? Output language MUST match input language
7. **Content Preservation** (-20 pts): CRITICAL - was content added, removed, or hallucinated?

**Output Format** (JSON):
{{
  "score": 85,
  "feedback": "Brief 1-sentence overall assessment",
  "issues": ["Specific issue 1", "Specific issue 2"],
  "strengths": ["What was done well"]
}}

Respond with ONLY the JSON object, no other text."""

    try:
        # Use GPT-OSS 120B for evaluation (more nuanced than 20B)
        response = requests.post(
            f"{base_url}/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            },
            json={
                "model": "openai/gpt-oss-120b",  # Larger model for better evaluation
                "messages": [
                    {"role": "user", "content": eval_prompt}
                ],
                "temperature": 0.1,  # Very deterministic for consistent evaluation
                "max_tokens": 500
            },
            timeout=30
        )
        response.raise_for_status()
        data = response.json()
        
        eval_text = data["choices"][0]["message"]["content"].strip()
        
        # Parse JSON response
        # Remove markdown code blocks if present
        if "```json" in eval_text:
            eval_text = eval_text.split("```json")[1].split("```")[0].strip()
        elif "```" in eval_text:
            eval_text = eval_text.split("```")[1].split("```")[0].strip()
        
        evaluation = json.loads(eval_text)
        return evaluation
        
    except Exception as e:
        # Fallback to simple programmatic check if LLM evaluation fails
        print(f"\n      ⚠️  LLM evaluation failed ({e}), using fallback")
        score = 100
        issues = []
        
        # Quick checks
        lower_output = corrected_output.lower()
        if any(w in lower_output for w in ["um", "uh", "äh", "ähm", "euh"]):
            score -= 15
            issues.append("Fillers not removed")
        if any(w in lower_output for w in ["comma", "period", "colon", "punkt"]):
            score -= 15
            issues.append("Spoken punctuation not converted")
        if any(phrase in lower_output for phrase in ["no wait", "i mean", "scratch that"]):
            score -= 20
            issues.append("Backtracking not resolved")
        
        return {
            "score": score,
            "feedback": f"Fallback evaluation (LLM eval failed)",
            "issues": issues,
            "strengths": []
        }

def run_production_tests(api_key: str = None, base_url: str = None):
    """
    Run all production tests and generate detailed report
    """
    print("=" * 80)
    print("🚀 DICTATOR PRODUCTION TEST SUITE")
    print("=" * 80)
    print()
    
    # Load test configuration
    config = load_test_config()
    test_cases = config["test_cases"]
    
    # Get system prompt (try multiple keys for compatibility)
    system_prompt = config.get("system_prompt_v1") or config.get("optimized_system_prompt") or config.get("system_prompt")
    if not system_prompt:
        print("❌ Error: No system prompt found in config")
        return
    
    params = config.get("model_parameters", {})
    model = params["model"]
    
    # Get API credentials
    if not api_key:
        api_key = os.environ.get("LLM_API_KEY") or os.environ.get("GROQ_API_KEY")
        
        # Try reading from test_config.json
        if not api_key:
            try:
                with open("test_config.json", "r") as f:
                    test_config = json.load(f)
                    if test_config.get("api_key") and test_config["api_key"] != "YOUR_API_KEY_HERE":
                        api_key = test_config["api_key"]
            except:
                pass
        
        # Interactive prompt if still not found
        if not api_key:
            print("⚠️  No API key found in environment variables or test_config.json")
            api_key = input("Please enter your Groq API key: ").strip()
            if not api_key:
                print("❌ Error: API key required")
                return
    
    if not base_url:
        base_url = os.environ.get("LLM_API_BASE_URL", "https://api.groq.com/openai/v1")
    
    if not api_key:
        print("❌ Error: No API key found. Set LLM_API_KEY or GROQ_API_KEY environment variable.")
        return
    
    # Groq Rate Limit: 30 req/min (Free Tier) → 3s delay to be safe (20 req/min effective)
    # With retries, actual rate will be lower
    RATE_LIMIT_DELAY = 3.0  # seconds
    
    print(f"📋 Configuration:")
    print(f"   Correction Model: {model}")
    print(f"   Evaluation Model: openai/gpt-oss-120b (LLM-based quality assessment)")
    print(f"   Test Cases: {len(test_cases)}")
    print(f"   Temperature: {params['temperature']}")
    print(f"   Top-P: {params['top_p']}")
    print(f"   Frequency Penalty: {params['frequency_penalty']}")
    print(f"   Max Tokens: {params['max_tokens']}")
    print(f"   System Prompt: {len(system_prompt)} chars")
    print(f"   Rate Limit: {RATE_LIMIT_DELAY}s between requests (with auto-retry on 429)")
    print(f"   Estimated Runtime: ~{len(test_cases) * RATE_LIMIT_DELAY / 60:.1f} minutes")
    print()
    
    # Run tests
    results = []
    latencies = []
    total_tokens = {"prompt": 0, "completion": 0}
    
    print(f"🧪 Running {len(test_cases)} tests...\n")
    
    for i, test_case in enumerate(test_cases, 1):
        test_id = test_case["id"]
        language = test_case["language"]
        category = test_case["category"]
        
        print(f"[{i:2d}/{len(test_cases)}] {test_id} ({language}, {category})...", end=" ", flush=True)
        
        output, latency_ms, usage = call_llm_api(
            api_key, base_url, model,
            system_prompt, test_case["input"], params
        )
        
        if output is None:
            print("❌ FAILED")
            continue
        
        # Evaluate with LLM (GPT-OSS 120B)
        evaluation = evaluate_output_with_llm(
            api_key, base_url,
            test_case["input"],
            output,
            test_case.get("features_tested", [test_case.get("whisper_problem", "general")]),
            language,
            category
        )
        
        results.append({
            "test_id": test_id,
            "language": language,
            "category": category,
            "input": test_case["input"],
            "output": output,
            "expected": test_case.get("expected_output", ""),
            "evaluation": evaluation,
            "latency_ms": latency_ms,
            "usage": usage
        })
        
        latencies.append(latency_ms)
        total_tokens["prompt"] += usage.get("prompt_tokens", 0)
        total_tokens["completion"] += usage.get("completion_tokens", 0)
        
        # Status icon
        score = evaluation["score"]
        if score >= 90:
            icon = "✅"
        elif score >= 70:
            icon = "⚠️"
        else:
            icon = "❌"
        
        print(f"{icon} {score:3.0f}% ({latency_ms:4.0f}ms)")
        
        # Show issues if any
        if evaluation.get("issues"):
            for issue in evaluation["issues"][:3]:  # Max 3 issues to keep output clean
                print(f"      └─ {issue}")
        
        # Rate limiting: wait between requests (except for last request)
        if i < len(test_cases):
            time.sleep(RATE_LIMIT_DELAY)
    
    # Calculate statistics
    print("\n" + "=" * 80)
    print("📊 RESULTS SUMMARY")
    print("=" * 80)
    print()
    
    quality_scores = [r["evaluation"]["score"] for r in results]
    avg_quality = statistics.mean(quality_scores) if quality_scores else 0
    
    print(f"Quality Score:      {avg_quality:.1f}/100")
    print(f"Tests Passed:       {sum(1 for s in quality_scores if s >= 90)}/{len(results)}")
    print(f"Tests Warning:      {sum(1 for s in quality_scores if 70 <= s < 90)}/{len(results)}")
    print(f"Tests Failed:       {sum(1 for s in quality_scores if s < 70)}/{len(results)}")
    print()
    
    if latencies:
        print(f"Average Latency:    {statistics.mean(latencies):.0f}ms")
        print(f"Median Latency:     {statistics.median(latencies):.0f}ms")
        print(f"P95 Latency:        {sorted(latencies)[int(len(latencies) * 0.95)]:.0f}ms")
        print(f"Max Latency:        {max(latencies):.0f}ms")
        print()
    
    total_tok = total_tokens["prompt"] + total_tokens["completion"]
    if total_tok > 0:
        print(f"Total Tokens:       {total_tok:,}")
        print(f"  Prompt:           {total_tokens['prompt']:,}")
        print(f"  Completion:       {total_tokens['completion']:,}")
    
    # Category breakdown
    print("\n" + "=" * 80)
    print("📈 CATEGORY BREAKDOWN")
    print("=" * 80)
    print()
    
    categories = {}
    for result in results:
        cat = result["category"]
        if cat not in categories:
            categories[cat] = []
        categories[cat].append(result["evaluation"]["score"])
    
    for cat in sorted(categories.keys()):
        scores = categories[cat]
        avg = statistics.mean(scores)
        count = len(scores)
        print(f"{cat:15s}  {avg:5.1f}%  ({count} tests)")
    
    # Language breakdown
    print("\n" + "=" * 80)
    print("🌍 LANGUAGE BREAKDOWN")
    print("=" * 80)
    print()
    
    languages = {}
    for result in results:
        lang = result["language"]
        if lang not in languages:
            languages[lang] = []
        languages[lang].append(result["evaluation"]["score"])
    
    for lang in sorted(languages.keys()):
        scores = languages[lang]
        avg = statistics.mean(scores)
        count = len(scores)
        print(f"{lang:5s}  {avg:5.1f}%  ({count} tests)")
    
    # Save results
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = f"test_results_production_{timestamp}.json"
    
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump({
            "timestamp": timestamp,
            "model": model,
            "parameters": params,
            "summary": {
                "avg_quality": avg_quality,
                "total_tests": len(results),
                "passed": sum(1 for s in quality_scores if s >= 90),
                "warning": sum(1 for s in quality_scores if 70 <= s < 90),
                "failed": sum(1 for s in quality_scores if s < 70),
                "avg_latency_ms": statistics.mean(latencies) if latencies else 0,
                "total_tokens": total_tok
            },
            "results": results
        }, f, indent=2, ensure_ascii=False)
    
    print("\n" + "=" * 80)
    print(f"💾 Results saved to: {output_file}")
    print("=" * 80)
    
    # Final verdict
    print()
    if avg_quality >= 95:
        print("🎉 EXCELLENT! Production-ready quality achieved.")
    elif avg_quality >= 85:
        print("✅ GOOD! Minor improvements recommended.")
    elif avg_quality >= 70:
        print("⚠️  ACCEPTABLE but needs optimization.")
    else:
        print("❌ NEEDS WORK! Significant issues found.")
    print()

if __name__ == "__main__":
    import sys
    
    # Optional: pass API key and base URL as arguments
    api_key = sys.argv[1] if len(sys.argv) > 1 else None
    base_url = sys.argv[2] if len(sys.argv) > 2 else None
    
    run_production_tests(api_key, base_url)

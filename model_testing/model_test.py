#!/usr/bin/env python3
"""
Model Testing Framework for Dictator LLM Correction
Tests various LLM models for text correction quality, speed, and cost-effectiveness.
"""

import json
import time
import requests
import statistics
from typing import Dict, List, Any, Tuple
from dataclasses import dataclass, asdict
from datetime import datetime
import os
import sys
from pathlib import Path

# Color output for terminal
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

@dataclass
class TestResult:
    """Single test execution result"""
    model_id: str
    model_name: str
    test_case: str
    run_number: int
    input_text: str
    output_text: str
    tokens_prompt: int
    tokens_completion: int
    latency_ms: float
    tps: float  # Tokens per second
    cost_usd: float
    success: bool
    error: str = None
    timestamp: str = None

    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now().isoformat()

@dataclass
class ModelStats:
    """Aggregated statistics for a model"""
    model_id: str
    model_name: str
    total_runs: int
    successful_runs: int
    failed_runs: int
    avg_latency_ms: float
    median_latency_ms: float
    avg_tps: float
    total_cost_usd: float
    avg_cost_per_test: float
    quality_score: float
    consistency_score: float  # How consistent are the outputs?

class ModelTester:
    """Main testing orchestrator"""
    
    def __init__(self, config_path: str = "models_config.json", 
                 test_cases_path: str = "test_cases.json",
                 api_key: str = None):
        self.config = self._load_json(config_path)
        self.test_cases_data = self._load_json(test_cases_path)
        self.test_cases = self.test_cases_data["test_cases"]
        self.system_prompt = self.test_cases_data["system_prompt"]
        self.api_key = api_key or os.environ.get("LLM_API_KEY")
        
        if not self.api_key:
            print(f"{Colors.FAIL}Error: No API key provided. Set LLM_API_KEY env var or pass --api-key{Colors.ENDC}")
            sys.exit(1)
        
        self.results: List[TestResult] = []
        
    def _load_json(self, path: str) -> Dict:
        """Load JSON configuration file"""
        try:
            with open(path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            print(f"{Colors.FAIL}Error loading {path}: {e}{Colors.ENDC}")
            sys.exit(1)
    
    def _call_api(self, model: Dict, text: str, provider_config: Dict) -> Tuple[str, int, int, float]:
        """
        Call LLM API for text correction
        Returns: (output_text, prompt_tokens, completion_tokens, latency_ms)
        """
        url = f"{provider_config['base_url']}/chat/completions"
        
        headers = {
            "Content-Type": "application/json",
            f"{provider_config['auth_header']}": f"{provider_config['auth_prefix']} {self.api_key}"
        }
        
        payload = {
            "model": model["id"],
            "messages": [
                {"role": "system", "content": self.system_prompt},
                {"role": "user", "content": text}
            ],
            "temperature": self.config["test_config"]["temperature"],
            "max_tokens": self.config["test_config"]["max_tokens"]
        }
        
        start_time = time.time()
        
        try:
            response = requests.post(
                url, 
                headers=headers, 
                json=payload,
                timeout=self.config["test_config"]["timeout_seconds"]
            )
            
            latency_ms = (time.time() - start_time) * 1000
            
            response.raise_for_status()
            data = response.json()
            
            output_text = data["choices"][0]["message"]["content"]
            prompt_tokens = data["usage"]["prompt_tokens"]
            completion_tokens = data["usage"]["completion_tokens"]
            
            return output_text, prompt_tokens, completion_tokens, latency_ms
            
        except requests.exceptions.Timeout:
            raise Exception(f"Request timeout after {self.config['test_config']['timeout_seconds']}s")
        except requests.exceptions.RequestException as e:
            raise Exception(f"API request failed: {str(e)}")
        except KeyError as e:
            raise Exception(f"Unexpected API response format: {str(e)}")
    
    def _calculate_cost(self, model: Dict, prompt_tokens: int, completion_tokens: int) -> float:
        """Calculate cost in USD for the API call"""
        input_cost = (prompt_tokens / 1_000_000) * model["input_price_per_1m"]
        output_cost = (completion_tokens / 1_000_000) * model["output_price_per_1m"]
        return input_cost + output_cost
    
    def _calculate_tps(self, completion_tokens: int, latency_ms: float) -> float:
        """Calculate tokens per second"""
        if latency_ms <= 0:
            return 0
        return (completion_tokens / latency_ms) * 1000
    
    def _evaluate_quality(self, test_case: Dict, output: str) -> float:
        """
        Simple heuristic quality evaluation
        Returns score 0-100
        """
        score = 100.0
        input_text = test_case["whisper_output"].lower()
        output_lower = output.lower()
        
        # Check for filler words (should be removed)
        filler_words = ["äh", "ähm", "also ja", "naja"]
        for word in filler_words:
            if word in output_lower:
                score -= 5
        
        # Check if output is not empty
        if len(output.strip()) < 10:
            score -= 50
        
        # Check if output is not too different in length (shouldn't add much content)
        input_words = len(input_text.split())
        output_words = len(output.split())
        length_ratio = output_words / max(input_words, 1)
        
        if length_ratio > 1.5:  # Output much longer than input
            score -= 20
        elif length_ratio < 0.5:  # Output much shorter (might be truncated)
            score -= 30
        
        # Check for proper capitalization
        if output and output[0].isupper():
            score += 5
        
        # Check for ending punctuation
        if output and output[-1] in '.!?':
            score += 5
        
        # Email format detection
        if test_case["name"] == "email":
            if "Betreff:" in output or "Subject:" in output:
                score += 10
            if any(greeting in output for greeting in ["Lieber", "Liebe", "Hallo", "Sehr geehrte"]):
                score += 5
            if any(closing in output for closing in ["Grüße", "Grüssen", "MfG", "VG"]):
                score += 5
        
        # List format detection
        if test_case["name"] == "list_notes":
            if any(char in output for char in ['-', '•', '*']) or any(f"{i}." in output for i in range(1, 10)):
                score += 15
        
        return max(0, min(100, score))
    
    def run_single_test(self, model: Dict, test_case: Dict, run_number: int) -> TestResult:
        """Execute a single test run"""
        provider_config = self.config["providers"][model["provider"]]
        
        print(f"  Run {run_number}/3: {test_case['name']}...", end=" ", flush=True)
        
        try:
            output_text, prompt_tokens, completion_tokens, latency_ms = self._call_api(
                model, test_case["whisper_output"], provider_config
            )
            
            cost = self._calculate_cost(model, prompt_tokens, completion_tokens)
            tps = self._calculate_tps(completion_tokens, latency_ms)
            
            result = TestResult(
                model_id=model["id"],
                model_name=model["name"],
                test_case=test_case["name"],
                run_number=run_number,
                input_text=test_case["whisper_output"],
                output_text=output_text,
                tokens_prompt=prompt_tokens,
                tokens_completion=completion_tokens,
                latency_ms=round(latency_ms, 2),
                tps=round(tps, 2),
                cost_usd=round(cost, 6),
                success=True
            )
            
            print(f"{Colors.OKGREEN}✓{Colors.ENDC} {latency_ms:.0f}ms, {tps:.0f} TPS, ${cost:.6f}")
            return result
            
        except Exception as e:
            print(f"{Colors.FAIL}✗ {str(e)}{Colors.ENDC}")
            return TestResult(
                model_id=model["id"],
                model_name=model["name"],
                test_case=test_case["name"],
                run_number=run_number,
                input_text=test_case["whisper_output"],
                output_text="",
                tokens_prompt=0,
                tokens_completion=0,
                latency_ms=0,
                tps=0,
                cost_usd=0,
                success=False,
                error=str(e)
            )
    
    def run_all_tests(self, model_ids: List[str] = None):
        """Run all tests for specified models (or all if None)"""
        models_to_test = self.config["models"]
        
        if model_ids:
            models_to_test = [m for m in models_to_test if m["id"] in model_ids]
        
        if not models_to_test:
            print(f"{Colors.FAIL}No models found to test{Colors.ENDC}")
            return
        
        print(f"\n{Colors.HEADER}{Colors.BOLD}Starting Model Testing{Colors.ENDC}")
        print(f"Models: {len(models_to_test)}")
        print(f"Test Cases: {len(self.test_cases)}")
        print(f"Runs per case: {self.config['test_config']['runs_per_case']}")
        print(f"Total tests: {len(models_to_test) * len(self.test_cases) * self.config['test_config']['runs_per_case']}\n")
        
        for model in models_to_test:
            print(f"\n{Colors.OKCYAN}{Colors.BOLD}Testing: {model['name']}{Colors.ENDC}")
            print(f"  ID: {model['id']}")
            print(f"  Speed: {model['speed_tps']} TPS (advertised)")
            print(f"  Price: ${model['input_price_per_1m']:.3f}/${model['output_price_per_1m']:.3f} per 1M tokens\n")
            
            for test_case in self.test_cases:
                for run in range(1, self.config['test_config']['runs_per_case'] + 1):
                    result = self.run_single_test(model, test_case, run)
                    self.results.append(result)
                    
                    # Small delay between requests
                    if not self.config["test_config"]["parallel_requests"]:
                        time.sleep(0.5)
    
    def calculate_statistics(self) -> Dict[str, ModelStats]:
        """Calculate aggregated statistics per model"""
        stats_by_model = {}
        
        for model in self.config["models"]:
            model_results = [r for r in self.results if r.model_id == model["id"]]
            
            if not model_results:
                continue
            
            successful = [r for r in model_results if r.success]
            failed = [r for r in model_results if not r.success]
            
            if not successful:
                continue
            
            # Calculate average quality across test cases
            quality_scores = []
            for test_case in self.test_cases:
                case_results = [r for r in successful if r.test_case == test_case["name"]]
                if case_results:
                    avg_quality = statistics.mean([
                        self._evaluate_quality(test_case, r.output_text)
                        for r in case_results
                    ])
                    quality_scores.append(avg_quality)
            
            # Calculate consistency (std dev of latencies)
            latencies = [r.latency_ms for r in successful]
            consistency = 100 - min(100, (statistics.stdev(latencies) / statistics.mean(latencies)) * 100) if len(latencies) > 1 else 100
            
            stats = ModelStats(
                model_id=model["id"],
                model_name=model["name"],
                total_runs=len(model_results),
                successful_runs=len(successful),
                failed_runs=len(failed),
                avg_latency_ms=round(statistics.mean([r.latency_ms for r in successful]), 2),
                median_latency_ms=round(statistics.median([r.latency_ms for r in successful]), 2),
                avg_tps=round(statistics.mean([r.tps for r in successful]), 2),
                total_cost_usd=round(sum([r.cost_usd for r in successful]), 6),
                avg_cost_per_test=round(statistics.mean([r.cost_usd for r in successful]), 6),
                quality_score=round(statistics.mean(quality_scores), 2) if quality_scores else 0,
                consistency_score=round(consistency, 2)
            )
            
            stats_by_model[model["id"]] = stats
        
        return stats_by_model
    
    def print_summary(self):
        """Print test results summary"""
        stats = self.calculate_statistics()
        
        if not stats:
            print(f"\n{Colors.FAIL}No successful tests to summarize{Colors.ENDC}")
            return
        
        print(f"\n\n{Colors.HEADER}{Colors.BOLD}{'='*100}{Colors.ENDC}")
        print(f"{Colors.HEADER}{Colors.BOLD}TEST RESULTS SUMMARY{Colors.ENDC}")
        print(f"{Colors.HEADER}{Colors.BOLD}{'='*100}{Colors.ENDC}\n")
        
        # Sort by quality score
        sorted_stats = sorted(stats.values(), key=lambda x: x.quality_score, reverse=True)
        
        print(f"{Colors.BOLD}{'Model':<35} {'Quality':<10} {'Speed':<12} {'Cost':<12} {'Latency':<12} {'Success':<10}{Colors.ENDC}")
        print("-" * 100)
        
        for stat in sorted_stats:
            quality_color = Colors.OKGREEN if stat.quality_score >= 80 else Colors.WARNING if stat.quality_score >= 60 else Colors.FAIL
            speed_color = Colors.OKGREEN if stat.avg_tps >= 500 else Colors.WARNING if stat.avg_tps >= 200 else ""
            cost_color = Colors.OKGREEN if stat.avg_cost_per_test <= 0.0001 else Colors.WARNING if stat.avg_cost_per_test <= 0.001 else ""
            
            print(f"{stat.model_name:<35} "
                  f"{quality_color}{stat.quality_score:.1f}/100{Colors.ENDC:<10} "
                  f"{speed_color}{stat.avg_tps:.0f} TPS{Colors.ENDC:<12} "
                  f"{cost_color}${stat.avg_cost_per_test:.6f}{Colors.ENDC:<12} "
                  f"{stat.avg_latency_ms:.0f}ms{'':<12} "
                  f"{stat.successful_runs}/{stat.total_runs}{'':<10}")
        
        print("\n" + "-" * 100)
        
        # Best recommendations
        best_quality = max(sorted_stats, key=lambda x: x.quality_score)
        best_speed = max(sorted_stats, key=lambda x: x.avg_tps)
        best_cost = min(sorted_stats, key=lambda x: x.avg_cost_per_test)
        
        # Best overall (weighted score)
        def overall_score(stat):
            normalized_quality = stat.quality_score / 100
            normalized_speed = min(stat.avg_tps / 1000, 1)  # Cap at 1000 TPS
            normalized_cost = 1 - min(stat.avg_cost_per_test / 0.001, 1)  # Lower is better
            return (normalized_quality * 0.5) + (normalized_speed * 0.25) + (normalized_cost * 0.25)
        
        best_overall = max(sorted_stats, key=overall_score)
        
        print(f"\n{Colors.BOLD}{Colors.OKGREEN}RECOMMENDATIONS:{Colors.ENDC}\n")
        print(f"🏆 {Colors.BOLD}Best Overall:{Colors.ENDC} {best_overall.model_name} (Score: {overall_score(best_overall):.2f})")
        print(f"   Quality: {best_overall.quality_score:.1f}/100 | Speed: {best_overall.avg_tps:.0f} TPS | Cost: ${best_overall.avg_cost_per_test:.6f}")
        
        print(f"\n✨ {Colors.BOLD}Best Quality:{Colors.ENDC} {best_quality.model_name} ({best_quality.quality_score:.1f}/100)")
        print(f"⚡ {Colors.BOLD}Fastest:{Colors.ENDC} {best_speed.model_name} ({best_speed.avg_tps:.0f} TPS)")
        print(f"💰 {Colors.BOLD}Cheapest:{Colors.ENDC} {best_cost.model_name} (${best_cost.avg_cost_per_test:.6f} per test)")
        
        print(f"\n{Colors.HEADER}{Colors.BOLD}{'='*100}{Colors.ENDC}\n")
    
    def save_results(self, output_path: str = "test_results.json"):
        """Save detailed results to JSON file"""
        output = {
            "metadata": {
                "timestamp": datetime.now().isoformat(),
                "total_tests": len(self.results),
                "successful_tests": len([r for r in self.results if r.success]),
                "failed_tests": len([r for r in self.results if not r.success]),
                "config": self.config
            },
            "results": [asdict(r) for r in self.results],
            "statistics": {k: asdict(v) for k, v in self.calculate_statistics().items()}
        }
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(output, f, indent=2, ensure_ascii=False)
        
        print(f"{Colors.OKGREEN}Results saved to: {output_path}{Colors.ENDC}")

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Test LLM models for text correction")
    parser.add_argument("--api-key", help="API key for the LLM provider")
    parser.add_argument("--models", nargs="+", help="Specific model IDs to test (space-separated)")
    parser.add_argument("--config", default="models_config.json", help="Path to models config file")
    parser.add_argument("--test-cases", default="test_cases.json", help="Path to test cases file")
    parser.add_argument("--output", default="test_results.json", help="Output file for results")
    
    args = parser.parse_args()
    
    # Change to script directory
    script_dir = Path(__file__).parent
    os.chdir(script_dir)
    
    tester = ModelTester(
        config_path=args.config,
        test_cases_path=args.test_cases,
        api_key=args.api_key
    )
    
    tester.run_all_tests(model_ids=args.models)
    tester.print_summary()
    tester.save_results(args.output)

if __name__ == "__main__":
    main()

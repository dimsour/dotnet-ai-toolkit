#!/usr/bin/env python3
"""Behavioral trigger evaluation using haiku.

Tests whether Claude routes user prompts to the correct skill
by sending all skill descriptions + one test prompt to haiku.

Usage:
    python3 -m lab.eval.trigger_scorer --skill plan       # Test one skill
    python3 -m lab.eval.trigger_scorer --all               # Test all skills with triggers
    python3 -m lab.eval.trigger_scorer --all --cache       # Use cached results (no API calls)

Cost: ~$0.001 per test prompt, ~$0.04 for all 40 skills × 8 prompts.
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

EVAL_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(os.path.dirname(EVAL_DIR))
sys.path.insert(0, PROJECT_ROOT)

from lab.eval.matchers import parse_frontmatter

PLUGIN_ROOT = os.path.join(PROJECT_ROOT, "plugins", "dotnet")
TRIGGERS_DIR = os.path.join(EVAL_DIR, "triggers")
RESULTS_DIR = os.path.join(TRIGGERS_DIR, "results")


def load_all_descriptions() -> dict[str, str]:
    """Load all skill names and descriptions."""
    skills_dir = os.path.join(PLUGIN_ROOT, "skills")
    descriptions = {}
    for name in sorted(os.listdir(skills_dir)):
        skill_path = os.path.join(skills_dir, name, "SKILL.md")
        if not os.path.isfile(skill_path):
            continue
        with open(skill_path) as f:
            content = f.read()
        fm = parse_frontmatter(content)
        desc = str(fm.get("description", ""))
        if desc:
            descriptions[name] = desc
    return descriptions


def load_trigger_file(skill_name: str) -> dict | None:
    """Load trigger test prompts for a skill."""
    path = os.path.join(TRIGGERS_DIR, f"{skill_name}.json")
    if not os.path.isfile(path):
        return None
    with open(path) as f:
        return json.load(f)


def ask_haiku(all_descriptions: dict[str, str], prompt: str) -> list[str]:
    """Ask haiku which skill(s) it would load for a given prompt."""
    desc_list = "\n".join(f"- {name}: {desc[:150]}" for name, desc in all_descriptions.items())

    system_prompt = f"""You are testing skill routing for a Claude Code plugin.

Given these available skills:
{desc_list}

The user says: "{prompt}"

Which skill(s) should be loaded? Reply with ONLY the skill name(s), one per line.
If no skill should be loaded, reply with "none".
List at most 3 skills, ordered by relevance."""

    try:
        result = subprocess.run(
            [
                "claude", "-p", system_prompt,
                "--model", "haiku",
                "--output-format", "text",
                "--max-budget-usd", "0.50",
                "--no-session-persistence",
            ],
            capture_output=True, text=True, timeout=30,
        )

        if result.returncode != 0:
            return []

        text = result.stdout.strip()
        # Parse skill names from response — one per line, strip bullets/numbers
        skills = []
        for line in text.split("\n"):
            line = line.strip().lstrip("-*0123456789.) ").strip()
            # Remove explanations after dashes or parentheses
            if " — " in line:
                line = line.split(" — ")[0].strip()
            if " (" in line:
                line = line.split(" (")[0].strip()
            if " -" in line:
                line = line.split(" -")[0].strip()
            line = line.strip("`").strip()
            if line and line != "none" and not line.startswith("No "):
                skills.append(line)
        return skills

    except (subprocess.TimeoutExpired, Exception):
        return []


def score_skill_triggers(
    skill_name: str,
    triggers: dict,
    all_descriptions: dict[str, str],
    use_cache: bool = False,
) -> dict:
    """Score trigger accuracy for one skill. Returns precision/recall/accuracy."""
    cache_path = os.path.join(RESULTS_DIR, f"{skill_name}.json")

    if use_cache and os.path.isfile(cache_path):
        with open(cache_path) as f:
            return json.load(f)

    should_trigger = triggers.get("should_trigger", [])
    should_not = triggers.get("should_not_trigger", [])

    results = []

    # Test should-trigger prompts
    for prompt in should_trigger:
        chosen = ask_haiku(all_descriptions, prompt)
        correct = skill_name in chosen
        results.append({
            "prompt": prompt,
            "expected": True,
            "chosen": chosen,
            "correct": correct,
        })

    # Test should-not-trigger prompts
    for prompt in should_not:
        chosen = ask_haiku(all_descriptions, prompt)
        correct = skill_name not in chosen
        results.append({
            "prompt": prompt,
            "expected": False,
            "chosen": chosen,
            "correct": correct,
        })

    # Compute metrics
    total = len(results)
    correct_count = sum(1 for r in results if r["correct"])

    tp = sum(1 for r in results if r["expected"] and r["correct"])  # should trigger, did trigger
    fp = sum(1 for r in results if not r["expected"] and not r["correct"])  # shouldn't trigger, did
    fn = sum(1 for r in results if r["expected"] and not r["correct"])  # should trigger, didn't
    tn = sum(1 for r in results if not r["expected"] and r["correct"])  # shouldn't trigger, didn't

    precision = tp / (tp + fp) if (tp + fp) > 0 else 1.0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 1.0
    accuracy = correct_count / total if total > 0 else 0.0

    score_data = {
        "skill": skill_name,
        "accuracy": round(accuracy, 4),
        "precision": round(precision, 4),
        "recall": round(recall, 4),
        "total": total,
        "correct": correct_count,
        "tp": tp, "fp": fp, "fn": fn, "tn": tn,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "results": results,
    }

    # Cache results
    os.makedirs(RESULTS_DIR, exist_ok=True)
    with open(cache_path, "w") as f:
        json.dump(score_data, f, indent=2)
        f.write("\n")

    return score_data


def main():
    parser = argparse.ArgumentParser(description="Test skill trigger accuracy with haiku")
    parser.add_argument("--skill", help="Test one skill")
    parser.add_argument("--all", action="store_true", help="Test all skills with trigger files")
    parser.add_argument("--cache", action="store_true", help="Use cached results")
    parser.add_argument("--summary", action="store_true", help="Print summary only")
    args = parser.parse_args()

    all_descriptions = load_all_descriptions()

    if args.skill:
        triggers = load_trigger_file(args.skill)
        if not triggers:
            print(f"No trigger file for {args.skill}", file=sys.stderr)
            sys.exit(1)
        result = score_skill_triggers(args.skill, triggers, all_descriptions, args.cache)
        if args.summary:
            print(f"{args.skill}: accuracy={result['accuracy']:.0%} precision={result['precision']:.0%} recall={result['recall']:.0%}")
        else:
            print(json.dumps(result, indent=2))

    elif args.all:
        skills_tested = 0
        total_accuracy = 0
        results = {}

        for name in sorted(all_descriptions.keys()):
            triggers = load_trigger_file(name)
            if not triggers:
                continue
            print(f"  Testing {name}...", end=" ", flush=True)
            result = score_skill_triggers(name, triggers, all_descriptions, args.cache)
            results[name] = result
            total_accuracy += result["accuracy"]
            skills_tested += 1
            print(f"accuracy={result['accuracy']:.0%} (P={result['precision']:.0%} R={result['recall']:.0%})")

        avg = total_accuracy / skills_tested if skills_tested else 0
        print(f"\n{skills_tested} skills tested, average accuracy: {avg:.0%}")

        if not args.summary:
            # Save aggregate
            aggregate_path = os.path.join(RESULTS_DIR, "_aggregate.json")
            with open(aggregate_path, "w") as f:
                json.dump({
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "skills_tested": skills_tested,
                    "average_accuracy": round(avg, 4),
                    "per_skill": {k: {"accuracy": v["accuracy"], "precision": v["precision"], "recall": v["recall"]}
                                  for k, v in results.items()},
                }, f, indent=2)

    else:
        parser.print_help()


if __name__ == "__main__":
    main()

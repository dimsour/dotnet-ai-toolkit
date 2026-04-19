"""Data models for the plugin skill evaluation framework."""

from dataclasses import dataclass, field
from typing import Any
import json


@dataclass
class AssertionResult:
    """Result of a single assertion check."""
    id: str
    check_type: str
    description: str
    passed: bool
    evidence: str
    weight: float = 1.0


@dataclass
class DimensionResult:
    """Aggregated result for one scoring dimension."""
    dimension: str
    score: float  # 0.0 - 1.0
    passed: int
    failed: int
    total: int
    assertions: list[AssertionResult] = field(default_factory=list)

    @classmethod
    def from_assertions(cls, dimension: str, assertions: list[AssertionResult]) -> "DimensionResult":
        total_weight = sum(a.weight for a in assertions)
        if total_weight == 0:
            return cls(dimension=dimension, score=0.0, passed=0, failed=0, total=0, assertions=assertions)
        passed_weight = sum(a.weight for a in assertions if a.passed)
        return cls(
            dimension=dimension,
            score=passed_weight / total_weight,
            passed=sum(1 for a in assertions if a.passed),
            failed=sum(1 for a in assertions if not a.passed),
            total=len(assertions),
            assertions=assertions,
        )


@dataclass
class SkillScore:
    """Complete score for one skill across all dimensions."""
    skill_name: str
    skill_path: str
    composite: float  # Weighted average of dimensions
    dimensions: dict[str, DimensionResult] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "skill": self.skill_name,
            "skill_path": self.skill_path,
            "composite": round(self.composite, 4),
            "dimensions": {
                name: {
                    "score": round(dim.score, 4),
                    "passed": dim.passed,
                    "failed": dim.failed,
                    "total": dim.total,
                    "assertions": [
                        {
                            "id": a.id,
                            "type": a.check_type,
                            "desc": a.description,
                            "passed": a.passed,
                            "evidence": a.evidence,
                        }
                        for a in dim.assertions
                    ],
                }
                for name, dim in self.dimensions.items()
            },
        }

    def to_json(self) -> str:
        return json.dumps(self.to_dict())


@dataclass
class EvalCheck:
    """A single check definition from an eval JSON file."""
    check_type: str
    description: str
    weight: float = 1.0
    # Type-specific parameters stored as kwargs
    params: dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "EvalCheck":
        check_type = d["type"]
        desc = d.get("desc", d.get("description", ""))
        weight = d.get("weight", 1.0)
        params = {k: v for k, v in d.items() if k not in ("type", "desc", "description", "weight")}
        return cls(check_type=check_type, description=desc, weight=weight, params=params)


@dataclass
class EvalDimension:
    """A dimension definition from an eval JSON file."""
    name: str
    weight: float
    checks: list[EvalCheck]

    @classmethod
    def from_dict(cls, name: str, d: dict[str, Any]) -> "EvalDimension":
        return cls(
            name=name,
            weight=d.get("weight", 0.2),
            checks=[EvalCheck.from_dict(c) for c in d.get("checks", [])],
        )


@dataclass
class EvalDefinition:
    """Complete eval definition for one skill."""
    skill: str
    skill_path: str
    dimensions: dict[str, EvalDimension]

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "EvalDefinition":
        return cls(
            skill=d["skill"],
            skill_path=d["skill_path"],
            dimensions={
                name: EvalDimension.from_dict(name, dim_data)
                for name, dim_data in d.get("dimensions", {}).items()
            },
        )

    @classmethod
    def from_file(cls, path: str) -> "EvalDefinition":
        with open(path) as f:
            return cls.from_dict(json.load(f))

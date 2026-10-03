"""
Statistical Rarity Scoring Algorithms for NFT Collections.
Implements Rarity Score, Information Entropy, Statistical Probability, and Harmonic Rarity.
"""

from __future__ import annotations

import math
from typing import Dict, List, Tuple

from lux.nft.types import TraitScoreDetail


class RarityScorer:
    """
    Computes mathematical rarity across multiple models:
    1. Rarity Score (RarityTools standard: sum of 1 / frequency)
    2. Information Entropy / Shannon Surprisal (-log2(P(x)))
    3. Statistical Probability Product (product of frequencies)
    4. Harmonic Mean Rarity
    """

    @staticmethod
    def calculate_trait_rarity_score(frequency: float) -> float:
        """Rarity Score contribution: 1 / frequency."""
        if frequency <= 0.0:
            return 10000.0  # Safe upper cap for zero frequency
        return 1.0 / frequency

    @staticmethod
    def calculate_trait_entropy_score(frequency: float) -> float:
        """Shannon Information Content / Surprisal: -log2(frequency) in bits."""
        if frequency <= 0.0:
            return 32.0
        return -math.log2(frequency)

    @staticmethod
    def calculate_token_rarity_score(trait_frequencies: List[float]) -> float:
        """Sum of 1 / frequency across all traits."""
        return sum(RarityScorer.calculate_trait_rarity_score(f) for f in trait_frequencies)

    @staticmethod
    def calculate_token_entropy_score(trait_frequencies: List[float]) -> float:
        """Sum of -log2(frequency) across all traits."""
        return sum(RarityScorer.calculate_trait_entropy_score(f) for f in trait_frequencies)

    @staticmethod
    def calculate_token_statistical_probability(trait_frequencies: List[float]) -> float:
        """
        Calculates joint probability under trait independence assumption.
        Returns value in log10 scale to prevent floating point underflow.
        """
        if not trait_frequencies:
            return 0.0
        log_prob = sum(math.log10(max(1e-12, f)) for f in trait_frequencies)
        return log_prob

    @staticmethod
    def calculate_token_harmonic_score(trait_frequencies: List[float]) -> float:
        """
        Harmonic rarity: K / sum(frequencies) where lower average frequency yields higher score.
        """
        if not trait_frequencies:
            return 0.0
        sum_f = sum(trait_frequencies)
        return len(trait_frequencies) / max(1e-12, sum_f)

    @staticmethod
    def calculate_collection_entropy(distribution: Dict[str, int], total_tokens: int) -> float:
        """
        Calculates Shannon Entropy H(X) = -sum(p(x) * log2(p(x))) for a trait category.
        """
        if total_tokens <= 0:
            return 0.0
        entropy = 0.0
        for count in distribution.values():
            if count > 0:
                p = count / total_tokens
                entropy -= p * math.log2(p)
        return entropy

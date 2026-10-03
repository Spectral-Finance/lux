"""
Unit and Integration tests for Trait Rarity Engine & Statistical Scoring.
"""

import math
import pytest

from lux.nft.rarity.engine import TraitRarityEngine
from lux.nft.rarity.scoring import RarityScorer
from lux.nft.types import (
    RarityTier,
    TokenMetadata,
    TraitAttribute,
    ValidationError,
)


def test_rarity_scorer_mathematical_properties():
    # 1. Trait rarity score: 1 / frequency
    assert round(RarityScorer.calculate_trait_rarity_score(0.01), 2) == 100.0
    assert round(RarityScorer.calculate_trait_rarity_score(0.5), 2) == 2.0

    # 2. Shannon Entropy: -log2(0.25) = 2.0 bits
    assert round(RarityScorer.calculate_trait_entropy_score(0.25), 2) == 2.0

    # 3. Statistical probability: log10(0.1 * 0.1) = -2.0
    assert round(RarityScorer.calculate_token_statistical_probability([0.1, 0.1]), 2) == -2.0

    # 4. Harmonic score: 2 / (0.1 + 0.1) = 10.0
    assert round(RarityScorer.calculate_token_harmonic_score([0.1, 0.1]), 2) == 10.0

    # 5. Collection entropy: 50/50 split -> -2 * (0.5 * log2(0.5)) = 1.0 bit
    dist = {"A": 50, "B": 50}
    assert round(RarityScorer.calculate_collection_entropy(dist, 100), 2) == 1.0


def test_trait_rarity_engine_full_collection_analysis():
    # Collection of 10 tokens with distinct trait frequencies
    # Token 1: 1/1 Golden Crown (10% frequency) + Laser Eyes (10%) -> ultra rare
    # Token 2: Golden Crown (10%) + Blue Eyes (90%)
    # Tokens 3-10: Cap (80%) + Blue Eyes (90%)
    tokens = [
        TokenMetadata(
            token_id="1",
            collection_address="0x123",
            attributes=[
                TraitAttribute(trait_type="Hat", value="Golden Crown"),
                TraitAttribute(trait_type="Eyes", value="Laser Eyes"),
                TraitAttribute(trait_type="Mouth", value="Grin"),
            ],
        ),
        TokenMetadata(
            token_id="2",
            collection_address="0x123",
            attributes=[
                TraitAttribute(trait_type="Hat", value="Golden Crown"),
                TraitAttribute(trait_type="Eyes", value="Blue Eyes"),
                TraitAttribute(trait_type="Mouth", value="Grin"),
            ],
        ),
    ]

    for i in range(3, 11):
        tokens.append(
            TokenMetadata(
                token_id=str(i),
                collection_address="0x123",
                attributes=[
                    TraitAttribute(trait_type="Hat", value="Cap"),
                    TraitAttribute(trait_type="Eyes", value="Blue Eyes"),
                    TraitAttribute(trait_type="Mouth", value="Grin"),
                ],
            )
        )

    engine = TraitRarityEngine(include_missing_traits=True, include_trait_count=True)
    report = engine.analyze_collection("0x123", tokens)

    assert report.total_supply == 10
    assert report.total_traits_count == 3
    assert len(report.token_scores) == 10

    # Token 1 must be Rank #1 (rarest)
    top_tok = engine.get_token_rarity("1")
    assert top_tok is not None
    assert top_tok.rank == 1
    assert top_tok.tier == RarityTier.LEGENDARY
    assert top_tok.rarest_trait is not None
    assert top_tok.rarest_trait.trait_type in ("Hat", "Eyes")

    # Token 2 must be Rank #2
    tok2 = engine.get_token_rarity("2")
    assert tok2 is not None
    assert tok2.rank == 2

    # Common tokens
    tok10 = engine.get_token_rarity("10")
    assert tok10.rank >= 3
    assert tok10.rarity_score < top_tok.rarity_score


def test_missing_traits_handling():
    # Token 1 has Earring, Token 2 does not have Earring
    tokens = [
        TokenMetadata(
            token_id="1",
            collection_address="0x123",
            attributes=[TraitAttribute(trait_type="Earring", value="Diamond")],
        ),
        TokenMetadata(
            token_id="2",
            collection_address="0x123",
            attributes=[],  # Missing Earring trait
        ),
        TokenMetadata(
            token_id="3",
            collection_address="0x123",
            attributes=[],
        ),
        TokenMetadata(
            token_id="4",
            collection_address="0x123",
            attributes=[],
        ),
    ]

    engine = TraitRarityEngine(include_missing_traits=True)
    report = engine.analyze_collection("0x123", tokens)

    # 1 Diamond earring (25%), 3 missing "None" (75%)
    assert report.trait_distribution["Earring"]["Diamond"] == 1
    assert report.trait_distribution["Earring"]["None"] == 3

    tok2 = engine.get_token_rarity("2")
    missing_detail = next((d for d in tok2.trait_details if d.trait_type == "Earring"), None)
    assert missing_detail is not None
    assert missing_detail.value == "None"
    assert missing_detail.is_missing_trait is True
    assert missing_detail.frequency == 0.75


def test_rarity_engine_validation():
    engine = TraitRarityEngine()
    with pytest.raises(ValidationError):
        engine.analyze_collection("0x123", [])

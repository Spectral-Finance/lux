"""
Trait Rarity Scoring Engine for NFT Collections.
Handles trait frequency normalization, missing trait handling, trait count inclusion,
and statistical rarity ranking.
"""

from __future__ import annotations

from collections import defaultdict
import logging
from typing import Any, Dict, List, Optional, Set, Tuple
import time

from lux.nft.rarity.scoring import RarityScorer
from lux.nft.types import (
    CollectionRarityReport,
    RarityTier,
    TokenMetadata,
    TokenRarityScore,
    TraitAttribute,
    TraitScoreDetail,
    ValidationError,
)

logger = logging.getLogger(__name__)


class TraitRarityEngine:
    """
    Comprehensive NFT Trait Rarity Engine.
    Features:
    - Trait frequency normalization across the entire collection supply
    - Explicit missing-trait calculation
    - Trait-count property evaluation
    - Multi-algorithm scoring (RarityScore, Shannon Entropy, Joint Probability, Harmonic)
    - Full rank and percentile indexing
    """

    def __init__(
        self,
        include_missing_traits: bool = True,
        include_trait_count: bool = True,
    ):
        self.include_missing_traits = include_missing_traits
        self.include_trait_count = include_trait_count
        self._report: Optional[CollectionRarityReport] = None
        self._token_scores_map: Dict[str, TokenRarityScore] = {}

    def analyze_collection(
        self,
        collection_address: str,
        tokens: List[TokenMetadata],
        total_supply: Optional[int] = None,
    ) -> CollectionRarityReport:
        """
        Analyzes and scores all tokens in a collection.
        """
        if not tokens:
            raise ValidationError("Tokens list cannot be empty for rarity analysis.")

        collection_size = total_supply if (total_supply and total_supply >= len(tokens)) else len(tokens)

        # 1. Gather all unique trait types and compute frequency counts
        all_trait_types: Set[str] = set()
        trait_distribution: Dict[str, Dict[str, int]] = defaultdict(lambda: defaultdict(int))
        trait_counts_per_token: Dict[str, int] = {}
        trait_count_distribution: Dict[str, int] = defaultdict(int)

        for token in tokens:
            trait_types_present = set()
            for attr in token.attributes:
                t_type = str(attr.trait_type).strip()
                t_val = str(attr.value).strip()
                if not t_type or not t_val:
                    continue
                all_trait_types.add(t_type)
                trait_types_present.add(t_type)
                trait_distribution[t_type][t_val] += 1

            count = len(trait_types_present)
            trait_counts_per_token[token.token_id] = count
            trait_count_distribution[str(count)] += 1

        # 2. Add explicit 'None' / missing count for each trait type
        if self.include_missing_traits:
            for t_type in all_trait_types:
                present_count = sum(trait_distribution[t_type].values())
                missing_count = collection_size - present_count
                if missing_count > 0:
                    trait_distribution[t_type]["None"] = missing_count

        # 3. Compute Shannon Entropy for each trait type
        trait_entropy: Dict[str, float] = {}
        for t_type, dist in trait_distribution.items():
            trait_entropy[t_type] = round(
                RarityScorer.calculate_collection_entropy(dist, collection_size), 4
            )

        # 4. Score every token
        raw_scores: List[Tuple[TokenMetadata, float, float, float, float, int, List[TraitScoreDetail]]] = []

        for token in tokens:
            token_traits_map = {
                str(a.trait_type).strip(): str(a.value).strip()
                for a in token.attributes
                if str(a.trait_type).strip() and str(a.value).strip()
            }
            score_details: List[TraitScoreDetail] = []
            frequencies: List[float] = []

            # Process all collection trait categories
            for t_type in sorted(all_trait_types):
                if t_type in token_traits_map:
                    val = token_traits_map[t_type]
                    count = trait_distribution[t_type][val]
                    freq = count / collection_size
                    r_score = RarityScorer.calculate_trait_rarity_score(freq)
                    e_score = RarityScorer.calculate_trait_entropy_score(freq)
                    frequencies.append(freq)
                    score_details.append(
                        TraitScoreDetail(
                            trait_type=t_type,
                            value=val,
                            count=count,
                            frequency=round(freq, 6),
                            rarity_score=round(r_score, 4),
                            entropy_score=round(e_score, 4),
                            is_missing_trait=False,
                            is_trait_count=False,
                        )
                    )
                elif self.include_missing_traits:
                    # Missing trait
                    count = trait_distribution[t_type]["None"]
                    freq = count / collection_size
                    r_score = RarityScorer.calculate_trait_rarity_score(freq)
                    e_score = RarityScorer.calculate_trait_entropy_score(freq)
                    frequencies.append(freq)
                    score_details.append(
                        TraitScoreDetail(
                            trait_type=t_type,
                            value="None",
                            count=count,
                            frequency=round(freq, 6),
                            rarity_score=round(r_score, 4),
                            entropy_score=round(e_score, 4),
                            is_missing_trait=True,
                            is_trait_count=False,
                        )
                    )

            # Include Trait Count as a trait
            t_count = trait_counts_per_token[token.token_id]
            if self.include_trait_count:
                tc_count = trait_count_distribution[str(t_count)]
                tc_freq = tc_count / collection_size
                tc_r_score = RarityScorer.calculate_trait_rarity_score(tc_freq)
                tc_e_score = RarityScorer.calculate_trait_entropy_score(tc_freq)
                frequencies.append(tc_freq)
                score_details.append(
                    TraitScoreDetail(
                        trait_type="Trait Count",
                        value=t_count,
                        count=tc_count,
                        frequency=round(tc_freq, 6),
                        rarity_score=round(tc_r_score, 4),
                        entropy_score=round(tc_e_score, 4),
                        is_missing_trait=False,
                        is_trait_count=True,
                    )
                )

            # Aggregate token scores
            total_r_score = RarityScorer.calculate_token_rarity_score(frequencies)
            total_e_score = RarityScorer.calculate_token_entropy_score(frequencies)
            stat_prob = RarityScorer.calculate_token_statistical_probability(frequencies)
            harm_score = RarityScorer.calculate_token_harmonic_score(frequencies)

            raw_scores.append(
                (
                    token,
                    total_r_score,
                    total_e_score,
                    stat_prob,
                    harm_score,
                    t_count,
                    score_details,
                )
            )

        # 5. Rank tokens by Rarity Score descending
        raw_scores.sort(key=lambda item: item[1], reverse=True)

        token_scores: List[TokenRarityScore] = []
        ranked_ids: List[str] = []
        total_tokens_count = len(raw_scores)

        for rank_idx, (tok, r_sc, e_sc, s_prob, h_sc, tc, details) in enumerate(raw_scores, start=1):
            percentile = (rank_idx - 1) / total_tokens_count
            tier = RarityTier.from_percentile(percentile)

            # Find rarest trait (highest individual rarity score)
            rarest = max(details, key=lambda d: d.rarity_score) if details else None

            # Sort details by rarest first
            sorted_details = sorted(details, key=lambda d: d.rarity_score, reverse=True)

            score_obj = TokenRarityScore(
                token_id=tok.token_id,
                collection_address=collection_address.lower(),
                rank=rank_idx,
                total_tokens=total_tokens_count,
                percentile=round(percentile, 4),
                tier=tier,
                rarity_score=round(r_sc, 4),
                entropy_score=round(e_sc, 4),
                statistical_rarity=round(s_prob, 6),
                harmonic_score=round(h_sc, 4),
                trait_count=tc,
                rarest_trait=rarest,
                trait_details=sorted_details,
            )
            token_scores.append(score_obj)
            ranked_ids.append(tok.token_id)
            self._token_scores_map[tok.token_id] = score_obj

        # Build final report
        dist_clean = {k: dict(v) for k, v in trait_distribution.items()}
        if self.include_trait_count:
            dist_clean["Trait Count"] = dict(trait_count_distribution)

        self._report = CollectionRarityReport(
            collection_address=collection_address.lower(),
            total_supply=collection_size,
            total_traits_count=len(all_trait_types),
            trait_distribution=dist_clean,
            token_scores=token_scores,
            trait_entropy=trait_entropy,
            ranked_token_ids=ranked_ids,
            generated_at=time.time(),
        )

        return self._report

    def get_token_rarity(self, token_id: str) -> Optional[TokenRarityScore]:
        """Retrieves computed rarity details for a specific token."""
        return self._token_scores_map.get(str(token_id))

    def get_top_rarest(self, limit: int = 10) -> List[TokenRarityScore]:
        """Returns the top rarest tokens in the collection."""
        if not self._report:
            return []
        return self._report.token_scores[:limit]

    def get_tokens_by_tier(self, tier: RarityTier) -> List[TokenRarityScore]:
        """Filters tokens matching a specified rarity tier."""
        if not self._report:
            return []
        return [ts for ts in self._report.token_scores if ts.tier == tier]

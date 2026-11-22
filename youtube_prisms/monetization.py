"""
Monetization prisms for the Lux YouTube content-intelligence suite (issue #76).

* :class:`RevenueEstimatePrism` -- produce a transparent, assumption-driven
  revenue *range* for a video or channel from its view count and a
  cost-per-mille (CPM) band. This is an estimate, not a quote: the prism is
  explicit that actual payouts depend on advertiser demand, geography, watch
  time and YouTube's revenue share.

The prism is pure and deterministic; callers pass in the view count (and an
optional CPM band) they already have.
"""

from __future__ import annotations

from typing import Any, Dict

from .base import Prism, PrismInput
from .util import round_to, to_float, to_int

__all__ = ["RevenueEstimatePrism"]

# Default CPM band in USD per 1,000 monetized playbacks. Conservative and
# transparent; callers may override with their own observed band.
_DEFAULT_CPM_LOW = 1.0
_DEFAULT_CPM_HIGH = 5.0
# A single playback is not always monetized; this is the assumed monetized share.
_DEFAULT_MONETIZED_RATE = 0.45


class RevenueEstimatePrism(Prism):
    """Estimate a video/channel revenue range from views and a CPM band.

    ``revenue_low`` / ``revenue_high`` bound the estimate using
    ``monetized_plays * cpm / 1000`` at the low and high CPM ends. The prism
    reports every assumption it used so the number is auditable.
    """

    name = "YouTube Revenue Estimate"
    description = (
        "Estimates a transparent, assumption-driven revenue range for a video "
        "or channel from its view count and a cost-per-mille (CPM) band"
    )
    input_schema = {
        "type": "object",
        "properties": {
            "views": {"type": "integer", "description": "Monetized-playback base (views)"},
            "cpm_low": {"type": "number", "description": "Low end of CPM band (USD)"},
            "cpm_high": {"type": "number", "description": "High end of CPM band (USD)"},
            "monetized_rate": {
                "type": "number",
                "description": "Assumed fraction of views that are monetized (0-1)",
            },
        },
        "required": ["views"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "views": {"type": "integer"},
            "monetized_plays": {"type": "number"},
            "cpm_low": {"type": "number"},
            "cpm_high": {"type": "number"},
            "revenue_low": {"type": "number"},
            "revenue_high": {"type": "number"},
            "revenue_mid": {"type": "number"},
            "currency": {"type": "string"},
        },
        "required": ["views", "revenue_low", "revenue_high"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        views = params.get_int("views", 0)
        cpm_low = to_float(params._raw.get("cpm_low"), _DEFAULT_CPM_LOW) \
            if params.has("cpm_low") else _DEFAULT_CPM_LOW
        cpm_high = to_float(params._raw.get("cpm_high"), _DEFAULT_CPM_HIGH) \
            if params.has("cpm_high") else _DEFAULT_CPM_HIGH
        monetized_rate = to_float(
            params._raw.get("monetized_rate"), _DEFAULT_MONETIZED_RATE
        ) if params.has("monetized_rate") else _DEFAULT_MONETIZED_RATE

        # Guard against a nonsensical band by ordering the ends.
        if cpm_high < cpm_low:
            cpm_low, cpm_high = cpm_high, cpm_low

        monetized_plays = round_to(views * monetized_rate, 2)
        revenue_low = round_to(monetized_plays * cpm_low / 1000.0, 4)
        revenue_high = round_to(monetized_plays * cpm_high / 1000.0, 4)
        revenue_mid = round_to((revenue_low + revenue_high) / 2.0, 4)

        return {
            "views": views,
            "monetized_plays": monetized_plays,
            "cpm_low": round_to(cpm_low, 4),
            "cpm_high": round_to(cpm_high, 4),
            "revenue_low": revenue_low,
            "revenue_high": revenue_high,
            "revenue_mid": revenue_mid,
            "currency": "USD",
        }
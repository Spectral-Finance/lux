"""
End-to-End Integration tests for NFT Marketplace Data Aggregation Pipeline.
"""

import time
import pytest
from unittest.mock import MagicMock

from lux.nft.connectors.aggregator import MultiMarketplaceAggregator
from lux.nft.connectors.blur import BlurConnector
from lux.nft.connectors.looksrare import LooksRareConnector
from lux.nft.connectors.opensea import OpenSeaConnector
from lux.nft.pipeline import NFTMarketplacePipeline
from lux.nft.types import (
    EventType,
    FeeBreakdown,
    Marketplace,
    SaleEvent,
    TokenMetadata,
    TraitAttribute,
)


def test_nft_marketplace_pipeline_full_aggregation():
    # 1. Setup multi-marketplace connectors with mock data
    os_conn = OpenSeaConnector(custom_http_client=lambda url, **kw: {
        "total": {"floor_price": 10.5, "floor_price_usd": 31500.0, "supply": 1000, "volume": 500.0, "sales": 40},
        "intervals": [{"interval": "one_day", "volume": 50.0, "sales": 4}],
    })
    blur_conn = BlurConnector(custom_http_client=lambda url, **kw: {
        "collection": {"floorPrice": {"amount": "10.2"}, "volumeOneDay": {"amount": "60.0"}, "salesOneDay": 5, "totalSupply": 1000}
    })
    lr_conn = LooksRareConnector(custom_http_client=lambda url, **kw: {
        "data": {"floorPrice": "10600000000000000000", "volume24h": "15000000000000000000", "count24h": 1, "totalSupply": 1000}
    })

    aggregator = MultiMarketplaceAggregator(
        opensea_connector=os_conn,
        blur_connector=blur_conn,
        looksrare_connector=lr_conn,
    )

    # 2. Setup mock historical sales
    now = time.time()
    mock_sales = [
        SaleEvent(
            event_id="s1",
            marketplace=Marketplace.BLUR,
            collection_address="0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
            token_id="101",
            price_raw="10200000000000000000",
            price_eth=10.2,
            price_usd=30600.0,
            payment_token="ETH",
            buyer_address="0x111",
            seller_address="0x222",
            transaction_hash="0xabc1",
            block_number=19000000,
            timestamp=now - 1000,
            event_type=EventType.SALE,
            fee_breakdown=FeeBreakdown(),
        ),
        SaleEvent(
            event_id="s2",
            marketplace=Marketplace.OPENSEA,
            collection_address="0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
            token_id="102",
            price_raw="10500000000000000000",
            price_eth=10.5,
            price_usd=31500.0,
            payment_token="ETH",
            buyer_address="0x333",
            seller_address="0x444",
            transaction_hash="0xabc2",
            block_number=19000010,
            timestamp=now - 2000,
            event_type=EventType.SALE,
            fee_breakdown=FeeBreakdown(),
        ),
    ]

    # 3. Setup token metadata for rarity
    tokens = [
        TokenMetadata(
            token_id="101",
            collection_address="0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
            attributes=[
                TraitAttribute(trait_type="Background", value="Gold"),
                TraitAttribute(trait_type="Fur", value="Trippy"),
            ],
        ),
        TokenMetadata(
            token_id="102",
            collection_address="0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
            attributes=[
                TraitAttribute(trait_type="Background", value="Purple"),
                TraitAttribute(trait_type="Fur", value="Brown"),
            ],
        ),
    ]

    pipeline = NFTMarketplacePipeline(aggregator=aggregator)
    result = pipeline.analyze_collection_full(
        collection_address="0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
        tokens_metadata=tokens,
        historical_sales=mock_sales,
    )

    # 4. Verify all components in report
    assert result["collection_address"] == "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"
    
    # Floor pricing check
    floor = result["floor_pricing"]
    assert floor["best_floor_price_eth"] == 10.2
    assert floor["best_marketplace"] == "blur"
    assert floor["spread_eth"] > 0

    # Trend analysis check
    trend = result["trend_analysis"]
    assert trend["current_floor_eth"] == 10.2
    assert trend["vwap_24h_eth"] == round((10.2 + 10.5) / 2.0, 6)
    assert trend["analyzed_sales_count"] == 2

    # Rarity summary check
    rarity = result["rarity_summary"]
    assert rarity is not None
    assert len(rarity["top_rarest_tokens"]) == 2
    assert rarity["total_supply"] == 1000

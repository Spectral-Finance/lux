"""
Unit tests for Telegram MessageAnalyzer and analysis pipeline.
"""

import pytest
from lux.telegram.analysis import MessageAnalyzer
from lux.telegram.types import (
    EntityType,
    IntentCategory,
    MessageEntity,
    UrgencyLevel,
)


@pytest.fixture
def analyzer():
    return MessageAnalyzer()


def test_empty_and_whitespace_analysis(analyzer):
    res = analyzer.analyze("")
    assert res.intent in (IntentCategory.UNKNOWN, "unknown")
    assert res.word_count == 0
    assert res.char_count == 0
    assert res.token_count == 0

    res2 = analyzer.analyze("   \n\t  ")
    assert res2.intent in (IntentCategory.UNKNOWN, "unknown")
    assert res2.word_count == 0


def test_bot_command_intent(analyzer):
    res = analyzer.analyze("/trade buy 1 ETH")
    assert res.intent in (IntentCategory.COMMAND, "command")
    assert res.confidence == 1.0


def test_trading_intent_and_tickers(analyzer):
    text = "Can you please buy 2.5 ETH with $5,000 USDT on market order?"
    res = analyzer.analyze(text)
    assert res.intent in (IntentCategory.TRADING, "trading")
    assert "ETH" in res.extracted_entities["crypto_tickers"]
    assert "USDT" in res.extracted_entities["crypto_tickers"]
    assert any("2.5 ETH" in amt for amt in res.extracted_entities["crypto_amounts"])
    assert "$5,000" in res.extracted_entities["fiat_amounts"]


def test_wallet_intent_and_evm_addresses(analyzer):
    addr = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
    text = f"Check the wallet balance of {addr}"
    res = analyzer.analyze(text)
    assert res.intent in (IntentCategory.WALLET, "wallet")
    assert addr in res.extracted_entities["evm_addresses"]


def test_transaction_intent_and_tx_hash(analyzer):
    tx_hash = "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"
    text = f"Why is this transaction pending {tx_hash}?"
    res = analyzer.analyze(text)
    assert res.intent in (IntentCategory.TRANSACTION, "transaction")
    assert tx_hash in res.extracted_entities["tx_hashes"]


def test_sentiment_scoring_positive_and_negative(analyzer):
    pos_text = "LUX is super bullish, massive pump and great rally ahead! Huge profit!"
    pos_res = analyzer.analyze(pos_text)
    assert pos_res.sentiment_score > 0.2
    assert pos_res.sentiment_label == "positive"

    neg_text = "This is a terrible scam rug crash and rekt exploit drain!"
    neg_res = analyzer.analyze(neg_text)
    assert neg_res.sentiment_score < -0.2
    assert neg_res.sentiment_label == "negative"


def test_urgency_assessment(analyzer):
    crit_text = "EMERGENCY! I WAS HACKED AND FUNDS ARE BEING LIQUIDATED IMMEDIATELY! HELP ASAP!!!"
    crit_res = analyzer.analyze(crit_text)
    assert crit_res.urgency in (UrgencyLevel.HIGH, UrgencyLevel.CRITICAL, "high", "critical")
    assert crit_res.urgency_score > 0.6

    calm_text = "Hello, what is the current gas price when you have a moment?"
    calm_res = analyzer.analyze(calm_text)
    assert calm_res.urgency in (UrgencyLevel.LOW, "low")


def test_language_detection(analyzer):
    assert analyzer.analyze("Hello, how are you today?").language == "en"
    assert analyzer.analyze("Привет, как дела? Помоги с ботом").language == "ru"
    assert analyzer.analyze("你好，我想购买一些加密货币").language == "zh"
    assert analyzer.analyze("Hola amigo, necesito ayuda con mi cuenta de trading").language == "es"


def test_spam_detection(analyzer):
    spam_text = "Free crypto giveaway! Claim airdrop now at https://fakeairdrop.com and double your money!"
    spam_res = analyzer.analyze(spam_text)
    assert spam_res.is_spam is True
    assert spam_res.spam_score >= 0.6


def test_toxicity_detection(analyzer):
    toxic_text = "You idiot moron fuck you and your trash bot stfu"
    toxic_res = analyzer.analyze(toxic_text)
    assert toxic_res.is_toxic is True
    assert toxic_res.toxicity_score >= 0.5


def test_entity_extraction_from_telegram_entities(analyzer):
    text = "Visit https://spectral.finance or contact @luxbot #defi $LUX"
    # "Visit " -> 6
    # "https://spectral.finance" -> length 24 (6..30)
    # " or contact " -> length 12 (30..42)
    # "@luxbot" -> length 7 (42..49)
    # " " -> 1 (49..50)
    # "#defi" -> length 5 (50..55)
    # " " -> 1 (55..56)
    # "$LUX" -> length 4 (56..60)
    entities = [
        MessageEntity(type=EntityType.URL, offset=6, length=24),
        MessageEntity(type=EntityType.MENTION, offset=42, length=7),
        MessageEntity(type=EntityType.HASHTAG, offset=50, length=5),
        MessageEntity(type=EntityType.CASHTAG, offset=56, length=4),
    ]
    res = analyzer.analyze(text, entities=entities)
    assert "https://spectral.finance" in res.extracted_entities["urls"]
    assert "@luxbot" in res.extracted_entities["mentions"]
    assert "#defi" in res.extracted_entities["hashtags"]
    assert "LUX" in res.extracted_entities["crypto_tickers"]

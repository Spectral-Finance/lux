"""
Content analysis engine for Telegram messages in the Lux Framework.

Performs intent classification, financial entity extraction (crypto tickers, EVM addresses,
tx hashes, amounts), sentiment scoring, urgency assessment, language detection, token metrics,
and spam/toxicity filtering.
"""

from __future__ import annotations

import math
import re
from typing import Any, Dict, List, Optional, Set, Tuple

from lux.telegram.types import (
    AnalysisResult,
    EntityType,
    IntentCategory,
    MessageEntity,
    UrgencyLevel,
)


# Common crypto tickers and symbols
KNOWN_TICKERS: Set[str] = {
    "BTC", "ETH", "SOL", "LUX", "USDT", "USDC", "BNB", "XRP", "ADA",
    "AVAX", "DOGE", "DOT", "MATIC", "LINK", "UNI", "NEAR", "ARB", "OP",
    "SUI", "APT", "PEPE", "SHIB", "DAI", "WBTC", "AAVE", "MKR", "LDO",
    "RENDER", "FET", "INJ", "TIA", "SEI", "PENDLE", "ONDO", "STRK"
}

# Intent keyword maps
INTENT_PATTERNS: Dict[IntentCategory, List[str]] = {
    IntentCategory.TRADING: [
        r"\b(buy|sell|swap|trade|long|short|leverage|order|limit\s*order|market\s*order|bid|ask|slippage)\b",
        r"\b(entry|target|stop\s*loss|take\s*profit|pnl|position|margin)\b",
    ],
    IntentCategory.WALLET: [
        r"\b(wallet|balance|deposit|withdraw|transfer|send|receive|address|vault|gas\s*fee|nonce)\b",
        r"\b(connect\s*wallet|metamask|phantom|keplr|private\s*key|seed\s*phrase)\b",
    ],
    IntentCategory.TRANSACTION: [
        r"\b(tx|transaction|receipt|hash|confirmed|pending|reverted|mined|broadcast)\b",
        r"\b(0x[a-fA-F0-9]{64})\b",
    ],
    IntentCategory.HELP: [
        r"^(/(start|help|info|about|faq|docs)|how\s+to|what\s+is|help\s+me|guide|commands?)\b",
    ],
    IntentCategory.SUPPORT: [
        r"\b(issue|bug|problem|error|failed|broken|not\s*working|stuck|lost|assist|support\s*ticket)\b",
    ],
    IntentCategory.FEEDBACK: [
        r"\b(feedback|suggest|feature\s*request|review|rating|improve|enhancement)\b",
    ],
    IntentCategory.GREETING: [
        r"^(hi|hello|hey|gm|gn|good\s*morning|good\s*evening|greetings|sup|yo)\b",
    ],
    IntentCategory.QUERY: [
        r"\b(what|why|when|where|who|which|how\s*much|price|rate|market\s*cap|volume|stats|status|metrics?)\b",
    ],
}

# Sentiment lexicon with crypto context
POSITIVE_WORDS: Dict[str, float] = {
    "bullish": 0.9, "moon": 0.85, "pump": 0.8, "rally": 0.8, "surge": 0.75,
    "profit": 0.8, "gain": 0.7, "ath": 0.85, "breakout": 0.75, "growth": 0.6,
    "awesome": 0.8, "great": 0.7, "good": 0.5, "excellent": 0.85, "up": 0.4,
    "green": 0.5, "gem": 0.75, "win": 0.7, "success": 0.75, "love": 0.8,
    "solid": 0.6, "strong": 0.65, "legit": 0.7, "innovative": 0.7, "secure": 0.65
}

NEGATIVE_WORDS: Dict[str, float] = {
    "bearish": -0.85, "dump": -0.85, "crash": -0.9, "rekt": -0.9, "loss": -0.75,
    "rug": -0.95, "scam": -0.95, "drop": -0.6, "bad": -0.6, "terrible": -0.85,
    "awful": -0.85, "down": -0.4, "red": -0.5, "fail": -0.8, "failed": -0.8,
    "hack": -0.95, "exploit": -0.95, "scammed": -0.95, "drain": -0.9, "phishing": -0.9,
    "slow": -0.4, "worst": -0.85, "liquidated": -0.9, "reverted": -0.6, "bug": -0.5
}

# Urgency triggers
URGENCY_KEYWORDS: Dict[str, float] = {
    "urgent": 0.9, "immediately": 0.9, "asap": 0.85, "emergency": 0.95,
    "liquidate": 0.8, "liquidated": 0.85, "margin call": 0.9, "hacked": 0.95,
    "exploit": 0.95, "stolen": 0.95, "critical": 0.85, "quick": 0.6,
    "hurry": 0.7, "danger": 0.8, "alert": 0.75, "attention": 0.7, "now": 0.5
}

# Spam patterns
SPAM_PATTERNS: List[Tuple[str, float]] = [
    (r"\b(claim\s*airdrop|free\s*crypto|giveaway|claim\s*now|presale\s*live|double\s*your\s*money)\b", 0.85),
    (r"\b(guaranteed\s*profit|invest\s*\$?\d+\s*earn\s*\$?\d+|100%\s*daily|risk-free\s*returns?)\b", 0.9),
    (r"\b(send\s*dm|dm\s*me\s*on\s*whatsapp|contact\s*admin|whatsapp\s*\+?\d+)\b", 0.8),
    (r"\b(t\.me/\+[a-zA-Z0-9_\-]+|telegram\.me/joinchat)\b", 0.6),
    (r"\b(official\s*airdrop|connect\s*wallet\s*to\s*claim|bonus\s*reward\s*pool)\b", 0.85),
]

# Toxicity patterns
TOXIC_PATTERNS: List[Tuple[str, float]] = [
    (r"\b(fuck\s*you|idiot|moron|retard|scumbag|bastard|kill\s*yourself|kys|stfu)\b", 0.9),
    (r"\b(fucker|bitch|asshole|dipshit|dickhead|cunt)\b", 0.85),
    (r"\b(scammer|thief|cheat|liar)\b", 0.5),
]


class MessageAnalyzer:
    """Production analyzer for message content and metadata."""

    def __init__(self, custom_tickers: Optional[Set[str]] = None):
        self.known_tickers = KNOWN_TICKERS.union(custom_tickers or set())

    def analyze(
        self,
        text: str,
        entities: Optional[List[MessageEntity]] = None,
        user_metadata: Optional[Dict[str, Any]] = None,
    ) -> AnalysisResult:
        """Runs the complete analysis pipeline on text and returns an AnalysisResult."""
        raw_text = text or ""
        clean_text = raw_text.strip()

        # 1. Basic Token & Character Metrics
        char_count = len(clean_text)
        words = re.findall(r"\b\w+\b", clean_text)
        word_count = len(words)
        token_count = max(1, math.ceil(char_count / 4.0)) if char_count > 0 else 0

        if not clean_text:
            return AnalysisResult(
                intent=IntentCategory.UNKNOWN,
                confidence=0.0,
                sentiment_score=0.0,
                sentiment_label="neutral",
                urgency=UrgencyLevel.LOW,
                urgency_score=0.0,
                language="en",
                is_spam=False,
                spam_score=0.0,
                is_toxic=False,
                toxicity_score=0.0,
                token_count=0,
                char_count=0,
                word_count=0,
                extracted_entities={},
                keywords=[],
            )

        # 2. Entity Extraction
        extracted_entities = self._extract_entities(clean_text, entities)

        # 3. Intent Classification
        intent, confidence = self._classify_intent(clean_text, entities, extracted_entities)

        # 4. Sentiment Analysis
        sentiment_score, sentiment_label = self._analyze_sentiment(clean_text)

        # 5. Urgency Assessment
        urgency, urgency_score = self._assess_urgency(clean_text)

        # 6. Language Detection
        language = self._detect_language(clean_text)

        # 7. Spam & Toxicity Filtering
        is_spam, spam_score = self._detect_spam(clean_text, extracted_entities)
        is_toxic, toxicity_score = self._detect_toxicity(clean_text)

        # 8. Keywords Extraction
        keywords = self._extract_keywords(words)

        return AnalysisResult(
            intent=intent,
            confidence=round(confidence, 3),
            sentiment_score=round(sentiment_score, 3),
            sentiment_label=sentiment_label,
            urgency=urgency,
            urgency_score=round(urgency_score, 3),
            language=language,
            is_spam=is_spam,
            spam_score=round(spam_score, 3),
            is_toxic=is_toxic,
            toxicity_score=round(toxicity_score, 3),
            token_count=token_count,
            char_count=char_count,
            word_count=word_count,
            extracted_entities=extracted_entities,
            keywords=keywords,
        )

    def _extract_entities(
        self, text: str, entities: Optional[List[MessageEntity]]
    ) -> Dict[str, List[str]]:
        """Extracts crypto addresses, transaction hashes, tickers, amounts, URLs, mentions."""
        results: Dict[str, List[str]] = {
            "evm_addresses": [],
            "tx_hashes": [],
            "crypto_tickers": [],
            "fiat_amounts": [],
            "crypto_amounts": [],
            "percentages": [],
            "urls": [],
            "mentions": [],
            "hashtags": [],
        }

        # Telegram MessageEntities extraction
        if entities:
            for entity in entities:
                extracted = entity.extract_text(text)
                etype = entity.type.value if isinstance(entity.type, EntityType) else str(entity.type)
                if etype in (EntityType.URL.value, "url", EntityType.TEXT_LINK.value, "text_link"):
                    target_url = entity.url or extracted
                    if target_url not in results["urls"]:
                        results["urls"].append(target_url)
                elif etype in (EntityType.MENTION.value, "mention", EntityType.TEXT_MENTION.value, "text_mention"):
                    if extracted not in results["mentions"]:
                        results["mentions"].append(extracted)
                elif etype in (EntityType.HASHTAG.value, "hashtag"):
                    if extracted not in results["hashtags"]:
                        results["hashtags"].append(extracted)
                elif etype in (EntityType.CASHTAG.value, "cashtag"):
                    ticker = extracted.replace("$", "").upper()
                    if ticker not in results["crypto_tickers"]:
                        results["crypto_tickers"].append(ticker)

        # EVM addresses (40 hex chars after 0x)
        addr_matches = re.findall(r"\b(0x[a-fA-F0-9]{40})\b", text)
        for addr in addr_matches:
            if addr not in results["evm_addresses"]:
                results["evm_addresses"].append(addr)

        # Tx Hashes (64 hex chars after 0x)
        tx_matches = re.findall(r"\b(0x[a-fA-F0-9]{64})\b", text)
        for tx in tx_matches:
            if tx not in results["tx_hashes"]:
                results["tx_hashes"].append(tx)

        # Cashtags / Crypto Tickers
        cashtags = re.findall(r"\$([a-zA-Z0-9]{2,10})\b", text)
        for c in cashtags:
            upper_c = c.upper()
            if upper_c not in results["crypto_tickers"]:
                results["crypto_tickers"].append(upper_c)

        # Standalone known tickers
        for word in re.findall(r"\b[A-Za-z]{2,8}\b", text):
            up = word.upper()
            if up in self.known_tickers and up not in results["crypto_tickers"]:
                results["crypto_tickers"].append(up)

        # Fiat amounts ($100, $5.50, 100 USD, 50 EUR)
        fiat_matches = re.findall(r"(\$\s*[\d,]+(?:\.\d+)?|\b[\d,]+(?:\.\d+)?\s*(?:USD|USDT|USDC|EUR|GBP)\b)", text, re.IGNORECASE)
        for f in fiat_matches:
            cleaned = f.strip()
            if cleaned not in results["fiat_amounts"]:
                results["fiat_amounts"].append(cleaned)

        # Crypto amounts (0.5 ETH, 100.25 LUX, 10 BTC)
        crypto_amt_matches = re.findall(
            r"\b(\d+(?:\.\d+)?)\s*(" + "|".join(re.escape(t) for t in self.known_tickers) + r")\b",
            text,
            re.IGNORECASE,
        )
        for amt, ticker in crypto_amt_matches:
            entry = f"{amt} {ticker.upper()}"
            if entry not in results["crypto_amounts"]:
                results["crypto_amounts"].append(entry)

        # Percentages (+5%, -10.5%, 25%)
        pct_matches = re.findall(r"([+-]?\d+(?:\.\d+)?%)", text)
        for p in pct_matches:
            if p not in results["percentages"]:
                results["percentages"].append(p)

        # Generic URLs if not already caught by entities
        url_matches = re.findall(r"(https?://[^\s<>\"']+)", text)
        for u in url_matches:
            if u not in results["urls"]:
                results["urls"].append(u)

        return results

    def _classify_intent(
        self,
        text: str,
        entities: Optional[List[MessageEntity]],
        extracted: Dict[str, List[str]],
    ) -> Tuple[IntentCategory, float]:
        """Classifies intent using regex patterns, bot commands, and entity context."""
        # 1. Bot command check
        if text.startswith("/"):
            return IntentCategory.COMMAND, 1.0

        if entities:
            for e in entities:
                etype = e.type.value if isinstance(e.type, EntityType) else str(e.type)
                if etype in (EntityType.BOT_COMMAND.value, "bot_command") and e.offset == 0:
                    return IntentCategory.COMMAND, 1.0

        scores: Dict[IntentCategory, float] = {cat: 0.0 for cat in IntentCategory}

        # Entity bonuses
        if extracted.get("tx_hashes"):
            scores[IntentCategory.TRANSACTION] += 0.6
        if extracted.get("evm_addresses"):
            scores[IntentCategory.WALLET] += 0.4
        if extracted.get("crypto_amounts") or extracted.get("percentages"):
            scores[IntentCategory.TRADING] += 0.4

        # Pattern scoring
        lower_text = text.lower()
        for cat, patterns in INTENT_PATTERNS.items():
            for pat in patterns:
                matches = re.findall(pat, lower_text, re.IGNORECASE)
                if matches:
                    scores[cat] += len(matches) * 0.35

        # Determine best match
        best_cat = max(scores, key=lambda k: scores[k])
        best_score = scores[best_cat]

        if best_score >= 0.3:
            confidence = min(0.98, 0.4 + best_score * 0.3)
            return best_cat, confidence

        return IntentCategory.GENERAL, 0.4

    def _analyze_sentiment(self, text: str) -> Tuple[float, str]:
        """Calculates sentiment polarity (-1.0 to 1.0) and assigns a label."""
        lower_words = re.findall(r"\b[a-zA-Z]+\b", text.lower())
        if not lower_words:
            return 0.0, "neutral"

        pos_score = 0.0
        neg_score = 0.0

        for word in lower_words:
            if word in POSITIVE_WORDS:
                pos_score += POSITIVE_WORDS[word]
            elif word in NEGATIVE_WORDS:
                neg_score += abs(NEGATIVE_WORDS[word])

        total = pos_score + neg_score
        if total == 0:
            return 0.0, "neutral"

        polarity = (pos_score - neg_score) / (total + 0.5)
        # Clamp to [-1.0, 1.0]
        polarity = max(-1.0, min(1.0, polarity))

        if polarity > 0.15:
            label = "positive"
        elif polarity < -0.15:
            label = "negative"
        else:
            label = "neutral"

        return polarity, label

    def _assess_urgency(self, text: str) -> Tuple[UrgencyLevel, float]:
        """Assesses the urgency of a message."""
        lower = text.lower()
        score = 0.0

        # Keyword checks
        for kw, weight in URGENCY_KEYWORDS.items():
            if re.search(r"\b" + re.escape(kw) + r"\b", lower):
                score += weight

        # Exclamation marks
        exclamations = text.count("!")
        if exclamations >= 3:
            score += 0.3
        elif exclamations >= 1:
            score += 0.1

        # All-caps ratio for messages > 10 chars
        letters = [c for c in text if c.isalpha()]
        if len(letters) >= 10:
            upper_ratio = sum(1 for c in letters if c.isupper()) / len(letters)
            if upper_ratio > 0.7:
                score += 0.35

        score = min(1.0, score)

        if score >= 0.8:
            level = UrgencyLevel.CRITICAL
        elif score >= 0.55:
            level = UrgencyLevel.HIGH
        elif score >= 0.25:
            level = UrgencyLevel.MEDIUM
        else:
            level = UrgencyLevel.LOW

        return level, score

    def _detect_language(self, text: str) -> str:
        """Heuristic language detection (en, es, ru, zh, ja, fr, de, it, pt, ar)."""
        # Script checks
        if re.search(r"[\u0400-\u04FF]", text):
            return "ru"
        if re.search(r"[\u4E00-\u9FFF]", text):
            return "zh"
        if re.search(r"[\u3040-\u309F\u30A0-\u30FF]", text):
            return "ja"
        if re.search(r"[\u0600-\u06FF]", text):
            return "ar"

        lower = text.lower()
        # Spanish stop words
        if re.search(r"\b(el|la|los|las|de|que|en|un|una|por|para|con|como)\b", lower):
            if re.search(r"\b(hola|gracias|comprar|vender|precio|cuenta|ayuda)\b", lower):
                return "es"

        # French stop words
        if re.search(r"\b(le|la|les|des|du|que|dans|pour|avec|bonjour|merci)\b", lower):
            return "fr"

        # German stop words
        if re.search(r"\b(der|die|das|und|nicht|ein|eine|mit|hallo|danke|kaufen)\b", lower):
            return "de"

        # Default fallback
        return "en"

    def _detect_spam(
        self, text: str, extracted_entities: Dict[str, List[str]]
    ) -> Tuple[bool, float]:
        """Detects spam or scam intent."""
        score = 0.0
        lower = text.lower()

        # Spam pattern matches
        for pat, weight in SPAM_PATTERNS:
            if re.search(pat, lower):
                score += weight

        # Excessive links or mentions
        if len(extracted_entities.get("urls", [])) >= 3:
            score += 0.3
        if len(extracted_entities.get("mentions", [])) >= 4:
            score += 0.35

        # Repeated characters (e.g. "freeeeeeeee")
        if re.search(r"(.)\1{5,}", text):
            score += 0.2

        score = min(1.0, score)
        return score >= 0.6, score

    def _detect_toxicity(self, text: str) -> Tuple[bool, float]:
        """Detects abusive, toxic, or offensive text."""
        score = 0.0
        lower = text.lower()

        for pat, weight in TOXIC_PATTERNS:
            if re.search(pat, lower):
                score += weight

        score = min(1.0, score)
        return score >= 0.5, score

    def _extract_keywords(self, words: List[str]) -> List[str]:
        """Extracts significant keywords excluding common English stop words."""
        stop_words = {
            "a", "about", "above", "after", "again", "against", "all", "am", "an",
            "and", "any", "are", "as", "at", "be", "because", "been", "before",
            "being", "below", "between", "both", "but", "by", "could", "did", "do",
            "does", "doing", "down", "during", "each", "few", "for", "from", "further",
            "had", "has", "have", "having", "he", "her", "here", "hers", "herself",
            "him", "himself", "his", "how", "i", "if", "in", "into", "is", "it",
            "its", "itself", "just", "me", "more", "most", "my", "myself", "no",
            "nor", "not", "of", "off", "on", "once", "only", "or", "other", "ought",
            "our", "ours", "ourselves", "out", "over", "own", "same", "she", "should",
            "so", "some", "such", "than", "that", "the", "their", "theirs", "them",
            "themselves", "then", "there", "these", "they", "this", "those", "through",
            "to", "too", "under", "until", "up", "very", "was", "we", "were", "what",
            "when", "where", "which", "while", "who", "whom", "why", "with", "would",
            "you", "your", "yours", "yourself", "yourselves"
        }

        keywords: List[str] = []
        for w in words:
            lw = w.lower()
            if len(lw) >= 3 and lw not in stop_words and lw not in keywords:
                keywords.append(lw)
            if len(keywords) >= 10:
                break

        return keywords

"""
youtube_community_prisms.analysis — deterministic, dependency-free text analysis.

Implements the analytical features required by lux issue #70 without any
third-party dependency or network call:

  * Sentiment analysis      — a lexicon-based classifier (positive/negative/
                              neutral) with negation handling and emoji cues.
  * Spam detection          — a rule engine (caps ratio, link density, repeated
                              tokens, banned phrases, contact-info solicitation).
  * Response generation     — template-driven reply suggestions conditioned on
                              sentiment and detected intent (question, praise,
                              complaint, spam).

All functions are pure and unit-testable.
"""

from __future__ import annotations

import re
from typing import Any, Dict, List, Optional, Tuple

__all__ = [
    "analyze_sentiment",
    "detect_spam",
    "generate_response",
    "score_to_label",
    "POSITIVE_WORDS",
    "NEGATIVE_WORDS",
]

# --------------------------------------------------------------------------- #
# Lexicons
# --------------------------------------------------------------------------- #
POSITIVE_WORDS = {
    "love", "loved", "lovely", "great", "awesome", "amazing", "excellent",
    "good", "best", "perfect", "fantastic", "wonderful", "brilliant",
    "thanks", "thank", "helpful", "nice", "cool", "beautiful", "incredible",
    "outstanding", "superb", "enjoy", "enjoyed", "happy", "glad", "fun",
    "recommend", "inspiring", "inspired", "impressive", "wow", "kudos",
    "appreciate", "appreciated", "epic", "solid", "clean", "clear",
}

NEGATIVE_WORDS = {
    "hate", "hated", "terrible", "awful", "bad", "worst", "horrible",
    "boring", "disappointed", "disappointing", "useless", "stupid", "dumb",
    "waste", "wasted", "poor", "sad", "angry", "annoying", "annoyed",
    "broken", "wrong", "fail", "failed", "garbage", "trash", "scam",
    "fraud", "misleading", "clickbait", "pathetic", "ridiculous", "lame",
    "slow", "confusing", "overrated", "problem", "issue", "bug",
}

NEGATIONS = {"not", "no", "never", "none", "nobody", "nothing", "neither",
             "cannot", "can't", "don't", "doesn't", "didn't", "isn't",
             "wasn't", "aren't", "weren't", "won't", "wouldn't", "hardly"}

#: Words that, when present, mark a comment as a question.
QUESTION_STARTERS = {"how", "what", "why", "when", "where", "who", "which",
                     "can", "could", "should", "would", "is", "are", "do",
                     "does", "did", "will"}

#: Phrases strongly associated with spam / self-promotion.
SPAM_PHRASES = [
    "buy now", "click here", "subscribe to my", "check out my channel",
    "visit my", "follow me", "dm me", "whatsapp", "telegram me",
    "make money", "earn cash", "get rich", "free money", "crypto giveaway",
    "you won", "you have won", "claim your prize", "limited time offer",
    "act now", "100% free", "work from home", "guaranteed income",
    "click the link in my bio", "sub4sub", "sub for sub",
]

#: Regex for URLs / handles / contact info.
_URL_RE = re.compile(r"https?://\S+|www\.\S+|t\.me/\S+", re.IGNORECASE)
_HANDLE_RE = re.compile(r"(^|\s)@[A-Za-z0-9_]{3,}")
_PHONE_RE = re.compile(r"\+?\d[\d\s().-]{7,}\d")
_EMAIL_RE = re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.-]+\b")

_EMOJI_POSITIVE = ("❤", "😍", "🥰", "👍", "🔥", "💯", "👏", "😊", "😁", "🎉")
_EMOJI_NEGATIVE = ("😡", "😠", "👎", "💔", "😢", "😠", "🤬", "😒")

_TOKEN_RE = re.compile(r"[A-Za-z']+")
_WORD_RE = re.compile(r"[A-Za-z']+")


# --------------------------------------------------------------------------- #
# Sentiment
# --------------------------------------------------------------------------- #
def _tokenize(text: str) -> List[str]:
    return _TOKEN_RE.findall(text.lower())


def score_to_label(score: float) -> str:
    """Map a normalised sentiment score in [-1, 1] to a label."""
    if score >= 0.15:
        return "positive"
    if score <= -0.15:
        return "negative"
    return "neutral"


def analyze_sentiment(text: str) -> Dict[str, Any]:
    """Classify ``text`` into positive/negative/neutral.

    Returns a dict with ``label``, ``score`` (in ``[-1, 1]``), ``confidence``
    and the matched ``positive`` / ``negative`` tokens. Negations flip the
    polarity of the immediately following token.
    """
    if not text:
        return {"label": "neutral", "score": 0.0, "confidence": 0.0,
                "positive": [], "negative": []}

    tokens = _tokenize(text)
    pos_hits: List[str] = []
    neg_hits: List[str] = []
    score = 0.0
    negate_next = False

    for tok in tokens:
        if tok in NEGATIONS:
            negate_next = True
            continue
        if tok in POSITIVE_WORDS:
            if negate_next:
                score -= 1.0
                neg_hits.append(tok)
            else:
                score += 1.0
                pos_hits.append(tok)
            negate_next = False
        elif tok in NEGATIVE_WORDS:
            if negate_next:
                score += 1.0
                pos_hits.append(tok)
            else:
                score -= 1.0
                neg_hits.append(tok)
            negate_next = False
        else:
            negate_next = False

    # Emoji cues.
    for emo in _EMOJI_POSITIVE:
        if emo in text:
            score += 1.0
            pos_hits.append(emo)
    for emo in _EMOJI_NEGATIVE:
        if emo in text:
            score -= 1.0
            neg_hits.append(emo)

    # Exclamation emphasis (mild).
    if "!" in text and score != 0.0:
        score += 0.2 if score > 0 else -0.2

    n = max(1, len(tokens))
    normalised = max(-1.0, min(1.0, score / (n ** 0.5)))
    label = score_to_label(normalised)
    confidence = min(1.0, abs(normalised) + 0.05 * (len(pos_hits) + len(neg_hits)))
    return {
        "label": label,
        "score": round(normalised, 4),
        "confidence": round(confidence, 4),
        "positive": pos_hits,
        "negative": neg_hits,
    }


# --------------------------------------------------------------------------- #
# Spam detection
# --------------------------------------------------------------------------- #
def detect_spam(text: str, banned_phrases: Optional[List[str]] = None,
                max_links: int = 2) -> Dict[str, Any]:
    """Score ``text`` for spam likelihood.

    Returns ``{"spam": bool, "score": float, "reasons": [...]}`` where
    ``score`` is in ``[0, 1]``. A score >= 0.5 is classified as spam.
    """
    if not text:
        return {"spam": False, "score": 0.0, "reasons": []}

    lowered = text.lower()
    reasons: List[str] = []
    score = 0.0

    # 1. ALL-CAPS shouting.
    letters = [c for c in text if c.isalpha()]
    if len(letters) >= 8:
        caps_ratio = sum(1 for c in letters if c.isupper()) / len(letters)
        if caps_ratio > 0.7:
            score += 0.25
            reasons.append("excessive_caps")

    # 2. Link density.
    links = _URL_RE.findall(text)
    if len(links) > max_links:
        score += 0.3
        reasons.append("too_many_links")
    elif links:
        score += 0.1
        reasons.append("contains_link")

    # 3. Contact solicitation.
    if _EMAIL_RE.search(text) or _PHONE_RE.search(text):
        score += 0.25
        reasons.append("contact_info")
    if _HANDLE_RE.search(text):
        score += 0.1
        reasons.append("mentions_handle")

    # 4. Banned / spam phrases.
    phrase_hits = [p for p in (banned_phrases or SPAM_PHRASES) if p in lowered]
    if phrase_hits:
        score += min(0.5, 0.2 * len(phrase_hits))
        reasons.append("spam_phrases")

    # 5. Repeated tokens (e.g. "buy buy buy buy").
    tokens = _WORD_RE.findall(lowered)
    if tokens:
        counts: Dict[str, int] = {}
        for t in tokens:
            counts[t] = counts.get(t, 0) + 1
        top = max(counts.values())
        if top >= 5 and len(tokens) >= 8:
            score += 0.2
            reasons.append("repeated_tokens")

    # 6. Excessive exclamation / emoji spam.
    if text.count("!") >= 5:
        score += 0.15
        reasons.append("excessive_exclamation")

    score = max(0.0, min(1.0, score))
    return {"spam": score >= 0.5, "score": round(score, 4), "reasons": reasons}


# --------------------------------------------------------------------------- #
# Response generation
# --------------------------------------------------------------------------- #
def _detect_intent(text: str) -> str:
    lowered = text.lower().strip()
    if not lowered:
        return "neutral"
    first = _WORD_RE.findall(lowered)
    if lowered.endswith("?") or (first and first[0] in QUESTION_STARTERS):
        return "question"
    if any(w in lowered for w in ("thanks", "thank you", "appreciate", "love it")):
        return "praise"
    if any(w in lowered for w in ("hate", "terrible", "awful", "worst", "scam",
                                   "disappointed", "broken", "clickbait")):
        return "complaint"
    return "neutral"


def generate_response(text: str, sentiment: Optional[Dict[str, Any]] = None,
                      creator_name: str = "the team",
                      include_emoji: bool = True) -> Dict[str, Any]:
    """Generate a suggested reply for ``text``.

    Returns ``{"reply": str, "intent": str, "sentiment": str}``. The reply is
    deterministic (template based) so it is fully unit-testable and requires no
    LLM call.
    """
    sentiment = sentiment or analyze_sentiment(text)
    intent = _detect_intent(text)
    label = sentiment.get("label", "neutral")
    emoji = " 🙏" if include_emoji else ""

    if intent == "question":
        reply = (f"Great question! Thanks for reaching out — we'll look into "
                 f"this and follow up with more details soon.{emoji}")
    elif intent == "complaint" or label == "negative":
        reply = (f"We're really sorry to hear you had a rough experience. "
                 f"That's not what we want for you — please reach out to us "
                 f"directly so we can make it right.{emoji}")
    elif intent == "praise" or label == "positive":
        reply = (f"Thank you so much for the kind words! We're thrilled you're "
                 f"enjoying the content — it means a lot to {creator_name}.{emoji}")
    else:
        reply = (f"Thanks for watching and being part of the community! "
                 f"Let us know if there's anything you'd like to see next.{emoji}")

    return {"reply": reply, "intent": intent, "sentiment": label}
"""
Base Connector, Rate Limiter, Retry Logic, and Circuit Breaker for NFT Marketplaces.
"""

from __future__ import annotations

import abc
import asyncio
import logging
import random
import threading
import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Callable, Dict, List, Optional, Tuple, TypeVar, Union
import json
import urllib.request
import urllib.error
import urllib.parse

from lux.nft.types import (
    CollectionStats,
    FloorPriceQuote,
    InvalidResponseError,
    Marketplace,
    MarketplaceAuthenticationError,
    MarketplaceUnavailableError,
    NFTMarketplaceError,
    RateLimitExceededError,
    ResourceNotFoundError,
    SaleEvent,
    TokenMetadata,
    ValidationError,
)

logger = logging.getLogger(__name__)

T = TypeVar("T")


class CircuitState(str, Enum):
    CLOSED = "CLOSED"        # Normal operations
    OPEN = "OPEN"            # Fast-failing, downstream service is broken
    HALF_OPEN = "HALF_OPEN"  # Testing downstream service recovery


@dataclass
class CircuitBreakerConfig:
    failure_threshold: int = 5
    recovery_timeout: float = 30.0  # seconds to wait before probing
    half_open_success_threshold: int = 2


class CircuitBreaker:
    """Thread-safe circuit breaker preventing cascading failures."""

    def __init__(self, name: str, config: Optional[CircuitBreakerConfig] = None):
        self.name = name
        self.config = config or CircuitBreakerConfig()
        self._state = CircuitState.CLOSED
        self._failure_count = 0
        self._consecutive_successes = 0
        self._last_state_change = time.time()
        self._lock = threading.RLock()

    @property
    def state(self) -> CircuitState:
        with self._lock:
            if self._state == CircuitState.OPEN:
                if time.time() - self._last_state_change >= self.config.recovery_timeout:
                    logger.info(f"CircuitBreaker [{self.name}]: Recovery timeout elapsed. Transitioning to HALF_OPEN.")
                    self._state = CircuitState.HALF_OPEN
                    self._consecutive_successes = 0
            return self._state

    def record_success(self) -> None:
        with self._lock:
            if self._state == CircuitState.HALF_OPEN:
                self._consecutive_successes += 1
                if self._consecutive_successes >= self.config.half_open_success_threshold:
                    logger.info(f"CircuitBreaker [{self.name}]: Probes succeeded. Closing circuit.")
                    self._state = CircuitState.CLOSED
                    self._failure_count = 0
                    self._consecutive_successes = 0
            elif self._state == CircuitState.CLOSED:
                self._failure_count = 0

    def record_failure(self) -> None:
        with self._lock:
            self._failure_count += 1
            if self._state == CircuitState.HALF_OPEN or self._failure_count >= self.config.failure_threshold:
                logger.warning(
                    f"CircuitBreaker [{self.name}]: Tripped to OPEN. Failures: {self._failure_count}"
                )
                self._state = CircuitState.OPEN
                self._last_state_change = time.time()

    def allow_request(self) -> bool:
        return self.state != CircuitState.OPEN


class TokenBucketRateLimiter:
    """
    High-precision Token Bucket Rate Limiter with thread-safety and jitter.
    Supports bursts and steady refill rate per second.
    """

    def __init__(self, requests_per_second: float = 5.0, burst_capacity: Optional[float] = None):
        self.rate = max(0.1, requests_per_second)
        self.capacity = burst_capacity if burst_capacity is not None else max(1.0, requests_per_second * 2)
        self.tokens = self.capacity
        self.last_update = time.time()
        self._lock = threading.RLock()

    def _refill(self) -> None:
        now = time.time()
        elapsed = now - self.last_update
        if elapsed > 0:
            self.tokens = min(self.capacity, self.tokens + elapsed * self.rate)
            self.last_update = now

    def acquire(self, tokens: float = 1.0, max_wait: float = 10.0) -> bool:
        """Blocks until a token is available or max_wait is exceeded."""
        start = time.time()
        while True:
            with self._lock:
                self._refill()
                if self.tokens >= tokens:
                    self.tokens -= tokens
                    return True
                
                # Calculate sleep duration needed
                needed = tokens - self.tokens
                sleep_time = needed / self.rate

            if time.time() - start + sleep_time > max_wait:
                return False

            time.sleep(min(sleep_time, 0.05))

    async def acquire_async(self, tokens: float = 1.0, max_wait: float = 10.0) -> bool:
        """Asynchronous token acquisition."""
        start = time.time()
        while True:
            with self._lock:
                self._refill()
                if self.tokens >= tokens:
                    self.tokens -= tokens
                    return True
                needed = tokens - self.tokens
                sleep_time = needed / self.rate

            if time.time() - start + sleep_time > max_wait:
                return False

            await asyncio.sleep(min(sleep_time, 0.05))

    def update_rate(self, new_rps: float) -> None:
        with self._lock:
            self.rate = max(0.1, new_rps)
            self.capacity = max(1.0, new_rps * 2)
            self.tokens = min(self.tokens, self.capacity)


@dataclass
class RetryConfig:
    max_retries: int = 3
    base_delay: float = 0.5
    max_delay: float = 10.0
    backoff_factor: float = 2.0
    jitter: bool = True
    retryable_status_codes: Tuple[int, ...] = (429, 500, 502, 503, 504)


class BaseMarketplaceConnector(abc.ABC):
    """
    Abstract Base Connector providing unified rate limiting, exponential backoff retries,
    circuit breaker patterns, and error normalization for NFT marketplaces.
    """

    def __init__(
        self,
        marketplace: Marketplace,
        base_url: str,
        api_key: Optional[str] = None,
        requests_per_second: float = 5.0,
        retry_config: Optional[RetryConfig] = None,
        circuit_breaker_config: Optional[CircuitBreakerConfig] = None,
        timeout: float = 15.0,
        custom_http_client: Optional[Callable[..., Any]] = None,
    ):
        self.marketplace = marketplace
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.timeout = timeout
        self.rate_limiter = TokenBucketRateLimiter(requests_per_second=requests_per_second)
        self.retry_config = retry_config or RetryConfig()
        self.circuit_breaker = CircuitBreaker(marketplace.value, circuit_breaker_config)
        self._custom_http_client = custom_http_client

    @abc.abstractmethod
    def get_headers(self) -> Dict[str, str]:
        """Returns standard headers including authentication."""
        pass

    @abc.abstractmethod
    def get_floor_price(self, collection_address: str) -> FloorPriceQuote:
        """Fetches the current floor price for a collection."""
        pass

    @abc.abstractmethod
    def get_collection_stats(self, collection_address: str) -> CollectionStats:
        """Fetches collection-level trading and volume metrics."""
        pass

    @abc.abstractmethod
    def get_recent_sales(
        self, collection_address: str, limit: int = 50, cursor: Optional[str] = None
    ) -> List[SaleEvent]:
        """Fetches recent normalized sales events."""
        pass

    @abc.abstractmethod
    def get_token_metadata(self, collection_address: str, token_id: str) -> TokenMetadata:
        """Fetches metadata and trait attributes for a specific token."""
        pass

    def health_check(self) -> Dict[str, Any]:
        """Returns the health status, circuit breaker state, and configuration."""
        return {
            "marketplace": self.marketplace.value,
            "circuit_state": self.circuit_breaker.state.value,
            "has_api_key": bool(self.api_key),
            "requests_per_second": self.rate_limiter.rate,
            "base_url": self.base_url,
        }

    def _calculate_backoff(self, attempt: int, retry_after: Optional[float] = None) -> float:
        if retry_after is not None and retry_after > 0:
            return min(retry_after, self.retry_config.max_delay)

        delay = self.retry_config.base_delay * (self.retry_config.backoff_factor ** attempt)
        if self.retry_config.jitter:
            delay += random.uniform(0, 0.25 * delay)
        return min(delay, self.retry_config.max_delay)

    def request(
        self,
        endpoint: str,
        params: Optional[Dict[str, Any]] = None,
        headers: Optional[Dict[str, str]] = None,
        method: str = "GET",
        payload: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Executes an HTTP request with circuit breaker, rate limiting, and exponential retry backoff.
        """
        if not self.circuit_breaker.allow_request():
            raise MarketplaceUnavailableError(
                f"Circuit breaker is OPEN for {self.marketplace.value}. Downstream requests blocked.",
                marketplace=self.marketplace.value,
            )

        if not self.rate_limiter.acquire(max_wait=self.timeout):
            raise RateLimitExceededError(
                f"Client-side rate limit timeout for {self.marketplace.value}",
                marketplace=self.marketplace.value,
            )

        # Build full URL
        clean_endpoint = endpoint.lstrip("/")
        url = f"{self.base_url}/{clean_endpoint}"
        if params:
            clean_params = {k: v for k, v in params.items() if v is not None}
            url = f"{url}?{urllib.parse.urlencode(clean_params)}"

        req_headers = self.get_headers()
        if headers:
            req_headers.update(headers)

        body_bytes = None
        if payload is not None:
            body_bytes = json.dumps(payload).encode("utf-8")
            req_headers["Content-Type"] = "application/json"

        last_exception: Optional[Exception] = None

        for attempt in range(self.retry_config.max_retries + 1):
            try:
                # Custom HTTP client hook for mocking / testing or custom sessions
                if self._custom_http_client:
                    response_data = self._custom_http_client(
                        url=url,
                        method=method,
                        headers=req_headers,
                        data=body_bytes,
                        timeout=self.timeout,
                    )
                    self.circuit_breaker.record_success()
                    return response_data

                # Default standard library HTTP client
                req = urllib.request.Request(url, data=body_bytes, headers=req_headers, method=method)
                with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                    status_code = resp.status
                    raw_content = resp.read().decode("utf-8")

                    if not raw_content:
                        self.circuit_breaker.record_success()
                        return {}

                    try:
                        data = json.loads(raw_content)
                    except json.JSONDecodeError as jde:
                        raise InvalidResponseError(
                            f"Failed to parse JSON response from {self.marketplace.value}: {jde}",
                            marketplace=self.marketplace.value,
                        )

                    self.circuit_breaker.record_success()
                    return data

            except urllib.error.HTTPError as he:
                status_code = he.code
                error_body = ""
                try:
                    error_body = he.read().decode("utf-8")
                except Exception:
                    pass

                retry_after = None
                if "Retry-After" in he.headers:
                    try:
                        retry_after = float(he.headers["Retry-After"])
                    except ValueError:
                        pass

                if status_code == 401 or status_code == 403:
                    self.circuit_breaker.record_failure()
                    raise MarketplaceAuthenticationError(
                        f"Authentication failed for {self.marketplace.value} (HTTP {status_code}): {error_body}",
                        marketplace=self.marketplace.value,
                    )

                if status_code == 404:
                    raise ResourceNotFoundError(
                        f"Resource not found on {self.marketplace.value} (HTTP 404): {url}",
                        marketplace=self.marketplace.value,
                    )

                if status_code in self.retry_config.retryable_status_codes:
                    if attempt < self.retry_config.max_retries:
                        backoff = self._calculate_backoff(attempt, retry_after)
                        logger.warning(
                            f"[{self.marketplace.value}] HTTP {status_code}. Retrying in {backoff:.2f}s (Attempt {attempt+1}/{self.retry_config.max_retries})"
                        )
                        time.sleep(backoff)
                        continue
                    else:
                        self.circuit_breaker.record_failure()
                        if status_code == 429:
                            raise RateLimitExceededError(
                                f"Rate limit exceeded on {self.marketplace.value} after {self.retry_config.max_retries} retries",
                                retry_after=retry_after or 5.0,
                                marketplace=self.marketplace.value,
                            )
                        raise MarketplaceUnavailableError(
                            f"{self.marketplace.value} server error (HTTP {status_code}): {error_body}",
                            marketplace=self.marketplace.value,
                        )

                self.circuit_breaker.record_failure()
                raise NFTMarketplaceError(
                    f"HTTP Error {status_code} from {self.marketplace.value}: {error_body}",
                    marketplace=self.marketplace.value,
                )

            except (urllib.error.URLError, TimeoutError, ConnectionError) as net_err:
                last_exception = net_err
                if attempt < self.retry_config.max_retries:
                    backoff = self._calculate_backoff(attempt)
                    logger.warning(
                        f"[{self.marketplace.value}] Network error ({net_err}). Retrying in {backoff:.2f}s"
                    )
                    time.sleep(backoff)
                    continue
                else:
                    self.circuit_breaker.record_failure()
                    raise MarketplaceUnavailableError(
                        f"Network connection failed for {self.marketplace.value}: {net_err}",
                        marketplace=self.marketplace.value,
                    )

            except NFTMarketplaceError:
                self.circuit_breaker.record_failure()
                raise
            except Exception as ex:
                self.circuit_breaker.record_failure()
                raise NFTMarketplaceError(
                    f"Unexpected error communicating with {self.marketplace.value}: {ex}",
                    marketplace=self.marketplace.value,
                )

        self.circuit_breaker.record_failure()
        raise MarketplaceUnavailableError(
            f"Failed to complete request to {self.marketplace.value} after max retries: {last_exception}",
            marketplace=self.marketplace.value,
        )

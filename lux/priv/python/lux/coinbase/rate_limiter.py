"""
Thread-safe Token Bucket Rate Limiter with Exponential Backoff and Jitter.

Designed for Coinbase Advanced Trade REST and WebSocket interactions with
distinct rate limits for Public (10 req/s, burst 15) and Private (30 req/s, burst 50) endpoints.
"""

import contextlib
import random
import threading
import time
from typing import Generator, Optional


class TokenBucket:
    """Thread-safe Token Bucket algorithm implementation."""

    def __init__(self, rate: float, capacity: float):
        """
        Args:
            rate: Token refill rate (tokens added per second).
            capacity: Maximum token capacity (burst size).
        """
        self.rate = float(rate)
        self.capacity = float(capacity)
        self.tokens = float(capacity)
        self.last_update = time.monotonic()
        self.lock = threading.Lock()

    def _refill(self) -> None:
        """Internal refill calculation based on elapsed monotonic time."""
        now = time.monotonic()
        elapsed = now - self.last_update
        self.last_update = now
        self.tokens = min(self.capacity, self.tokens + elapsed * self.rate)

    def try_acquire(self, tokens: float = 1.0) -> bool:
        """
        Attempt to acquire tokens without blocking.
        
        Returns:
            True if tokens were acquired, False otherwise.
        """
        with self.lock:
            self._refill()
            if self.tokens >= tokens:
                self.tokens -= tokens
                return True
            return False

    def acquire(self, tokens: float = 1.0, timeout: Optional[float] = None) -> float:
        """
        Acquire tokens, blocking if necessary until available or until timeout.
        
        Args:
            tokens: Number of tokens requested.
            timeout: Maximum wait time in seconds (None for infinite).
            
        Returns:
            Total wait time in seconds.
            
        Raises:
            TimeoutError: If timeout is reached before tokens become available.
        """
        start_time = time.monotonic()
        while True:
            with self.lock:
                self._refill()
                if self.tokens >= tokens:
                    self.tokens -= tokens
                    return time.monotonic() - start_time

                # Calculate required sleep duration
                needed = tokens - self.tokens
                wait_time = needed / self.rate

            # Check timeout
            if timeout is not None:
                elapsed = time.monotonic() - start_time
                if elapsed + wait_time > timeout:
                    raise TimeoutError(f"Rate limit timeout: needed {wait_time:.3f}s but timeout is {timeout:.3f}s")

            time.sleep(min(wait_time, 0.05))


class CoinbaseRateLimiter:
    """
    Dual-Bucket Rate Limiter for Coinbase API endpoints.
    
    - Public endpoints: 10 requests / second (burst capacity 15)
    - Private / Trading endpoints: 30 requests / second (burst capacity 50)
    """

    def __init__(
        self,
        public_rate: float = 10.0,
        public_burst: float = 15.0,
        private_rate: float = 30.0,
        private_burst: float = 50.0,
    ):
        self.public_bucket = TokenBucket(rate=public_rate, capacity=public_burst)
        self.private_bucket = TokenBucket(rate=private_rate, capacity=private_burst)

    def acquire(
        self,
        endpoint_type: str = "private",
        tokens: float = 1.0,
        timeout: Optional[float] = 30.0,
    ) -> float:
        """
        Acquire tokens for the specified endpoint category.
        
        Args:
            endpoint_type: 'public' or 'private' (default 'private')
            tokens: Number of tokens
            timeout: Timeout in seconds
            
        Returns:
            Time waited in seconds.
        """
        bucket = self.public_bucket if endpoint_type.lower() == "public" else self.private_bucket
        return bucket.acquire(tokens=tokens, timeout=timeout)

    @contextlib.contextmanager
    def limit(
        self,
        endpoint_type: str = "private",
        tokens: float = 1.0,
        timeout: Optional[float] = 30.0,
    ) -> Generator[float, None, None]:
        """Context manager for automatic rate limiting before execution."""
        waited = self.acquire(endpoint_type=endpoint_type, tokens=tokens, timeout=timeout)
        try:
            yield waited
        finally:
            pass

    def calculate_backoff(
        self,
        attempt: int,
        base_delay: float = 0.5,
        max_delay: float = 30.0,
        retry_after: Optional[float] = None,
    ) -> float:
        """
        Calculate backoff delay using full jitter exponential algorithm or Retry-After header.
        
        Args:
            attempt: Current retry attempt number (1-based).
            base_delay: Initial base delay in seconds.
            max_delay: Cap for backoff duration.
            retry_after: Explicit delay specified in server HTTP 429 response.
            
        Returns:
            Delay duration in seconds.
        """
        if retry_after is not None and retry_after > 0:
            # Add small random jitter (0 - 100ms) to server-provided Retry-After
            return retry_after + random.uniform(0.01, 0.1)

        exp_backoff = min(max_delay, base_delay * (2 ** (attempt - 1)))
        # Full jitter: uniform between 0 and exp_backoff
        jittered_delay = random.uniform(0.0, exp_backoff)
        return max(base_delay / 2.0, jittered_delay)

    def backoff_sleep(
        self,
        attempt: int,
        base_delay: float = 0.5,
        max_delay: float = 30.0,
        retry_after: Optional[float] = None,
    ) -> float:
        """Calculate backoff delay and perform sleep."""
        delay = self.calculate_backoff(attempt, base_delay, max_delay, retry_after)
        time.sleep(delay)
        return delay

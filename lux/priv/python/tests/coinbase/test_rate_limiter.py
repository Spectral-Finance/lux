"""
Unit tests for TokenBucket Rate Limiter and Exponential Backoff.
"""

from concurrent.futures import ThreadPoolExecutor
import time
import pytest

from lux.coinbase.rate_limiter import CoinbaseRateLimiter, TokenBucket


def test_token_bucket_initial_capacity():
    bucket = TokenBucket(rate=10.0, capacity=10.0)
    assert bucket.try_acquire(5.0) is True
    assert bucket.try_acquire(5.0) is True
    # Bucket should now be exhausted
    assert bucket.try_acquire(1.0) is False


def test_token_bucket_refill():
    bucket = TokenBucket(rate=100.0, capacity=10.0)
    assert bucket.try_acquire(10.0) is True
    assert bucket.try_acquire(1.0) is False

    # Sleep 0.05s -> refills 5 tokens
    time.sleep(0.06)
    assert bucket.try_acquire(3.0) is True


def test_token_bucket_acquire_timeout():
    bucket = TokenBucket(rate=1.0, capacity=1.0)
    bucket.acquire(1.0)

    # Attempting to acquire 10 tokens with 0.01s timeout should raise TimeoutError
    with pytest.raises(TimeoutError):
        bucket.acquire(10.0, timeout=0.01)


def test_concurrency_thread_safety():
    bucket = TokenBucket(rate=200.0, capacity=50.0)
    acquired_count = 0

    def worker():
        nonlocal acquired_count
        if bucket.try_acquire(1.0):
            acquired_count += 1

    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(worker) for _ in range(50)]
        for f in futures:
            f.result()

    assert acquired_count == 50


def test_coinbase_rate_limiter_buckets():
    limiter = CoinbaseRateLimiter(public_rate=10.0, public_burst=15.0, private_rate=30.0, private_burst=50.0)
    
    assert limiter.public_bucket.capacity == 15.0
    assert limiter.private_bucket.capacity == 50.0

    # Acquire public token
    waited = limiter.acquire(endpoint_type="public", tokens=1.0)
    assert waited >= 0.0

    # Test context manager
    with limiter.limit(endpoint_type="private") as w:
        assert w >= 0.0


def test_backoff_calculation():
    limiter = CoinbaseRateLimiter()

    # Retry-After provided
    delay = limiter.calculate_backoff(attempt=1, retry_after=2.0)
    assert 2.0 <= delay <= 2.2

    # Exponential backoff with jitter
    d1 = limiter.calculate_backoff(attempt=1, base_delay=0.1)
    d3 = limiter.calculate_backoff(attempt=4, base_delay=0.1)
    assert d1 >= 0.05
    assert d3 <= 30.0

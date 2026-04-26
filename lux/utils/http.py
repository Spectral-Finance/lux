"""HTTP utilities with retry logic."""
import asyncio
import logging
import random
from functools import wraps
from typing import Any, Callable, Dict

import aiohttp

logger = logging.getLogger(__name__)

AsyncFn = Callable[..., Any]


def with_retry(
    max_retries: int = 3,
    backoff_base: float = 1.0,
    backoff_factor: float = 0.1,
    jitter: bool = True,
    retryable_exceptions: tuple = (aiohttp.ClientResponseError,),
):
    """
    Decorator to add retry logic with exponential backoff.

    Handles rate limiting (429) and transient network errors.
    """
    def decorator(func: AsyncFn) -> AsyncFn:
        @wraps(func)
        async def wrapper(*args, **kwargs):
            last_exception = None

            for attempt in range(max_retries + 1):
                try:
                    return await func(*args, **kwargs)
                except retryable_exceptions as e:
                    last_exception = e
                    if attempt >= max_retries:
                        break

                    # Check if it's a 429 rate limit
                    if isinstance(e, aiohttp.ClientResponseError) and e.status == 429:
                        base_delay = backoff_base
                    else:
                        base_delay = backoff_base * (2 ** attempt)

                    if jitter:
                        base_delay *= random.uniform(1 - backoff_factor, 1 + backoff_factor)

                    logger.warning(
                        f"Retry {attempt + 1}/{max_retries + 1} after {base_delay:.2f}s "
                        f"for {func.__name__}: {e}"
                    )
                    await asyncio.sleep(base_delay)
                    continue
                except Exception as e:
                    logger.error(f"Non-retryable error in {func.__name__}: {e}")
                    raise

            logger.error(f"Failed after {max_retries + 1} attempts: {last_exception}")
            raise last_exception

        return wrapper

    return decorator


async def create_session() -> aiohttp.ClientSession:
    """Create HTTP session with default timeouts and headers."""
    timeout = aio
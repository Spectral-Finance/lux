"""
Coinbase Advanced Trade Production REST API Client.

Provides synchronous HTTP client with session pooling, rate limiting,
cryptographic authentication, automatic retries, and comprehensive error wrapping.
"""

from datetime import datetime
import json
import logging
from typing import Any, Dict, List, Optional, Union
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from lux.coinbase.auth import CoinbaseAuth
from lux.coinbase.rate_limiter import CoinbaseRateLimiter
from lux.coinbase.types import (
    AccountBalance,
    Candle,
    CancelOrderResponse,
    Granularity,
    Order,
    OrderPlacementRequest,
    OrderStatus,
    OrderType,
    PortfolioSummary,
    Product,
    Ticker,
)

logger = logging.getLogger(__name__)


# ============================================================================
# Exceptions
# ============================================================================

class CoinbaseAPIError(Exception):
    """Base exception for all Coinbase API errors."""
    def __init__(self, message: str, status_code: Optional[int] = None, response_body: Optional[Any] = None):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.response_body = response_body

    def __str__(self) -> str:
        return f"[HTTP {self.status_code}] {self.message}" if self.status_code else self.message


class CoinbaseAuthError(CoinbaseAPIError):
    """Authentication or signature validation failure (HTTP 401 / 403)."""
    pass


class CoinbaseRateLimitError(CoinbaseAPIError):
    """Rate limit exceeded error (HTTP 429)."""
    def __init__(self, message: str, retry_after: Optional[float] = None, response_body: Optional[Any] = None):
        super().__init__(message, status_code=429, response_body=response_body)
        self.retry_after = retry_after


class CoinbaseNotFoundError(CoinbaseAPIError):
    """Resource not found (HTTP 404)."""
    pass


# ============================================================================
# REST Client
# ============================================================================

class CoinbaseRestClient:
    """
    Production REST Client for Coinbase Advanced Trade API.
    """

    DEFAULT_BASE_URL = "https://api.coinbase.com/api/v3/brokerage"
    DEFAULT_HOST = "api.coinbase.com"

    def __init__(
        self,
        auth: Optional[CoinbaseAuth] = None,
        base_url: Optional[str] = None,
        rate_limiter: Optional[CoinbaseRateLimiter] = None,
        timeout: float = 15.0,
        max_retries: int = 3,
        session: Optional[requests.Session] = None,
    ):
        """
        Initialize Coinbase REST Client.
        
        Args:
            auth: CoinbaseAuth instance (defaults to loading from env).
            base_url: Base endpoint URL.
            rate_limiter: TokenBucket rate limiter instance.
            timeout: Default request timeout in seconds.
            max_retries: Number of automatic retries on network/rate-limit errors.
            session: Optional custom requests Session.
        """
        self.auth = auth or CoinbaseAuth.from_env()
        self.base_url = (base_url or self.DEFAULT_BASE_URL).rstrip("/")
        self.rate_limiter = rate_limiter or CoinbaseRateLimiter()
        self.timeout = timeout
        self.max_retries = max_retries

        if session is not None:
            self.session = session
        else:
            self.session = requests.Session()
            retries = Retry(
                total=max_retries,
                backoff_factor=0.3,
                status_forcelist=[500, 502, 503, 504],
                raise_on_status=False,
            )
            adapter = HTTPAdapter(max_retries=retries, pool_connections=20, pool_maxsize=50)
            self.session.mount("https://", adapter)
            self.session.mount("http://", adapter)

    def _extract_host_and_path(self, full_url: str) -> tuple[str, str]:
        """Extract host and request path from full URL for signature computation."""
        from urllib.parse import urlparse
        parsed = urlparse(full_url)
        host = parsed.netloc or self.DEFAULT_HOST
        path = parsed.path
        if parsed.query:
            path = f"{path}?{parsed.query}"
        return host, path

    def _request(
        self,
        method: str,
        endpoint: str,
        params: Optional[Dict[str, Any]] = None,
        json_data: Optional[Dict[str, Any]] = None,
        is_public: bool = False,
    ) -> Dict[str, Any]:
        """
        Execute an authenticated HTTP request with rate limiting and retry handling.
        """
        endpoint = endpoint if endpoint.startswith("/") else f"/{endpoint}"
        full_url = f"{self.base_url}{endpoint}"

        # Clean params: remove None values
        cleaned_params = {k: v for k, v in (params or {}).items() if v is not None}
        body_str = json.dumps(json_data) if json_data is not None else ""

        endpoint_type = "public" if is_public else "private"

        for attempt in range(1, self.max_retries + 1):
            # 1. Acquire Rate Limit Token
            self.rate_limiter.acquire(endpoint_type=endpoint_type)

            # 2. Build Signature / Auth Headers
            req_host, req_path = self._extract_host_and_path(
                requests.Request("GET", full_url, params=cleaned_params).prepare().url or full_url
            )
            headers = {
                "Accept": "application/json",
                "Content-Type": "application/json",
            }
            if not is_public and self.auth.is_authenticated:
                auth_headers = self.auth.get_auth_headers(
                    method=method,
                    path=req_path,
                    body=body_str,
                    host=req_host,
                )
                headers.update(auth_headers)

            try:
                response = self.session.request(
                    method=method.upper(),
                    url=full_url,
                    params=cleaned_params,
                    data=body_str if body_str else None,
                    headers=headers,
                    timeout=self.timeout,
                )

                # Check HTTP status
                if response.status_code in (200, 201, 202):
                    if not response.content:
                        return {}
                    return response.json()

                # Handle 429 Rate Limit
                if response.status_code == 429:
                    retry_after_hdr = response.headers.get("Retry-After")
                    retry_after_val = float(retry_after_hdr) if retry_after_hdr else None
                    if attempt < self.max_retries:
                        self.rate_limiter.backoff_sleep(attempt=attempt, retry_after=retry_after_val)
                        continue
                    raise CoinbaseRateLimitError(
                        message=f"Rate limit exceeded: {response.text}",
                        retry_after=retry_after_val,
                        response_body=response.text,
                    )

                # Handle 401 / 403 Auth Error
                if response.status_code in (401, 403):
                    raise CoinbaseAuthError(
                        message=f"Authentication failed ({response.status_code}): {response.text}",
                        status_code=response.status_code,
                        response_body=response.text,
                    )

                # Handle 404 Not Found
                if response.status_code == 404:
                    raise CoinbaseNotFoundError(
                        message=f"Resource not found: {endpoint}",
                        status_code=404,
                        response_body=response.text,
                    )

                # Other HTTP errors
                raise CoinbaseAPIError(
                    message=f"Coinbase API error {response.status_code}: {response.text}",
                    status_code=response.status_code,
                    response_body=response.text,
                )

            except (requests.ConnectionError, requests.Timeout) as e:
                if attempt < self.max_retries:
                    self.rate_limiter.backoff_sleep(attempt=attempt)
                    continue
                raise CoinbaseAPIError(f"Network error communicating with Coinbase: {str(e)}")

        raise CoinbaseAPIError(f"Exceeded maximum retries ({self.max_retries}) for {method} {endpoint}")

    # ========================================================================
    # Market Data Endpoints
    # ========================================================================

    def get_products(self, product_type: str = "SPOT", limit: int = 250) -> List[Product]:
        """List tradable products on Coinbase Advanced Trade."""
        data = self._request("GET", "/products", params={"product_type": product_type, "limit": limit}, is_public=True)
        raw_products = data.get("products", [])
        return [Product.model_validate(p) for p in raw_products]

    def get_product(self, product_id: str) -> Product:
        """Get product details by product_id (e.g. 'BTC-USD')."""
        data = self._request("GET", f"/products/{product_id}", is_public=True)
        return Product.model_validate(data)

    def get_market_trades(self, product_id: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Get snapshot of recent market trades for a product."""
        data = self._request("GET", f"/products/{product_id}/ticker", params={"limit": limit}, is_public=True)
        return data.get("trades", [])

    def get_candles(
        self,
        product_id: str,
        granularity: Union[Granularity, str],
        start: Optional[Union[str, int, datetime]] = None,
        end: Optional[Union[str, int, datetime]] = None,
    ) -> List[Candle]:
        """
        Get historical candlestick (OHLCV) bars for a product.
        """
        granularity_str = granularity.value if isinstance(granularity, Granularity) else str(granularity)

        def _fmt_ts(val: Optional[Union[str, int, datetime]]) -> Optional[str]:
            if val is None:
                return None
            if isinstance(val, datetime):
                return str(int(val.timestamp()))
            return str(val)

        params = {
            "granularity": granularity_str,
            "start": _fmt_ts(start),
            "end": _fmt_ts(end),
        }
        data = self._request("GET", f"/products/{product_id}/candles", params=params, is_public=True)
        raw_candles = data.get("candles", [])
        return [Candle.model_validate(c) for c in raw_candles]

    def get_best_bid_ask(self, product_ids: Optional[List[str]] = None) -> List[Ticker]:
        """Get snapshot of current best bid and ask for given product IDs."""
        params = {"product_ids": product_ids} if product_ids else None
        data = self._request("GET", "/best_bid_ask", params=params, is_public=True)
        raw_pricebooks = data.get("pricebooks", [])
        tickers: List[Ticker] = []
        for pb in raw_pricebooks:
            bids = pb.get("bids", [])
            asks = pb.get("asks", [])
            best_bid = float(bids[0]["price"]) if bids else 0.0
            best_ask = float(asks[0]["price"]) if asks else 0.0
            price = (best_bid + best_ask) / 2.0 if (best_bid and best_ask) else (best_bid or best_ask)
            tickers.append(
                Ticker(
                    product_id=pb.get("product_id", ""),
                    price=price,
                    best_bid=best_bid,
                    best_ask=best_ask,
                    timestamp=pb.get("time"),
                )
            )
        return tickers

    # ========================================================================
    # Accounts & Portfolio Endpoints
    # ========================================================================

    def get_accounts(self, limit: int = 100, cursor: Optional[str] = None) -> List[AccountBalance]:
        """List brokerage accounts and balances."""
        data = self._request("GET", "/accounts", params={"limit": limit, "cursor": cursor})
        raw_accounts = data.get("accounts", [])
        accounts: List[AccountBalance] = []
        for acc in raw_accounts:
            avail = acc.get("available_balance", {}).get("value", 0.0)
            hold = acc.get("hold", {}).get("value", 0.0)
            curr = acc.get("currency", "")
            bal = float(avail) + float(hold)
            accounts.append(
                AccountBalance(
                    currency=curr,
                    available=float(avail),
                    hold=float(hold),
                    balance=bal,
                    account_uuid=acc.get("uuid"),
                )
            )
        return accounts

    def get_account(self, account_uuid: str) -> AccountBalance:
        """Get details for a specific account UUID."""
        data = self._request("GET", f"/accounts/{account_uuid}")
        acc = data.get("account", {})
        avail = acc.get("available_balance", {}).get("value", 0.0)
        hold = acc.get("hold", {}).get("value", 0.0)
        curr = acc.get("currency", "")
        bal = float(avail) + float(hold)
        return AccountBalance(
            currency=curr,
            available=float(avail),
            hold=float(hold),
            balance=bal,
            account_uuid=acc.get("uuid"),
        )

    def get_portfolio_breakdown(self, portfolio_uuid: Optional[str] = None) -> PortfolioSummary:
        """Get aggregated portfolio balance breakdown and total USD valuation."""
        endpoint = f"/portfolios/{portfolio_uuid}/breakdown" if portfolio_uuid else "/portfolios"
        data = self._request("GET", endpoint)
        
        breakdown = data.get("breakdown", data)
        spot_positions = breakdown.get("spot_positions", [])
        total_balance_usd = float(breakdown.get("portfolio_balances", {}).get("total_balance", {}).get("value", 0.0))

        accounts: List[AccountBalance] = []
        allocations: Dict[str, float] = {}

        for pos in spot_positions:
            asset = pos.get("asset", "")
            val_usd = float(pos.get("total_balance_fiat", 0.0))
            amount = float(pos.get("total_balance_crypto", 0.0))
            accounts.append(
                AccountBalance(
                    currency=asset,
                    available=amount,
                    hold=float(pos.get("hold_crypto", 0.0)),
                    balance=amount,
                    account_uuid=pos.get("account_uuid"),
                )
            )
            if total_balance_usd > 0:
                allocations[asset] = round((val_usd / total_balance_usd) * 100.0, 2)

        return PortfolioSummary(
            total_balance_usd=total_balance_usd,
            accounts=accounts,
            allocations=allocations,
            unrealized_pnl=float(breakdown.get("portfolio_balances", {}).get("unrealized_pnl", {}).get("value", 0.0)),
        )

    # ========================================================================
    # Order Management Endpoints
    # ========================================================================

    def create_order(self, request: Union[OrderPlacementRequest, Dict[str, Any]]) -> Order:
        """
        Create and submit a new order.
        """
        if isinstance(request, dict):
            req_model = OrderPlacementRequest.model_validate(request)
        else:
            req_model = request

        payload = req_model.to_coinbase_payload()
        data = self._request("POST", "/orders", json_data=payload)

        # Handle successful response structure
        order_resp = data.get("order_configuration", {})
        success_response = data.get("success_response", {})
        order_id = success_response.get("order_id", data.get("order_id", ""))
        
        if not order_id and data.get("error_response"):
            err = data["error_response"]
            raise CoinbaseAPIError(f"Failed to place order: {err.get('message', err)}")

        return Order(
            order_id=order_id,
            client_order_id=req_model.client_order_id or success_response.get("client_order_id", ""),
            product_id=req_model.product_id,
            side=req_model.side,
            order_type=req_model.order_type,
            price=req_model.price,
            size=req_model.size,
            status=OrderStatus.OPEN,
            time_in_force=req_model.time_in_force,
            stop_price=req_model.stop_price,
        )

    def cancel_orders(self, order_ids: List[str]) -> List[CancelOrderResponse]:
        """Cancel one or more open orders by order IDs."""
        data = self._request("POST", "/orders/batch_cancel", json_data={"order_ids": order_ids})
        results: List[CancelOrderResponse] = []
        for item in data.get("results", []):
            results.append(
                CancelOrderResponse(
                    success=item.get("success", False),
                    order_id=item.get("order_id"),
                    failure_reason=item.get("failure_reason"),
                )
            )
        return results

    def get_order(self, order_id: str) -> Order:
        """Get details and status of a single order by order_id."""
        data = self._request("GET", f"/orders/historical/{order_id}")
        raw_order = data.get("order", data)
        return Order.model_validate(raw_order)

    def list_orders(
        self,
        product_id: Optional[str] = None,
        order_status: Optional[Union[OrderStatus, str, List[str]]] = None,
        limit: int = 50,
    ) -> List[Order]:
        """List historical orders with optional status and product filtering."""
        params: Dict[str, Any] = {"limit": limit}
        if product_id:
            params["product_id"] = product_id
        if order_status:
            if isinstance(order_status, list):
                params["order_status"] = [str(s) for s in order_status]
            elif isinstance(order_status, OrderStatus):
                params["order_status"] = order_status.value
            else:
                params["order_status"] = str(order_status)

        data = self._request("GET", "/orders/historical/batch", params=params)
        raw_orders = data.get("orders", [])
        return [Order.model_validate(o) for o in raw_orders]

    # ========================================================================
    # Fees & Summary Endpoints
    # ========================================================================

    def get_transaction_summary(self) -> Dict[str, Any]:
        """Get trading volume, fee tier, and transaction fee summary."""
        return self._request("GET", "/transaction_summary")

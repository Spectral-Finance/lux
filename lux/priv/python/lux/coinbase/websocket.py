"""
Coinbase Advanced Trade WebSocket Client and Manager.

Provides real-time streaming market data, orderbook updates, user order executions,
and heartbeat monitoring with auto-reconnection and thread-safe callback dispatching.
"""

import asyncio
import json
import logging
import threading
import time
from typing import Any, Callable, Dict, List, Optional, Set, Union
import websockets

from lux.coinbase.auth import CoinbaseAuth
from lux.coinbase.types import ChannelType, Ticker

logger = logging.getLogger(__name__)

CallbackType = Callable[[Dict[str, Any]], None]


class CoinbaseWebSocketManager:
    """
    Manages an active WebSocket connection to Coinbase Advanced Trade (`wss://advanced-trade-ws.coinbase.com`).
    
    Runs an asynchronous event loop inside a dedicated background thread to provide
    a synchronous, non-blocking interface for applications and Elixir interop.
    """

    DEFAULT_WS_URL = "wss://advanced-trade-ws.coinbase.com"

    def __init__(
        self,
        auth: Optional[CoinbaseAuth] = None,
        ws_url: Optional[str] = None,
        auto_reconnect: bool = True,
        max_reconnect_attempts: int = 10,
        heartbeat_timeout: float = 30.0,
    ):
        self.auth = auth or CoinbaseAuth.from_env()
        self.ws_url = ws_url or self.DEFAULT_WS_URL
        self.auto_reconnect = auto_reconnect
        self.max_reconnect_attempts = max_reconnect_attempts
        self.heartbeat_timeout = heartbeat_timeout

        # Internal state
        self._thread: Optional[threading.Thread] = None
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._ws: Optional[websockets.WebSocketClientProtocol] = None
        self._running = False
        self._connected = threading.Event()
        self._last_heartbeat: float = 0.0

        # Subscriptions: Dict[channel, Set[product_id]]
        self._subscriptions: Dict[str, Set[str]] = {}
        self._callbacks: Dict[str, List[CallbackType]] = {}
        self._global_callbacks: List[CallbackType] = []
        self._lock = threading.RLock()

    @property
    def is_connected(self) -> bool:
        """True if the WebSocket connection is open and active."""
        return self._connected.is_set()

    @property
    def last_heartbeat(self) -> float:
        """Timestamp of the most recently received heartbeat or message."""
        return self._last_heartbeat

    # ========================================================================
    # Lifecycle Management
    # ========================================================================

    def start(self, timeout: float = 10.0) -> bool:
        """
        Start the background WebSocket thread and connect.
        
        Args:
            timeout: Maximum time to wait for connection confirmation.
            
        Returns:
            True if connected successfully, False otherwise.
        """
        with self._lock:
            if self._running:
                return True
            self._running = True
            self._connected.clear()

            self._thread = threading.Thread(target=self._run_loop, daemon=True, name="CoinbaseWSThread")
            self._thread.start()

        return self._connected.wait(timeout=timeout)

    def stop(self) -> None:
        """Stop the background WebSocket manager and disconnect gracefully."""
        with self._lock:
            self._running = False
            self._connected.clear()

            if self._loop and self._loop.is_running():
                future = asyncio.run_coroutine_threadsafe(self._async_close(), self._loop)
                try:
                    future.result(timeout=3.0)
                except Exception:
                    pass

            if self._thread and self._thread.is_alive():
                self._thread.join(timeout=2.0)
                self._thread = None

    def _run_loop(self) -> None:
        """Entry point for the background thread."""
        self._loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self._loop)
        try:
            self._loop.run_until_complete(self._connection_supervisor())
        finally:
            self._loop.close()

    async def _async_close(self) -> None:
        """Close active websocket coroutine."""
        if self._ws:
            await self._ws.close()
            self._ws = None

    # ========================================================================
    # Connection Supervisor & Reconnect Loop
    # ========================================================================

    async def _connection_supervisor(self) -> None:
        """Supervisor loop handling initial connect, listening, and auto-reconnect."""
        attempts = 0
        while self._running:
            try:
                async with websockets.connect(
                    self.ws_url,
                    ping_interval=20,
                    ping_timeout=10,
                    close_timeout=5,
                ) as ws:
                    self._ws = ws
                    self._last_heartbeat = time.time()
                    self._connected.set()
                    attempts = 0
                    logger.info("Connected to Coinbase WebSocket feed.")

                    # Resubscribe all registered channels
                    await self._resubscribe_all()

                    # Message listening loop
                    async for raw_message in ws:
                        if not self._running:
                            break
                        self._last_heartbeat = time.time()
                        self._handle_raw_message(raw_message)

            except Exception as e:
                self._connected.clear()
                self._ws = None
                if not self._running:
                    break

                attempts += 1
                if not self.auto_reconnect or attempts > self.max_reconnect_attempts:
                    logger.error(f"WebSocket disconnected and max reconnect attempts reached: {e}")
                    break

                backoff = min(30.0, 0.5 * (2 ** (attempts - 1)))
                logger.warning(f"WebSocket disconnected ({e}). Reconnecting in {backoff:.2f}s (attempt {attempts})...")
                await asyncio.sleep(backoff)

        self._connected.clear()

    # ========================================================================
    # Subscription Management
    # ========================================================================

    def subscribe(
        self,
        channel: Union[ChannelType, str],
        product_ids: Optional[List[str]] = None,
        callback: Optional[CallbackType] = None,
    ) -> None:
        """
        Subscribe to a channel for one or more product IDs.
        """
        ch_str = channel.value if isinstance(channel, ChannelType) else str(channel)
        p_ids = product_ids or []

        with self._lock:
            if ch_str not in self._subscriptions:
                self._subscriptions[ch_str] = set()
            self._subscriptions[ch_str].update(p_ids)

            if callback:
                self.register_callback(ch_str, callback)

            if self.is_connected and self._loop and self._loop.is_running():
                asyncio.run_coroutine_threadsafe(
                    self._send_subscription("subscribe", ch_str, list(p_ids)),
                    self._loop,
                )

    def unsubscribe(
        self,
        channel: Union[ChannelType, str],
        product_ids: Optional[List[str]] = None,
    ) -> None:
        """
        Unsubscribe from a channel.
        """
        ch_str = channel.value if isinstance(channel, ChannelType) else str(channel)
        p_ids = product_ids or []

        with self._lock:
            if ch_str in self._subscriptions:
                if p_ids:
                    self._subscriptions[ch_str].difference_update(p_ids)
                else:
                    self._subscriptions[ch_str].clear()

            if self.is_connected and self._loop and self._loop.is_running():
                asyncio.run_coroutine_threadsafe(
                    self._send_subscription("unsubscribe", ch_str, list(p_ids)),
                    self._loop,
                )

    def register_callback(
        self,
        channel: Optional[Union[ChannelType, str]],
        callback: CallbackType,
    ) -> None:
        """Register a callback function for a specific channel or globally (if channel is None)."""
        with self._lock:
            if channel is None:
                if callback not in self._global_callbacks:
                    self._global_callbacks.append(callback)
            else:
                ch_str = channel.value if isinstance(channel, ChannelType) else str(channel)
                if ch_str not in self._callbacks:
                    self._callbacks[ch_str] = []
                if callback not in self._callbacks[ch_str]:
                    self._callbacks[ch_str].append(callback)

    async def _send_subscription(self, action: str, channel: str, product_ids: List[str]) -> None:
        """Format and send subscribe/unsubscribe message over WebSocket."""
        if not self._ws:
            return

        payload: Dict[str, Any] = {
            "type": action,
            "channel": channel,
        }
        if product_ids:
            payload["product_ids"] = product_ids

        # Inject authentication if channel requires auth or credentials exist
        if self.auth and self.auth.is_authenticated:
            auth_fields = self.auth.get_ws_auth_payload(channel, product_ids)
            payload.update(auth_fields)

        try:
            await self._ws.send(json.dumps(payload))
        except Exception as e:
            logger.error(f"Failed to send {action} message for {channel}: {e}")

    async def _resubscribe_all(self) -> None:
        """Re-send subscriptions for all registered channels upon reconnection."""
        with self._lock:
            sub_items = list(self._subscriptions.items())

        for channel, p_ids in sub_items:
            await self._send_subscription("subscribe", channel, list(p_ids))

    # ========================================================================
    # Message Dispatching
    # ========================================================================

    def _handle_raw_message(self, raw_message: Union[str, bytes]) -> None:
        """Parse raw incoming JSON message and dispatch to registered callbacks."""
        try:
            data = json.loads(raw_message)
        except json.JSONDecodeError:
            logger.warning(f"Received non-JSON message: {raw_message}")
            return

        channel = data.get("channel", "")
        
        # Dispatch to channel-specific callbacks
        with self._lock:
            callbacks = list(self._callbacks.get(channel, []))
            global_cbs = list(self._global_callbacks)

        for cb in callbacks:
            try:
                cb(data)
            except Exception as e:
                logger.error(f"Error in callback for channel {channel}: {e}")

        for cb in global_cbs:
            try:
                cb(data)
            except Exception as e:
                logger.error(f"Error in global callback: {e}")

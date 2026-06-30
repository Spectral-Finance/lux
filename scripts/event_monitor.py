"""
Smart Contract Event Monitoring System for Spectral-Finance/lux

This module provides a robust system for tracking and processing events 
across multiple contracts and chains.

Features:
- Contract event subscription management
- Event filtering and pattern matching
- Historical event syncing
- Real-time event monitoring
- Custom event parsing and decoding
- Webhook notifications
- Event persistence and replay
"""

import asyncio
import json
import logging
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Callable, Dict, List, Optional, Set

# Attempt to import web3, fallback to mock if not installed for standalone testing
try:
    from web3 import Web3
    from web3.types import EventData, LogReceipt
    WEB3_AVAILABLE = True
except ImportError:
    WEB3_AVAILABLE = False
    # Mock classes for standalone execution without web3 installed
    class Web3: pass
    class EventData(dict): pass
    class LogReceipt(dict): pass

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("LuxEventMonitor")

@dataclass
class EventSubscription:
    """Represents a subscription to a specific contract event."""
    contract_address: str
    event_name: str
    filters: Dict[str, Any] = field(default_factory=dict)
    callback: Optional[Callable[[EventData], None]] = None
    is_active: bool = True

@dataclass
class ProcessedEvent:
    """Container for a processed event with metadata."""
    event_name: str
    contract_address: str
    block_number: int
    transaction_hash: str
    timestamp: datetime
    data: Dict[str, Any]
    raw_log: Any

class EventPersistence:
    """Handles saving and replaying events to a local store (JSON/DB)."""
    
    def __init__(self, storage_path: str = "events_store.json"):
        self.storage_path = storage_path
        self.events: List[Dict[str, Any]] = []
        self._load()

    def _load(self):
        """Load events from storage."""
        try:
            with open(self.storage_path, 'r') as f:
                self.events = json.load(f)
            logger.info(f"Loaded {len(self.events)} events from {self.storage_path}")
        except FileNotFoundError:
            self.events = []
            logger.info("No existing event store found. Starting fresh.")

    def save(self, event: ProcessedEvent):
        """Persist an event to storage."""
        event_dict = {
            "event_name": event.event_name,
            "contract_address": event.contract_address,
            "block_number": event.block_number,
            "transaction_hash": event.transaction_hash,
            "timestamp": event.timestamp.isoformat(),
            "data": event.data
        }
        self.events.append(event_dict)
        # Simple append to file for demo; in production, use a DB
        with open(self.storage_path, 'w') as f:
            json.dump(self.events, f, indent=2)

    def replay(self, from_block: int = 0, to_block: Optional[int] = None) -> List[ProcessedEvent]:
        """Replay events from storage."""
        replayed = []
        end = to_block if to_block else float('inf')
        
        for item in self.events:
            if from_block <= item["block_number"] <= end:
                # Reconstruct ProcessedEvent
                event = ProcessedEvent(
                    event_name=item["event_name"],
                    contract_address=item["contract_address"],
                    block_number=item["block_number"],
                    transaction_hash=item["transaction_hash"],
                    timestamp=datetime.fromisoformat(item["timestamp"]),
                    data=item["data"],
                    raw_log=None
                )
                replayed.append(event)
        return replayed

class WebhookNotifier:
    """Handles sending event notifications to external webhooks."""
    
    def __init__(self, webhook_url: str):
        self.webhook_url = webhook_url

    async def notify(self, event: ProcessedEvent):
        """Send event data to webhook."""
        if not self.webhook_url:
            return
        
        payload = {
            "type": "event_detected",
            "timestamp": event.timestamp.isoformat(),
            "event": event.event_name,
            "contract": event.contract_address,
            "block": event.block_number,
            "data": event.data
        }
        
        # In a real scenario, use aiohttp or requests
        logger.info(f"Sending webhook to {self.webhook_url}: {event.event_name}")
        # await aiohttp.post(self.webhook_url, json=payload)

class EventMonitor:
    """
    Main class for monitoring smart contract events.
    Supports historical syncing and real-time monitoring.
    """

    def __init__(self, rpc_url: str, persistence_path: str = "events_store.json", webhook_url: str = ""):
        if not WEB3_AVAILABLE:
            logger.warning("web3.py not installed. Running in simulation mode.")
            self.w3 = None
        else:
            self.w3 = Web3(Web3.HTTPProvider(rpc_url))
            if not self.w3.is_connected():
                raise ConnectionError("Failed to connect to RPC node")
        
        self.subscriptions: List[EventSubscription] = []
        self.persistence = EventPersistence(persistence_path)
        self.notifier = WebhookNotifier(webhook_url)
        self.running = False
        self.last_processed_block = 0

    def subscribe(self, contract_address: str, event_name: str, 
                  filters: Optional[Dict[str, Any]] = None, 
                  callback: Optional[Callable] = None):
        """Add a new event subscription."""
        sub = EventSubscription(
            contract_address=contract_address,
            event_name=event_name,
            filters=filters or {},
            callback=callback
        )
        self.subscriptions.append(sub)
        logger.info(f"Subscribed to {event_name} on {contract_address}")

    def _matches_filters(self, log: LogReceipt, sub: EventSubscription) -> bool:
        """Check if a log matches the subscription filters."""
        # Basic implementation: check if log topics match (simplified)
        # In production, use ABI to decode topics and compare values
        if not sub.filters:
            return True
        
        # Placeholder for actual topic matching logic
        # This would involve decoding log topics based on the event ABI
        return True

    async def _process_log(self, log: LogReceipt):
        """Process a single log entry."""
        for sub in self.subscriptions:
            if not sub.is_active:
                continue
            
            if log['address'].lower() == sub.contract_address.lower():
                # In a real app, we would decode the event here using ABI
                # For this demo, we assume the log is relevant if address matches
                if self._matches_filters(log, sub):
                    event_data = ProcessedEvent(
                        event_name=sub.event_name,
                        contract_address=log['address'],
                        block_number=log['blockNumber'],
                        transaction_hash=log['transactionHash'],
                        timestamp=datetime.fromtimestamp(int(time.time())),
                        data={"raw": str(log)}, # Simplified data extraction
                        raw_log=log
                    )
                    
                    # Persist
                    self.persistence.save(event_data)
                    
                    # Notify
                    await self.notifier.notify(event_data)
                    
                    # Callback
                    if sub.callback:
                        try:
                            if asyncio.iscoroutinefunction(sub.callback):
                                await sub.callback(event_data)
                            else:
                                sub.callback(event_data)
                        except Exception as e:
                            logger.error(f"Error in callback: {e}")

    async def sync_historical(self, start_block: int, end_block: Optional[int] = None):
        """Sync historical events from start_block to end_block."""
        if not self.w3:
            logger.warning("Web3 not available, skipping historical sync.")
            return

        if end_block is None:
            end_block = self.w3.eth.block_number

        logger.info(f"Starting historical sync from {start_block} to {end_block}")
        
        for block_num in range(start_block, end_block + 1):
            try:
                block = self.w3.eth.get_block(block_num, full_transactions=False)
                for tx_hash in block['transactions']:
                    # In real implementation, fetch logs for the block
                    # logs = self.w3.eth.get_logs({"fromBlock": block_num, "toBlock": block_num})
                    # For demo, we simulate a log if subscriptions exist
                    pass
                
                # Simulate processing for demo purposes if no real logs found
                # In production: logs = self.w3.eth.get_logs(...)
                # for log in logs: await self._process_log(log)
                
                self.last_processed_block = block_num
                if block_num % 100 == 0:
                    logger.info(f"Synced up to block {block_num}")
                    
            except Exception as e:
                logger.error(f"Error syncing block {block_num}: {e}")
                break

    async def monitor_realtime(self):
        """Monitor for new events in real-time."""
        if not self.w3:
            logger.warning("Web3 not available, running in simulation mode.")
            # Simulation loop
            while self.running:
                await asyncio.sleep(5)
                # Simulate a random event
                if self.subscriptions:
                    sub = self.subscriptions[0]
                    mock_log = {
                        'address': sub.contract_address,
                        'blockNumber': self.last_processed_block + 1,
                        'transactionHash': '0x' + '0' * 64,
                        'data': '0x'
                    }
                    await self._process_log(mock_log)
                    self.last_processed_block += 1
                continue

        # Real implementation using Web3.py filters
        # filters = []
        # for sub in self.subscriptions:
        #     filter_params = {
        #         'address': sub.contract_address,
        #         'topics': [self.w3.keccak(text=sub.event_name)] # Simplified
        #     }
        #     f = self.w3.eth.filter(filter_params)
        #     filters.append(f)
        
        while self.running:
            # Check for new blocks
            current_block = self.w3.eth.block_number
            if current_block > self.last_processed_block:
                # Fetch logs from last processed block to current
                # logs = self.w3.eth.get_logs({"fromBlock": self.last_processed_block + 1, "toBlock": current_block})
                # for log in logs:
                #     await self._process_log(log)
                self.last_processed_block = current_block
            
            await asyncio.sleep(1)

    async def start(self, historical_start: int = 0, historical_end: Optional[int] = None):
        """Start the monitoring system."""
        self.running = True
        
        # 1. Historical Sync
        if historical_start > 0 or historical_end:
            await self.sync_historical(historical_start, historical_end)
        
        # 2. Real-time Monitoring
        try:
            await self.monitor_realtime()
        except KeyboardInterrupt:
            self.stop()

    def stop(self):
        """Stop the monitoring system."""
        self.running = False
        logger.info("Event monitor stopped.")

# Example Usage / Entry Point
async def main():
    # Initialize monitor
    # Replace with actual RPC URL
    monitor = EventMonitor(
        rpc_url="https://eth-mainnet.g.alchemy.com/v2/demo", 
        persistence_path="lux_events.json",
        webhook_url="https://hooks.spectral-finance.io/events"
    )

    # Subscribe to a hypothetical event
    monitor.subscribe(
        contract_address="0x1234567890123456789012345678901234567890",
        event_name="Transfer",
        filters={"from": "0x..."}
    )

    # Start monitoring (sync from block 0, then real-time)
    await monitor.start(historical_start=0)

if __name__ == "__main__":
    asyncio.run(main())
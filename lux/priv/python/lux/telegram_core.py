import os
from telethon import TelegramClient
from telethon.errors import SessionPasswordNeededError
import asyncio

class TelegramCoreClient:
    """
    Telegram Core API Client using Telethon.
    Handles User-level authentication and interaction.
    """
    def __init__(self, session_name: str, api_id: int, api_hash: str):
        self.session_name = session_name
        self.api_id = api_id
        self.api_hash = api_hash
        self.client = TelegramClient(session_name, api_id, api_hash)

    async def connect(self):
        if not self.client.is_connected():
            await self.client.connect()

    async def send_message(self, chat_id: str, text: str) -> str:
        await self.connect()
        message = await self.client.send_message(chat_id, text)
        return str(message.id)

    async def get_messages(self, chat_id: str, limit: int = 10) -> list:
        await self.connect()
        messages = await self.client.get_messages(chat_id, limit=limit)
        return [
            {
                "id": m.id,
                "text": m.text,
                "date": m.date.isoformat(),
                "sender_id": m.sender_id
            }
            for m in messages
        ]

    async def get_user_info(self, user_id: str) -> dict:
        await self.connect()
        user = await self.client.get_entity(user_id)
        return {
            "id": user.id,
            "username": getattr(user, "username", None),
            "first_name": getattr(user, "first_name", None),
            "last_name": getattr(user, "last_name", None),
            "phone": getattr(user, "phone", None),
        }

    async def disconnect(self):
        await self.client.disconnect()

# Bridge for Elixir (Erlport compatible)
async def run_send_message(session, api_id, api_hash, chat_id, text):
    client = TelegramCoreClient(session, api_id, api_hash)
    try:
        res = await client.send_message(chat_id, text)
        return {"status": "ok", "message_id": res}
    except Exception as e:
        return {"status": "error", "message": str(e)}
    finally:
        await client.disconnect()

async def run_get_messages(session, api_id, api_hash, chat_id, limit):
    client = TelegramCoreClient(session, api_id, api_hash)
    try:
        res = await client.get_messages(chat_id, limit)
        return {"status": "ok", "messages": res}
    except Exception as e:
        return {"status": "error", "message": str(e)}
    finally:
        await client.disconnect()

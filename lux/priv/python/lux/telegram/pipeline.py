"""
Unified end-to-end Telegram update processing pipeline for the Lux Framework.

Orchestrates update normalization, content analysis, deep link decoding,
command parsing, callback dispatching, thread history management, and safe response
payload formatting.
"""

from __future__ import annotations

import time
import traceback
from typing import Any, Callable, Dict, List, Optional, Union

from lux.telegram.analysis import MessageAnalyzer
from lux.telegram.callbacks import CallbackProcessor
from lux.telegram.commands import CommandContext, CommandParser, CommandRouter, CommandValidationError
from lux.telegram.deep_links import DeepLinkHandler, ParsedDeepLink
from lux.telegram.formatter import TelegramFormatter
from lux.telegram.replies import ReplyManager
from lux.telegram.threads import ThreadManager
from lux.telegram.types import (
    AnalysisResult,
    CallbackQuery,
    Message,
    ParsedCommand,
    ParseMode,
    PermissionLevel,
    ProcessingResult,
    Update,
    UpdateType,
)


class TelegramPipeline:
    """Production pipeline connecting analysis, routing, threads, and response formatting."""

    def __init__(
        self,
        bot_username: Optional[str] = None,
        secret_key: Optional[str] = None,
        analyzer: Optional[MessageAnalyzer] = None,
        command_router: Optional[CommandRouter] = None,
        callback_processor: Optional[CallbackProcessor] = None,
        deep_link_handler: Optional[DeepLinkHandler] = None,
        thread_manager: Optional[ThreadManager] = None,
    ):
        self.bot_username = bot_username
        self.analyzer = analyzer or MessageAnalyzer()
        self.command_router = command_router or CommandRouter(bot_username=bot_username)
        self.callback_processor = callback_processor or CallbackProcessor()
        self.deep_link_handler = deep_link_handler or DeepLinkHandler(secret_key=secret_key)
        self.thread_manager = thread_manager or ThreadManager()
        self.reply_manager = ReplyManager()
        self._message_handlers: List[Callable[[Message, AnalysisResult, Any], Any]] = []

    def on_message(self, handler: Callable[[Message, AnalysisResult, Any], Any]) -> None:
        """Registers a fallback handler for non-command conversational messages."""
        self._message_handlers.append(handler)

    def process_raw_update(
        self,
        raw_update: Union[Dict[str, Any], Update],
        user_permission: PermissionLevel = PermissionLevel.USER,
        extra_context: Optional[Dict[str, Any]] = None,
    ) -> ProcessingResult:
        """Main entry point: processes a raw update dict or Update model end-to-end."""
        start_time = time.perf_counter()

        # 1. Normalization
        if isinstance(raw_update, dict):
            update = Update.model_validate(raw_update)
        elif isinstance(raw_update, Update):
            update = raw_update
        else:
            raise ValueError(f"Invalid update object type: {type(raw_update)}")

        update_type = update.update_type
        response_payloads: List[Dict[str, Any]] = []
        errors: List[str] = []
        analysis: Optional[AnalysisResult] = None
        command: Optional[ParsedCommand] = None
        callback_dict: Optional[Dict[str, Any]] = None
        action_taken = "none"

        try:
            # 2. Callback Query branch
            if update_type == UpdateType.CALLBACK_QUERY and update.callback_query:
                cb = update.callback_query
                action_taken = "callback_query"
                cb_payload = self.callback_processor.decode(cb.data)
                callback_dict = {
                    "action": cb_payload.action,
                    "target": cb_payload.target,
                    "item_id": cb_payload.item_id,
                    "params": cb_payload.params,
                }

                answer, handler_result = self.callback_processor.process(cb, user_permission)
                if answer:
                    response_payloads.append({
                        "method": "answerCallbackQuery",
                        "params": answer.to_api_payload(),
                    })

                if isinstance(handler_result, dict) and "method" in handler_result:
                    response_payloads.append(handler_result)

            # 3. Message / Channel Post branch
            elif update.effective_message:
                msg = update.effective_message
                chat_id = msg.chat.id
                topic_id = msg.message_thread_id

                # Record message into thread history & reply tree
                self.thread_manager.record_incoming_message(msg)
                self.reply_manager.track_reply(msg)

                # Run message analysis
                text = msg.effective_text
                analysis = self.analyzer.analyze(text, entities=msg.effective_entities)

                # Check for /start payload (deep link)
                if text.startswith("/start ") or text == "/start":
                    action_taken = "deep_link"
                    parsed_link = self.deep_link_handler.parse(text)
                    command = CommandParser.parse(text, self.bot_username)

                    # Execute deep link action if registered
                    dl_result = self.deep_link_handler.dispatch(parsed_link, {"message": msg, "update": update})
                    if dl_result:
                        self._handle_response_payload(dl_result, chat_id, topic_id, msg.message_id, response_payloads)
                    elif self.command_router.resolve_command("start"):
                        cmd_ctx = CommandContext(
                            command=command,
                            message=msg,
                            user=msg.from_user,
                            user_permission=user_permission,
                            bot_username=self.bot_username,
                            extra_state={"deep_link": parsed_link},
                        )
                        cmd_result = self.command_router.execute(cmd_ctx)
                        self._handle_response_payload(cmd_result, chat_id, topic_id, msg.message_id, response_payloads)

                # Check for regular bot command
                elif CommandParser.is_command(text):
                    action_taken = "command"
                    command = CommandParser.parse(text, self.bot_username)
                    cmd_ctx = CommandContext(
                        command=command,
                        message=msg,
                        user=msg.from_user,
                        user_permission=user_permission,
                        bot_username=self.bot_username,
                        extra_state=extra_context or {},
                    )
                    cmd_result = self.command_router.execute(cmd_ctx)
                    self._handle_response_payload(cmd_result, chat_id, topic_id, msg.message_id, response_payloads)

                # Non-command conversational message
                else:
                    action_taken = "conversation"
                    for handler in self._message_handlers:
                        h_res = handler(msg, analysis, extra_context)
                        if h_res:
                            self._handle_response_payload(h_res, chat_id, topic_id, msg.message_id, response_payloads)

            elapsed_ms = (time.perf_counter() - start_time) * 1000.0
            return ProcessingResult(
                success=True,
                update_id=update.update_id,
                action_taken=action_taken,
                response_payloads=response_payloads,
                analysis=analysis,
                command=command,
                callback_data=callback_dict,
                errors=errors,
                execution_time_ms=round(elapsed_ms, 2),
            )

        except Exception as exc:
            elapsed_ms = (time.perf_counter() - start_time) * 1000.0
            errors.append(f"{type(exc).__name__}: {str(exc)}")
            return ProcessingResult(
                success=False,
                update_id=update.update_id,
                action_taken=action_taken,
                response_payloads=response_payloads,
                analysis=analysis,
                command=command,
                callback_data=callback_dict,
                errors=errors,
                execution_time_ms=round(elapsed_ms, 2),
            )

    def _handle_response_payload(
        self,
        result: Any,
        chat_id: int,
        topic_id: Optional[int],
        reply_to_id: Optional[int],
        payloads: List[Dict[str, Any]],
    ) -> None:
        """Formats and chunks handler output into valid Telegram API method payloads."""
        if result is None:
            return

        if isinstance(result, dict) and "method" in result:
            payloads.append(result)
            return

        if isinstance(result, list):
            for item in result:
                self._handle_response_payload(item, chat_id, topic_id, reply_to_id, payloads)
            return

        # String response -> format and split if needed
        text_str = str(result)
        chunks = ReplyManager.split_message(text_str, max_limit=4096)

        for chunk in chunks:
            payload: Dict[str, Any] = {
                "method": "sendMessage",
                "params": {
                    "chat_id": chat_id,
                    "text": chunk,
                    "parse_mode": "MarkdownV2",
                },
            }
            if topic_id is not None:
                payload["params"]["message_thread_id"] = topic_id
            if reply_to_id is not None:
                payload["params"]["reply_to_message_id"] = reply_to_id

            payloads.append(payload)

            # Record outgoing response in history
            self.thread_manager.record_outgoing_response(
                chat_id=chat_id,
                text=chunk,
                topic_id=topic_id,
                reply_to_id=reply_to_id,
            )

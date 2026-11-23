"""Concrete LLM provider implementations (OpenAI, Anthropic, Ollama).

Each provider subclasses :class:`lux.llm.base.BaseProvider` (which supplies
retry/backoff) and implements the single-attempt ``_do_complete`` /
``_do_stream`` hooks. Native payloads are normalised into the unified
:class:`~lux.llm.base.CompletionResponse` / :class:`~lux.llm.base.StreamChunk`
schema.
"""
from __future__ import annotations

import json
from typing import Any, Dict, Iterator, List, Sequence

from lux.llm.base import (
    BaseProvider,
    CompletionResponse,
    ProviderError,
    StreamChunk,
    Usage,
)
from lux.llm import http_utils
from lux.llm.http_utils import iter_sse_json
from lux.llm.message import Message, Role, ToolCall

__all__ = ["OpenAIProvider", "AnthropicProvider", "OllamaProvider"]


# --------------------------------------------------------------------------- #
# OpenAI (also works for any OpenAI-compatible endpoint)
# --------------------------------------------------------------------------- #
class OpenAIProvider(BaseProvider):
    """OpenAI Chat Completions provider (``/v1/chat/completions``)."""

    name = "openai"

    @staticmethod
    def default_base_url() -> str:
        return "https://api.openai.com/v1"

    def _headers(self) -> Dict[str, str]:
        headers = {"Accept": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        return headers

    def _endpoint(self) -> str:
        return f"{self.base_url.rstrip('/')}/chat/completions"

    def _build_body(
        self,
        messages: Sequence[Message],
        model: str,
        temperature: Any,
        max_tokens: Any,
        stream: bool,
        params: Dict[str, Any],
    ) -> Dict[str, Any]:
        body: Dict[str, Any] = {
            "model": model,
            "messages": [m.to_dict() for m in messages],
            "stream": stream,
        }
        if temperature is not None:
            body["temperature"] = temperature
        if max_tokens is not None:
            body["max_tokens"] = max_tokens
        body.update(self._merge_params(params))
        return body

    def _do_complete(self, messages: Sequence[Message], **params: Any) -> CompletionResponse:
        model = self._resolve_model(params.pop("model", None))
        temperature = params.pop("temperature", None)
        max_tokens = params.pop("max_tokens", None)
        body = self._build_body(messages, model, temperature, max_tokens, False, params)
        data = http_utils.http_post(self._endpoint(), body, self._headers(), timeout=self.timeout, provider=self.name)

        choice = (data.get("choices") or [{}])[0]
        msg = choice.get("message", {})
        tool_calls = [
            ToolCall(
                id=tc.get("id", ""),
                name=tc.get("function", {}).get("name", ""),
                arguments=tc.get("function", {}).get("arguments", {}),
            )
            for tc in msg.get("tool_calls", [])
        ]
        return CompletionResponse(
            text=msg.get("content", "") or "",
            model=data.get("model", model),
            provider=self.name,
            usage=Usage.from_dict(data.get("usage", {})),
            tool_calls=tool_calls,
            finish_reason=choice.get("finish_reason"),
            raw=data,
        )

    def _do_stream(self, messages: Sequence[Message], **params: Any) -> Iterator[StreamChunk]:
        model = self._resolve_model(params.pop("model", None))
        temperature = params.pop("temperature", None)
        max_tokens = params.pop("max_tokens", None)
        body = self._build_body(messages, model, temperature, max_tokens, True, params)
        lines = http_utils.http_post_stream(self._endpoint(), body, self._headers(), timeout=self.timeout, provider=self.name)
        for event in iter_sse_json(lines):
            choice = (event.get("choices") or [{}])[0]
            delta = choice.get("delta", {})
            text = delta.get("content") or ""
            finish = choice.get("finish_reason")
            usage = Usage.from_dict(event["usage"]) if event.get("usage") else None
            yield StreamChunk(
                text=text,
                model=event.get("model", model),
                provider=self.name,
                finish_reason=finish,
                usage=usage,
                done=finish is not None,
            )


# --------------------------------------------------------------------------- #
# Anthropic
# --------------------------------------------------------------------------- #
class AnthropicProvider(BaseProvider):
    """Anthropic Messages provider (``/v1/messages``)."""

    name = "anthropic"
    api_version = "2023-06-01"

    @staticmethod
    def default_base_url() -> str:
        return "https://api.anthropic.com/v1"

    def _headers(self) -> Dict[str, str]:
        headers = {
            "Accept": "application/json",
            "anthropic-version": self.api_version,
        }
        if self.api_key:
            headers["x-api-key"] = self.api_key
        return headers

    def _endpoint(self) -> str:
        return f"{self.base_url.rstrip('/')}/messages"

    def _split_messages(self, messages: Sequence[Message]):
        """Anthropic takes ``system`` separately from the message list."""
        system_parts: List[str] = []
        convo: List[Dict[str, Any]] = []
        for m in messages:
            if m.role == Role.SYSTEM:
                system_parts.append(m.content)
            else:
                role = "assistant" if m.role == Role.ASSISTANT else "user"
                convo.append({"role": role, "content": m.content})
        system = "\n".join(system_parts) if system_parts else None
        return system, convo

    def _build_body(
        self,
        messages: Sequence[Message],
        model: str,
        temperature: Any,
        max_tokens: Any,
        stream: bool,
        params: Dict[str, Any],
    ) -> Dict[str, Any]:
        system, convo = self._split_messages(messages)
        body: Dict[str, Any] = {
            "model": model,
            "messages": convo,
            "max_tokens": max_tokens if max_tokens is not None else 1024,
            "stream": stream,
        }
        if system:
            body["system"] = system
        if temperature is not None:
            body["temperature"] = temperature
        body.update(self._merge_params(params))
        return body

    def _do_complete(self, messages: Sequence[Message], **params: Any) -> CompletionResponse:
        model = self._resolve_model(params.pop("model", None))
        temperature = params.pop("temperature", None)
        max_tokens = params.pop("max_tokens", None)
        body = self._build_body(messages, model, temperature, max_tokens, False, params)
        data = http_utils.http_post(self._endpoint(), body, self._headers(), timeout=self.timeout, provider=self.name)

        text_parts = [b.get("text", "") for b in data.get("content", []) if b.get("type") == "text"]
        return CompletionResponse(
            text="".join(text_parts),
            model=data.get("model", model),
            provider=self.name,
            usage=Usage.from_dict(data.get("usage", {})),
            finish_reason=data.get("stop_reason"),
            raw=data,
        )

    def _do_stream(self, messages: Sequence[Message], **params: Any) -> Iterator[StreamChunk]:
        model = self._resolve_model(params.pop("model", None))
        temperature = params.pop("temperature", None)
        max_tokens = params.pop("max_tokens", None)
        body = self._build_body(messages, model, temperature, max_tokens, True, params)
        lines = http_utils.http_post_stream(self._endpoint(), body, self._headers(), timeout=self.timeout, provider=self.name)
        for event in iter_sse_json(lines):
            etype = event.get("type")
            if etype == "content_block_delta":
                delta = event.get("delta", {})
                yield StreamChunk(text=delta.get("text", ""), model=model, provider=self.name)
            elif etype == "message_delta":
                stop = event.get("delta", {}).get("stop_reason")
                yield StreamChunk(text="", model=model, provider=self.name, finish_reason=stop, done=stop is not None)
            elif etype == "message_stop":
                yield StreamChunk(text="", model=model, provider=self.name, finish_reason="stop", done=True)
                return


# --------------------------------------------------------------------------- #
# Ollama (local models)
# --------------------------------------------------------------------------- #
class OllamaProvider(BaseProvider):
    """Local Ollama provider (``/api/chat``). No API key required."""

    name = "ollama"

    @staticmethod
    def default_base_url() -> str:
        return "http://localhost:11434"

    def _headers(self) -> Dict[str, str]:
        return {"Accept": "application/json"}

    def _endpoint(self) -> str:
        return f"{self.base_url.rstrip('/')}/api/chat"

    def _build_body(
        self,
        messages: Sequence[Message],
        model: str,
        temperature: Any,
        max_tokens: Any,
        stream: bool,
        params: Dict[str, Any],
    ) -> Dict[str, Any]:
        options: Dict[str, Any] = {}
        if temperature is not None:
            options["temperature"] = temperature
        if max_tokens is not None:
            options["num_predict"] = max_tokens
        body: Dict[str, Any] = {
            "model": model,
            "messages": [m.to_dict() for m in messages],
            "stream": stream,
        }
        if options:
            body["options"] = options
        body.update(self._merge_params(params))
        return body

    def _do_complete(self, messages: Sequence[Message], **params: Any) -> CompletionResponse:
        model = self._resolve_model(params.pop("model", None))
        temperature = params.pop("temperature", None)
        max_tokens = params.pop("max_tokens", None)
        body = self._build_body(messages, model, temperature, max_tokens, False, params)
        data = http_utils.http_post(self._endpoint(), body, self._headers(), timeout=self.timeout, provider=self.name)

        prompt_tokens = int(data.get("prompt_eval_count", 0) or 0)
        completion_tokens = int(data.get("eval_count", 0) or 0)
        return CompletionResponse(
            text=data.get("message", {}).get("content", "") or "",
            model=data.get("model", model),
            provider=self.name,
            usage=Usage(prompt_tokens=prompt_tokens, completion_tokens=completion_tokens),
            finish_reason="stop" if data.get("done") else None,
            raw=data,
        )

    def _do_stream(self, messages: Sequence[Message], **params: Any) -> Iterator[StreamChunk]:
        model = self._resolve_model(params.pop("model", None))
        temperature = params.pop("temperature", None)
        max_tokens = params.pop("max_tokens", None)
        body = self._build_body(messages, model, temperature, max_tokens, True, params)
        # Ollama streams newline-delimited JSON (not SSE "data:" framed).
        lines = http_utils.http_post_stream(self._endpoint(), body, self._headers(), timeout=self.timeout, provider=self.name)
        for line in lines:
            if not line:
                continue
            try:
                event = json.loads(line)
            except ValueError:
                continue
            text = event.get("message", {}).get("content", "")
            done = bool(event.get("done"))
            usage = None
            if done:
                usage = Usage(
                    prompt_tokens=int(event.get("prompt_eval_count", 0) or 0),
                    completion_tokens=int(event.get("eval_count", 0) or 0),
                )
            yield StreamChunk(
                text=text,
                model=event.get("model", model),
                provider=self.name,
                finish_reason="stop" if done else None,
                usage=usage,
                done=done,
            )
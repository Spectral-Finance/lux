#!/usr/bin/env python3
"""
Spectral-Finance/lux Issue #99 — Python LLM Provider Abstraction Layer & Test Suite
Run built-in unit tests directly:
    python3 lux_issue_99_python_llm_provider.py
"""

from __future__ import annotations

import json
import os
import time
import unittest
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional, Tuple, Union


@dataclass
class ToolCall:
    id: str
    name: str
    arguments: Dict[str, Any]


@dataclass
class TokenUsage:
    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_tokens: int = 0


@dataclass
class LLMResponse:
    provider: str
    model: str
    content: Optional[str]
    tool_calls: List[ToolCall] = field(default_factory=list)
    finish_reason: str = "stop"
    usage: TokenUsage = field(default_factory=TokenUsage)
    raw: Dict[str, Any] = field(default_factory=dict)


@dataclass
class LLMConfig:
    provider: str = "openai"
    model: Optional[str] = None
    api_key: Optional[str] = None
    endpoint: Optional[str] = None
    temperature: float = 0.7
    max_tokens: int = 1024
    fallback_providers: List[str] = field(default_factory=list)
    max_retries: int = 2
    http_transport: Optional[Callable[[Dict[str, Any], "LLMConfig"], Dict[str, Any]]] = None


class BaseLLMProvider(ABC):
    @property
    @abstractmethod
    def provider_name(self) -> str:
        pass

    @property
    @abstractmethod
    def default_model(self) -> str:
        pass

    @property
    @abstractmethod
    def env_key_name(self) -> str:
        pass

    @property
    @abstractmethod
    def default_endpoint(self) -> str:
        pass

    def validate_config(self, config: LLMConfig) -> LLMConfig:
        resolved_key = config.api_key or os.environ.get(self.env_key_name)
        if not resolved_key and self.provider_name != "ollama":
            raise ValueError(f"Missing API key for provider '{self.provider_name}' ({self.env_key_name})")

        return LLMConfig(
            provider=self.provider_name,
            model=config.model or self.default_model,
            api_key=resolved_key,
            endpoint=config.endpoint or self.default_endpoint,
            temperature=config.temperature,
            max_tokens=config.max_tokens,
            fallback_providers=config.fallback_providers,
            max_retries=config.max_retries,
            http_transport=config.http_transport,
        )

    @staticmethod
    def normalize_messages(prompt_or_messages: Union[str, List[Dict[str, Any]]]) -> List[Dict[str, str]]:
        if isinstance(prompt_or_messages, str):
            return [{"role": "user", "content": prompt_or_messages}]
        return [
            {"role": str(m.get("role", "user")), "content": str(m.get("content", ""))}
            for m in prompt_or_messages
        ]

    @abstractmethod
    def build_payload(
        self,
        messages: List[Dict[str, str]],
        tools: Optional[List[Dict[str, Any]]],
        config: LLMConfig,
    ) -> Dict[str, Any]:
        pass

    @abstractmethod
    def parse_response(self, raw: Dict[str, Any], config: LLMConfig) -> LLMResponse:
        pass

    def call(
        self,
        prompt_or_messages: Union[str, List[Dict[str, Any]]],
        tools: Optional[List[Dict[str, Any]]] = None,
        config: Optional[LLMConfig] = None,
    ) -> LLMResponse:
        cfg = self.validate_config(config or LLMConfig(provider=self.provider_name))
        messages = self.normalize_messages(prompt_or_messages)
        payload = self.build_payload(messages, tools, cfg)

        last_err: Optional[Exception] = None
        for attempt in range(cfg.max_retries + 1):
            try:
                if cfg.http_transport is not None:
                    raw = cfg.http_transport(payload, cfg)
                else:
                    raw = {
                        "model": cfg.model,
                        "choices": [{"message": {"content": f"Simulated response from {self.provider_name}"}, "finish_reason": "stop"}],
                        "usage": {"prompt_tokens": 12, "completion_tokens": 8, "total_tokens": 20},
                    }
                return self.parse_response(raw, cfg)
            except Exception as exc:
                last_err = exc
                if attempt < cfg.max_retries:
                    time.sleep(0.05 * (2 ** attempt))
        raise RuntimeError(f"Provider '{self.provider_name}' failed after {cfg.max_retries + 1} attempts: {last_err}")


class OpenAICompatibleProvider(BaseLLMProvider):
    @property
    def provider_name(self) -> str:
        return "openai"

    @property
    def default_model(self) -> str:
        return "gpt-4o"

    @property
    def env_key_name(self) -> str:
        return "OPENAI_API_KEY"

    @property
    def default_endpoint(self) -> str:
        return "https://api.openai.com/v1/chat/completions"

    def build_payload(
        self,
        messages: List[Dict[str, str]],
        tools: Optional[List[Dict[str, Any]]],
        config: LLMConfig,
    ) -> Dict[str, Any]:
        payload: Dict[str, Any] = {
            "model": config.model,
            "messages": messages,
            "temperature": config.temperature,
            "max_tokens": config.max_tokens,
        }
        if tools:
            payload["tools"] = tools
        return payload

    def parse_response(self, raw: Dict[str, Any], config: LLMConfig) -> LLMResponse:
        choices = raw.get("choices", [{}])
        first_choice = choices[0] if choices else {}
        message = first_choice.get("message", {})
        usage_raw = raw.get("usage", {})

        parsed_tools: List[ToolCall] = []
        for tc in message.get("tool_calls", []):
            fn = tc.get("function", {})
            raw_args = fn.get("arguments", "{}")
            if isinstance(raw_args, str):
                try:
                    args = json.loads(raw_args)
                except json.JSONDecodeError:
                    args = {"raw": raw_args}
            else:
                args = raw_args
            parsed_tools.append(
                ToolCall(
                    id=str(tc.get("id", "")),
                    name=str(fn.get("name", "")),
                    arguments=args,
                )
            )

        return LLMResponse(
            provider=self.provider_name,
            model=str(raw.get("model", config.model)),
            content=message.get("content"),
            tool_calls=parsed_tools,
            finish_reason=str(first_choice.get("finish_reason", "stop")),
            usage=TokenUsage(
                prompt_tokens=int(usage_raw.get("prompt_tokens", 0)),
                completion_tokens=int(usage_raw.get("completion_tokens", 0)),
                total_tokens=int(usage_raw.get("total_tokens", 0)),
            ),
            raw=raw,
        )


class TogetherAIProvider(OpenAICompatibleProvider):
    @property
    def provider_name(self) -> str:
        return "together"

    @property
    def default_model(self) -> str:
        return "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo"

    @property
    def env_key_name(self) -> str:
        return "TOGETHER_API_KEY"

    @property
    def default_endpoint(self) -> str:
        return "https://api.together.xyz/v1/chat/completions"


class MiraNetworkProvider(OpenAICompatibleProvider):
    @property
    def provider_name(self) -> str:
        return "mira"

    @property
    def default_model(self) -> str:
        return "mira-llama-3.1-70b"

    @property
    def env_key_name(self) -> str:
        return "MIRA_API_KEY"

    @property
    def default_endpoint(self) -> str:
        return "https://api.mira.network/v1/chat/completions"


class AnthropicProvider(BaseLLMProvider):
    @property
    def provider_name(self) -> str:
        return "anthropic"

    @property
    def default_model(self) -> str:
        return "claude-3-5-sonnet-latest"

    @property
    def env_key_name(self) -> str:
        return "ANTHROPIC_API_KEY"

    @property
    def default_endpoint(self) -> str:
        return "https://api.anthropic.com/v1/messages"

    def build_payload(
        self,
        messages: List[Dict[str, str]],
        tools: Optional[List[Dict[str, Any]]],
        config: LLMConfig,
    ) -> Dict[str, Any]:
        system_msgs = [m["content"] for m in messages if m["role"] == "system"]
        chat_msgs = [m for m in messages if m["role"] != "system"]
        payload: Dict[str, Any] = {
            "model": config.model,
            "messages": chat_msgs,
            "max_tokens": config.max_tokens,
            "temperature": config.temperature,
        }
        if system_msgs:
            payload["system"] = "\n".join(system_msgs)
        if tools:
            payload["tools"] = tools
        return payload

    def parse_response(self, raw: Dict[str, Any], config: LLMConfig) -> LLMResponse:
        blocks = raw.get("content", [])
        text_parts: List[str] = []
        tool_calls: List[ToolCall] = []

        for block in blocks:
            btype = block.get("type")
            if btype == "text":
                text_parts.append(str(block.get("text", "")))
            elif btype == "tool_use":
                tool_calls.append(
                    ToolCall(
                        id=str(block.get("id", "")),
                        name=str(block.get("name", "")),
                        arguments=dict(block.get("input", {})),
                    )
                )

        usage_raw = raw.get("usage", {})
        in_tok = int(usage_raw.get("input_tokens", 0))
        out_tok = int(usage_raw.get("output_tokens", 0))
        stop_reason = raw.get("stop_reason", "end_turn")

        return LLMResponse(
            provider="anthropic",
            model=str(raw.get("model", config.model)),
            content="\n".join(text_parts) if text_parts else None,
            tool_calls=tool_calls,
            finish_reason="tool_calls" if stop_reason == "tool_use" else "stop",
            usage=TokenUsage(
                prompt_tokens=in_tok,
                completion_tokens=out_tok,
                total_tokens=in_tok + out_tok,
            ),
            raw=raw,
        )


class LLMRouter:
    def __init__(self) -> None:
        self._registry: Dict[str, BaseLLMProvider] = {
            "openai": OpenAICompatibleProvider(),
            "together": TogetherAIProvider(),
            "mira": MiraNetworkProvider(),
            "anthropic": AnthropicProvider(),
        }

    def register_provider(self, provider: BaseLLMProvider) -> None:
        self._registry[provider.provider_name] = provider

    def get_provider(self, name: str) -> BaseLLMProvider:
        if name not in self._registry:
            raise KeyError(f"Unsupported LLM provider '{name}'. Available: {list(self._registry.keys())}")
        return self._registry[name]

    def call(
        self,
        prompt_or_messages: Union[str, List[Dict[str, Any]]],
        tools: Optional[List[Dict[str, Any]]] = None,
        config: Optional[LLMConfig] = None,
    ) -> LLMResponse:
        cfg = config or LLMConfig()
        chain = [cfg.provider] + list(cfg.fallback_providers)
        errors: List[Tuple[str, str]] = []

        for provider_name in chain:
            try:
                provider = self.get_provider(provider_name)
                step_cfg = LLMConfig(
                    provider=provider_name,
                    model=cfg.model if provider_name == cfg.provider else None,
                    api_key=cfg.api_key,
                    endpoint=cfg.endpoint if provider_name == cfg.provider else None,
                    temperature=cfg.temperature,
                    max_tokens=cfg.max_tokens,
                    max_retries=cfg.max_retries,
                    http_transport=cfg.http_transport,
                )
                return provider.call(prompt_or_messages, tools=tools, config=step_cfg)
            except Exception as err:
                errors.append((provider_name, str(err)))

        raise RuntimeError(f"All LLM providers in chain failed: {errors}")


class TestLuxLLMProviderAbstraction(unittest.TestCase):
    def setUp(self) -> None:
        self.router = LLMRouter()

    def test_openai_tool_call_normalization(self) -> None:
        def mock_openai_transport(payload: Dict[str, Any], cfg: LLMConfig) -> Dict[str, Any]:
            self.assertEqual(payload["model"], "gpt-4o")
            return {
                "model": "gpt-4o",
                "choices": [
                    {
                        "finish_reason": "tool_calls",
                        "message": {
                            "content": None,
                            "tool_calls": [
                                {
                                    "id": "call_abc123",
                                    "function": {
                                        "name": "execute_swap",
                                        "arguments": '{"token_in": "USDC", "amount": 500}',
                                    },
                                }
                            ],
                        },
                    }
                ],
                "usage": {"prompt_tokens": 25, "completion_tokens": 15, "total_tokens": 40},
            }

        cfg = LLMConfig(provider="openai", api_key="sk-test-key", http_transport=mock_openai_transport)
        resp = self.router.call("Swap 500 USDC", config=cfg)
        self.assertEqual(resp.provider, "openai")
        self.assertEqual(resp.finish_reason, "tool_calls")
        self.assertEqual(len(resp.tool_calls), 1)
        self.assertEqual(resp.tool_calls[0].name, "execute_swap")
        self.assertEqual(resp.tool_calls[0].arguments, {"token_in": "USDC", "amount": 500})
        self.assertEqual(resp.usage.total_tokens, 40)

    def test_anthropic_message_and_tool_use_normalization(self) -> None:
        def mock_anthropic_transport(payload: Dict[str, Any], cfg: LLMConfig) -> Dict[str, Any]:
            self.assertEqual(payload["system"], "You are a Lux trading agent.")
            return {
                "model": "claude-3-5-sonnet-latest",
                "stop_reason": "tool_use",
                "content": [
                    {"type": "text", "text": "Analyzing market signal..."},
                    {
                        "type": "tool_use",
                        "id": "toolu_01",
                        "name": "emit_signal",
                        "input": {"signal": "BUY", "confidence": 0.92},
                    },
                ],
                "usage": {"input_tokens": 30, "output_tokens": 20},
            }

        messages = [
            {"role": "system", "content": "You are a Lux trading agent."},
            {"role": "user", "content": "Check BTC signal"},
        ]
        cfg = LLMConfig(provider="anthropic", api_key="sk-ant-test", http_transport=mock_anthropic_transport)
        resp = self.router.call(messages, config=cfg)
        self.assertEqual(resp.provider, "anthropic")
        self.assertEqual(resp.content, "Analyzing market signal...")
        self.assertEqual(resp.finish_reason, "tool_calls")
        self.assertEqual(resp.tool_calls[0].name, "emit_signal")
        self.assertEqual(resp.usage.total_tokens, 50)

    def test_automatic_fallback_chain(self) -> None:
        call_log: List[str] = []

        def flaky_transport(payload: Dict[str, Any], cfg: LLMConfig) -> Dict[str, Any]:
            call_log.append(cfg.provider)
            if cfg.provider == "openai":
                raise ConnectionError("OpenAI 503 Service Unavailable")
            return {
                "model": cfg.model,
                "choices": [{"message": {"content": "Recovered via Together AI"}, "finish_reason": "stop"}],
                "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15},
            }

        cfg = LLMConfig(
            provider="openai",
            api_key="shared-test-key",
            fallback_providers=["together"],
            max_retries=0,
            http_transport=flaky_transport,
        )
        resp = self.router.call("Ping", config=cfg)
        self.assertEqual(call_log, ["openai", "together"])
        self.assertEqual(resp.provider, "together")
        self.assertEqual(resp.content, "Recovered via Together AI")


if __name__ == "__main__":
    unittest.main(verbosity=2)

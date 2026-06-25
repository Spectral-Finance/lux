defmodule Lux.LLM.Providers.OpenRouter do
  @moduledoc """
  OpenRouter API integration for Lux.

  Provides access to a wide range of LLM models through a single unified API.
  Supports multiple models, rate limiting, cost tracking, and error handling with retries.

  ## Configuration

  
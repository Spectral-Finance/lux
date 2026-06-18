defmodule Lux.Lenses.Telegram.MissingTokenTest do
  @moduledoc """
  Regression tests ensuring the Telegram read lenses fail locally with the same
  `{:error, :missing_token}` shape returned by `Lux.Integrations.Telegram.Client`
  when no bot token is configured, instead of issuing a live request against the
  unsubstituted ":token" URL placeholder.

  Runs `async: false` because it temporarily removes the globally configured bot
  token; isolation prevents interference with concurrent token-dependent tests.
  """
  use UnitAPICase, async: false

  alias Lux.Lenses.Telegram.GetFile
  alias Lux.Lenses.Telegram.GetWebhookInfo
  alias Lux.Lenses.Telegram.ListUpdates

  setup do
    original_keys = Application.get_env(:lux, :api_keys)
    original_env = System.get_env("TELEGRAM_BOT_TOKEN")

    Application.delete_env(:lux, :api_keys)
    System.delete_env("TELEGRAM_BOT_TOKEN")

    on_exit(fn ->
      if original_keys, do: Application.put_env(:lux, :api_keys, original_keys)
      if original_env, do: System.put_env("TELEGRAM_BOT_TOKEN", original_env)
    end)

    :ok
  end

  # No `Req.Test.expect/2` is set in these tests: if a lens fell through to a live
  # request the configured `{Req.Test, Lux.Lens}` plug would raise on the
  # unexpected call, so reaching the assertion proves the failure happened locally.

  test "ListUpdates.focus/2 fails locally with {:error, :missing_token}" do
    assert {:error, :missing_token} = ListUpdates.focus()
    assert {:error, :missing_token} = ListUpdates.focus(%{offset: 1, limit: 10})
  end

  test "GetFile.focus/2 fails locally with {:error, :missing_token}" do
    assert {:error, :missing_token} = GetFile.focus(%{file_id: "file_123"})
  end

  test "GetWebhookInfo.focus/2 fails locally with {:error, :missing_token}" do
    assert {:error, :missing_token} = GetWebhookInfo.focus()
  end
end

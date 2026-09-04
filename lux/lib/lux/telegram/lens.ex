defmodule Lux.Telegram.Lens do
  @moduledoc """
  Macro for defining Telegram API lenses with default headers and authentication.
  """

  defmacro __using__(opts) do
    quote do
      alias Lux.Integrations.Telegram

      opts =
        unquote(opts)
        |> Keyword.put_new(:headers, Telegram.headers())
        |> Keyword.put_new(:auth, Telegram.auth())

      use Lux.Lens, opts
    end
  end
end

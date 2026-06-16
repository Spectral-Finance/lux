defmodule Lux.Integrations.Telegram do
  @moduledoc """
  Common settings and functions for Telegram Bot API integration.

  Provides safe token retrieval with fallback and polymorphic authentication
  handling for `%Lux.Lens{}`, `%Plug.Conn{}`, and `%Req.Request{}` structs.
  """

  @doc """
  Common request settings for Telegram Bot API calls.
  """
  def request_settings do
    %{
      headers: [{"Content-Type", "application/json"}],
      auth: %{
        type: :custom,
        auth_function: &__MODULE__.add_auth/1
      }
    }
  end

  @doc """
  Common headers for Telegram Bot API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Common auth settings for Telegram Bot API calls.
  """
  def auth,
    do: %{
      type: :custom,
      auth_function: &__MODULE__.add_auth/1
    }

  @doc """
  Retrieves the Telegram Bot token with fallback.

  1. Checks `Application.get_env(:lux, :api_keys)[:telegram_bot]`
  2. Falls back to the `TELEGRAM_BOT_TOKEN` environment variable
  3. Returns `{:error, :missing_token}` if neither is configured

  ## Examples

      iex> Lux.Integrations.Telegram.get_token()
      {:ok, "123456:ABC-DEF"}

      iex> Lux.Integrations.Telegram.get_token()
      {:error, :missing_token}
  """
  @spec get_token() :: {:ok, String.t()} | {:error, :missing_token}
  def get_token do
    case Application.get_env(:lux, :api_keys) do
      keys when is_list(keys) or is_map(keys) ->
        case keys[:telegram_bot] do
          nil -> get_token_from_env()
          token when is_binary(token) and token != "" -> {:ok, token}
          _ -> get_token_from_env()
        end

      _ ->
        get_token_from_env()
    end
  end

  defp get_token_from_env do
    case System.get_env("TELEGRAM_BOT_TOKEN") do
      nil -> {:error, :missing_token}
      "" -> {:error, :missing_token}
      token -> {:ok, token}
    end
  end

  @doc """
  Resolves authentication by retrieving the Telegram bot token and replacing
  the `:token` placeholder in URL or path fields.

  Safely handles the following struct types:
  - `%Lux.Lens{}` — replaces `:token` in the `url` field
  - `%Plug.Conn{}` — replaces `:token` in the `request_path` field
  - `%Req.Request{}` — replaces `:token` in the URL path

  Returns the struct unmodified if the token is missing, preventing crashes.

  ## Examples

      iex> lens = %Lux.Lens{url: "https://api.telegram.org/bot:token/getMe"}
      iex> Lux.Integrations.Telegram.add_auth(lens)
      %Lux.Lens{url: "https://api.telegram.org/bot<TOKEN>/getMe"}
  """
  @spec add_auth(Lux.Lens.t() | Plug.Conn.t() | Req.Request.t() | any()) ::
          Lux.Lens.t() | Plug.Conn.t() | Req.Request.t() | any()
  def add_auth(input) do
    case get_token() do
      {:ok, token} ->
        apply_auth(input, token)

      {:error, _reason} ->
        # Return unmodified structure to prevent crash
        input
    end
  end

  @doc """
  Adds Telegram bot token to the URL.
  Deprecated — use `add_auth/1` instead.
  """
  @spec add_auth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    add_auth(conn)
  end

  # --- Private Helpers ---

  defp apply_auth(%Lux.Lens{} = lens, token) do
    updated_url = replace_token_in_string(lens.url || "", token)
    normalized_params = normalize_keys(lens.params || %{})
    %{lens | url: updated_url, params: normalized_params}
  end

  defp apply_auth(%Plug.Conn{} = conn, token) do
    updated_path = replace_token_in_string(conn.request_path, token)
    %{conn | request_path: updated_path}
  end

  defp apply_auth(%Req.Request{} = req, token) do
    path = req.url.path || ""
    updated_path = replace_token_in_string(path, token)
    %{req | url: %{req.url | path: updated_path}}
  end

  defp apply_auth(other, _token), do: other

  defp replace_token_in_string(string, token) do
    case Regex.run(~r/(^|\/)bot(?::token|(?=\/|$))(\/?)/, string) do
      [match, leading, trailing] ->
        String.replace(string, match, "#{leading}bot#{token}#{trailing}")

      _ ->
        string
    end
  end

  @doc """
  Recursively normalizes map keys of the input to existing atoms when possible,
  bypassing structs to preserve system invariants.
  """
  def normalize_keys(input) when is_map(input) do
    if Map.has_key?(input, :__struct__) do
      input
    else
      Map.new(input, fn {key, val} ->
        new_key =
          cond do
            is_binary(key) ->
              try do
                String.to_existing_atom(key)
              rescue
                ArgumentError -> key
              end

            true ->
              key
          end

        {new_key, normalize_keys(val)}
      end)
    end
  end

  def normalize_keys(list) when is_list(list) do
    Enum.map(list, &normalize_keys/1)
  end

  def normalize_keys(other), do: other
end

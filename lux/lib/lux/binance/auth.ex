defmodule Lux.Binance.Auth do
  @moduledoc """
  Authentication helper for Binance Spot & Futures REST/WebSocket APIs.

  Provides HMAC-SHA256 signing for query string and body parameters,
  handling timestamping (`timestamp`), receive windows (`recvWindow`),
  and API key headers (`X-MBX-APIKEY`).

  ## Examples

      iex> params = %{symbol: "LTCBTC", side: "BUY", type: "LIMIT", timeInForce: "GTC", quantity: "1", price: "0.1", recvWindow: 5000, timestamp: 1499827319559}
      iex> secret = "NhqPtMDL5cvBxT3a65KSTBmUzaw9M6PZ18fLiNFZw9z86St0695BWkTxzYD6dAe3"
      iex> signed = Lux.Binance.Auth.sign_params(params, secret)
      iex> signed[:signature]
      "309283bae93927d3ac2a62c8fe2030238d02e914fc802e5dab819aced58b234b"
  """

  @doc """
  Signs a map, keyword list, or query binary payload with HMAC-SHA256 using the secret key.
  Appends `timestamp` and `recvWindow` if missing, then adds the computed signature.
  """
  @spec sign_params(map() | keyword() | binary(), binary(), integer()) :: map() | keyword() | binary()
  def sign_params(params, secret_key, recv_window \\ 5000)

  def sign_params(payload, secret_key, recv_window) when is_binary(payload) do
    payload_with_defaults = add_auth_defaults_binary(payload, recv_window)
    signature = sign(payload_with_defaults, secret_key)

    if payload_with_defaults == "" do
      "signature=" <> signature
    else
      payload_with_defaults <> "&signature=" <> signature
    end
  end

  def sign_params(params, secret_key, recv_window) when is_map(params) do
    params_with_defaults = add_auth_defaults_map(params, recv_window)
    query_string = to_query_string_for_signing(params_with_defaults)
    signature = sign(query_string, secret_key)

    if Map.has_key?(params, "symbol") or Map.has_key?(params, "timestamp") do
      Map.put(params_with_defaults, "signature", signature)
    else
      Map.put(params_with_defaults, :signature, signature)
    end
  end

  def sign_params(params, secret_key, recv_window) when is_list(params) do
    params_with_defaults = add_auth_defaults_keyword(params, recv_window)
    query_string = to_query_string(params_with_defaults)
    signature = sign(query_string, secret_key)

    params_with_defaults ++ [signature: signature]
  end

  @doc """
  Generates lower-case hex HMAC-SHA256 signature for given binary payload.
  """
  @spec sign(binary(), binary()) :: binary()
  def sign(payload, secret_key) when is_binary(payload) and is_binary(secret_key) do
    :crypto.mac(:hmac, :sha256, secret_key, payload)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Alias for `sign/2`. Generates lower-case hex HMAC-SHA256 signature.
  """
  @spec hmac_sha256(binary(), binary()) :: binary()
  def hmac_sha256(secret_key, payload) do
    sign(payload, secret_key)
  end

  @doc """
  Builds standard headers including `X-MBX-APIKEY` header.
  """
  @spec headers(binary() | nil) :: list({binary(), binary()})
  def headers(nil), do: []
  def headers(api_key) when is_binary(api_key) do
    [{"X-MBX-APIKEY", api_key}]
  end

  @doc """
  Converts params to URI query string for signing and HTTP requests,
  ensuring signature is placed strictly as the VERY LAST query parameter.
  """
  @spec to_query_string(map() | keyword() | binary()) :: binary()
  def to_query_string(payload) when is_binary(payload), do: payload

  def to_query_string(params) when is_map(params) do
    sig = Map.get(params, :signature) || Map.get(params, "signature")
    rest = Map.drop(params, [:signature, "signature"])
    sorted = Enum.sort_by(rest, fn {k, _v} -> to_string(k) end)
    qs = URI.encode_query(sorted)

    if sig do
      if qs == "", do: "signature=#{sig}", else: "#{qs}&signature=#{sig}"
    else
      qs
    end
  end

  def to_query_string(params) when is_list(params) do
    {sig, rest} = pop_keyword_signature(params)
    qs = URI.encode_query(rest)

    if sig do
      if qs == "", do: "signature=#{sig}", else: "#{qs}&signature=#{sig}"
    else
      qs
    end
  end

  # Helper functions

  defp to_query_string_for_signing(map) when is_map(map) do
    sorted = Enum.sort_by(map, fn {k, _v} -> to_string(k) end)
    URI.encode_query(sorted)
  end

  defp add_auth_defaults_binary(payload, recv_window) do
    has_timestamp = String.contains?(payload, "timestamp=") or String.contains?(payload, "timestamp%3D")
    has_recv_window = String.contains?(payload, "recvWindow=") or String.contains?(payload, "recvWindow%3D")

    if has_timestamp and has_recv_window do
      payload
    else
      now = System.system_time(:millisecond)
      to_add = []
      to_add = if has_timestamp, do: to_add, else: to_add ++ ["timestamp=#{now}"]
      to_add = if has_recv_window, do: to_add, else: to_add ++ ["recvWindow=#{recv_window}"]
      added_str = Enum.join(to_add, "&")

      cond do
        payload == "" -> added_str
        added_str == "" -> payload
        true -> payload <> "&" <> added_str
      end
    end
  end

  defp add_auth_defaults_map(params, recv_window) do
    now = System.system_time(:millisecond)

    params
    |> put_default_if_missing("timestamp", :timestamp, now)
    |> put_default_if_missing("recvWindow", :recvWindow, recv_window)
  end

  defp put_default_if_missing(map, str_key, atom_key, default) do
    has_str = Map.has_key?(map, str_key)
    has_atom = Map.has_key?(map, atom_key)

    cond do
      has_str or has_atom -> map
      Map.has_key?(map, "symbol") -> Map.put(map, str_key, default)
      true -> Map.put(map, atom_key, default)
    end
  end

  defp add_auth_defaults_keyword(params, recv_window) do
    now = System.system_time(:millisecond)

    params =
      if Keyword.has_key?(params, :timestamp) do
        params
      else
        params ++ [timestamp: now]
      end

    if Keyword.has_key?(params, :recvWindow) do
      params
    else
      params ++ [recvWindow: recv_window]
    end
  end

  defp pop_keyword_signature(params) do
    case Keyword.pop(params, :signature) do
      {nil, rest} -> {nil, rest}
      {sig, rest} -> {sig, rest}
    end
  end
end

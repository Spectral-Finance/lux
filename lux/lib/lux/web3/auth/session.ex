defmodule Lux.Web3.Auth.Session do
  @moduledoc """
  Stateless session helpers for Web3 authentication flows.
  """

  @doc """
  Issues a session map for a verified wallet address.
  """
  @spec issue(String.t(), keyword() | map()) :: map()
  def issue(address, opts \\ %{}) do
    now = option(opts, :now, DateTime.utc_now())
    ttl_seconds = option(opts, :ttl_seconds, 3_600)

    %{
      id: Lux.UUID.generate(),
      subject: String.downcase(address),
      roles: option(opts, :roles, []),
      permissions: option(opts, :permissions, []),
      issued_at: DateTime.to_iso8601(now),
      expires_at: now |> DateTime.add(ttl_seconds, :second) |> DateTime.to_iso8601()
    }
  end

  @doc """
  Returns true when a session is expired.
  """
  @spec expired?(map(), DateTime.t()) :: boolean()
  def expired?(session, now \\ DateTime.utc_now()) do
    case DateTime.from_iso8601(session.expires_at) do
      {:ok, expires_at, _offset} -> DateTime.compare(expires_at, now) != :gt
      _ -> true
    end
  end

  defp option(opts, key, default) do
    case opts[key] do
      nil -> default
      value -> value
    end
  end
end

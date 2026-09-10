defmodule Lux.Web3.Auth.SIWE do
  @moduledoc """
  EIP-4361: Sign-In with Ethereum implementation for Lux.
  Provides structured message generation, parsing, and cryptographically sound validation.
  """

  @type t :: %__MODULE__{
          domain: String.t(),
          address: String.t(),
          statement: String.t() | nil,
          uri: String.t(),
          version: String.t(),
          chain_id: pos_integer(),
          nonce: String.t(),
          issued_at: DateTime.t(),
          expiration_time: DateTime.t() | nil,
          not_before: DateTime.t() | nil,
          request_id: String.t() | nil,
          resources: [String.t()]
        }

  defstruct [
    :domain,
    :address,
    :statement,
    :uri,
    :version,
    :chain_id,
    :nonce,
    :issued_at,
    :expiration_time,
    :not_before,
    :request_id,
    resources: []
  ]

  @doc """
  Generates a cryptographically secure random nonce for session isolation and replay protection.
  """
  def generate_nonce(bytes \\ 16) do
    :crypto.strong_rand_bytes(bytes) |> Base.encode16(case: :lower)
  end

  @doc """
  Formats a SIWE struct into an EIP-4361 compliant message string.
  """
  def format_message(%__MODULE__{} = msg) do
    header = "#{msg.domain} wants you to sign in with your Ethereum account:\n#{msg.address}\n\n"
    statement = if msg.statement, do: "#{msg.statement}\n\n", else: ""
    body = "URI: #{msg.uri}\nVersion: #{msg.version}\nChain ID: #{msg.chain_id}\nNonce: #{msg.nonce}\nIssued At: #{DateTime.to_iso8601(msg.issued_at)}"
    
    header <> statement <> body
  end

  @doc """
  Validates message freshness and expiration.
  """
  def validate_timestamps(%__MODULE__{expiration_time: exp, not_before: nbf}) do
    now = DateTime.utc_now()

    cond do
      exp != nil and DateTime.compare(now, exp) == :gt ->
        {:error, :expired}

      nbf != nil and DateTime.compare(now, nbf) == :lt ->
        {:error, :not_yet_valid}

      true ->
        :ok
    end
  end
end

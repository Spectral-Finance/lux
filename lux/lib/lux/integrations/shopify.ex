defmodule Lux.Integrations.Shopify do
  @moduledoc """
  Common settings and functions for the Shopify Admin API integration.

  Shopify exposes two Admin API surfaces:

    * **REST Admin API** — resource-oriented endpoints under
      `https://{shop}.myshopify.com/admin/api/{version}/{resource}.json`.
    * **GraphQL Admin API** — a single `POST /admin/api/{version}/graphql.json`
      endpoint.

  This module centralises configuration (shop domain, API version, access
  token), header construction, and authentication so that lenses and prisms can
  share a single source of truth.

  ## Configuration

      config :lux, Lux.Integrations.Shopify,
        shop: System.get_env("SHOPIFY_SHOP") || "my-shop.myshopify.com",
        api_version: System.get_env("SHOPIFY_API_VERSION") || "2024-10",
        access_token: System.get_env("SHOPIFY_ACCESS_TOKEN")

  ## Authentication

  Shopify supports two authentication modes:

    * **Admin API access token** (private / custom app) — sent via the
      `X-Shopify-Access-Token` header.
    * **OAuth 2.0** — the access token obtained from the OAuth grant is used in
      exactly the same way (it is still sent via `X-Shopify-Access-Token`).

  ## Usage

      alias Lux.Integrations.Shopify

      Shopify.base_url()   # => "https://my-shop.myshopify.com"
      Shopify.headers()    # => [{"Content-Type", "application/json"}, ...]
      Shopify.auth()       # => %{type: :custom, auth_function: &Shopify.add_auth_header/1}
  """

  require Logger

  @default_api_version "2024-10"

  @type headers :: [{String.t(), String.t()}]

  @doc """
  Returns the configured shop domain (e.g. `"my-shop.myshopify.com"`).
  """
  @spec shop() :: String.t()
  def shop do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:shop, System.get_env("SHOPIFY_SHOP"))
  end

  @doc """
  Returns the configured Admin API version (defaults to `"2024-10"`).
  """
  @spec api_version() :: String.t()
  def api_version do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:api_version, System.get_env("SHOPIFY_API_VERSION") || @default_api_version)
  end

  @doc """
  Returns the base URL for the configured shop, e.g.
  `"https://my-shop.myshopify.com"`.

  When no shop is configured, a placeholder is returned so that modules which
  reference the URL at compile time (e.g. lenses) can still be built. The
  access token is still required at request time.
  """
  @spec base_url() :: String.t()
  def base_url do
    case shop() do
      nil -> "https://shop.myshopify.com"
      shop -> "https://#{shop}"
    end
  end

  @doc """
  Returns the base URL for Admin API requests, including the API version, e.g.
  `"https://my-shop.myshopify.com/admin/api/2024-10"`.
  """
  @spec admin_api_url() :: String.t()
  def admin_api_url do
    "#{base_url()}/admin/api/#{api_version()}"
  end

  @doc """
  Returns the default headers for Shopify Admin API requests.
  """
  @spec headers() :: headers()
  def headers do
    [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]
  end

  @doc """
  Returns the authentication configuration for Shopify Admin API requests.
  """
  @spec auth() :: map()
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    }
  end

  @doc """
  Adds the `X-Shopify-Access-Token` header to a `Lux.Lens` or `Plug.Conn`.
  """
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    %{lens | headers: lens.headers ++ [{"X-Shopify-Access-Token", access_token()}]}
  end

  @spec add_auth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    Plug.Conn.put_req_header(conn, "x-shopify-access-token", access_token())
  end

  @doc """
  Returns the configured Shopify Admin API access token.
  Raises if the token is not configured.
  """
  @spec access_token() :: String.t()
  def access_token do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:access_token, System.get_env("SHOPIFY_ACCESS_TOKEN")) ||
      raise "Shopify access token is not configured (set :access_token in config or SHOPIFY_ACCESS_TOKEN)"
  end
end
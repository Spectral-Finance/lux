# Coinbase Exchange Integration

`Lux.Integrations.Coinbase.Exchange` provides a safe planning layer for
Coinbase Advanced Trade integration. It does not store API keys, sign JWTs, or
submit live orders. Instead, it prepares REST request plans, JWT claims,
WebSocket subscribe messages, order payloads, account snapshots, and rate-limit
summaries that a lens, prism, or client adapter can execute.

## REST market data

```elixir
alias Lux.Integrations.Coinbase.Exchange

{:ok, request} =
  Exchange.public_request(:product_book, %{
    product_id: "BTC-USD",
    limit: 50
  })

request.url
#=> "https://api.coinbase.com/api/v3/brokerage/product_book"

request.params
#=> %{product_id: "BTC-USD", limit: 50}
```

Supported public request names:

- `:products`
- `:product`
- `:product_book`
- `:best_bid_ask`
- `:market_trades`
- `:candles`

## Signed requests

Signed request planning returns the path, body, headers, and JWT claims that an
external signer can sign. Secrets stay outside this module.

```elixir
{:ok, request} =
  Exchange.signed_request(:create_order, %{
    jwt: "already-signed-jwt",
    api_key_name: "organizations/org/apiKeys/key",
    issued_at: 1_700_000_000,
    client_order_id: "lux-1",
    product_id: "BTC-USD",
    side: "BUY",
    type: "MARKET",
    base_size: "0.1"
  })

request.jwt_claims.uri
#=> "POST api.coinbase.com/api/v3/brokerage/orders"
```

Supported signed request names:

- `:accounts`
- `:account`
- `:portfolios`
- `:orders`
- `:order`
- `:fills`
- `:create_order`
- `:cancel_orders`

## Order planning

Market orders require either `base_size` or `quote_size`.

```elixir
{:ok, order} =
  Exchange.order_plan(%{
    product_id: "ETH-USD",
    side: :buy,
    type: :market,
    quote_size: "100.50"
  })

order.order_configuration
#=> %{market_market_ioc: %{quote_size: "100.5"}}
```

Limit orders require `base_size` and `limit_price`.

```elixir
{:ok, order} =
  Exchange.order_plan(%{
    product_id: "ETH-USD",
    side: :sell,
    type: :limit,
    base_size: "1.25",
    limit_price: "3100",
    post_only: true
  })
```

## WebSocket feeds

```elixir
{:ok, sub} =
  Exchange.websocket_subscription([:ticker, :level2], ["BTC-USD", "ETH-USD"], %{
    jwt: "optional-jwt"
  })

sub.message
#=> %{
#=>   type: "subscribe",
#=>   product_ids: ["BTC-USD", "ETH-USD"],
#=>   channel_names: ["ticker", "level2"],
#=>   jwt: "optional-jwt"
#=> }
```

## Rate limits

```elixir
Exchange.rate_limit_summary([%{weight: 2}, %{weight: 3}], %{limit_per_second: 10})
#=> %{
#=>   request_count: 2,
#=>   used_weight: 5,
#=>   limit_per_second: 10,
#=>   remaining_weight: 5,
#=>   allowed?: true,
#=>   utilization: 0.5
#=> }
```

## Portfolio snapshots

```elixir
Exchange.portfolio_snapshot(%{
  accounts: [
    %{uuid: "btc", currency: "BTC", available_balance: %{value: "0.25"}, hold: "0.01"},
    %{uuid: "usd", currency: "USD", available: "100.50", hold_balance: 0}
  ]
})
```

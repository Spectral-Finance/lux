alias Lux.Integrations.Twitter
alias Lux.Integrations.Twitter.Client

iterations =
  System.get_env("ITERATIONS", "10000")
  |> String.to_integer()

results = %{
  authorization_url:
    Client.benchmark(
      fn ->
        Client.authorization_url(%{
          client_id: "client-id",
          redirect_uri: "https://example.com/callback",
          state: "state",
          code_verifier: "verifier"
        })
      end,
      iterations
    ),
  rate_limit:
    Client.benchmark(
      fn ->
        Twitter.rate_limit(%{
          "x-rate-limit-limit" => "300",
          "x-rate-limit-remaining" => "299",
          "x-rate-limit-reset" => "1"
        })
      end,
      iterations
    )
}

IO.inspect(results, label: "Twitter client benchmark")

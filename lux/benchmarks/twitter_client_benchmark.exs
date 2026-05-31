Mix.install([{:benchee, "~> 1.3"}])

alias Lux.Integrations.Twitter.Client

Benchee.run(%{
  "authorization_url/1" => fn ->
    Client.authorization_url(%{
      client_id: "client",
      redirect_uri: "https://example.com/callback",
      state: "state",
      code_verifier: "verifier"
    })
  end,
  "pkce_pair/1" => fn ->
    Client.pkce_pair("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
  end
})

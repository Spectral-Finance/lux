# Run with: mix run examples/rust_components.exs
#
# Demonstrates Lux.Rust.Component: listing registered native Prisms/Beams,
# viewing them as %Lux.Prism{} / %Lux.Beam{} structs, running them through
# the dirty-CPU NIF, and (when Tokio is up) the async sleep prism.

unless Lux.Rust.available?() do
  Mix.raise("""
  lux_core NIF is not loaded. From the lux/ mix project run:

      mix deps.get
      mix compile
      mix run examples/rust_components.exs
  """)
end

IO.puts("lux_core #{elem(Lux.Rust.version(), 1)}")
IO.puts("async runtime: #{Lux.Rust.async_available?()}")
IO.puts("")

{:ok, components} = Lux.Rust.Component.list()

IO.puts("registered components:")

for c <- components do
  id = Map.get(c, :id) || Map.get(c, "id")
  kind = Map.get(c, :kind) || Map.get(c, "kind")
  IO.puts("  - #{id} (#{kind})")
end

IO.puts("")

{:ok, echo} = Lux.Rust.Component.view("echo")
IO.inspect(echo.handler, label: "echo handler")
IO.inspect(Lux.Rust.Component.run("echo", %{"hello" => "from rust"}), label: "echo")
IO.inspect(Lux.Rust.Component.run("fib", 10), label: "fib(10)")
IO.inspect(Lux.Rust.Component.run("hash", "lux"), label: "hash")

IO.inspect(
  Lux.Rust.Component.run("map_get", %{"map" => %{"a" => 1, "b" => 2}, "key" => "b"}),
  label: "map_get"
)

if Lux.Rust.Component.async_available?() do
  IO.inspect(Lux.Rust.Component.run_async("sleep", %{"ms" => 10}), label: "sleep async")
end

IO.inspect(Lux.Rust.Component.run("sequence", "lux"), label: "sequence beam")

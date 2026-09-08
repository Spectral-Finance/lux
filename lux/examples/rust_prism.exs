# Example: run built-in Rust prisms and beams through Lux.
#
#   mix run examples/rust_prism.exs
#
# Requires the lux_core NIF (`mix compile` builds priv/rust).

unless Code.ensure_loaded?(Lux.Rust) and Lux.Rust.available?() do
  IO.puts("lux_core NIF is not loaded. Run `mix compile` first.")
  System.halt(1)
end

{:ok, version} = Lux.Rust.version()
IO.puts("Rust core " <> version)

{:ok, echo} = Lux.Rust.Component.view("echo")
IO.inspect(echo.handler, label: "echo.handler")
IO.inspect(Lux.Prism.run(echo, %{"hello" => "from rust"}), label: "prism.run echo")

IO.inspect(Lux.Rust.Component.run("fib", 10), label: "fib(10)")
IO.inspect(Lux.Rust.Component.run("echo.rs", %{"n" => 1}), label: "echo.rs")
IO.inspect(Lux.Rust.Component.run_async("sleep", %{"ms" => 5}), label: "sleep async")
IO.inspect(Lux.Rust.Component.run("sequence", "payload"), label: "beam sequence")

{:ok, listed} = Lux.Rust.Component.list()

ids =
  Enum.map(listed, fn
    item when is_map(item) -> item["id"] || item[:id]
    other -> other
  end)

IO.inspect(ids, label: "components")

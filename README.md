# KNXex

KNXex is a KNXnet/IP library for Elixir. It implements a KNXnet/IP multicast client to receive and send KNX telegrams.

This library offers to parse a ETS project export to be able to get all defined group addresses for the KNXnet client modules. See the corresponding module documentation for a short rundown.

Together with the `knxnet_ip` library, it also offers a KNXnet/IP tunnelling client, based on their tunnel behaviour module.

A GenStage producer is available to consume and further dispatch received KNX telegrams. A group address server listens for KNX telegrams and stores the last group address values in ETS, so you can always fetch the value of a group address at a later time.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `knxex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:knxex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/knxex](https://hexdocs.pm/knxex).


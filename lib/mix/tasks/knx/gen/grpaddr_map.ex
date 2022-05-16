defmodule Mix.Tasks.KNX.Gen.GrpaddrMap do
  use Mix.Task

  @moduledoc """
  Reads the given KNX ETS project and generates a map of all group addresses to their Datapoint Type (DPT).
  This map can be used for the KNX Tunnel server.

  Group addresses that do not specify a DPT are ignored.

  The first argument must be given to specify the path to the ETS project.
  The second argument can be given to specify the path where to store the map (in `Inspect` format). If no target is given, the map is printed to stdout.

  Info output is only generated when map is written to file, and not to stdout.
  """

  @shortdoc "Reads the given KNX ETS project and generates a map of all group addresses to their Datapoint Type (DPT)."
  @spec run(list()) :: :ok
  def run(args) do
    {path, args_rest} = extract_path_args(args) || raise "No path given"
    {target_path, _args_rest} = extract_target_path_args(args_rest)

    if target_path != nil do
      Mix.shell().info("Reading ETS project from file #{path}...")
    end

    ets =
      KNXex.ProjectParser.parse(path,
        only: [:group_addresses],
        group_addresses_key: :address
      )

    if target_path != nil do
      Mix.shell().info("Mapping group addresses to DPT...")
    end

    {inspected_addresses, total, filtered} =
      ets.group_addresses
      |> Enum.reduce({%{}, 0, 0}, fn {key, addr}, {acc, total, filtered} ->
        if addr.type == nil do
          {acc, total + 1, filtered + 1}
        else
          {Map.put(acc, key, addr.type), total + 1, filtered}
        end
      end)
      |> (&{inspect(elem(&1, 0), limit: :infinity, printable_limit: :infinity, pretty: true),
           elem(&1, 1), elem(&1, 2)}).()

    if target_path != nil do
      Mix.shell().info(
        "We have found #{total} group address(es), of which we dropped #{filtered} group addresses without a type"
      )
    end

    if target_path == nil do
      Mix.shell().info(inspected_addresses)
    else
      Mix.shell().info("Writing group addresses map to file #{target_path}...")
      File.write!(target_path, inspected_addresses, [:binary])
    end

    :ok
  end

  @spec extract_path_args(list()) :: {binary(), list()} | nil
  defp extract_path_args([]), do: nil
  defp extract_path_args([arg | tail]), do: {arg, tail}

  @spec extract_target_path_args(list()) :: {binary() | nil, list()}
  defp extract_target_path_args([]), do: {nil, []}
  defp extract_target_path_args([arg | tail]), do: {arg, tail}
end

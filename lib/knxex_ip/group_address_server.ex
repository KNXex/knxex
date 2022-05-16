defmodule KNXexIP.GroupAddressServer do
  @moduledoc """
  The KNX Group Address Server listens for KNX group telegrams and stores their values.

  The group addresses must be known by this server and the KNX client, in order to be able
  to decode and encode the value. Unknown group addresses by this server are ignored, even
  if received and decoded by the KNX client.

  Group addresses without a type found in the `:ets_project` are filtered out. In other cases,
  where group addresses is explicitely given, an exception is raised.

  The server can read all relevant group addresses from the KNX bus on startup to hydrate the values.
  To avoid reading group addresses on startup from the KNX bus, an alternative approach to hydrate
  the group addresses state can be provided by the `hydratation_state` option.
  During hydration, the server does not answer any requests.

  This server uses one ETS table to store the data.
  Multiple instances of this server should be carefully considered, as the ETS table is shared.

  Each function takes an `opts` keyword list, which can have an optional `:name` option, which is then used
  to call the `MulticastClient` identified by the `:name` (a PID or registered name), and an optional `:timeout` option (defaults to 5000).
  """

  alias KNXexIP

  require Logger
  use GenServer

  @type hydration_state_item ::
          {address :: binary(), value :: term()}
          | {address :: binary(), value :: term(), timestamp_seconds :: integer()}

  defmodule State do
    @moduledoc false

    @fields [:datastore, :knx_module, :knx_server, :subscriber, :opts]
    @enforce_keys @fields
    defstruct @fields
  end

  defmodule GroupAddressData do
    @moduledoc """
    The KNX Group Address server's group address data structure.
    """

    @typedoc """
    Represents the KNX group address, that is used in this server.

    In addition to `KNXexIP.GroupAddress.t()`, the name, last update time and value are stored.
    If the value is `nil`, the value is not known (has not been hydrated or received from the KNX bus yet).

    Type is a tuple of name and type, i.e. `{"DPT_Switch", "1.001"}`.
    """
    @type t :: %__MODULE__{
            address: KNXexIP.GroupAddress.t(),
            name: String.t() | nil,
            type: {name :: String.t(), type :: String.t()},
            last_update: DateTime.t() | nil,
            value: term() | nil
          }

    @fields [:address, :name, :type, :last_update, :value]
    @enforce_keys @fields
    defstruct @fields
  end

  # Trick credo  due to complexity
  defmacrop validate_opts_group_addresses(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      case opts[:group_addresses] do
        %{} = map ->
          Map.new(map, fn
            {_key, %KNXexIP.EtsProject.GroupAddressInfo{} = term} ->
              if term.type == nil do
                raise ArgumentError, "Group address #{term.address} has no type"
              end

              {term.address,
               %GroupAddressData{
                 address: term.address,
                 name: term.name,
                 type: dpt_to_type_tuple(term.type),
                 last_update: nil,
                 value: nil
               }}

            {key, type} when is_binary(key) and is_binary(type) ->
              case KNXexIP.GroupAddress.from_string(key) do
                {:ok, grpaddr} ->
                  {grpaddr,
                   %GroupAddressData{
                     address: grpaddr,
                     name: nil,
                     type: dpt_to_type_tuple(type),
                     last_update: nil,
                     value: nil
                   }}

                {:error, _err} ->
                  raise ArgumentError, "Invalid group address: #{key}"
              end

            term ->
              raise ArgumentError, "Invalid group addresses map element, got: #{inspect(term)}"
          end)

        nil ->
          ets_project =
            case opts[:ets_project] do
              path when is_binary(path) ->
                KNXexIP.ProjectParser.parse(path, only: [:group_addresses])

              %KNXexIP.EtsProject{} = term ->
                term

              nil ->
                raise ArgumentError, "Missing group addresses"

              term ->
                raise ArgumentError,
                      "Invalid group addresses, expected file path or EtsProject struct, got: #{inspect(term)}"
            end

          ets_project.group_addresses
          |> Enum.filter(fn
            # Get rid of group addresses without type
            {_key, %KNXexIP.EtsProject.GroupAddressInfo{type: nil}} -> false
            {_key, %KNXexIP.EtsProject.GroupAddressInfo{}} -> true
            _any -> false
          end)
          |> Map.new(fn
            {_key, %KNXexIP.EtsProject.GroupAddressInfo{} = term} ->
              {term.address,
               %GroupAddressData{
                 address: term.address,
                 name: term.name,
                 type: dpt_to_type_tuple(term.type),
                 last_update: nil,
                 value: nil
               }}
          end)

        term ->
          raise ArgumentError, "Invalid group addresses map, got: #{inspect(term)}"
      end
    end
  end

  defmacrop get_opts_name() do
    quote do
      Keyword.get(var!(opts), :name, __MODULE__)
    end
  end

  defmacrop get_opts_timeout() do
    quote do
      Keyword.get(var!(opts), :timeout, 5000)
    end
  end

  @doc """
  Starts a new Group Address Server.

  The group addresses with their name and type is read from the ETS project file (.knxproj export).

  The following options are available (some are required):
    - `ets_project: KNXexIP.EtsProject.t() | path :: binary()` - Required. The ETS project to use, or the path to the ETS project file.
    - `hydrate_on_start: boolean() | [address :: binary()]` - Optional. Whether to hydrate the group addresses state on startup, by reading the group addresses from the KNX bus.
      If `true`, all group addresses are read. If a list of group addresses is given (in `x/y/z` format), only those are read.
    - `hydration_state: [hydration_state_item()]` - Optional. The hydration state to use when hydrating the group addresses state on startup.
      If not given and `hydrate_on_start` is given, the hydration state is read from the KNX bus.
    - `hydration_timeout: pos_integer()` - Optional. The timeout used when hydrating the state from the KNX bus (defaults to `5000`ms).
    - `knx_interface: module() | {module(), atom() | pid()}` - Required. The KNX interface to use. The module name or a tuple of module name and PID/registered name.
      The only supported KNX interface modules are `MulticastClient` and `TunnelClient` currently.
  """
  @spec start_link(Keyword.t()) :: {:ok, pid()} | {:error, {:already_started, pid()}}
  def start_link(opts \\ []) when is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "start_link/1 expected a keyword list, got: #{inspect(opts)}"
    end

    knx_interface =
      case opts[:knx_interface] do
        nil ->
          raise ArgumentError, "Missing KNX interface"

        {module, name_or_pid} = val when is_atom(name_or_pid) or is_pid(name_or_pid) ->
          Code.ensure_loaded!(module)

          if module != KNXexIP.MulticastClient and
               module != KNXexIP.TunnelClient do
            raise ArgumentError,
                  "Expected the KNX interface module to be MulticastClient or TunnelClient, got: #{inspect(module)}"
          end

          val

        module when is_atom(module) ->
          Code.ensure_loaded!(module)

          if module != KNXexIP.MulticastClient and
               module != KNXexIP.TunnelClient do
            raise ArgumentError,
                  "Expected the KNX interface module to be MulticastClient or TunnelClient, got: #{inspect(module)}"
          end

          {module, module}

        term ->
          raise ArgumentError, "Invalid KNX interface, got: #{inspect(term)}"
      end

    group_addresses = validate_opts_group_addresses(opts)

    {opts, genserver_opts} =
      opts
      |> Keyword.put_new(:name, __MODULE__)
      |> Keyword.put_new(:hydration_timeout, 5000)
      |> Keyword.split([:group_addresses, :hydrate_on_start, :hydration_timeout, :knx_interface])

    srv_opts =
      opts
      |> Map.new()
      |> Map.put(:knx_interface, knx_interface)
      |> Map.put(:group_addresses, group_addresses)

    GenServer.start_link(__MODULE__, srv_opts, genserver_opts)
  end

  @doc """
  Creates the ETS table. The current process will be the owner of the table.

  The table should be created before starting the server, if multiple are started.
  This would prevent losing the whole table if one server crashes.

  The ETS table will be automatically created in the server process, if it does not exist, however.

  If the ETS table already exists, the table identifier will be returned. The owner is not modified.
  """
  @spec create_ets_table() :: :ets.tid()
  def create_ets_table() do
    case :ets.whereis(__MODULE__) do
      :undefined ->
        :ets.new(__MODULE__, [
          :set,
          :public,
          :named_table,
          read_concurrency: true,
          write_concurrency: true
        ])

      tid ->
        tid
    end
  end

  @doc """
  Converts the current ETS table state into an usable hydration state. Group addresses without a value are skipped.
  """
  @spec to_hydration_state() :: [hydration_state_item()]
  def to_hydration_state() do
    case :ets.whereis(__MODULE__) do
      :undefined ->
        []

      _tid ->
        __MODULE__
        |> :ets.tab2list()
        |> Stream.map(fn {_key, grpaddr} -> grpaddr end)
        |> Stream.filter(fn %GroupAddressData{} = grpaddr -> grpaddr.value != nil end)
        |> Enum.map(fn %GroupAddressData{} = grpaddr ->
          {KNXexIP.GroupAddress.to_string(grpaddr.address), grpaddr.value,
           DateTime.to_unix(grpaddr.last_update)}
        end)
    end
  end

  @doc """
  Waits for the startup sequence to complete. This will block indefinitely until the server replies.
  This is useful during hydration, to wait until the hydration is completed and available to answer requests.
  """
  @spec wait_for_startup(Keyword.t()) :: :ok
  def wait_for_startup(opts) when is_list(opts) do
    GenServer.call(
      get_opts_name(),
      :heartbeat,
      :infinity
    )
  end

  @doc """
  Gets all group addresses from the ETS table.
  """
  @spec get_group_addresses() :: [GroupAddressData.t()]
  def get_group_addresses() do
    __MODULE__
    |> :ets.tab2list()
    |> Enum.map(fn {_key, grpaddr} -> grpaddr end)
  end

  @doc """
  Adds the given group address with the datapoint type (DPT) to the group address list.
  Unknown group addresses can not be used to send or receive telegrams.

  The DPT is in the form of "x.yyy" where x and y are numbers, i.e. `1.001`.

  The following options are additionally supported:
  - `hydrate: boolean()` - Optional. Specifies whether the group address should be read to hydrate the value (defaults to `false`).
  """
  @spec add(KNXexIP.GroupAddress.t(), String.t(), Keyword.t()) :: :ok
  def add(%KNXexIP.GroupAddress{} = group_address, dpt, opts \\ [])
      when is_binary(dpt) and is_list(opts) do
    grpaddr = %GroupAddressData{
      address: group_address,
      name: nil,
      type: dpt_to_type_tuple(dpt),
      last_update: nil,
      value: nil
    }

    :ets.insert(__MODULE__, {group_address, grpaddr})

    if opts[:hydrate] == true do
      Logger.debug("Reading group address #{group_address} for hydration")

      new_opts = Keyword.put(opts, :timeout, get_opts_timeout())

      case read(group_address, new_opts) do
        {:ok, _val} -> :ok
        term -> term
      end
    else
      :ok
    end
  end

  @doc """
  Removes the given group address from the group address list.
  """
  @spec remove(KNXexIP.GroupAddress.t()) :: :ok
  def remove(%KNXexIP.GroupAddress{} = group_address) do
    :ets.delete(__MODULE__, group_address)
    :ok
  end

  @doc """
  Reads the group address from the ETS table.

  If specified, the value will be read from the KNX bus, if the value is `nil`.
  The function can also be instructed to read the value from the KNX bus,
  regardless whether the value is available or not.

  The following options are additionally supported:
  - `force_value_read: boolean()` - Optional. Specifies whether the group address must be read from the KNX bus before returning it (defaults to `false`).
  - `read_value_on_nil: boolean()` - Optional. Specifies whether the group address is read from the KNX bus before returning, if the value is nil (defaults to `false`).
  """
  @spec read(KNXexIP.GroupAddress.t(), keyword) ::
          {:ok, %GroupAddressData{}} | {:error, term()}
  def read(%KNXexIP.GroupAddress{} = group_address, opts \\ []) when is_list(opts) do
    case :ets.lookup(__MODULE__, group_address) do
      [{_key, %GroupAddressData{} = grpaddr}] ->
        # The :only_ets is only used to prevent another read,
        # since we already read and only want to do an ETS lookup
        read_knx_value =
          (opts[:only_ets] != true and opts[:force_value_read] == true) or
            (grpaddr.value == nil and opts[:read_value_on_nil] == true)

        if read_knx_value do
          Logger.debug(fn ->
            "Explicitely reading group address #{grpaddr.address} value from KNX bus (current value: #{inspect(grpaddr.value)})"
          end)

          case GenServer.call(
                 get_opts_name(),
                 {:read_group_knx_value, group_address, get_opts_timeout()},
                 get_opts_timeout()
               ) do
            {:ok, _value} ->
              # Call this function again, but only to get the new
              # group address from ETS (prevent different data)
              read(group_address, only_ets: true)

            val ->
              val
          end
        else
          grpaddr
        end

      _any ->
        {:error, :unknown_group_address}
    end
  end

  @doc """
  Writes the group address. The value is written to the KNX bus and then stored in the ETS table.
  """
  @spec write(KNXexIP.GroupAddress.t(), term(), Keyword.t()) ::
          :ok | {:error, term()}
  def write(%KNXexIP.GroupAddress{} = group_address, value, opts \\ []) when is_list(opts) do
    GenServer.call(
      get_opts_name(),
      {:write_group_address, group_address, value, get_opts_timeout()},
      get_opts_timeout()
    )
  end

  @doc """
  Sets the subscriber to the given PID. The PID is not checked for aliveness.

  Only a single subscriber is supported. This function is used with the `GenStageProducer`.
  """
  @spec subscribe(pid(), Keyword.t()) :: :ok
  def subscribe(pid, opts \\ []) when is_pid(pid) and is_list(opts) do
    GenServer.cast(get_opts_name(), {:subscribe, pid})
  end

  @doc """
  Unsets the subscriber. The first argument is ignored and only for compatibility.

  This function is used with the `GenStageProducer`.
  """
  @spec unsubscribe(any(), Keyword.t()) :: :ok
  def unsubscribe(_pid, opts \\ []) when is_list(opts) do
    GenServer.cast(get_opts_name(), {:unsubscribe, :any})
  end

  @doc """
  This is a helper function that takes an ETS project struct, optionally the path to the ETS project file,
  and whether group addresses which have an unknown `read` flag should be read from the KNX bus.

  The ETS project file MUST exist, as it must be read from disk to read the manufacturer data.

  As output you will receive a list of group addresses that can be read from the KNX bus, optionally
  with group addresses that may be readable.

  The following optional options can be given:
  - `allow_nil: boolean()` - Whether group addresses that have an unknown `read` flag should be read from the KNX bus (defaults to `true`).

  - `manufacturer_map: map()` - A map from `KNXexIP.ProjectParser.parse_manufacturers/2`, if it has already been done before.
  This helps not having to parse the ETS project file again. If not given, it will be parsed from the ETS project file.

  - `path: String.t()` - The path to the ETS project file. If not given, the path from the ETS project struct is used.

  All other given elements in `opts` are passed to `KNXexIP.ProjectParser.parse_manufacturers/2`.
  """
  @spec filter_gpa_hydration_by_read_flag(
          KNXexIP.EtsProject.t(),
          Keyword.t()
        ) :: [group_address :: String.t()]
  def filter_gpa_hydration_by_read_flag(
        %KNXexIP.EtsProject{} = ets_project,
        opts \\ []
      )
      when is_list(opts) do
    if map_size(ets_project.topology) == 0 do
      raise ArgumentError, "ETS Project struct does not contain the topology"
    end

    ets_project
    |> generate_hydration_gpas_list_from_ets(Map.new(opts))
    |> Stream.filter(fn {_key, {_gpa, value}} -> value == true end)
    |> Stream.map(fn {_key, {gpa, _value}} -> gpa end)
    |> Enum.to_list()
  end

  #### Private API ####

  @doc false
  def init(%{knx_interface: {knx_module, knx_server}} = opts) do
    state = %State{
      datastore: create_ets_table(),
      knx_module: knx_module,
      knx_server: knx_server,
      subscriber: nil,
      opts: Map.drop(opts, [:group_addresses, :knx_interface])
    }

    if opts.group_addresses != [] do
      :ets.insert(state.datastore, Map.to_list(opts.group_addresses))
    end

    # Subscribe to events
    knx_module.subscribe(self(), name: knx_server, timeout: 5000)

    {:ok, state, {:continue, opts.group_addresses}}
  end

  @doc false
  def handle_continue(
        grpaddrs,
        %State{opts: %{hydrate_on_start: mode, hydration_state: hydr_state}} = state
      )
      when (mode == true or is_list(mode)) and is_list(hydr_state) do
    Logger.debug(
      "Hydrating Group Address Server with #{length(hydr_state)} group addresses with Hydration State"
    )

    Enum.each(hydr_state, &hydrate_from_hydration_state(&1, grpaddrs))

    # Drop hydration state after hydration to minimize process heap size
    new_state = %State{state | opts: Map.delete(state.opts, :hydration_state)}

    {:noreply, new_state, :hibernate}
  end

  def handle_continue(
        grpaddrs,
        %State{
          opts: %{hydrate_on_start: mode, hydration_timeout: timeout},
          knx_module: module,
          knx_server: server
        } = state
      )
      when mode == true or is_list(mode) do
    # Assert we do not have any hydration state left (cleanup any potential values given)
    new_state = %State{state | opts: Map.delete(state.opts, :hydration_state)}

    hydrate =
      if mode == true do
        grpaddrs
      else
        grpaddrs
        |> Enum.filter(fn
          {_key, %GroupAddressData{} = term} ->
            KNXexIP.GroupAddress.to_string(term.address) in mode
        end)
        |> Enum.into(%{})
      end

    Logger.debug("Hydrating Group Address Server with #{map_size(hydrate)} group addresses")

    Enum.each(hydrate, fn {_key, %GroupAddressData{} = grpaddr} ->
      Logger.debug("Reading group address #{grpaddr.address} for hydration")

      case module.read_group_address(grpaddr.address, name: server, timeout: timeout) do
        {:ok, %KNXexIP.Telegram{} = telegram} ->
          new_grpaddr = %GroupAddressData{
            grpaddr
            | last_update: DateTime.utc_now(),
              value: telegram.value
          }

          :ets.insert(__MODULE__, {grpaddr.address, new_grpaddr})

        {:error, _err} ->
          Logger.warn("Unable to hydrate value on start for group address #{grpaddr.address}")
      end
    end)

    {:noreply, new_state, :hibernate}
  end

  @doc false
  def handle_continue(_continue, state) do
    {:noreply, state, :hibernate}
  end

  @doc false
  def handle_call(:heartbeat, _from, state) do
    {:reply, :ok, state, :hibernate}
  end

  @doc false
  def handle_call(
        {:read_group_knx_value, group_address, timeout},
        from,
        %State{knx_module: module, knx_server: server} = state
      ) do
    # We do not need to update the group address struct in ETS,
    # as this is automatically done through the subscribe mechanism (handle_info)
    # We only need to fetch the updated group address struct on the client side
    spawn(fn ->
      value =
        try do
          module.read_group_address(group_address, name: server, timeout: timeout - 500)
        catch
          :exit, _err -> {:error, :timeout}
        end

      GenServer.reply(from, value)
    end)

    {:noreply, state}
  end

  def handle_call(
        {:write_group_address, group_address, value, timeout},
        from,
        %State{knx_module: module, knx_server: server} = state
      ) do
    spawn(fn ->
      wrvalue =
        try do
          case module.write_group_address(group_address, value,
                 name: server,
                 timeout: timeout - 500
               ) do
            :ok ->
              case :ets.lookup(__MODULE__, group_address) do
                [{_key, %GroupAddressData{} = grpaddr}] ->
                  new_grpaddr = %GroupAddressData{
                    grpaddr
                    | last_update: DateTime.utc_now(),
                      value: value
                  }

                  :ets.insert(__MODULE__, {grpaddr.address, new_grpaddr})
                  :ok

                _any ->
                  {:error, :unknown_group_address}
              end

            val ->
              val
          end
        catch
          :exit, _err -> {:error, :timeout}
        end

      GenServer.reply(from, wrvalue)
    end)

    {:noreply, state}
  end

  def handle_cast({:subscribe, pid}, state) do
    new_state = %State{state | subscriber: pid}
    {:noreply, new_state}
  end

  def handle_cast({:unsubscribe, _any}, state) do
    new_state = %State{state | subscriber: nil}
    {:noreply, new_state}
  end

  def handle_cast(_cast, state) do
    {:noreply, state}
  end

  @doc false
  def handle_info({:knx, %KNXexIP.Telegram{type: type} = telegram}, %State{} = state)
      when type in [:group_write, :group_response] do
    Logger.debug("Handling subscription message for group address #{telegram.destination}")

    case :ets.lookup(__MODULE__, telegram.destination) do
      [{_key, %GroupAddressData{} = grpaddr}] ->
        new_grpaddr = %GroupAddressData{
          grpaddr
          | last_update: DateTime.utc_now(),
            value: telegram.value
        }

        :ets.insert(__MODULE__, {grpaddr.address, new_grpaddr})

        if state.subscriber do
          send(state.subscriber, {:knx_group, new_grpaddr})
        end

      _any ->
        Logger.debug("Unable to fetch group address #{telegram.destination} from ETS")
        # Ignore unknown group address
        :ok
    end

    {:noreply, state}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  #### Helpers ####

  # Hydrates the group address data map with the given hydration state
  @spec hydrate_from_hydration_state(hydration_state_item(), map()) :: map()
  defp hydrate_from_hydration_state({address, value}, acc),
    do: hydrate_from_hydration_state({address, value, System.os_time(:second)}, acc)

  defp hydrate_from_hydration_state({address, value, timestamp}, acc) do
    grpaddr = KNXexIP.GroupAddress.from_string(address)

    if Map.has_key?(acc, grpaddr) do
      old_data = Map.fetch!(acc, grpaddr)

      new_data = %GroupAddressData{
        old_data
        | last_update: DateTime.from_unix!(timestamp),
          value: value
      }

      :ets.insert(__MODULE__, {grpaddr, new_data})
      Map.put(acc, grpaddr, new_data)
    else
      acc
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp generate_hydration_gpas_list_from_ets(
         %KNXexIP.EtsProject{} = ets_project,
         opts
       ) do
    devices =
      ets_project.topology
      |> Enum.map(fn {_area, area} ->
        Enum.map(area.lines, fn {_line, line} -> Enum.to_list(line.devices) end) ++
          ets_project.unassigned_devices
      end)
      |> List.flatten()

    if not Enum.any?(devices, fn {_key, device} -> map_size(device.com_objects) > 0 end) do
      raise ArgumentError,
            "ETS Project struct does not contain any Com Objects, make sure you include `include_dev_com_objects: true` in your call to `parse/2`"
    end

    parse_opts =
      opts
      |> Map.drop([:allow_nil, :manufacturer_map, :path])
      |> Map.to_list()

    allow_nil = opts[:allow_nil] || true

    manufacturer_map =
      opts[:manufacturer_map] ||
        KNXexIP.ProjectParser.parse_manufacturers(
          opts[:path] || ets_project.project_path,
          parse_opts
        )

    manufacturer_coms =
      manufacturer_map
      |> Map.new(fn {manu_id, manu} ->
        hw =
          Map.new(manu.hardware, fn {_key, hardware} ->
            hw2p = elem(Enum.at(hardware.hardware2programs, 0), 1)
            {hw2p.id, hw2p.application_program_refid}
          end)

        prg =
          Map.new(manu.application_programs, fn {key, app_prg} ->
            {key, app_prg.com_objects}
          end)

        {manu_id,
         Enum.reduce(hw, %{}, fn {key, h2p_refid}, acc ->
           if h2p_refid == nil do
             acc
           else
             Map.put(acc, key, Map.fetch!(prg, h2p_refid))
           end
         end)}
      end)
      |> Enum.reduce(%{}, fn {_key, map}, acc ->
        Map.merge(acc, map)
      end)

    gpa_map =
      Enum.reduce(ets_project.group_addresses, %{}, fn {key, value}, acc ->
        Map.put(acc, value.id, {key, :to_determine})
      end)

    coms =
      Enum.reduce(devices, %{}, fn {_device, device}, acc ->
        Enum.reduce(device.com_objects, acc, fn {_com, com}, acc ->
          [head, _tail] = String.split(com.id, "_")

          if com.links do
            Map.put(acc, head, {com.read_flag, com.links, device.hardware2program_refid})
          else
            acc
          end
        end)
      end)

    Enum.reduce(coms, gpa_map, fn {com_id, {read_flag, links, h2p_id}}, acc ->
      gpa = Map.get(acc, links, nil)

      if is_tuple(gpa) and tuple_size(gpa) == 2 and elem(gpa, 1) == :to_determine do
        # GPA is known but unknown if we can read it

        flag =
          if read_flag == nil do
            case Map.get(manufacturer_coms, h2p_id) do
              nil ->
                allow_nil

              manufacturer_comobjects ->
                comobj = Map.fetch!(manufacturer_comobjects, com_id)

                if comobj.read_flag == nil and allow_nil do
                  true
                else
                  comobj.read_flag == true
                end
            end
          else
            read_flag
          end

        Map.put(acc, links, {elem(gpa, 0), flag})
      else
        # Unknown GPA or GPA+read_flag are known
        acc
      end
    end)
  end

  #### DPT helpers, based on DPT constants ####

  for {_type, name, dpt} <- KNXexIP.DPT.get_dpts() do
    defp get_dpt_name_by_value(unquote(dpt)), do: unquote(name)
  end

  defp get_dpt_name_by_value(any), do: raise("Unknown DPT: #{inspect(any)}")
  defp dpt_to_type_tuple(dpt), do: {get_dpt_name_by_value(dpt), dpt}
end

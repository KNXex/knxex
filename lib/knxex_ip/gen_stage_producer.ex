if Code.ensure_loaded?(GenStage) do
  defmodule KNXexIP.GenStageProducer do
    @moduledoc """
    KNX telegrams GenStage producer and broadcast dispatcher.
    """

    use GenStage

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
    Starts the GenStage producer and broadcast dispatcher.
    """
    @spec start_link(Keyword.t()) :: {:ok, pid()} | {:error, {:already_started, pid()}}
    def start_link(opts \\ []) do
      {knx_opts, gen_opts} =
        opts
        |> Keyword.put_new(:name, __MODULE__)
        |> Keyword.split([:subscribe_to])

      GenStage.start_link(__MODULE__, knx_opts, gen_opts)
    end

    @doc """
    Subscribes to the given KNX interface and thus receives KNX telegrams from it.

    The received KNX telegrams are forwarded as GenStage events, in the form of `{:knx, KNXexIP.Telegram.t()}`.

    This producer can also subscribe to `GroupAddressServer`, which will give you better information
    about the group address, but less information about the source.
    However said server uses a different struct and does not emit telegrams.
    You will receive `{:knx_group, GroupAddressData.t()}` events in that case.
    """
    @spec subscribe_to(module(), atom() | pid(), Keyword.t()) :: :ok
    def subscribe_to(knx_interface, name_or_pid \\ nil, opts \\ [])
        when is_atom(knx_interface) and (is_atom(name_or_pid) or is_pid(name_or_pid)) and
               is_list(opts) do
      Code.ensure_loaded!(knx_interface)

      if knx_interface != KNXexIP.GroupAddressServer and
           knx_interface != KNXexIP.MulticastClient and
           knx_interface != KNXexIP.TunnelClient do
        raise ArgumentError,
              "Expected the KNX interface module to be GroupAddressServer, MulticastClient or TunnelClient, got: #{inspect(knx_interface)}"
      end

      GenStage.call(
        get_opts_name(),
        {:subscribe, knx_interface, name_or_pid || knx_interface},
        get_opts_timeout()
      )
    end

    @doc """
    Unsubscribes from the given KNX interface. KNX telegrams cannot be received from it anymore.
    """
    @spec unsubscribe_from(module(), atom() | pid(), Keyword.t()) :: :ok
    def unsubscribe_from(knx_interface, name_or_pid \\ nil, opts \\ [])
        when is_atom(knx_interface) and (is_atom(name_or_pid) or is_pid(name_or_pid)) and
               is_list(opts) do
      Code.ensure_loaded!(knx_interface)

      if knx_interface != KNXexIP.GroupAddressServer and
           knx_interface != KNXexIP.MulticastClient and
           knx_interface != KNXexIP.TunnelClient do
        raise ArgumentError,
              "Expected the KNX interface module to be GroupAddressServer, MulticastClient or TunnelClient, got: #{inspect(knx_interface)}"
      end

      GenStage.call(
        get_opts_name(),
        {:unsubscribe, knx_interface, name_or_pid || knx_interface},
        get_opts_timeout()
      )
    end

    #### Private API ####

    @doc false
    def init(knx_opts) do
      if is_list(knx_opts) do
        knx_opts
        |> Keyword.get(:subscribe_to, [])
        |> Enum.each(fn knx ->
          {knx_module, knx_server} =
            case knx do
              {knx_module, name} when is_atom(knx_module) and (is_atom(name) or is_pid(name)) ->
                knx

              knx_module when is_atom(knx_module) ->
                {knx_module, knx_module}

              _term ->
                raise ArgumentError, "Expected a KNX interface module, got: #{inspect(knx)}"
            end

          knx_module.subscribe(self(), name: knx_server)
        end)
      end

      {:producer, nil, dispatcher: GenStage.BroadcastDispatcher}
    end

    @doc false
    def handle_demand(_demand, state) do
      {:noreply, [], state}
    end

    @doc false
    def handle_call({:subscribe, module, name}, _from, state) do
      module.subscribe(self(), name: name)
      {:reply, :ok, [], state}
    end

    def handle_call({:unsubscribe, module, name}, _from, state) do
      module.unsubscribe(self(), name: name)
      {:reply, :ok, [], state}
    end

    @doc false
    def handle_info({:knx, telegram}, state) do
      {:noreply, [telegram], state}
    end

    def handle_info({:knx_group, telegram}, state) do
      {:noreply, [telegram], state}
    end
  end
end

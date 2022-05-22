if Code.ensure_loaded?(KNXnetIP.Tunnel) do
  defmodule KNXex.TunnelClient do
    @moduledoc """
    KNXnet/IP Tunnel Client, which wraps around the `KNXnetIP.Tunnel` behaviour module.

    The KNX Tunnel Client connects to a KNXnet/IP server (gateway or router) using a tunnelling connection,
    to send and receive KNX telegrams.

    Processes interested in receiving received KNX telegram need to subscribe to them,
    using `subscribe/1` and `unsubscribe/1` to unsubscribe from them.

    Each function takes an `opts` keyword list, which can have an optional `:name` option, which is then used
    to call the `TunnelClient` identified by the `:name` (a PID or registered name), and an optional `:timeout` option (defaults to 5000).
    """

    require KNXex
    require Logger

    alias KNXex
    alias KNXnetIP.{Telegram, Tunnel}

    @behaviour Tunnel

    defmodule State do
      @moduledoc false

      @typedoc false
      @opaque t :: %__MODULE__{}

      defstruct [:subscribers, :group_addresses, :telegrams, :current_telegram, :connected, :opts]
    end

    defmacrop validate_opts_arg(opts) do
      {fun, arity} = __ENV__.function
      callee_str = "#{fun}/#{arity}"

      quote location: :keep do
        unless Keyword.keyword?(unquote(opts)) do
          raise ArgumentError,
                "#{unquote(callee_str)} expected a keyword list, got: #{inspect(unquote(opts))}"
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
    Starts the KNXnet/IP Tunnel Client.

    The following options are available (some are required):
    - `allow_unknown_gpa: boolean()` - Optional. Determines whether unknown Group Addresses are allowed (not ignored when received, defaults to `false`).
    This will also mean that you receive the raw undecoded value and you need to provide the raw encoded value when sending.

    - `group_addresses: map()` - Required. Group addresses map, where the key is the group address in `x/y/z` notation
    and the value is the DPT (datapoint type) - both being `String.t()`.
    The group address and its DPT is required to determine how to encode and decode received values.

    - `local_ip: :inet.ip4_address()` - Optional. The local IP address to use. If nil, the local IP address will be discovered.

    - `server_ip: :inet.ip4_address()` - Required. The KNX/IP gateway/router IP address to connect to.

    All other given options are passed to the `Tunnel` behaviour module (i.e. `:name` can be given to override the process name to register).
    """
    @spec start_link(Keyword.t()) ::
            {:ok, pid()} | {:error, {:already_started, pid()}}
    def start_link(opts) do
      unless Keyword.keyword?(opts) do
        raise ArgumentError, "start_link/1 expected a keyword list, got: #{inspect(opts)}"
      end

      {server_ip, local_ip} = extract_opts(opts)

      knxnet_ip_opts = [
        ip: local_ip,
        server_ip: server_ip
      ]

      {opts, genserver_opts} =
        opts
        |> Keyword.put_new(:allow_unknown_gpa, false)
        |> Keyword.put_new(:name, __MODULE__)
        |> Keyword.split([:allow_unknown_gpa, :group_addresses, :local_ip, :server_ip])

      genserver_opts2 = Keyword.put_new(genserver_opts, :name, __MODULE__)

      Tunnel.start_link(__MODULE__, Map.new(opts), knxnet_ip_opts, genserver_opts2)
    end

    @doc """
    Disconnects from the KNX/IP gateway/router and closes the KNXnet Tunnel server.
    """
    @spec close(Keyword.t()) :: :ok
    def close(opts \\ []) when is_list(opts) do
      validate_opts_arg(opts)
      Tunnel.call(get_opts_name(), :do_stop, get_opts_timeout())
    end

    @doc """
    Subscribes to telegram notifications. The subscriber will receive messages in the form `{:knx, KNXex.Telegram.t()}`.
    """
    @spec subscribe(pid(), Keyword.t()) :: :ok
    def subscribe(pid, opts \\ []) when is_pid(pid) and is_list(opts) do
      validate_opts_arg(opts)
      Tunnel.call(get_opts_name(), {:subscribe, pid}, get_opts_timeout())
    end

    # Taken outside of the @doc for future use?
    # The reference is usually used in combination with the group read and group write functions in this module.
    # The reference is nil, if we receive a telegram outside of our request-response flow,
    # meaning it was initiated by the KNXnet/IP gateway/router.

    @doc """
    Unsubscribes from telegram notifications.
    """
    @spec unsubscribe(pid(), Keyword.t()) :: :ok
    def unsubscribe(pid, opts \\ []) when is_pid(pid) and is_list(opts) do
      validate_opts_arg(opts)
      Tunnel.call(get_opts_name(), {:unsubscribe, pid}, get_opts_timeout())
    end

    @doc """
    Gets all group addresses from the state.
    """
    @spec get_group_addresses(Keyword.t()) ::
            {:ok, %{optional(address :: String.t()) => dpt :: String.t()}}
    def get_group_addresses(opts \\ []) when is_list(opts) do
      validate_opts_arg(opts)
      Tunnel.call(get_opts_name(), :get_group_addresses, get_opts_timeout())
    end

    @doc """
    Adds the given group address with the datapoint type (DPT) to the group address list.
    Unknown group addresses can not be used to send or receive telegrams.

    The DPT is in the form of "x.yyy" where x and y are numbers, i.e. `1.001`.
    """
    @spec add_group_address(KNXex.GroupAddress.t(), binary(), Keyword.t()) :: :ok
    def add_group_address(%KNXex.GroupAddress{} = group_address, dpt, opts \\ [])
        when is_list(opts) do
      validate_opts_arg(opts)

      Tunnel.call(
        get_opts_name(),
        {:add_group_address, group_address, dpt},
        get_opts_timeout()
      )
    end

    @doc """
    Removes the given group address from the group address list.
    """
    @spec remove_group_address(KNXex.GroupAddress.t(), Keyword.t()) :: :ok
    def remove_group_address(%KNXex.GroupAddress{} = group_address, opts \\ [])
        when is_list(opts) do
      validate_opts_arg(opts)

      Tunnel.call(
        get_opts_name(),
        {:remove_group_address, group_address},
        get_opts_timeout()
      )
    end

    @doc """
    Sends a `GroupValueRead` to `group_address`. Waits up to `timeout` for the response.
    Utilizes a `Task` to subscribe temporarily to events.
    """
    @spec read_group_address(KNXex.GroupAddress.t(), Keyword.t()) ::
            {:ok, KNXex.Telegram.t()} | {:error, :unknown_group_address} | {:error, :timeout}
    def read_group_address(%KNXex.GroupAddress{} = group_address, opts \\ [])
        when is_list(opts) do
      validate_opts_arg(opts)

      task =
        Task.async(fn ->
          __MODULE__.subscribe(self())
          timeout = get_opts_timeout()

          response =
            case Tunnel.call(
                   get_opts_name(),
                   {:group_read, group_address},
                   timeout
                 ) do
              :ok ->
                receive do
                  {:knx, %{type: :group_response, destination: ^group_address} = telegram} ->
                    {:ok, telegram}
                after
                  timeout -> {:error, :timeout}
                end

              val ->
                val
            end

          __MODULE__.unsubscribe(self())
          response
        end)

      Task.await(task, :infinity)
    end

    @doc """
    Encodes `value` according to the DPT of the `group_address`, and sends it in a `GroupValueWrite` to `group_address`.
    """
    @spec write_group_address(KNXex.GroupAddress.t(), term(), Keyword.t()) ::
            :ok | {:error, :unknown_group_address}
    def write_group_address(%KNXex.GroupAddress{} = group_address, value, opts \\ [])
        when is_list(opts) do
      validate_opts_arg(opts)

      Tunnel.call(
        get_opts_name(),
        {:group_write, group_address, value},
        get_opts_timeout()
      )
    end

    @doc """
    Sends a telegram. The DPT of the `group_address` must be known.
    The returned reference is currently without any meaning to the user.
    """
    @spec send_telegram(KNXex.Telegram.t(), Keyword.t()) ::
            :ok | {:error, term()}
    def send_telegram(%KNXex.Telegram{} = telegram, opts \\ []) when is_list(opts) do
      validate_opts_arg(opts)
      Tunnel.call(get_opts_name(), {:send_telegram, telegram}, get_opts_timeout())
    end

    @doc """
    Sends a raw telegram.
    The returned reference is currently without any meaning to the user.
    """
    @spec send_raw_telegram(Telegram.t(), Keyword.t()) ::
            :ok | {:error, term()}
    def send_raw_telegram(%Telegram{} = telegram, opts \\ []) when is_list(opts) do
      validate_opts_arg(opts)
      Tunnel.call(get_opts_name(), {:send_telegram, telegram}, get_opts_timeout())
    end

    #### Private API ####

    @impl true
    @doc false
    @spec init(map()) ::
            {:ok, map()}
    def init(opts) do
      state = %State{
        subscribers: [],
        group_addresses: opts.group_addresses,
        telegrams: :queue.new(),
        current_telegram: nil,
        connected: false,
        opts: Map.drop(opts, [:group_addresses])
      }

      {:ok, state}
    end

    @impl true
    @doc false
    def code_change(_vsn, state, _extra), do: {:ok, state}

    @impl true
    @doc false
    def terminate(_reason, state), do: state

    @impl true
    @doc false
    def on_connect(%State{} = state) do
      Logger.debug("Connected to KNX Tunnelling server")
      new_state = %State{state | connected: true}

      check_for_new_telegram_send(new_state)
    end

    @impl true
    @doc false
    def on_disconnect(reason, %State{} = state) do
      Logger.debug("Disconnected from KNX Tunnelling server for reason: #{inspect(reason)}")
      new_state = %State{state | connected: false}

      case reason do
        :disconnect_requested ->
          {:backoff, 0, new_state}

        {:tunnelling_ack_error, _any} ->
          {:backoff, 0, new_state}

        {:connectionstate_response_error, _any} ->
          {:backoff, 0, new_state}

        {:connect_response_error, _any} ->
          {:backoff, 10_000, new_state}
      end
    end

    @impl true
    @doc false
    def handle_call(:do_stop, _from, state) do
      {:stop, :normal, state}
    end

    def handle_call({:subscribe, pid}, _from, %State{} = state) do
      new_state =
        state
        |> Map.update(:subscribers, [], fn list ->
          [pid | list]
        end)
        |> KNXex.to_struct!(State)

      {:reply, :ok, new_state}
    end

    def handle_call({:unsubscribe, pid}, _from, %State{} = state) do
      new_state =
        state
        |> Map.update(:subscribers, [], fn list ->
          Enum.reject(list, fn val ->
            val == pid
          end)
        end)
        |> KNXex.to_struct!(State)

      {:reply, :ok, new_state}
    end

    def handle_call(:get_group_addresses, _from, %State{group_addresses: group_addresses} = state) do
      {:reply, {:ok, group_addresses}, state}
    end

    def handle_call(
          {:add_group_address, %KNXex.GroupAddress{} = group_address, dpt},
          _from,
          %State{} = state
        ) do
      new_state =
        state
        |> Map.update(:group_addresses, %{}, fn map ->
          Map.put(map, KNXex.GroupAddress.to_string(group_address), dpt)
        end)
        |> KNXex.to_struct!(State)

      {:reply, :ok, new_state}
    end

    def handle_call(
          {:remove_group_address, %KNXex.GroupAddress{} = group_address},
          _from,
          %State{} = state
        ) do
      new_state =
        state
        |> Map.update(:group_addresses, %{}, fn map ->
          Map.drop(map, [KNXex.GroupAddress.to_string(group_address)])
        end)
        |> KNXex.to_struct!(State)

      {:reply, :ok, new_state}
    end

    def handle_call(
          {:send_telegram, %KNXex.Telegram{} = telegram},
          _from,
          %State{} = state
        ) do
      grpaddr_str = KNXex.GroupAddress.to_string(telegram.destination)
      datapoint_type = state.group_addresses[grpaddr_str]

      if datapoint_type != nil or state.opts.allow_unknown_gpa do
        encode =
          case datapoint_type do
            nil -> {:ok, telegram.value}
            _dpt -> KNXex.DPT.encode(telegram.value, datapoint_type)
          end

        case encode do
          {:ok, raw_value} ->
            raw_telegram = %Telegram{
              type: :request,
              service: telegram.type,
              source: "0.0.0",
              destination: grpaddr_str,
              value: raw_value
            }

            # Pre-validate telegram to not crash the server
            case Telegram.encode(raw_telegram) do
              {:ok, _raw} -> send_telegram_or_queue(raw_telegram, state)
              val -> {:reply, val, state}
            end

          val ->
            {:reply, val, state}
        end
      else
        {:reply, {:error, :unknown_group_address}, state}
      end
    end

    def handle_call(
          {:send_telegram, %Telegram{} = telegram},
          _from,
          %State{} = state
        ) do
      # Pre-validate telegram to not crash the server
      case Telegram.encode(telegram) do
        {:ok, _raw} -> send_telegram_or_queue(telegram, state)
        val -> {:reply, val, state}
      end
    end

    def handle_call(
          {:group_read, %KNXex.GroupAddress{} = group_address},
          _from,
          %State{} = state
        ) do
      grpaddr_str = KNXex.GroupAddress.to_string(group_address)
      known_gpa = state.group_addresses[grpaddr_str] || state.opts.allow_unknown_gpa || nil

      case known_gpa do
        nil ->
          {:reply, {:error, :unknown_group_address}, state}

        _dpt ->
          telegram = %Telegram{
            type: :request,
            service: :group_read,
            source: "0.0.0",
            destination: grpaddr_str,
            value: ""
          }

          # Pre-validate telegram to not crash the server
          case Telegram.encode(telegram) do
            {:ok, _raw} -> send_telegram_or_queue(telegram, state)
            val -> {:reply, val, state}
          end
      end
    end

    def handle_call(
          {:group_write, %KNXex.GroupAddress{} = group_address, value},
          _from,
          %State{} = state
        ) do
      grpaddr_str = KNXex.GroupAddress.to_string(group_address)
      datapoint_type = state.group_addresses[grpaddr_str]

      if datapoint_type != nil or state.opts.allow_unknown_gpa do
        encode =
          case datapoint_type do
            nil -> {:ok, value}
            _dpt -> KNXex.DPT.encode(value, datapoint_type)
          end

        case encode do
          {:ok, raw_value} ->
            telegram = %Telegram{
              type: :request,
              service: :group_write,
              source: "0.0.0",
              destination: grpaddr_str,
              value: raw_value
            }

            # Pre-validate telegram to not crash the server
            case Telegram.encode(telegram) do
              {:ok, _raw} -> send_telegram_or_queue(telegram, state)
              val -> {:reply, val, state}
            end

          val ->
            {:reply, val, state}
        end
      else
        {:reply, {:error, :unknown_group_address}, state}
      end
    end

    #### Tunnel ####

    @impl true
    @doc false
    @spec on_telegram_ack(map()) ::
            {:ok, map()}
            | {:send_telegram, binary(), map()}
    def on_telegram_ack(%State{} = state) do
      Logger.debug("Received KNX Tunnelling ACK")

      new_state =
        case state.current_telegram do
          {_cur_telegram, _ref} ->
            new_state =
              state
              |> Map.put(:current_telegram, nil)
              |> Map.update(:telegrams, nil, fn queue ->
                :queue.drop(queue)
              end)
              |> KNXex.to_struct!(State)

            # Do we need this below? I don't think so.

            # Fan out notifications in a new process
            # to not block the Tunnelling ACK for too long
            # spawn(fn ->
            #   {:ok, srcaddr} = KNXex.IndividualAddress.from_string(cur_telegram.source)
            #   {:ok, grpaddr} = KNXex.GroupAddress.from_string(cur_telegram.destination)

            #   my_telegram = %KNXex.Telegram{
            #     type: cur_telegram.service,
            #     source: srcaddr,
            #     destination: grpaddr,
            #     value: cur_telegram.value
            #   }

            #   for subscriber <- state.subscribers do
            #     send(subscriber, {:knx, my_telegram})
            #   end
            # end)

            new_state

          nil ->
            state
        end

      check_for_new_telegram_send(new_state)
    end

    @impl true
    @doc false
    @spec on_telegram(binary(), map()) ::
            {:ok, map()}
            | {:send_telegram, binary(), map()}
    def on_telegram(encoded_telegram, %State{} = state) do
      {:ok, telegram} = Telegram.decode(encoded_telegram)

      Logger.debug(
        "Received KNX telegram service type #{telegram.service} from sender #{telegram.source} to #{telegram.destination}"
      )

      handle_telegram(telegram, state)
    end

    # Stores the telegram in the telegram list and sends it immediately, if possible.
    @spec send_telegram_or_queue(Telegram.t(), map()) ::
            {:reply, :ok, map()}
            | {:send_telegram, binary(), :ok, map()}
    defp send_telegram_or_queue(
           %Telegram{} = telegram,
           %State{current_telegram: nil, connected: true} = state
         ) do
      ref = make_ref()
      {:ok, encoded_telegram} = Telegram.encode(telegram)

      new_state = %State{
        state
        | current_telegram: {telegram, ref},
          telegrams: :queue.in({telegram, ref}, state.telegrams)
      }

      {:send_telegram, encoded_telegram, :ok, new_state}
    end

    defp send_telegram_or_queue(%Telegram{} = telegram, %State{} = state) do
      ref = make_ref()

      new_state = %State{
        state
        | telegrams: :queue.in({telegram, ref}, state.telegrams)
      }

      {:reply, :ok, new_state}
    end

    @spec handle_telegram(Telegram.t(), map()) ::
            {:ok, map()} | {:send_telegram, Telegram.t(), map()}
    defp handle_telegram(%Telegram{service: service} = telegram, %State{} = state)
         when service in [:group_write, :group_read, :group_response] do
      datapoint_type = state.group_addresses[telegram.destination]

      new_state =
        if datapoint_type != nil or state.opts.allow_unknown_gpa do
          # {new_state, _ref} = handle_telegram_callback_current(telegram, state)
          new_state = state

          decode =
            case datapoint_type do
              nil -> {:ok, telegram.value}
              _dpt -> KNXex.DPT.decode(telegram.value, datapoint_type)
            end

          case decode do
            {:ok, value} ->
              # Fan out notifications in a new process
              # to not block the Tunnelling ACK for too long
              spawn(fn ->
                {:ok, srcaddr} = KNXex.IndividualAddress.from_string(telegram.source)
                {:ok, grpaddr} = KNXex.GroupAddress.from_string(telegram.destination)

                my_telegram = %KNXex.Telegram{
                  type: service,
                  source: srcaddr,
                  destination: grpaddr,
                  value: value
                }

                for subscriber <- state.subscribers do
                  send(subscriber, {:knx, my_telegram})
                end
              end)

              new_state

            {:error, err} ->
              Logger.info("Unable to decode group address value, error: #{inspect(err)}")
              new_state
          end
        else
          Logger.info("Ignoring unspecified group address: #{telegram.destination}")
          state
        end

      check_for_new_telegram_send(new_state)
    end

    # Ignore telegrams which are not group writes or group responses
    # Only check if a new telegram can be sent
    defp handle_telegram(_telegram, %State{} = state) do
      check_for_new_telegram_send(state)
    end

    @spec check_for_new_telegram_send(map()) ::
            {:ok, map()} | {:send_telegram, binary(), map()}
    defp check_for_new_telegram_send(%State{connected: true} = state) do
      if state.current_telegram == nil and not :queue.is_empty(state.telegrams) do
        {new_telegram, _ref} = cur_telegram = :queue.head(state.telegrams)
        new_state = %State{state | current_telegram: cur_telegram}

        {:ok, encoded_telegram} = Telegram.encode(new_telegram)

        {:send_telegram, encoded_telegram, new_state}
      else
        new_state =
          if :queue.is_empty(state.telegrams) do
            %State{state | current_telegram: nil}
          else
            state
          end

        {:ok, new_state}
      end
    end

    defp check_for_new_telegram_send(%State{connected: false} = state) do
      {:ok, state}
    end

    # This is the callback function that handles the current telegram sending
    # for the `handle_telegram` function
    # @spec handle_telegram_callback_current(%Telegram{}, map()) :: {map(), reference() | nil}
    # defp handle_telegram_callback_current(%Telegram{service: service} = telegram, %State{} = state) do
    #   case state.current_telegram do
    #     {cur_telegram, ref} ->
    #       if cur_telegram.destination == telegram.destination and
    #            ((cur_telegram.service == :group_write and service == :group_read and
    #                telegram.type == :confirmation) or
    #               (cur_telegram.service == :group_read and service == :group_response and
    #                  telegram.type == :indication)) do
    #         new_state =
    #           state
    #           |> Map.put(:current_telegram, nil)
    #           |> Map.update(:telegrams, nil, fn queue ->
    #             Logger.debug("Dropping from queue")
    #             :queue.drop(queue)
    #           end)
    #           |> KNXex.to_struct!(State)

    #         {new_state, ref}
    #       else
    #         {state, nil}
    #       end

    #     nil ->
    #       {state, nil}
    #   end
    # end

    #### Helpers ####

    # credo:disable-for-lines:5 Credo.Check.Refactor.CyclomaticComplexity
    @spec extract_opts(Keyword.t()) ::
            {server_ip :: :inet.ip4_address(), local_ip :: :inet.ip4_address()}
    defp extract_opts(opts) when is_list(opts) do
      case opts[:group_addresses] do
        %{} = _map -> :ok
        nil -> raise ArgumentError, "Missing group addresses"
        term -> raise ArgumentError, "Invalid group addresses map, got: #{inspect(term)}"
      end

      server_ip =
        case opts[:server_ip] do
          term when is_tuple(term) and tuple_size(term) == 4 -> term
          nil -> raise ArgumentError, "Missing server IP"
          term -> raise ArgumentError, "Invalid server IP, got: #{inspect(term)}"
        end

      local_ip =
        case opts[:local_ip] do
          nil -> local_ipv4(server_ip)
          term when is_tuple(term) and tuple_size(term) == 4 -> term
          term -> raise ArgumentError, "Invalid local IP, got: #{inspect(term)}"
        end

      {server_ip, local_ip}
    end

    # Get the first non-local IPv4 address of the system, that may be in the range of the server IP
    @spec local_ipv4(:inet.ip4_address()) :: :inet.ip4_address()
    defp local_ipv4({s_one, s_two, s_three, _s_four} = server_ip) do
      with {:ok, ifaddrs} <- :inet.getifaddrs(),
           addrs <-
             Enum.map(ifaddrs, fn {_ifname, ifaddr} ->
               # The KW list contains two addr and netmask, for IPv4 and IPv6, IPv4 being the latter one
               {hd(tl(Keyword.get_values(ifaddr, :addr))),
                hd(tl(Keyword.get_values(ifaddr, :netmask)))}
             end),
           ipv4_addrs <-
             Enum.filter(addrs, fn {{one, _two, _three, _four} = addr, _netmask} ->
               tuple_size(addr) == 4 and one != 127 and one != 169
             end) do
        similar_ips =
          ipv4_addrs
          |> Enum.map(fn {{one, two, three, _four} = addr, netmask} ->
            ip_local = CIDR.parse("#{:inet.ntoa(addr)}/#{calculate_bitlength(netmask)}")

            cidr_match =
              case CIDR.match(ip_local, server_ip) do
                {:ok, true} -> 100
                _else -> 0
              end

            {addr,
             cidr_match +
               if(one == s_one, do: 25, else: 0) + if(two == s_two, do: 25, else: 0) +
               if(three == s_three, do: 25, else: 0)}
          end)
          |> Enum.sort_by(fn {_addr, score} -> score end, &>=/2)

        if length(similar_ips) > 0 do
          elem(hd(similar_ips), 0)
        else
          hd(ipv4_addrs)
        end
      end
    end

    # Calculate the bitmask length of a subnet mask (netmask)
    @spec calculate_bitlength(:inet.ip4_address()) :: integer()
    defp calculate_bitlength({one, two, three, four} = _netmask) do
      <<netmask_int::unsigned-integer-size(32)>> =
        <<one::unsigned-integer-size(8), two::unsigned-integer-size(8),
          three::unsigned-integer-size(8), four::unsigned-integer-size(8)>>

      netmask_int
      |> Integer.to_charlist(2)
      |> Enum.reduce(0, fn char, acc ->
        acc + if char == ?1, do: 1, else: 0
      end)
    end
  end
end

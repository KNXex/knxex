defmodule KNXexIP.MulticastClient do
  @moduledoc """
  KNXnet/IP Multicast Client.

  The KNX Multicast Client uses multicast to send and receive KNX telegrams (or any other KNX frame).
  The Client adds its membership to the multicast group and listens for incoming telegrams.

  Outgoing KNX frames are sent using multicast, too. The KNX/IP router must be correctly configured to forward the KNX frame to their KNX/TP connection.
  You may have multiple for each area or line, so the correct KNX/IP router, that should forward the KNX frame, must have the filter table correctly configured.

  Each function takes an `opts` keyword list, which can have an optional `:name` option, which is then used
  to call the `MulticastClient` identified by the `:name` (a PID or registered name), and an optional `:timeout` option (defaults to 5000).
  """

  require Logger
  require KNXexIP

  alias KNXexIP
  alias KNXexIP.Constants

  require Constants

  use GenServer

  @active_num_start 10
  @knx_multicast_ip {224, 0, 23, 12}
  @knx_port 3671

  @knx_header_size Constants.macro_by_name(:knx, :header_size_protocol_10)
  @knx_protocol_version Constants.macro_by_name(:knx, :protocol_version_10)

  @knx_send_apci 0x9CE0

  # TODO: Implement routing flow control
  # We should limit datagrams to 50 datagrams per second (as per specification),
  # additionally we should support ROUTING_BUSY frames
  defmodule State.Routing do
    @moduledoc false

    @fields [
      :is_busy,
      :num_busy,
      :timestamp_last_busy,
      :timer_busy_reset,
      :timer_frame,
      :current_frame,
      :frames
    ]

    # @enforce_keys @fields
    defstruct @fields
  end

  defmodule State do
    @moduledoc false

    @fields [
      :subscribers,
      :group_addresses,
      :local_ip,
      :multicast_ip,
      :port,
      :active_num,
      :opts,
      :routing
    ]

    @enforce_keys @fields
    defstruct @fields
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
  Starts the KNXnet/IP Multicast Client.

  The following options are available (some are required):
  - `allow_unknown_gpa: boolean()` - Optional. Determines whether unknown Group Addresses are allowed (not ignored when received, defaults to `false`).
  This will also mean that you receive the raw undecoded value and you need to provide the raw encoded value when sending.

  - `frame_callback: (KNXexIP.Frame.t(), :handled | unhandled) -> any()` - Optional. A callback module can be specified,
  that will be called for all frames which are not explicitely handled by this server module.
  Two arity: (KNXexIP.Frame.t(), :handled | :unhandled) - :handled for frames handled by this server module.

  - `group_addresses: map()` - Required. Group addresses map, where the key is the group address in `x/y/z` notation
  and the value is the DPT (datapoint type) - both being `String.t()`.
  The group address and its DPT is required to determine how to encode and decode received values.

  - `local_ip: :inet.ip4_address()` - Optional. The local IP address to use. If nil, the local IP address will be discovered.

  - `multicast_ip: :inet.ip4_address()` - Optional. The multicast IP address to use. If nil, it will default to `224.0.23.12`.

  - `source_address: KNXexIP.IndividualAddress.t()` - Required. The KNX individual address that will be used as source address for all non-raw frames.
  The source address is required, as the KNX/IP router does not fill it in, if the source is `0.0.0` (it is transmitted as-is to the KNX bus).

  All other given options are passed to the `GenServer` module (i.e. `:name` can be given to override the process name to register).
  """
  @spec start_link(Keyword.t()) ::
          {:ok, pid()} | {:error, {:already_started, pid()}}
  def start_link(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "start_link/1 expected a keyword list, got: #{inspect(opts)}"
    end

    {local_ip, multicast_ip} = extract_opts(opts)

    {opts, genserver_opts} =
      opts
      |> Keyword.put_new(:allow_unknown_gpa, false)
      |> Keyword.put_new(:name, __MODULE__)
      |> Keyword.split([
        :allow_unknown_gpa,
        :frame_callback,
        :group_addresses,
        :local_ip,
        :multicast_ip,
        :source_address
      ])

    GenServer.start_link(__MODULE__, {local_ip, multicast_ip, Map.new(opts)}, genserver_opts)
  end

  @doc """
  Subscribes to telegram notifications. The subscriber will receive messages in the form `{:knx, KNXexIP.Telegram.t()}`.
  """
  @spec subscribe(pid(), Keyword.t()) :: :ok
  def subscribe(pid, opts \\ []) when is_pid(pid) and is_list(opts) do
    GenServer.call(get_opts_name(), {:subscribe, pid}, get_opts_timeout())
  end

  @doc """
  Unsubscribes from telegram notifications.
  """
  @spec unsubscribe(pid(), Keyword.t()) :: :ok
  def unsubscribe(pid, opts \\ []) when is_pid(pid) and is_list(opts) do
    GenServer.call(get_opts_name(), {:unsubscribe, pid}, get_opts_timeout())
  end

  @doc """
  Gets all group addresses from the state.
  """
  @spec get_group_addresses(Keyword.t()) ::
          {:ok, %{optional(address :: String.t()) => dpt :: String.t()}}
  def get_group_addresses(opts \\ []) when is_list(opts) do
    GenServer.call(get_opts_name(), :get_group_addresses, get_opts_timeout())
  end

  @doc """
  Adds the given group address with the datapoint type (DPT) to the group address list.
  Unknown group addresses can not be used to send or receive telegrams.

  The DPT is in the form of "x.yyy" where x and y are numbers, i.e. `1.001`.
  """
  @spec add_group_address(KNXexIP.GroupAddress.t(), binary(), Keyword.t()) :: :ok
  def add_group_address(%KNXexIP.GroupAddress{} = group_address, dpt, opts \\ [])
      when is_list(opts) do
    GenServer.call(
      get_opts_name(),
      {:add_group_address, group_address, dpt},
      get_opts_timeout()
    )
  end

  @doc """
  Removes the given group address from the group address list.
  """
  @spec remove_group_address(KNXexIP.GroupAddress.t(), Keyword.t()) :: :ok
  def remove_group_address(%KNXexIP.GroupAddress{} = group_address, opts \\ [])
      when is_list(opts) do
    GenServer.call(
      get_opts_name(),
      {:remove_group_address, group_address},
      get_opts_timeout()
    )
  end

  @doc """
  Sends a `GroupValueRead` to `group_address`. Waits up to `get_opts_timeout()` for the response.
  Utilizes a `Task` to subscribe temporarily to events.
  """
  @spec read_group_address(KNXexIP.GroupAddress.t(), Keyword.t()) ::
          {:ok, KNXexIP.Telegram.t()} | {:error, :unknown_group_address} | {:error, :timeout}
  def read_group_address(%KNXexIP.GroupAddress{} = group_address, opts \\ [])
      when is_list(opts) do
    task =
      Task.async(fn ->
        __MODULE__.subscribe(self())
        timeout = get_opts_timeout()

        response =
          case GenServer.call(
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

  The returned reference is currently without any meaning to the user.
  """
  @spec write_group_address(KNXexIP.GroupAddress.t(), term(), Keyword.t()) ::
          {:ok, reference()} | {:error, :unknown_group_address}
  def write_group_address(%KNXexIP.GroupAddress{} = group_address, value, opts \\ [])
      when is_list(opts) do
    GenServer.call(
      get_opts_name(),
      {:group_write, group_address, value},
      get_opts_timeout()
    )
  end

  @doc """
  Sends a raw frame. The frame body must be binary or have a `FrameEncoder` implementation.

  If the frame body is a frame, the `request_type` can be set to `:auto` and it will be derived from the `FrameEncoder` implementation.
  """
  @spec send_frame(KNXexIP.Frame.t(), Keyword.t()) ::
          :ok | {:error, term()}
  def send_frame(frame, opts \\ [])

  def send_frame(%KNXexIP.Frame{body: body} = frame, opts)
      when is_struct(body) and is_list(opts) do
    Protocol.assert_impl!(KNXexIP.Frames.FrameEncoder, frame.body.__struct__)

    GenServer.call(get_opts_name(), {:send_frame, frame}, get_opts_timeout())
  end

  def send_frame(%KNXexIP.Frame{body: body} = frame, opts)
      when is_binary(body) and is_list(opts) do
    GenServer.call(get_opts_name(), {:send_frame, frame}, get_opts_timeout())
  end

  #### Private API ####

  @doc false
  def init({local_ip, multicast_ip, opts}) do
    Process.put({__MODULE__, :source_address}, opts.source_address)

    case :gen_udp.open(@knx_port, [
           :binary,
           ip: local_ip,
           active: @active_num_start,
           add_membership: {multicast_ip, local_ip},
           multicast_loop: false,
           reuseaddr: true
         ]) do
      {:ok, port} ->
        state = %State{
          subscribers: [],
          group_addresses: opts.group_addresses,
          local_ip: local_ip,
          multicast_ip: multicast_ip,
          port: port,
          active_num: @active_num_start,
          opts: Map.drop(opts, [:group_addresses, :local_ip, :multicast_ip]),
          routing: %State.Routing{
            frames: :queue.new()
          }
        }

        {:ok, state}

      err ->
        {:stop, err}
    end
  end

  @doc false
  def handle_call({:subscribe, pid}, _from, %State{} = state) do
    new_state =
      state
      |> Map.update(:subscribers, [], fn list ->
        [pid | list]
      end)
      |> KNXexIP.to_struct!(State)

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
      |> KNXexIP.to_struct!(State)

    {:reply, :ok, new_state}
  end

  def handle_call(:get_group_addresses, _from, %State{group_addresses: group_addresses} = state) do
    {:reply, {:ok, group_addresses}, state}
  end

  def handle_call(
        {:add_group_address, %KNXexIP.GroupAddress{} = group_address, dpt},
        _from,
        %State{} = state
      ) do
    new_state =
      state
      |> Map.update(:group_addresses, %{}, fn map ->
        Map.put(map, KNXexIP.GroupAddress.to_string(group_address), dpt)
      end)
      |> KNXexIP.to_struct!(State)

    {:reply, :ok, new_state}
  end

  def handle_call(
        {:remove_group_address, %KNXexIP.GroupAddress{} = group_address},
        _from,
        %State{} = state
      ) do
    new_state =
      state
      |> Map.update(:group_addresses, %{}, fn map ->
        Map.drop(map, [KNXexIP.GroupAddress.to_string(group_address)])
      end)
      |> KNXexIP.to_struct!(State)

    {:reply, :ok, new_state}
  end

  def handle_call({:group_read, %KNXexIP.GroupAddress{} = group_address}, from, %State{} = state) do
    grpaddr_str = KNXexIP.GroupAddress.to_string(group_address)
    known_gpa = state.group_addresses[grpaddr_str] || state.opts.allow_unknown_gpa || nil

    case known_gpa do
      nil ->
        {:reply, {:error, :unknown_group_address}, state}

      _dpt ->
        frame = %KNXexIP.Frame{
          body: %KNXexIP.Frames.RoutingIndicationFrame{
            message_code: Constants.macro_assert_name(:message_code, :data_request),
            additional_info: "",
            payload: %KNXexIP.Frames.RoutingIndicationFrame.Data{
              apci: Constants.macro_by_name(:frame_apci, :group_read),
              control_field: @knx_send_apci,
              destination: group_address,
              destination_type: :group,
              source: state.opts.source_address,
              tpci: 0,
              value: <<0::size(6)>>
            }
          },
          header_size: @knx_header_size,
          protocol_version: @knx_protocol_version,
          request_type: :auto
        }

        handle_call({:send_frame, frame}, from, state)
    end
  end

  def handle_call(
        {:group_write, %KNXexIP.GroupAddress{} = group_address, value},
        from,
        %State{} = state
      ) do
    grpaddr_str = KNXexIP.GroupAddress.to_string(group_address)
    datapoint_type = state.group_addresses[grpaddr_str]

    if datapoint_type != nil or state.opts.allow_unknown_gpa do
      encode =
        case datapoint_type do
          nil -> {:ok, value}
          _dpt -> KNXexIP.DPT.encode(value, datapoint_type)
        end

      case encode do
        {:ok, raw_value} ->
          frame = %KNXexIP.Frame{
            body: %KNXexIP.Frames.RoutingIndicationFrame{
              message_code: Constants.macro_assert_name(:message_code, :data_request),
              additional_info: "",
              payload: %KNXexIP.Frames.RoutingIndicationFrame.Data{
                apci: Constants.macro_by_name(:frame_apci, :group_write),
                control_field: @knx_send_apci,
                destination: group_address,
                destination_type: :group,
                source: state.opts.source_address,
                tpci: 0,
                value: raw_value
              }
            },
            header_size: @knx_header_size,
            protocol_version: @knx_protocol_version,
            request_type: :auto
          }

          handle_call({:send_frame, frame}, from, state)

        val ->
          {:reply, val, state}
      end
    else
      {:reply, {:error, :unknown_group_address}, state}
    end
  end

  def handle_call(
        {:send_frame, %KNXexIP.Frame{} = frame},
        _from,
        %State{} = state
      ) do
    frame_encoded =
      cond do
        is_struct(frame.body) ->
          KNXexIP.Frames.FrameEncoder.encode(frame.body, frame.protocol_version)

        is_binary(frame.body) ->
          {:ok, frame.body}

        true ->
          {:error, :invalid_frame_body}
      end

    case frame_encoded do
      {:ok, request_payload} ->
        # header is 6 bytes in length
        request_length = byte_size(request_payload) + 6

        request_type =
          case frame.request_type do
            :auto when is_struct(frame.body) ->
              Constants.by_name(
                :request_type,
                KNXexIP.Frames.FrameEncoder.get_request_type(frame.body)
              )

            request_type when is_atom(request_type) ->
              Constants.by_name(:request_type, request_type)

            request_type ->
              request_type
          end

        packet =
          <<frame.header_size::size(8), frame.protocol_version::size(8), request_type::size(16),
            request_length::size(16), request_payload::binary>>

        Logger.debug("Sending UDP data: #{inspect(packet)}")

        {:reply, :gen_udp.send(state.port, {state.multicast_ip, @knx_port}, packet), state}

      term ->
        {:reply, term, state}
    end
  end

  #### Frames ####

  @doc false
  def handle_info({:udp, _port, _sender_ip, _sender_port, data}, %State{} = state) do
    Logger.debug("Received UDP data: #{inspect(data)}")

    case decode_frame(data) do
      {:ok, frame} ->
        Logger.debug("Received KNX frame type #{frame.request_type}")
        handle_frame(frame, state)

      {:error, err} ->
        Logger.debug("Error while decoding frame, error: #{inspect(err)}")
        :ok

      :ignore ->
        Logger.debug("Ignoring frame with #{byte_size(data)} bytes")
        :ok

      :invalid ->
        Logger.debug("Ignoring invalid frame with #{byte_size(data)} bytes")
        :ok
    end

    new_state =
      if state.active_num - 1 <= 1 do
        :inet.setopts(state.port, active: @active_num_start)
        %State{state | active_num: @active_num_start}
      else
        %State{state | active_num: state.active_num - 1}
      end

    {:noreply, new_state}
  end

  def handle_info({:udp_passive, port}, %State{} = state) do
    :inet.setopts(port, active: @active_num_start)
    {:noreply, state}
  end

  #### Frame Decoding ####

  # Make sure frames have the correct length (request_length == frame length)
  # See the KNXexIP.FrameDecoder module
  @spec decode_frame(bitstring()) ::
          {:ok, KNXexIP.Frame.t()} | {:error, term()} | :ignore | :invalid
  defp decode_frame(
         <<@knx_header_size::size(8), @knx_protocol_version::size(8), request::size(16),
           request_length::size(16), frame_data::binary>> = data
       )
       when byte_size(data) == request_length do
    request_type = Constants.by_value(:request_type, request)

    case KNXexIP.FrameDecoder.decode_frame(
           Constants.macro_by_name(:knx, :protocol_version_10),
           request_type,
           frame_data
         ) do
      {:ok, body} ->
        {:ok,
         %KNXexIP.Frame{
           header_size: Constants.macro_by_name(:knx, :header_size_protocol_10),
           protocol_version: Constants.macro_by_name(:knx, :protocol_version_10),
           request_type: request_type,
           body: body
         }}

      term ->
        term
    end
  end

  defp decode_frame(_data), do: :invalid

  #### Frame Handling ####

  @spec handle_frame(KNXexIP.Frame.t(), %State{}) :: any()
  defp handle_frame(
         %KNXexIP.Frame{
           request_type: Constants.macro_assert_name(:request_type, :routing_indication),
           body: %KNXexIP.Frames.RoutingIndicationFrame{
             message_code: Constants.macro_assert_name(:message_code, :data_indicator),
             payload:
               %KNXexIP.Frames.RoutingIndicationFrame.Data{
                 apci: apci
               } = body
           }
         } = frame,
         %State{} = state
       )
       when apci in [
              Constants.macro_assert_name(:frame_apci, :group_read),
              Constants.macro_assert_name(:frame_apci, :group_response),
              Constants.macro_assert_name(:frame_apci, :group_write)
            ] do
    grpaddr_str = KNXexIP.GroupAddress.to_string(body.destination)

    case state.group_addresses[grpaddr_str] do
      nil ->
        Logger.info("Ignoring unspecified group address: #{grpaddr_str}")
        :ok

      datapoint_type ->
        # Do not try to decode value for a GroupValueRead request
        dp_value =
          if apci == Constants.macro_assert_name(:frame_apci, :group_read) do
            {:ok, ""}
          else
            KNXexIP.DPT.decode(body.value, datapoint_type)
          end

        case dp_value do
          {:ok, value} ->
            # Fan out notifications in a new process
            # to not block too long
            spawn(fn ->
              telegram = %KNXexIP.Telegram{
                type: apci,
                source: body.source,
                destination: body.destination,
                value: value
              }

              for subscriber <- state.subscribers do
                send(subscriber, {:knx, telegram})
              end
            end)

          {:error, err} ->
            Logger.info("Unable to decode group address value, error: #{inspect(err)}")
        end
    end

    call_frame_callback(frame, state, :handled)
    :ok
  end

  defp handle_frame(
         %KNXexIP.Frame{} = frame,
         %State{} = state
       ) do
    call_frame_callback(frame, state, :unhandled)
  end

  defp call_frame_callback(%KNXexIP.Frame{} = frame, %State{} = state, type) do
    case state.opts[:frame_callback] do
      nil ->
        :ok

      module ->
        try do
          module.knx_frame_callback(frame, type)
          :ok
        rescue
          err -> Logger.error("Frame callback has been rescued, error: #{inspect(err)}")
        catch
          type, err ->
            Logger.error("Frame callback has been catched, type: #{type}, error: #{inspect(err)}")
        end
    end
  end

  #### Helpers ####

  # credo:disable-for-lines:5 Credo.Check.Refactor.CyclomaticComplexity
  @spec extract_opts(Keyword.t()) ::
          {local_ip :: :inet.ip4_address(), multicast_ip :: :inet.ip4_address()}
  defp extract_opts(opts) when is_list(opts) do
    case opts[:frame_callback] do
      nil ->
        :ok

      module ->
        Code.ensure_loaded!(module)

        unless function_exported?(module, :knx_frame_callback, 2) do
          raise ArgumentError,
                "Given frame callback module does not implement or export knx_frame_callback/2"
        end
    end

    case opts[:group_addresses] do
      %{} = _map -> :ok
      nil -> raise ArgumentError, "Missing group addresses"
      term -> raise ArgumentError, "Invalid group addresses map, got: #{inspect(term)}"
    end

    case opts[:source_address] do
      %KNXexIP.IndividualAddress{} = _map -> :ok
      nil -> raise ArgumentError, "Missing source address"
      term -> raise ArgumentError, "Invalid source address, got: #{inspect(term)}"
    end

    local_ip =
      case opts[:local_ip] do
        nil -> local_ipv4()
        term when is_tuple(term) and tuple_size(term) == 4 -> term
        term -> raise ArgumentError, "Invalid local IP, got: #{inspect(term)}"
      end

    multicast_ip =
      case opts[:multicast_ip] do
        nil -> @knx_multicast_ip
        term when is_tuple(term) and tuple_size(term) == 4 -> term
        term -> raise ArgumentError, "Invalid multicast IP, got: #{inspect(term)}"
      end

    {local_ip, multicast_ip}
  end

  # Get the first non-local IPv4 address of the system
  @spec local_ipv4() :: :inet.ip4_address()
  defp local_ipv4() do
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
      elem(hd(ipv4_addrs), 0)
    end
  end

  # credo:disable-for-lines:100
  # The CEMI reference below is copied from the KNX protocol specification implementation for crystal-lang
  # https://github.com/spider-gazelle/knx

  # CEMI == Common External Message Interface
  # +--------+--------+--------+--------+----------------+----------------+--------+----------------+
  # |  Msg   |Add.Info| Ctrl 1 | Ctrl 2 | Source Address | Dest. Address  |  Data  |      APDU      |
  # | Code   | Length |        |        |                |                | Length |                |
  # +--------+--------+--------+--------+----------------+----------------+--------+----------------+
  #   1 byte   1 byte   1 byte   1 byte      2 bytes          2 bytes       1 byte      2 bytes
  #
  #  Message Code    = 0x11 - a L_Data.req primitive
  #      COMMON EMI MESSAGE CODES FOR DATA LINK LAYER PRIMITIVES
  #          FROM NETWORK LAYER TO DATA LINK LAYER
  #          +---------------------------+--------------+-------------------------+---------------------+------------------+
  #          | Data Link Layer Primitive | Message Code | Data Link Layer Service | Service Description | Common EMI Frame |
  #          +---------------------------+--------------+-------------------------+---------------------+------------------+
  #          |        L_Raw.req          |    0x10      |                         |                     |                  |
  #          +---------------------------+--------------+-------------------------+---------------------+------------------+
  #          |                           |              |                         | Primitive used for  | Sample Common    |
  #          |        L_Data.req         |    0x11      |      Data Service       | transmitting a data | EMI frame        |
  #          |                           |              |                         | frame               |                  |
  #          +---------------------------+--------------+-------------------------+---------------------+------------------+
  #          |        L_Poll_Data.req    |    0x13      |    Poll Data Service    |                     |                  |
  #          +---------------------------+--------------+-------------------------+---------------------+------------------+
  #
  #          FROM DATA LINK LAYER TO NETWORK LAYER
  #          +---------------------------+--------------+-------------------------+---------------------+
  #          | Data Link Layer Primitive | Message Code | Data Link Layer Service | Service Description |
  #          +---------------------------+--------------+-------------------------+---------------------+
  #          |        L_Poll_Data.con    |    0x25      |    Poll Data Service    |                     |
  #          +---------------------------+--------------+-------------------------+---------------------+
  #          |                           |              |                         | Primitive used for  |
  #          |        L_Data.ind         |    0x29      |      Data Service       | receiving a data    |
  #          |                           |              |                         | frame               |
  #          +---------------------------+--------------+-------------------------+---------------------+
  #          |        L_Busmon.ind       |    0x2B      |   Bus Monitor Service   |                     |
  #          +---------------------------+--------------+-------------------------+---------------------+
  #          |        L_Raw.ind          |    0x2D      |                         |                     |
  #          +---------------------------+--------------+-------------------------+---------------------+
  #          |                           |              |                         | Primitive used for  |
  #          |                           |              |                         | local confirmation  |
  #          |        L_Data.con         |    0x2E      |      Data Service       | that a frame was    |
  #          |                           |              |                         | sent (does not mean |
  #          |                           |              |                         | successful receive) |
  #          +---------------------------+--------------+-------------------------+---------------------+
  #          |        L_Raw.con          |    0x2F      |                         |                     |
  #          +---------------------------+--------------+-------------------------+---------------------+
  #
  #  Add.Info Length = 0x00 - no additional info
  #  Control Field 1 = see the bit structure in CemiControlField module
  #  Control Field 2 = see the bit structure in CemiControlField module
  #  Source Address  = 0x0000 - filled in by router/gateway with its source address which is
  #                    part of the KNX subnet
  #  Dest. Address   = KNX group or individual address (2 byte)
  #  Data Length     = Number of bytes of data in the APDU excluding the TPCI/APCI bits
  #  APDU            = Application Protocol Data Unit - the actual payload including transport
  #                    protocol control information (TPCI), application protocol control
  #                    information (APCI) and data passed as an argument from higher layers of
  #                    the KNX communication stack

  # See: https://youtu.be/UjOBudAG654?t=42m20s
  # group :wrapper, onlyif: ->{ request_type == RequestTypes::SecureWrapper } do
  #     uint16 :session_id # Not sure what this should be

  #     bit_field do
  #         bits 48, :timestamp         # Timestamp for multicast messages, sequence number for tunneling
  #         bits 48, :knx_serial_number # Serial of the device - random constant
  #     end
  #     uint16 :message_tag # Random number

  #     # header + security info + cbc_mac == 38
  #     #   6          16            16    == 38
  #     string :encrypted_frame, length: ->{ parent.request_length - 38 }
  #     # Encryption: Timestamp + Serial Number + Tag + 0x01 + counter (1 byte), starting at 0
  #     # Single key for each multicast group: PID_BACKBONE_KEY
  #     # https://en.wikipedia.org/wiki/CCM_mode

  #     # https://en.wikipedia.org/wiki/CBC-MAC (always 128bit (16bytes) in KNX)
  #     # Timestamp + Serial Number + Tag + frame length (2 bytes)
  #     string :cmac, length: ->{ 16 }
  # end
end

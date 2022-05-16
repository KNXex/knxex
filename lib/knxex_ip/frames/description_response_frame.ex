defmodule KNXexIP.Frames.DescriptionResponseFrame do
  @moduledoc """
  KNX Description Response Frame.

  This frame does have a frame encoder implementation.
  """

  alias KNXexIP
  alias KNXexIP.Constants

  @typedoc """
  Represents a KNX Description Response frame.
  """
  @type t :: %__MODULE__{
          protocol: :ipv4_udp | :ipv4_tcp,
          ip: :inet.ip4_address(),
          port: :inet.port_number(),
          device_info: KNXexIP.DIB.DeviceInfo.t(),
          dibs: [KNXexIP.DIB.dib()]
        }

  @fields [:protocol, :ip, :port, :device_info, :dibs]
  @enforce_keys @fields
  defstruct @fields

  #### Private API ####

  # Inlined into KNXexIP.FrameDecoder
  @doc false
  @spec __using__(any()) :: Macro.t()
  defmacro __using__(_any) do
    quote location: :keep do
      def decode_frame(
            Constants.macro_by_name(:knx, :protocol_version_10),
            Constants.macro_assert_name(:request_type, :description_response),
            <<_hpai_length::size(8), hpai_protocol::size(8), ip::size(32), port::size(16),
              dib::binary>>
          ) do
        dibs = KNXexIP.DIB.parse(dib)
        device_info = Enum.find(dibs, nil, fn {name, _dib} -> name === :device_info end)

        if device_info == nil do
          raise "No device info found in DIB"
        end

        {:ok,
         %KNXexIP.Frames.DescriptionResponseFrame{
           protocol: Constants.by_value(:protocol_type, hpai_protocol),
           ip: KNXexIP.DIB.IPConfig.integer_to_inet(ip),
           port: port,
           device_info: device_info,
           dibs: dibs
         }}
      end
    end
  end

  defimpl KNXexIP.Frames.FrameEncoder do
    alias KNXexIP
    alias KNXexIP.Constants

    require Constants

    def encode(%{} = frame, Constants.macro_by_name(:knx, :protocol_version_10))
        when is_struct(frame, KNXexIP.Frames.DescriptionResponseFrame) do
      struct =
        <<8, Constants.by_name(:protocol_type, frame.protocol),
          KNXexIP.DIB.IPConfig.inet_to_integer(frame.ip)::size(32), frame.port::size(16),
          encode_dib(frame)::binary>>

      struct_length = byte_size(struct) + 1
      {:ok, <<struct_length, struct::binary>>}
    end

    def encode(_frame, _protocol_version), do: {:error, :protocol_version_not_supported}

    def get_request_type(_frame),
      do: Constants.macro_assert_name(:request_type, :description_response)

    @spec encode_dib(KNXexIP.Frames.DescriptionResponseFrame.t()) :: binary()
    defp encode_dib(%KNXexIP.Frames.DescriptionResponseFrame{dibs: dibs} = _frame) do
      Enum.reduce(dibs, <<>>, fn
        dib, acc -> <<acc::binary, KNXexIP.DIB.encode(dib)::binary>>
      end)
    end
  end
end

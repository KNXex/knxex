defmodule KNXex.Frames.DescriptionRequestFrame do
  @moduledoc """
  KNX Description Request Frame.

  This frame does have a frame encoder implementation.
  """

  alias KNXex
  alias KNXex.Constants

  @typedoc """
  Represents a KNX Description Request frame.
  """
  @type t :: %__MODULE__{
          protocol: :ipv4_udp | :ipv4_tcp,
          ip: :inet.ip4_address(),
          port: :inet.port_number()
        }

  @fields [:protocol, :ip, :port]
  @enforce_keys @fields
  defstruct @fields

  #### Private API ####

  # Inlined into KNXex.FrameDecoder
  @doc false
  @spec __using__(any()) :: Macro.t()
  defmacro __using__(_any) do
    quote location: :keep do
      def decode_frame(
            Constants.macro_by_name(:knx, :protocol_version_10),
            Constants.macro_assert_name(:request_type, :description_request),
            <<_hpai_length::size(8), hpai_protocol::size(8), ip::size(32), port::size(16),
              _rest::binary>>
          ) do
        {:ok,
         %KNXex.Frames.DescriptionRequestFrame{
           protocol: Constants.by_value(:protocol_type, hpai_protocol),
           ip: KNXex.DIB.IPConfig.integer_to_inet(ip),
           port: port
         }}
      end
    end
  end

  defimpl KNXex.Frames.FrameEncoder do
    alias KNXex
    alias KNXex.Constants

    require Constants

    def encode(%{} = frame, Constants.macro_by_name(:knx, :protocol_version_10))
        when is_struct(frame, KNXex.Frames.DescriptionRequestFrame) do
      struct =
        <<8, Constants.by_name(:protocol_type, frame.protocol),
          KNXex.DIB.IPConfig.inet_to_integer(frame.ip)::size(32), frame.port::size(16)>>

      struct_length = byte_size(struct) + 1
      {:ok, <<struct_length, struct::binary>>}
    end

    def encode(_frame, _protocol_version), do: {:error, :protocol_version_not_supported}

    def get_request_type(_frame),
      do: Constants.macro_assert_name(:request_type, :description_request)
  end
end

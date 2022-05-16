defmodule KNXexIP.Frames.RoutingIndicationFrame do
  @moduledoc """
  KNX Routing Indication Frame.

  This frame does have a frame encoder implementation.

  The payload has the following type for a specific message code:
    - `:data_request` or `:data_indicator` -> `KNXexIP.Frames.RoutingIndicationFrame.Data`
    - Any other -> `KNXexIP.Frames.RoutingIndicationFrame.Raw`
  """

  alias KNXexIP
  alias KNXexIP.Constants

  @typedoc """
  KNX message codes.
  """
  @type message_code() ::
          :raw_request
          | :data_request
          | :poll_data_request
          | :poll_data_connection
          | :data_indicator
          | :busmon_indicator
          | :raw_indicator
          | :data_connection
          | :raw_connection
          | :data_connection_request
          | :data_individual_request
          | :data_connection_indicator
          | :data_individual_indicator
          | :reset_indicator
          | :reset_request
          | :prop_write_connection
          | :prop_write_request
          | :prop_info_indicator
          | :func_prop_com_request
          | :func_prop_state_read_request
          | :func_prop_com_connection
          | :prop_read_connection
          | :prop_read_request

  @typedoc """
  Represents a KNX Routing Indication frame.
  """
  @type t :: %__MODULE__{
          message_code: message_code(),
          additional_info: binary(),
          payload:
            KNXexIP.Frames.RoutingIndicationFrame.Data.t()
            | KNXexIP.Frames.RoutingIndicationFrame.Raw.t()
        }

  @fields [
    :message_code,
    :additional_info,
    :payload
  ]
  @enforce_keys @fields
  defstruct @fields

  #### Private API ####

  # Inlined into KNXexIP.FrameDecoder
  @doc false
  @spec __using__(any()) :: Macro.t()
  defmacro __using__(_any) do
    quote location: :keep do
      require KNXexIP.CEMIControlField

      @data_services [
        Constants.macro_by_name(:message_code, :data_request),
        Constants.macro_by_name(:message_code, :data_indicator)
      ]

      def decode_frame(
            Constants.macro_by_name(:knx, :protocol_version_10),
            Constants.macro_assert_name(:request_type, :routing_indication),
            <<message_code::size(8), add_info_length::size(8),
              add_info::binary-size(add_info_length)-unit(8), control_field::size(16),
              source_addr::size(16), dest_addr::size(16), data_length::size(8),
              tpci_apci_rest::binary>>
          )
          when message_code in @data_services do
        {_type, source_address} =
          {:individual, KNXexIP.IndividualAddress.from_raw_address(source_addr)}

        {dest_type, destination_address} =
          case Bitwise.band(control_field, 0x80) do
            0x80 ->
              {:group, KNXexIP.GroupAddress.from_raw_address(dest_addr)}

            _any ->
              {:individual, KNXexIP.IndividualAddress.from_raw_address(source_addr)}
          end

        {tpci, apci, value} =
          if data_length > 0 do
            bit_length = data_length * 8 - 2

            if bit_length == 6 do
              <<tpci::size(6), apci::size(4), value::bitstring>> = tpci_apci_rest
              {tpci, apci, value}
            else
              <<tpci::size(6), apci_raw::size(10), value::bitstring>> = tpci_apci_rest

              short_apci = Bitwise.bsr(apci_raw, 6)

              # Calculate whether APCI is short (4 bits) or long (10 bits)
              apci =
                if short_apci < 11 and short_apci != 7 do
                  short_apci
                else
                  apci_raw
                end

              {tpci, apci, value}
            end
          else
            {tpci_apci_rest, 0, <<>>}
          end

        apci_interpreted =
          try do
            Constants.by_value(:frame_apci, apci)
          rescue
            UndefinedFunctionError -> apci
          end

        {:ok,
         %unquote(__MODULE__){
           message_code: Constants.by_value(:message_code, message_code),
           additional_info: add_info,
           payload: %unquote(__MODULE__).Data{
             control_field: control_field,
             tpci: KNXexIP.TPCI.make(tpci),
             apci: apci_interpreted,
             source: source_address,
             destination_type: dest_type,
             destination: destination_address,
             value: value
           }
         }}
      end

      # All other frames are RAW
      def decode_frame(
            Constants.macro_by_name(:knx, :protocol_version_10),
            Constants.macro_assert_name(:request_type, :routing_indication),
            <<message_code::size(8), add_info_length::size(8),
              add_info::binary-size(add_info_length)-unit(8), raw_data::binary>>
          ) do
        {:ok,
         %unquote(__MODULE__){
           message_code: Constants.by_value(:message_code, message_code),
           additional_info: add_info,
           payload: %unquote(__MODULE__).Raw{
             raw_data: raw_data
           }
         }}
      end
    end
  end

  defimpl KNXexIP.Frames.FrameEncoder do
    alias KNXexIP
    alias KNXexIP.Constants

    require Constants

    def encode(%{} = frame, Constants.macro_by_name(:knx, :protocol_version_10))
        when is_struct(frame, KNXexIP.Frames.RoutingIndicationFrame) do
      add_info_length = byte_size(frame.additional_info)

      {:ok,
       <<Constants.by_name(:message_code, frame.message_code)::size(8), add_info_length::size(8)>> <>
         if(add_info_length > 0, do: <<frame.additional_info::binary>>, else: <<>>) <>
         do_encode_data(frame.payload)}
    end

    def encode(%{} = frame, Constants.macro_by_name(:knx, :protocol_version_10))
        when is_struct(frame, KNXexIP.Frames.RoutingIndicationFrame.Raw) do
      add_info_length = byte_size(frame.additional_info)

      {:ok,
       <<Constants.by_name(:message_code, frame.message_code)::size(8), add_info_length::size(8)>> <>
         if(add_info_length > 0, do: <<frame.additional_info::binary>>, else: <<>>) <>
         frame.payload.raw_data}
    end

    def encode(_frame, _protocol_version), do: {:error, :protocol_version_not_supported}

    def get_request_type(_frame),
      do: Constants.macro_assert_name(:request_type, :routing_indication)

    #### Frame Data Encoders ####

    defp do_encode_data(%KNXexIP.Frames.RoutingIndicationFrame.Data{} = frame) do
      {control_field, dest_addr} =
        case frame.destination_type do
          :group ->
            if not is_struct(frame.destination, KNXexIP.GroupAddress) do
              raise ArgumentError,
                    "Invalid type for field destionation, expected a GroupAddress, got: #{inspect(frame.destination)}"
            end

            {Bitwise.bor(frame.control_field, 0x80),
             KNXexIP.GroupAddress.to_raw_address(frame.destination)}

          :individual ->
            if not is_struct(frame.destination, KNXexIP.IndividualAddress) do
              raise ArgumentError,
                    "Invalid type for field destionation, expected a IndividualAddress, got: #{inspect(frame.destination)}"
            end

            {Bitwise.band(frame.control_field, Bitwise.bnot(0x80)),
             KNXexIP.IndividualAddress.to_raw_address(frame.destination)}
        end

      value =
        if frame.apci == Constants.macro_by_name(:frame_apci, :group_read) do
          <<0::size(6)>>
        else
          if is_bitstring(frame.value) do
            frame.value
          else
            <<frame.value>>
          end
        end

      apci =
        if is_integer(frame.apci) do
          frame.apci
        else
          Constants.by_name(:frame_apci, frame.apci)
        end

      tpci =
        if is_integer(frame.tpci) do
          frame.tpci
        else
          KNXexIP.TPCI.to_integer(frame.tpci)
        end

      {data_length, tpci_data} =
        if bit_size(value) == 6 do
          {1, <<tpci::size(6), apci::size(4), value::bitstring-size(6)>>}
        else
          <<apci_val::size(10)>> =
            if apci < 11 and apci != 7 do
              <<apci::size(4), 0::size(6)>>
            else
              <<apci::size(10)>>
            end

          {byte_size(value) + 1, <<tpci::size(6), apci_val::size(10), value::bitstring>>}
        end

      <<control_field::size(16), KNXexIP.IndividualAddress.to_raw_address(frame.source)::size(16),
        dest_addr::size(16), data_length::size(8), tpci_data::bitstring>>
    end

    defp do_encode_data(%KNXexIP.Frames.RoutingIndicationFrame.Raw{} = frame) do
      frame.raw_data
    end
  end
end

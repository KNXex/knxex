defmodule KNXex.Frames.RoutingIndicationFrame.Data do
  @moduledoc """
  This module contains the data of `Routing Indication` Frames, that have the message code `data_indicator` or `data_request`.

  These type of frames are used to send GroupValueRead, GroupValueRespond and GroupValueWrite requests, among other telegrams.
  """

  alias KNXex
  alias KNXex.Constants
  require Constants

  @typedoc """
  KNX Application Layer Protocol Control Information (APCI).

  The APCI defines the service.
  See also <https://support.KNXex.org/hc/en-us/articles/115003188529-Payload>.
  """
  @type apci() ::
          :group_read
          | :group_response
          | :group_write
          | :individual_write
          | :individual_read
          | :individual_response
          | :adc_read
          | :adc_response
          | :sys_net_param_read
          | :sys_net_param_response
          | :sys_net_param_write
          | :memory_read
          | :memory_response
          | :memory_write
          | :user_memory_read
          | :user_memory_response
          | :user_memory_write
          | :user_manufacturer_info_read
          | :user_manufacturer_info_response
          | :function_property_command
          | :function_property_state_read
          | :function_property_state_response
          | :device_descriptor_read
          | :device_descriptor_response
          | :restart
          | :escape
          | :authorize_request
          | :authorize_response
          | :key_write
          | :key_response
          | :property_value_read
          | :property_value_response
          | :property_value_write
          | :property_description_read
          | :property_description_response
          | :network_param_read
          | :network_param_response
          | :individual_serial_num_read
          | :individual_serial_num_response
          | :individual_serial_num_write
          | :domain_write
          | :domain_read
          | :domain_response
          | :domain_selective_read
          | :network_param_write
          | :link_read
          | :link_response
          | :link_write
          | :group_prop_value_read
          | :group_prop_value_response
          | :group_prop_value_write
          | :group_prop_value_info
          | :domain_serial_num_read
          | :domain_serial_num_response
          | :domain_serial_num_write
          | :filesystem_info

  @typedoc """
  Represents a data service frame.
  """
  @type t :: %__MODULE__{
          control_field: KNXex.CEMIControlField.t(),
          tpci: KNXex.TPCI.t(),
          apci: apci() | non_neg_integer(),
          source: KNXex.IndividualAddress.t(),
          destination_type: :group | :individual,
          destination: KNXex.GroupAddress.t() | KNXex.IndividualAddress.t(),
          value: bitstring()
        }

  @fields [
    :control_field,
    :tpci,
    :apci,
    :source,
    :destination_type,
    :destination,
    :value
  ]
  @enforce_keys @fields
  defstruct @fields
end

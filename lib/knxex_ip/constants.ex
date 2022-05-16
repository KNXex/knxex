defmodule KNXexIP.Constants do
  @moduledoc """
  KNX Constants.
  """

  import KNXexIP.Macro
  @before_compile KNXexIP.Macro

  # Header size 6 for KNXnet/IP protocol version 1.0 Constant
  defconstant(:knx, :header_size_protocol_10, 0x06)
  # KNXnet/IP protocol version 1.0 Constant
  defconstant(:knx, :protocol_version_10, 0x10)

  ###############################

  # Request Type Constants
  defconstant(:request_type, :search_request, 0x201)
  defconstant(:request_type, :search_response, 0x202)
  defconstant(:request_type, :description_request, 0x203)
  defconstant(:request_type, :description_response, 0x204)
  defconstant(:request_type, :connect_request, 0x205)
  defconstant(:request_type, :connect_response, 0x206)
  defconstant(:request_type, :connection_state_request, 0x207)
  defconstant(:request_type, :connection_state_response, 0x208)
  defconstant(:request_type, :disconnect_request, 0x209)
  defconstant(:request_type, :disconnect_response, 0x20A)
  defconstant(:request_type, :device_configuration_request, 0x310)
  defconstant(:request_type, :device_configuration_ack, 0x311)
  defconstant(:request_type, :tunnelling_request, 0x420)
  defconstant(:request_type, :tunnelling_ack, 0x421)
  defconstant(:request_type, :routing_indication, 0x530)
  defconstant(:request_type, :routing_lost_message, 0x531)
  defconstant(:request_type, :routing_busy, 0x532)
  defconstant(:request_type, :remote_diagnostics_request, 0x740)
  defconstant(:request_type, :remote_diagnostics_response, 0x741)
  defconstant(:request_type, :remote_basic_config_request, 0x742)
  defconstant(:request_type, :remote_reset_request, 0x743)

  # The Secure Wrapper wraps a regular KNX frame and contains additional
  # information for security/cryptography
  defconstant(:request_type, :secure_wrapper, 0x950)

  # KNXnet/IP services (tunnelling)
  defconstant(:request_type, :secure_session_request, 0x951)
  defconstant(:request_type, :secure_session_response, 0x952)
  defconstant(:request_type, :secure_session_authenticate, 0x953)
  defconstant(:request_type, :secure_session_status, 0x954)
  defconstant(:request_type, :secure_timer_notify, 0x955)

  # Object Server
  defconstant(:request_type, :object_server, 0xF080)

  ###############################

  # Message Codes Constants
  defconstant(:message_code, :raw_request, 0x10)
  defconstant(:message_code, :data_request, 0x11)
  defconstant(:message_code, :poll_data_request, 0x13)
  defconstant(:message_code, :poll_data_connection, 0x25)
  defconstant(:message_code, :data_indicator, 0x29)
  defconstant(:message_code, :busmon_indicator, 0x2B)
  defconstant(:message_code, :raw_indicator, 0x2D)
  defconstant(:message_code, :data_connection, 0x2E)
  defconstant(:message_code, :raw_connection, 0x2F)
  defconstant(:message_code, :data_connection_request, 0x41)
  defconstant(:message_code, :data_individual_request, 0x4A)
  defconstant(:message_code, :data_connection_indicator, 0x89)
  defconstant(:message_code, :data_individual_indicator, 0x9A)
  defconstant(:message_code, :reset_indicator, 0xF0)
  defconstant(:message_code, :reset_request, 0xF1)
  defconstant(:message_code, :prop_write_connection, 0xF5)
  defconstant(:message_code, :prop_write_request, 0xF6)
  defconstant(:message_code, :prop_info_indicator, 0xF7)
  defconstant(:message_code, :func_prop_com_request, 0xF8)
  defconstant(:message_code, :func_prop_state_read_request, 0xF9)
  defconstant(:message_code, :func_prop_com_connection, 0xFA)
  defconstant(:message_code, :prop_read_connection, 0xFB)
  defconstant(:message_code, :prop_read_request, 0xFC)

  ###############################

  # KNX Protocol Type Constants
  defconstant(:protocol_type, :ipv4_udp, 0x01)
  defconstant(:protocol_type, :ipv4_tcp, 0x02)

  ###############################

  # KNX Medium Type Constants
  defconstant(:medium_type, :reserved, 0x01)
  defconstant(:medium_type, :tp, 0x02)
  defconstant(:medium_type, :pl, 0x04)
  defconstant(:medium_type, :rf, 0x10)
  defconstant(:medium_type, :ip, 0x20)

  ###############################

  # Description Information Block (DIB) Types (used for search request/response, etc.)
  defconstant(:dib_type, :device_info, 0x01)
  defconstant(:dib_type, :supported_svc_families, 0x02)
  defconstant(:dib_type, :ip_config, 0x03)
  defconstant(:dib_type, :ip_cur_config, 0x04)
  defconstant(:dib_type, :knx_addresses, 0x05)
  defconstant(:dib_type, :manufacturer_data, 0xFE)

  ###############################

  # KNXnet/IP Service Family Constants
  defconstant(:service_family, :core_service, 0x02)
  defconstant(:service_family, :device_mgmt_service, 0x03)
  defconstant(:service_family, :tunnelling_service, 0x04)
  defconstant(:service_family, :routing_service, 0x05)

  ###############################

  # Transport Protocol Control Information (TPCI) Constants
  defconstant(:frame_tpci, :unnumbered_data, 0x00)
  defconstant(:frame_tpci, :numbered_data, 0x01)
  defconstant(:frame_tpci, :unnumbered_control, 0x02)
  defconstant(:frame_tpci, :numbered_control, 0x03)

  ###############################

  # Application Protocol Control Information (APCI) Constants
  defconstant(:frame_apci, :group_read, 0x00)
  defconstant(:frame_apci, :group_response, 0x01)
  defconstant(:frame_apci, :group_write, 0x02)

  defconstant(:frame_apci, :individual_write, 0x0C0)
  defconstant(:frame_apci, :individual_read, 0x100)
  defconstant(:frame_apci, :individual_response, 0x140)

  defconstant(:frame_apci, :adc_read, 0x06)
  defconstant(:frame_apci, :adc_response, 0x1C0)

  defconstant(:frame_apci, :sys_net_param_read, 0x1C4)
  defconstant(:frame_apci, :sys_net_param_response, 0x1C9)
  defconstant(:frame_apci, :sys_net_param_write, 0x1CA)

  defconstant(:frame_apci, :memory_read, 0x020)
  defconstant(:frame_apci, :memory_response, 0x024)
  defconstant(:frame_apci, :memory_write, 0x028)

  defconstant(:frame_apci, :user_memory_read, 0x2C0)
  defconstant(:frame_apci, :user_memory_response, 0x2C1)
  defconstant(:frame_apci, :user_memory_write, 0x2C2)

  defconstant(:frame_apci, :user_manufacturer_info_read, 0x2C5)
  defconstant(:frame_apci, :user_manufacturer_info_response, 0x2C6)

  defconstant(:frame_apci, :function_property_command, 0x2C7)
  defconstant(:frame_apci, :function_property_state_read, 0x2C8)
  defconstant(:frame_apci, :function_property_state_response, 0x2C9)

  defconstant(:frame_apci, :device_descriptor_read, 0x300)
  defconstant(:frame_apci, :device_descriptor_response, 0x340)

  defconstant(:frame_apci, :restart, 0x380)
  defconstant(:frame_apci, :escape, 0x3C0)

  defconstant(:frame_apci, :authorize_request, 0x3D1)
  defconstant(:frame_apci, :authorize_response, 0x3D2)

  defconstant(:frame_apci, :key_write, 0x3D3)
  defconstant(:frame_apci, :key_response, 0x3D4)

  defconstant(:frame_apci, :property_value_read, 0x3D5)
  defconstant(:frame_apci, :property_value_response, 0x3D6)
  defconstant(:frame_apci, :property_value_write, 0x3D7)

  defconstant(:frame_apci, :property_description_read, 0x3D8)
  defconstant(:frame_apci, :property_description_response, 0x3D9)

  defconstant(:frame_apci, :network_param_read, 0x3DA)
  defconstant(:frame_apci, :network_param_response, 0x3DB)

  defconstant(:frame_apci, :individual_serial_num_read, 0x3DC)
  defconstant(:frame_apci, :individual_serial_num_response, 0x3DD)
  defconstant(:frame_apci, :individual_serial_num_write, 0x3DF)

  defconstant(:frame_apci, :domain_write, 0x3E0)
  defconstant(:frame_apci, :domain_read, 0x3E1)
  defconstant(:frame_apci, :domain_response, 0x3E2)
  defconstant(:frame_apci, :domain_selective_read, 0x3E3)

  defconstant(:frame_apci, :network_param_write, 0x3E4)

  defconstant(:frame_apci, :link_read, 0x3E5)
  defconstant(:frame_apci, :link_response, 0x3E6)
  defconstant(:frame_apci, :link_write, 0x3E7)

  defconstant(:frame_apci, :group_prop_value_read, 0x3E8)
  defconstant(:frame_apci, :group_prop_value_response, 0x3E9)
  defconstant(:frame_apci, :group_prop_value_write, 0x3EA)
  defconstant(:frame_apci, :group_prop_value_info, 0x3EB)

  defconstant(:frame_apci, :domain_serial_num_read, 0x3EC)
  defconstant(:frame_apci, :domain_serial_num_response, 0x3ED)
  defconstant(:frame_apci, :domain_serial_num_write, 0x3EE)
  defconstant(:frame_apci, :filesystem_info, 0x3F0)

  ###############################
end

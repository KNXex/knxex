defmodule KNXex.DIB do
  @moduledoc """
  KNX Data Information Block (DIB).

  Implements parsing/decoding of DIBs.
  """

  alias KNXex
  alias KNXex.Constants
  alias KNXex.DIB
  alias KNXex.PID.IPAssignmentMethod

  require Constants

  @typedoc """
  Data Information Block.

  Always a two-item tuple, with the first item being the DIB identifier and the second item being the DIB data.
  """
  @type dib ::
          {:device_info, DIB.DeviceInfo.t()}
          | {:supported_svc_families, [{service_family_name(), version :: integer()}]}
          | {:ip_config, DIB.IPConfig.t()}
          | {:ip_cur_config, DIB.IPConfig.t()}
          | {:knx_addresses,
             {KNXex.IndividualAddress.t(), additional :: [KNXex.IndividualAddress.t()]}}
          | {:manufacturer_data, binary()}

  @typedoc """
  Service Family name.
  """
  @type service_family_name() ::
          :search_request
          | :search_response
          | :description_request
          | :description_response
          | :connect_request
          | :connect_response
          | :connectionstate_request
          | :connectionstate_response
          | :disconnect_request
          | :disconnect_response
          | :device_configuration_request
          | :device_configuration_ack
          | :tunneling_request
          | :tunneling_ack
          | :routing_indication
          | :routing_lost_message

  @doc """
  Parses the DIBs from the given binary DIB data.
  """
  @spec parse(bitstring()) :: [dib()]
  def parse(dib) when is_bitstring(dib) do
    parse_dib(dib)
  end

  @doc """
  Encodes a single DIB into a binary.
  """
  @spec encode(dib()) :: binary()
  def encode({name, _any} = dib) when is_atom(name) do
    bindib = encode_dib(dib)
    dib_length = byte_size(bindib)

    <<dib_length::size(8), bindib::binary>>
  end

  ##### Decoders/Parsers #####

  @spec parse_dib(bitstring()) :: [dib()]
  defp parse_dib(
         <<dib_length::size(8), Constants.macro_by_name(:dib_type, :device_info)::size(8),
           dib::binary-size(dib_length)-unit(8), rest_dib::binary>>
       ) do
    device_info = parse_device_info(dib)

    [{:device_info, device_info} | parse_dib(rest_dib)]
  end

  defp parse_dib(
         <<dib_length::size(8),
           Constants.macro_by_name(:dib_type, :supported_svc_families)::size(8),
           dib::binary-size(dib_length)-unit(8), rest_dib::binary>>
       ) do
    supp_svc_families = parse_supported_svc_families(dib)

    [{:supported_svc_families, supp_svc_families} | parse_dib(rest_dib)]
  end

  defp parse_dib(
         <<dib_length::size(8), Constants.macro_by_name(:dib_type, :ip_config)::size(8),
           dib::binary-size(dib_length)-unit(8), rest_dib::binary>>
       ) do
    ip_config = parse_ip_config(dib)

    [{:ip_config, ip_config} | parse_dib(rest_dib)]
  end

  defp parse_dib(
         <<dib_length::size(8), Constants.macro_by_name(:dib_type, :ip_cur_config)::size(8),
           dib::binary-size(dib_length)-unit(8), rest_dib::binary>>
       ) do
    ip_config = parse_ip_config(dib)

    cur_ip_config = %DIB.IPConfig{
      ip_config
      | # ip_capabilities byte is in "ip_cur_config" ip_assignment_method
        # and the following byte is always 0 (reserved field for future)
        ip_capabilities: 0,
        ip_assignment_method: IPAssignmentMethod.to_atom(ip_config.ip_capabilities)
    }

    [{:ip_cur_config, cur_ip_config} | parse_dib(rest_dib)]
  end

  defp parse_dib(
         <<dib_length::size(8), Constants.macro_by_name(:dib_type, :knx_addresses)::size(8),
           dib::binary-size(dib_length)-unit(8), rest_dib::binary>>
       ) do
    knx_addresses = parse_knx_addresses(dib)

    [{:knx_addresses, knx_addresses} | parse_dib(rest_dib)]
  end

  defp parse_dib(
         <<dib_length::size(8), Constants.macro_by_name(:dib_type, :manufacturer_data)::size(8),
           mfc_data::binary-size(dib_length)-unit(8), rest_dib::binary>>
       ) do
    [{:manufacturer_data, mfc_data} | parse_dib(rest_dib)]
  end

  defp parse_dib(_rest) do
    []
  end

  @spec parse_device_info(bitstring()) :: DIB.DeviceInfo.t()
  defp parse_device_info(
         <<knx_medium::size(8), device_status::size(8), individual_address::size(16),
           project_installation_id::size(16), serialnum::size(48),
           dev_routing_multicast_ip::size(32), mac_addr::size(48),
           device_name::binary-size(30)-unit(8)>>
       ) do
    %DIB.DeviceInfo{
      # Trim NULL-characters
      name: String.trim(device_name, <<0>>),
      status: device_status,
      medium: Constants.by_value(:medium_type, knx_medium),
      address: KNXex.IndividualAddress.from_raw_address(individual_address),
      project_installation_id: project_installation_id,
      serialnum: serialnum,
      multicast_ip: DIB.IPConfig.integer_to_inet(dev_routing_multicast_ip),
      mac_addr: :binary.bin_to_list(<<mac_addr::size(48)>>)
    }
  end

  @spec parse_supported_svc_families(bitstring()) :: [
          {service_family_name(), version :: integer()}
        ]
  defp parse_supported_svc_families(<<family::size(8), version::size(8), rest::binary>>) do
    [{Constants.by_name(:service_family, family), version} | parse_supported_svc_families(rest)]
  end

  defp parse_supported_svc_families(_rest) do
    []
  end

  @spec parse_ip_config(bitstring()) :: DIB.IPConfig.t()
  defp parse_ip_config(
         <<ip::size(32), netmask::size(32), gateway::size(32), ip_capabilities::size(8),
           ip_assignment_method::size(8)>>
       ) do
    %DIB.IPConfig{
      ip_address: DIB.IPConfig.integer_to_inet(ip),
      netmask: DIB.IPConfig.integer_to_inet(netmask),
      gateway: DIB.IPConfig.integer_to_inet(gateway),
      ip_capabilities: ip_capabilities,
      ip_assignment_method: IPAssignmentMethod.to_atom(ip_assignment_method)
    }
  end

  @spec parse_knx_addresses(bitstring()) ::
          {KNXex.IndividualAddress.t(), additional :: [KNXex.IndividualAddress.t()]}
  defp parse_knx_addresses(<<address::size(16), rest::binary>>) do
    {KNXex.IndividualAddress.from_raw_address(address), parse_additional_knx_addresses(rest)}
  end

  defp parse_additional_knx_addresses(<<address::size(16), rest::binary>>) do
    [KNXex.IndividualAddress.from_raw_address(address) | parse_additional_knx_addresses(rest)]
  end

  defp parse_additional_knx_addresses(_rest) do
    []
  end

  ##### Encoders #####

  defp encode_dib({:device_info, %DIB.DeviceInfo{} = device_info}) do
    # String must be null terminated and max 30 in length (must be 30 in length)
    device_name = String.pad_trailing(String.slice(device_info.name, 0, 29), 30, <<0>>)

    <<Constants.macro_by_name(:dib_type, :device_info)::size(8),
      Constants.by_name(:medium_type, device_info.medium)::size(8), device_info.status::size(8),
      KNXex.IndividualAddress.to_raw_address(device_info.address)::size(16),
      device_info.project_installation_id::size(16), device_info.serialnum::size(48),
      DIB.IPConfig.inet_to_integer(device_info.multicast_ip)::size(32),
      device_info.mac_addr::size(48), device_name::binary-size(30)-unit(8)>>
  end

  defp encode_dib({:supported_svc_families, svc_families}) when is_list(svc_families) do
    dib =
      Enum.reduce(svc_families, <<>>, fn {name, version}, acc ->
        service_family = Constants.by_name(:service_family, name)
        <<acc::binary, service_family::size(8), version::size(8)>>
      end)

    <<Constants.macro_by_name(:dib_type, :supported_svc_families)::size(8), dib::binary>>
  end

  defp encode_dib({:ip_config, %DIB.IPConfig{} = ip_config}) do
    <<Constants.macro_by_name(:dib_type, :ip_config)::size(8),
      DIB.IPConfig.inet_to_integer(ip_config.ip_address)::size(32),
      DIB.IPConfig.inet_to_integer(ip_config.netmask)::size(32),
      DIB.IPConfig.inet_to_integer(ip_config.gateway)::size(32),
      ip_config.ip_capabilities::size(8),
      IPAssignmentMethod.to_integer(ip_config.ip_assignment_method)::size(8)>>
  end

  defp encode_dib({:ip_cur_config, %DIB.IPConfig{} = ip_config}) do
    <<Constants.macro_by_name(:dib_type, :ip_cur_config)::size(8),
      DIB.IPConfig.inet_to_integer(ip_config.ip_address)::size(32),
      DIB.IPConfig.inet_to_integer(ip_config.netmask)::size(32),
      DIB.IPConfig.inet_to_integer(ip_config.gateway)::size(32),
      IPAssignmentMethod.to_integer(ip_config.ip_assignment_method)::size(8), 0::size(8)>>
  end

  defp encode_dib({:knx_addresses, {knx_addresses, add_knx_addresses}}) do
    <<Constants.macro_by_name(:dib_type, :knx_addresses)::size(8),
      KNXex.IndividualAddress.to_raw_address(knx_addresses.address)::size(16),
      encode_additional_knx_addresses(add_knx_addresses)::binary>>
  end

  defp encode_dib({:manufacturer_data, mfc_data}) do
    <<Constants.macro_by_name(:dib_type, :manufacturer_data)::size(8), mfc_data::binary>>
  end

  defp encode_additional_knx_addresses([address | tail]) do
    <<KNXex.IndividualAddress.to_raw_address(address)::size(16),
      encode_additional_knx_addresses(tail)::binary>>
  end

  defp encode_additional_knx_addresses([]) do
    <<>>
  end
end

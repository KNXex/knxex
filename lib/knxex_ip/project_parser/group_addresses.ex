# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
defmodule KNXexIP.ProjectParser.GroupAddresses do
  @moduledoc false

  alias KNXexIP
  import KNXexIP.ProjectParser.Macros

  #########################
  # Parse Group Addresses #
  #########################

  @doc false
  @spec __before_compile__(any()) :: Macro.t()
  defmacro __before_compile__(_env) do
    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote location: :keep do
      @spec parse_group_ranges(term(), KNXexIP.EtsProject.t(), map()) ::
              KNXexIP.EtsProject.t()
      defp parse_group_ranges(xml_group_ranges, ets_project, opts) do
        Enum.reduce(
          xml_group_ranges,
          ets_project,
          fn
            {:xmlElement, :GroupAddress, :GroupAddress, _list1, _namespace, _list3, _any2,
             xml_attributes, [], _list4, _cwd, _atom},
            acc_ets_project ->
              parse_group_address(xml_attributes, acc_ets_project, opts)

            {:xmlElement, :GroupRange, :GroupRange, _list1, _namespace, _list3, _any2, _attribs,
             xml_subelements, _list4, _cwd, _atom},
            acc_ets_project ->
              parse_group_ranges(xml_subelements, acc_ets_project, opts)

            _any, acc_ets_project ->
              acc_ets_project
          end
        )
      end

      @spec parse_group_address(term(), KNXexIP.EtsProject.t(), map()) ::
              KNXexIP.EtsProject.t()
      defp parse_group_address(xml_group_address, ets_project, opts) do
        base_info =
          Enum.reduce(
            xml_group_address,
            %{id: nil, address: nil, name: nil, type: nil, central: false, unfiltered: false},
            fn
              {:xmlAttribute, :Id, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
              acc ->
                %{acc | id: xml_value_to_string(value)}

              {:xmlAttribute, :Address, _list1, _list2, _list3, _list4, _any1, _list5, value,
               _any2},
              acc ->
                %{acc | address: xml_value_to_int(value)}

              {:xmlAttribute, :Name, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
              acc ->
                %{acc | name: xml_value_to_string(value)}

              {:xmlAttribute, :DatapointType, _list1, _list2, _list3, _list4, _any1, _list5,
               value, _any2},
              acc ->
                %{acc | type: :binary.list_to_bin(value)}

              {:xmlAttribute, :Central, _list1, _list2, _list3, _list4, _any1, _list5, value,
               _any2},
              acc ->
                %{acc | central: xml_value_to_bool(value)}

              {:xmlAttribute, :Unfiltered, _list1, _list2, _list3, _list4, _any1, _list5, value,
               _any2},
              acc ->
                %{acc | unfiltered: xml_value_to_bool(value)}

              _any, acc ->
                acc
            end
          )

        case base_info do
          %{id: nil} ->
            raise "Empty group address ID"

          %{address: nil} ->
            raise "Empty group address address"

          %{name: nil} ->
            raise "Empty group address name"

          _any ->
            # Destruct the address
            <<addr_main::size(5), addr_middle::size(3), addr_sub::size(8)>> =
              <<base_info.address::size(16)>>

            # Convert DPT to something more usable for us X.YYY (X being unpadded)
            dpt_type =
              if base_info.type != nil do
                type =
                  case Regex.scan(~r"DPS?T-(\d+)(?:-(\d+))?", base_info.type) do
                    list when is_list(list) and length(list) > 1 -> tl(list)
                    any -> any
                  end

                case type do
                  [[_full, main, sub]] ->
                    "#{main}.#{String.pad_leading(sub, 3, "0")}"

                  [[_full, main]] ->
                    "#{main}.*"

                  _invalid ->
                    raise "Invalid DPT type #{base_info.type} for group address #{addr_main}/#{addr_middle}/#{addr_sub} (#{base_info.address})"
                end
              end

            info =
              base_info
              |> Map.update!(:id, fn value ->
                Regex.replace(~r"(P-[0-9A-F]{4}-[0-9A-F]_)", value, "")
              end)
              |> Map.put(:type, dpt_type)
              |> Map.put(:address, %KNXexIP.GroupAddress{
                main: addr_main,
                middle: addr_middle,
                sub: addr_sub
              })
              |> KNXexIP.to_struct!(KNXexIP.EtsProject.GroupAddressInfo)

            key_by = opts[:group_addresses_key] || :address

            if key_by != :id and key_by != :address do
              raise "Invalid group addresses key: #{inspect(key_by)}, expected one of: :id, :address"
            end

            ets_project
            |> Map.update!(:group_addresses, fn map ->
              Map.put(
                map,
                if(key_by == :id,
                  do: info.id,
                  else: KNXexIP.GroupAddress.to_string(info.address)
                ),
                info
              )
            end)
            |> KNXexIP.to_struct!(KNXexIP.EtsProject)
        end
      end
    end
  end
end

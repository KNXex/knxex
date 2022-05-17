# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
defmodule KNXex.ProjectParser.Topology do
  @moduledoc false

  alias KNXex
  import KNXex.ProjectParser.Macros

  ###########################################################
  # Parse Topology (Area, Line, Device, Unassigned Devices) #
  ###########################################################

  @doc false
  @spec __before_compile__(any()) :: Macro.t()
  defmacro __before_compile__(_env) do
    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote location: :keep do
      @spec parse_topology(
              term(),
              KNXex.EtsProject.t(),
              non_neg_integer(),
              non_neg_integer(),
              map()
            ) ::
              KNXex.EtsProject.t()
      defp parse_topology(xml_topology, ets_project, parent_area, parent_line, opts) do
        {ets_project, _, _} =
          Enum.reduce(
            xml_topology,
            {ets_project, parent_area, parent_line},
            fn
              {:xmlElement, :UnassignedDevices, UnassignedDevices, _list1, _namespace, _list3,
               _any2, xml_uadev_attributes, xml_uadev_subelements, _list4, _cwd, _atom},
              {acc_ets_project, parent_area, parent_line} ->
                new_ets =
                  case parse_topology_device(
                         xml_uadev_attributes,
                         xml_uadev_subelements,
                         parent_area,
                         parent_line,
                         opts
                       ) do
                    nil ->
                      acc_ets_project

                    device ->
                      acc_ets_project
                      |> Map.update!(:unassigned_devices, fn devices ->
                        [device | devices]
                      end)
                      |> KNXex.to_struct!(KNXex.EtsProject)
                  end

                {new_ets, parent_area, parent_line}

              {:xmlElement, :Area, :Area, _list1, _namespace, _list3, _any2, xml_area_attributes,
               xml_area_subelements, _list4, _cwd, _atom},
              {acc_ets_project, parent_area, parent_line} ->
                {new_ets_project, new_parent_area} =
                  parse_topology_area(xml_area_attributes, acc_ets_project, parent_area, opts)

                new_ets =
                  case xml_area_subelements do
                    [] ->
                      new_ets_project

                    _any ->
                      parse_topology(
                        xml_area_subelements,
                        new_ets_project,
                        new_parent_area,
                        parent_line,
                        opts
                      )
                  end

                {new_ets, new_parent_area, 0}

              {:xmlElement, :Line, :Line, _list1, _namespace, _list3, _any2, xml_line_attributes,
               xml_line_subelements, _list4, _cwd, _atom},
              {acc_ets_project, parent_area, parent_line} ->
                {new_ets_project, new_parent_line} =
                  parse_topology_line(
                    xml_line_attributes,
                    acc_ets_project,
                    parent_area,
                    parent_line,
                    opts
                  )

                new_ets =
                  case xml_line_subelements do
                    [] ->
                      new_ets_project

                    _any ->
                      parse_topology(
                        xml_line_subelements,
                        new_ets_project,
                        parent_area,
                        new_parent_line,
                        opts
                      )
                  end

                {new_ets, parent_area, new_parent_line}

              {:xmlElement, :DeviceInstance, :DeviceInstance, _list1, _namespace, _list3, _any2,
               xml_device_attributes, xml_device_subelements, _list4, _cwd, _atom},
              {acc_ets_project, parent_area, parent_line} ->
                new_ets =
                  parse_topology_line_device(
                    xml_device_attributes,
                    xml_device_subelements,
                    acc_ets_project,
                    parent_area,
                    parent_line,
                    opts
                  )

                {new_ets, parent_area, parent_line}

              _any, acc ->
                acc
            end
          )

        ets_project
      end

      @spec parse_topology_area(
              term(),
              KNXex.EtsProject.t(),
              non_neg_integer(),
              map()
            ) ::
              {KNXex.EtsProject.t(), area_address :: non_neg_integer()}
      defp parse_topology_area(xml_area, ets_project, _parent_area, _opts) do
        base_info =
          Enum.reduce(
            xml_area,
            %{name: nil, address: nil},
            fn
              {:xmlAttribute, :Address, _list1, _list2, _list3, _list4, _any1, _list5, value,
               _any2},
              acc ->
                %{acc | address: xml_value_to_int(value)}

              {:xmlAttribute, :Name, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
              acc ->
                %{acc | name: xml_value_to_string(value)}

              _any, acc ->
                acc
            end
          )

        case base_info do
          %{address: nil} ->
            raise "Empty area address"

          %{name: nil} ->
            raise "Empty area name"

          _any ->
            area = KNXex.to_struct!(base_info, KNXex.EtsProject.Topology.Area)

            new_ets =
              ets_project
              |> Map.update!(:topology, fn map -> Map.put(map, area.address, area) end)
              |> KNXex.to_struct!(KNXex.EtsProject)

            {new_ets, area.address}
        end
      end

      @spec parse_topology_line(
              term(),
              KNXex.EtsProject.t(),
              non_neg_integer(),
              non_neg_integer(),
              map()
            ) ::
              {KNXex.EtsProject.t(), line_address :: non_neg_integer()}
      defp parse_topology_line(xml_line, ets_project, area_address, _line_address, _opts) do
        base_info =
          Enum.reduce(
            xml_line,
            %{name: nil, address: nil, medium_type: :unknown},
            fn
              {:xmlAttribute, :Address, _list1, _list2, _list3, _list4, _any1, _list5, value,
               _any2},
              acc ->
                %{acc | address: xml_value_to_int(value)}

              {:xmlAttribute, :Name, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
              acc ->
                %{acc | name: xml_value_to_string(value)}

              {:xmlAttribute, :MediumTypeRefId, _list1, _list2, _list3, _list4, _any1, _list5,
               value, _any2},
              acc ->
                %{acc | medium_type: parse_medium_type(xml_value_to_string(value))}

              # Catch empty values
              {:xmlAttribute, name, _list1, _list2, _list3, _list4, _any1, _list5, _any2}, acc ->
                # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
                key = String.to_atom(String.downcase("#{name}"))

                if Map.has_key?(acc, key) do
                  Map.put(acc, key, "")
                else
                  acc
                end

              _any, acc ->
                acc
            end
          )

        case base_info do
          %{address: nil} ->
            raise "Empty line address"

          %{name: nil} ->
            raise "Empty line name"

          _any ->
            line =
              base_info
              |> Map.update!(:address, fn line_address -> {area_address, line_address} end)
              |> KNXex.to_struct!(KNXex.EtsProject.Topology.Line)

            new_ets =
              ets_project
              |> Map.update!(:topology, fn map ->
                # map = Map of Topology.Area.t()
                Map.update!(map, area_address, fn area ->
                  # area = Topology.Area.t()
                  area
                  |> Map.update!(:lines, fn area_lines ->
                    # area_lines = Map of Topology.Line.t()
                    Map.put(area_lines, base_info.address, line)
                  end)
                  |> KNXex.to_struct!(KNXex.EtsProject.Topology.Area)
                end)
              end)
              |> KNXex.to_struct!(KNXex.EtsProject)

            {new_ets, base_info.address}
        end
      end

      @spec parse_topology_line_device(
              term(),
              term(),
              KNXex.EtsProject.t(),
              non_neg_integer(),
              non_neg_integer(),
              map()
            ) ::
              KNXex.EtsProject.t()
      defp parse_topology_line_device(
             xml_device_attributes,
             xml_device_subelements,
             ets_project,
             area_address,
             line_address,
             opts
           ) do
        case parse_topology_device(
               xml_device_attributes,
               xml_device_subelements,
               area_address,
               line_address,
               opts
             ) do
          nil ->
            ets_project

          device ->
            # credo:disable-for-lines:24 Credo.Check.Refactor.Nesting
            new_ets =
              ets_project
              |> Map.update!(:topology, fn map ->
                # map = Map of Topology.Area.t()
                Map.update!(map, area_address, fn area ->
                  # area = Topology.Area.t()
                  area
                  |> Map.update!(:lines, fn area_lines ->
                    # area_lines = Map of Topology.Line.t()
                    Map.update!(area_lines, line_address, fn line ->
                      # line = Topology.Line.t()
                      line
                      |> Map.update!(:devices, fn line_devices ->
                        # line_devices = Map of Topology.Device.t()
                        Map.put(line_devices, device.address.device, device)
                      end)
                      |> KNXex.to_struct!(KNXex.EtsProject.Topology.Line)
                    end)
                  end)
                  |> KNXex.to_struct!(KNXex.EtsProject.Topology.Area)
                end)
              end)
              |> KNXex.to_struct!(KNXex.EtsProject)

            new_ets
        end
      end

      @spec parse_topology_device(
              term(),
              term(),
              non_neg_integer(),
              non_neg_integer(),
              map()
            ) :: KNXex.EtsProject.Topology.Device.t() | nil
      defp parse_topology_device(
             xml_device_attributes,
             xml_device_subelements,
             area_address,
             line_address,
             opts
           ) do
        base_info =
          Enum.reduce(
            xml_device_attributes,
            %{
              name: "",
              address: nil,
              description: "",
              comment: "",
              product_refid: "",
              hardware2program_refid: "",
              completion_status: :unknown,
              last_modified: nil,
              last_download: nil,
              device_status: %KNXex.EtsProject.Topology.Device.Status{},
              parameters: %{},
              com_objects: %{}
            },
            fn
              {:xmlAttribute, :Address, _list1, _list2, _list3, _list4, _any1, _list5, value,
               _any2},
              acc ->
                device_address =
                  value
                  |> :binary.list_to_bin()
                  |> String.to_integer()

                address = KNXex.IndividualAddress.make(area_address, line_address, device_address)

                %{acc | address: address}

              {:xmlAttribute, :Name, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
              acc ->
                %{acc | name: xml_value_to_string(value)}

              {:xmlAttribute, :Description, _list1, _list2, _list3, _list4, _any1, _list5, value,
               _any2},
              acc ->
                %{acc | description: xml_value_to_string(value)}

              {:xmlAttribute, :Comment, _list1, _list2, _list3, _list4, _any1, _list5, value,
               _any2},
              acc ->
                %{acc | comment: xml_value_to_string(value)}

              {:xmlAttribute, :ProductRefId, _list1, _list2, _list3, _list4, _any1, _list5, value,
               _any2},
              acc ->
                %{acc | product_refid: xml_value_to_string(value)}

              {:xmlAttribute, :Hardware2ProgramRefId, _list1, _list2, _list3, _list4, _any1,
               _list5, value, _any2},
              acc ->
                %{acc | hardware2program_refid: xml_value_to_string(value)}

              {:xmlAttribute, :CompletionStatus, _list1, _list2, _list3, _list4, _any1, _list5,
               value, _any2},
              acc ->
                %{acc | completion_status: parse_completion_status(xml_value_to_string(value))}

              {:xmlAttribute, :LastModified, _list1, _list2, _list3, _list4, _any1, _list5, value,
               _any2},
              acc ->
                %{acc | last_modified: xml_value_to_ndt(value)}

              {:xmlAttribute, :LastDownload, _list1, _list2, _list3, _list4, _any1, _list5, value,
               _any2},
              acc ->
                %{acc | last_download: xml_value_to_ndt(value)}

              #### Device Status Start ####

              {:xmlAttribute, :ApplicationProgramLoaded, _list1, _list2, _list3, _list4, _any1,
               _list5, value, _any2},
              acc ->
                device_status =
                  acc.device_status
                  |> Map.put(:application_program_loaded, xml_value_to_bool(value))
                  |> KNXex.to_struct!(KNXex.EtsProject.Topology.Device.Status)

                %{acc | device_status: device_status}

              {:xmlAttribute, :CommunicationPartLoaded, _list1, _list2, _list3, _list4, _any1,
               _list5, value, _any2},
              acc ->
                device_status =
                  acc.device_status
                  |> Map.put(:communication_part_loaded, xml_value_to_bool(value))
                  |> KNXex.to_struct!(KNXex.EtsProject.Topology.Device.Status)

                %{acc | device_status: device_status}

              {:xmlAttribute, :IndividualAddressLoaded, _list1, _list2, _list3, _list4, _any1,
               _list5, value, _any2},
              acc ->
                device_status =
                  acc.device_status
                  |> Map.put(:individual_address_loaded, xml_value_to_bool(value))
                  |> KNXex.to_struct!(KNXex.EtsProject.Topology.Device.Status)

                %{acc | device_status: device_status}

              {:xmlAttribute, :MediumConfigLoaded, _list1, _list2, _list3, _list4, _any1, _list5,
               value, _any2},
              acc ->
                device_status =
                  acc.device_status
                  |> Map.put(:medium_config_loaded, xml_value_to_bool(value))
                  |> KNXex.to_struct!(KNXex.EtsProject.Topology.Device.Status)

                %{acc | device_status: device_status}

              {:xmlAttribute, :ParametersLoaded, _list1, _list2, _list3, _list4, _any1, _list5,
               value, _any2},
              acc ->
                device_status =
                  acc.device_status
                  |> Map.put(:parameters_loaded, xml_value_to_bool(value))
                  |> KNXex.to_struct!(KNXex.EtsProject.Topology.Device.Status)

                %{acc | device_status: device_status}

              #### Device Status End ####

              # Catch empty values
              {:xmlAttribute, name, _list1, _list2, _list3, _list4, _any1, _list5, _any2}, acc ->
                # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
                key = String.to_atom(String.downcase("#{name}"))

                if Map.has_key?(acc, key) do
                  Map.put(acc, key, "")
                else
                  acc
                end

              _any, acc ->
                acc
            end
          )

        com_objects =
          if opts[:include_dev_com_objects] do
            parse_topology_device_com_objects(xml_device_subelements, %{})
          else
            %{}
          end

        parameters =
          if opts[:include_dev_parameters] do
            parse_topology_device_parameters(xml_device_subelements, %{})
          else
            %{}
          end

        additional_attributes =
          if opts[:include_dev_add_attributes] do
            parse_topology_device_additional_attributes(xml_device_subelements, %{})
          else
            %{}
          end

        case base_info do
          %{address: nil} ->
            nil

          _any ->
            base_info
            |> Map.put(:com_objects, com_objects)
            |> Map.put(:parameters, parameters)
            |> Map.put(:additional_attributes, additional_attributes)
            |> KNXex.to_struct!(KNXex.EtsProject.Topology.Device)
        end
      end

      @spec parse_topology_device_com_objects(term(), map()) :: map()
      defp parse_topology_device_com_objects(xml_attributes, comobjects_map) do
        case Enum.find_value(xml_attributes, nil, fn
               {:xmlElement, :ComObjectInstanceRefs, :ComObjectInstanceRefs, _list1, _namespace,
                _list2, _any1, _attribs, elements, _list3, _any2, _any3} ->
                 elements

               _any ->
                 false
             end) do
          nil ->
            %{}

          xml_elements ->
            Enum.reduce(xml_elements, comobjects_map, fn
              {:xmlElement, :ComObjectInstanceRef, :ComObjectInstanceRef, _list1, _namespace,
               _list2, _any1, attribs, _elements, _list3, _any2, _any3},
              acc ->
                new_object =
                  parse_device_com_object(
                    attribs,
                    %KNXex.EtsProject.Topology.Device.ComObject{}
                  )

                Map.put(acc, new_object.id, new_object)

              _any, acc ->
                acc
            end)
        end
      end

      @spec parse_device_com_object(term(), map()) ::
              KNXex.EtsProject.Topology.Device.ComObject.t()
      defp parse_device_com_object(xml_attribs, comobjects_map) do
        xml_attribs
        |> Enum.reduce(comobjects_map, fn
          {:xmlAttribute, :RefId, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
          acc ->
            %{acc | id: xml_value_to_string(value)}

          {:xmlAttribute, :Description, _list1, _list2, _list3, _list4, _any1, _list5, value,
           _any2},
          acc ->
            %{acc | description: xml_value_to_string(value)}

          {:xmlAttribute, :Text, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
          acc ->
            %{acc | text: xml_value_to_string(value)}

          {:xmlAttribute, :FunctionText, _list1, _list2, _list3, _list4, _any1, _list5, value,
           _any2},
          acc ->
            %{acc | function_text: xml_value_to_string(value)}

          {:xmlAttribute, :Links, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
          acc ->
            %{acc | links: xml_value_to_string(value)}

          {:xmlAttribute, :DatapointType, _list1, _list2, _list3, _list4, _any1, _list5, value,
           _any2},
          acc ->
            # Convert DPT to something more usable for us X.YYY (X being unpadded)
            dpt_type =
              if value != nil do
                base_type = :binary.list_to_bin(value)

                type =
                  case Regex.scan(~r"DPS?T-(\d+)(?:-(\d+))?", base_type) do
                    list when is_list(list) and length(list) > 1 -> tl(list)
                    any -> any
                  end

                case type do
                  [[_full, main, sub]] ->
                    "#{main}.#{String.pad_leading(sub, 3, "0")}"

                  [[_full, main]] ->
                    "#{main}.*"

                  _invalid ->
                    raise "Invalid DPT type #{base_type} for com object"
                end
              end

            %{acc | dpt: dpt_type}

          {:xmlAttribute, :Priority, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
          acc ->
            %{acc | priority: charlist_to_priority_atom(value)}

          {:xmlAttribute, :CommunicationFlag, _list1, _list2, _list3, _list4, _any1, _list5,
           value, _any2},
          acc ->
            %{acc | communication_flag: charlist_enable_state_to_bool(value)}

          {:xmlAttribute, :ReadFlag, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
          acc ->
            %{acc | read_flag: charlist_enable_state_to_bool(value)}

          {:xmlAttribute, :ReadOnInitFlag, _list1, _list2, _list3, _list4, _any1, _list5, value,
           _any2},
          acc ->
            %{acc | read_on_init_flag: charlist_enable_state_to_bool(value)}

          {:xmlAttribute, :TransmitFlag, _list1, _list2, _list3, _list4, _any1, _list5, value,
           _any2},
          acc ->
            %{acc | transmit_flag: charlist_enable_state_to_bool(value)}

          {:xmlAttribute, :UpdateFlag, _list1, _list2, _list3, _list4, _any1, _list5, value,
           _any2},
          acc ->
            %{acc | update_flag: charlist_enable_state_to_bool(value)}

          {:xmlAttribute, :WriteFlag, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
          acc ->
            %{acc | write_flag: charlist_enable_state_to_bool(value)}

          _any, acc ->
            acc
        end)
        |> KNXex.to_struct!(KNXex.EtsProject.Topology.Device.ComObject)
      end

      @spec parse_topology_device_parameters(term(), map()) :: map()
      defp parse_topology_device_parameters(xml_attributes, parameters_map) do
        case Enum.find_value(xml_attributes, nil, fn
               {:xmlElement, :ParameterInstanceRefs, :ParameterInstanceRefs, _list1, _namespace,
                _list2, _any1, _attribs, elements, _list3, _any2, _any3} ->
                 elements

               _any ->
                 false
             end) do
          nil ->
            %{}

          xml_elements ->
            xml_elements
            |> Enum.reduce(parameters_map, fn
              {:xmlElement, :ParameterInstanceRef, :ParameterInstanceRef, _list1, _namespace,
               _list2, _any1, attribs, _elements, _list3, _any2, _any3},
              acc ->
                new_object =
                  parse_device_parameters(
                    attribs,
                    %{}
                  )

                Map.put(acc, new_object["refid"], new_object["value"])

              _any, acc ->
                acc
            end)
            |> Map.drop([nil])
        end
      end

      @spec parse_device_parameters(term(), map()) :: map()
      defp parse_device_parameters(xml_attribs, parameters_map) do
        xml_attribs
        |> Enum.reduce(parameters_map, fn
          {:xmlAttribute, name, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
          acc ->
            Map.put(acc, String.downcase("#{name}"), xml_value_to_string(value))

          {:xmlAttribute, name, _list1, _list2, _list3, _list4, _any1, _list5, _any2}, acc ->
            Map.put(acc, String.downcase("#{name}"), "")

          _any, acc ->
            acc
        end)
      end

      @spec parse_topology_device_additional_attributes(term(), map()) :: map()
      defp parse_topology_device_additional_attributes(xml_attributes, attribs_map) do
        Enum.reduce(xml_attributes, attribs_map, fn
          # Skip elements we don't want here (in general or we parse them somewhere else)
          {:xmlElement, :ComObjectInstanceRefs, :ComObjectInstanceRefs, _list1, _namespace,
           _list2, _any1, _attribs, _elements, _list3, _any2, _any3},
          acc ->
            acc

          {:xmlElement, :ParameterInstanceRefs, :ParameterInstanceRefs, _list1, _namespace,
           _list2, _any1, _attribs, _elements, _list3, _any2, _any3},
          acc ->
            acc

          {:xmlElement, :GroupObjectTree, :GroupObjectTree, _list1, _namespace, _list2, _any1,
           _attribs, _elements, _list3, _any2, _any3},
          acc ->
            acc

          # Prevent empty additional attributes, they're not useful
          {:xmlElement, name, _name2, _list1, _namespace, _list2, _any1, attribs, elements,
           _list3, _any2, _any3},
          acc
          when attribs != [] or elements != [] ->
            new_attrib = parse_device_additional_attributes(attribs, %{})

            new_attribs_map =
              elements
              |> Enum.reduce({new_attrib, MapSet.new()}, fn
                {:xmlElement, name2, _name2, _list1, _namespace, _list2, _any1, attribs2,
                 elements2, _list3, _any2, _any3},
                {acc, dedup} ->
                  new_object =
                    parse_device_additional_attributes(
                      attribs2,
                      %{}
                    )

                  dedup_key = Macro.underscore("#{name2}")
                  dedup_map(acc, dedup, dedup_key, new_object)

                _any, acc ->
                  acc
              end)
              |> elem(0)

            Map.put(acc, Macro.underscore("#{name}"), new_attribs_map)

          _any, acc ->
            acc
        end)
      end

      defp parse_device_additional_attributes(xml_attribs, attribs_map) do
        xml_attribs
        |> Enum.reduce({attribs_map, MapSet.new()}, fn
          {:xmlAttribute, name, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
          {acc, dedup} ->
            key = Macro.underscore("#{name}")
            str = xml_value_to_string(value)
            dedup_map(acc, dedup, key, str)

          {:xmlAttribute, name, _list1, _list2, _list3, _list4, _any1, _list5, _any2},
          {acc, dedup} = full_acc ->
            key = Macro.underscore("#{name}")

            if Map.has_key?(acc, key) do
              full_acc
            else
              new_map = Map.put(acc, key, "")
              {new_map, dedup}
            end

          _any, acc ->
            acc
        end)
        |> elem(0)
      end

      # Returns the medium type atom for the medium type string from the .knxproj XML
      @spec parse_medium_type(binary()) :: KNXex.EtsProject.medium()
      defp parse_medium_type("MT-0"), do: :tp
      defp parse_medium_type("MT-1"), do: :pl
      defp parse_medium_type("MT-2"), do: :rf
      defp parse_medium_type("MT-5"), do: :ip
      defp parse_medium_type(_any), do: :unknown

      # Deduplicates a map using a MapSet as a deduplication keeper
      @spec dedup_map(map(), MapSet.t(), term(), term()) :: {map(), MapSet.t()}
      defp dedup_map(map, dedup, key, value) do
        if Map.has_key?(map, key) do
          if MapSet.member?(dedup, key) do
            new_map =
              Map.update!(map, key, fn old_value ->
                [value | old_value]
              end)

            {new_map, dedup}
          else
            new_map =
              Map.update!(map, key, fn old_value ->
                [value | [old_value]]
              end)

            new_dedup = MapSet.put(dedup, key)

            {new_map, new_dedup}
          end
        else
          new_map = Map.put(map, key, value)
          {new_map, dedup}
        end
      end

      defp charlist_enable_state_to_bool('Enabled'), do: true
      defp charlist_enable_state_to_bool('enabled'), do: true
      defp charlist_enable_state_to_bool('Disabled'), do: false
      defp charlist_enable_state_to_bool('disabled'), do: false

      defp charlist_to_priority_atom('Alert'), do: :alert
      defp charlist_to_priority_atom('alert'), do: :alert
      defp charlist_to_priority_atom('High'), do: :high
      defp charlist_to_priority_atom('high'), do: :high
      defp charlist_to_priority_atom('Low'), do: :low
      defp charlist_to_priority_atom('low'), do: :low
    end
  end
end

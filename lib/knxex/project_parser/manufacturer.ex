# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
defmodule KNXex.ProjectParser.Manufacturer do
  @moduledoc false

  alias KNXex
  import KNXex.ProjectParser.Macros

  #######################
  # Parse Manufacturers #
  #######################

  @doc false
  @spec __before_compile__(any()) :: Macro.t()
  defmacro __before_compile__(_env) do
    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote location: :keep do
      # acc = %{hardware: map(), application_programs: map()}

      @spec parse_manufacturer(term(), map(), map()) :: map()

      # XML File Hardware.xml
      defp parse_manufacturer(
             {:xmlElement, :Hardware, :Hardware, _list1, _namespace, _list3, _any2, _attribs,
              xml_hardwares, _list4, _cwd, _atom},
             acc,
             opts
           ) do
        xml_hardwares
        |> Enum.reduce(acc.hardware, &parse_manufacturer_hardware(&1, &2, opts))
        |> (&Map.put(acc, :hardware, &1)).()
      end

      # XML File M-[...].xml
      defp parse_manufacturer(
             {:xmlElement, :ApplicationPrograms, :ApplicationPrograms, _list1, _namespace, _list3,
              _any2, _attribs, xml_programs, _list4, _cwd, _atom},
             acc,
             opts
           ) do
        xml_programs
        |> Enum.reduce(acc.application_programs, &parse_manufacturer_app_program(&1, &2, opts))
        |> (&Map.put(acc, :application_programs, &1)).()
      end

      # Catch-all (M-[...].xml contains Languages XML Element we don't support (yet))
      defp parse_manufacturer(_any, acc, _opts), do: acc

      @spec parse_manufacturer_hardware(term(), map(), map()) :: map()
      defp parse_manufacturer_hardware(
             {:xmlElement, :Hardware, :Hardware, _list1, _namespace, _list3, _any2, attribs,
              subelements, _list4, _cwd, _atom},
             hardware_acc,
             opts
           ) do
        hardware = parse_manufacturer_hardware_attribs(attribs)

        {products, hw2prg} =
          Enum.reduce(subelements, {%{}, %{}}, fn
            {:xmlElement, :Products, :Products, _list1, _namespace, _list3, _any2, _attribs,
             products_subs, _list4, _cwd, _atom},
            {_products, hwprg} ->
              {parse_manufacturer_products(products_subs, opts), hwprg}

            {:xmlElement, :Hardware2Programs, :Hardware2Programs, _list1, _namespace, _list3,
             _any2, _attribs, hwprg_subs, _list4, _cwd, _atom},
            {products, _hwprg} ->
              {products, parse_manufacturer_hardware2programs(hwprg_subs, opts)}

            _any, acc ->
              acc
          end)

        hwprod = %KNXex.EtsProject.Manufacturer.Hardware{
          hardware
          | hardware2programs: hw2prg,
            products: products
        }

        Map.put(hardware_acc, hwprod.id, hwprod)
      end

      defp parse_manufacturer_hardware(_any, acc, _opts), do: acc

      @spec parse_manufacturer_hardware_attribs(term()) ::
              KNXex.EtsProject.Manufacturer.Hardware.t()
      defp parse_manufacturer_hardware_attribs(attribs) do
        attribs
        |> Enum.reduce(
          %{
            id: nil,
            name: nil,
            serialnum: nil,
            version: nil,
            bus_current: nil,
            has_individual_address: nil,
            has_application_program: nil,
            is_coupler: nil,
            is_ip_enabled: nil,
            is_power_supply: nil,
            hardware2programs: %{},
            products: %{}
          },
          fn
            {:xmlAttribute, name, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
            acc
            when name in [:Id, :Name] ->
              # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
              key = String.to_atom(String.downcase("#{name}"))

              if Map.has_key?(acc, key) do
                Map.put(acc, key, xml_value_to_string(value))
              else
                acc
              end

            {:xmlAttribute, :SerialNumber, _list1, _list2, _list3, _list4, _any1, _list5, value,
             _any2},
            acc ->
              %{acc | serialnum: xml_value_to_string(value)}

            {:xmlAttribute, :VersionNumber, _list1, _list2, _list3, _list4, _any1, _list5, value,
             _any2},
            acc ->
              %{acc | version: xml_value_to_string(value)}

            {:xmlAttribute, :BusCurrent, _list1, _list2, _list3, _list4, _any1, _list5, value,
             _any2},
            acc ->
              %{acc | bus_current: parse_xml_to_int_float(value)}

            {:xmlAttribute, :HasIndividualAddress, _list1, _list2, _list3, _list4, _any1, _list5,
             value, _any2},
            acc ->
              %{acc | has_individual_address: xml_value_to_bool(value)}

            {:xmlAttribute, :HasApplicationProgram, _list1, _list2, _list3, _list4, _any1, _list5,
             value, _any2},
            acc ->
              %{acc | has_application_program: xml_value_to_bool(value)}

            {:xmlAttribute, :IsCoupler, _list1, _list2, _list3, _list4, _any1, _list5, value,
             _any2},
            acc ->
              %{acc | is_coupler: xml_value_to_bool(value)}

            {:xmlAttribute, :IsIPEnabled, _list1, _list2, _list3, _list4, _any1, _list5, value,
             _any2},
            acc ->
              %{acc | is_ip_enabled: xml_value_to_bool(value)}

            {:xmlAttribute, :IsPowerSupply, _list1, _list2, _list3, _list4, _any1, _list5, value,
             _any2},
            acc ->
              %{acc | is_power_supply: xml_value_to_bool(value)}

            _any, acc ->
              acc
          end
        )
        |> KNXex.to_struct!(KNXex.EtsProject.Manufacturer.Hardware)
      end

      @spec parse_manufacturer_products(term(), map()) :: map()
      defp parse_manufacturer_products(products_subs, _opts) do
        Enum.reduce(products_subs, %{}, fn
          {:xmlElement, :Product, :Product, _list1, _namespace, _list3, _any2, attribs,
           _subelements, _list4, _cwd, _atom},
          acc ->
            prod = parse_manufacturer_product(attribs)
            Map.put(acc, prod.id, prod)

          _any, acc ->
            acc
        end)
      end

      @spec parse_manufacturer_product(term()) :: map()
      defp parse_manufacturer_product(attribs) do
        attribs
        |> Enum.reduce(
          %{
            id: nil,
            text: nil,
            order_number: nil,
            is_rail_mounted: nil,
            hash: nil,
            width: nil
          },
          fn
            {:xmlAttribute, name, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
            acc
            when name in [:Id, :Text, :Hash] ->
              # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
              key = String.to_atom(String.downcase("#{name}"))

              if Map.has_key?(acc, key) do
                Map.put(acc, key, xml_value_to_string(value))
              else
                acc
              end

            {:xmlAttribute, :OrderNumber, _list1, _list2, _list3, _list4, _any1, _list5, value,
             _any2},
            acc ->
              %{acc | order_number: xml_value_to_string(value)}

            {:xmlAttribute, :IsRailMounted, _list1, _list2, _list3, _list4, _any1, _list5, value,
             _any2},
            acc ->
              %{acc | is_rail_mounted: xml_value_to_bool(value)}

            {:xmlAttribute, :WidthInMillimeter, _list1, _list2, _list3, _list4, _any1, _list5,
             value, _any2},
            acc ->
              %{acc | width: parse_xml_to_int_float(value)}

            _any, acc ->
              acc
          end
        )
        |> KNXex.to_struct!(KNXex.EtsProject.Manufacturer.Hardware.Product)
      end

      @spec parse_manufacturer_hardware2programs(term(), map()) :: map()
      defp parse_manufacturer_hardware2programs(hwprg_subs, _opts) do
        Enum.reduce(hwprg_subs, %{}, fn
          {:xmlElement, :Hardware2Program, :Hardware2Program, _list1, _namespace, _list3, _any2,
           attribs, subelements, _list4, _cwd, _atom},
          acc ->
            appprog_refid =
              Enum.find_value(subelements, fn
                {:xmlElement, :ApplicationProgramRef, :ApplicationProgramRef, _list1, _namespace,
                 _list3, _any2, app_attribs, _subelements, _list4, _cwd, _atom} ->
                  Enum.find_value(app_attribs, fn
                    {:xmlAttribute, :RefId, _list1, _list2, _list3, _list4, _any1, _list5, value,
                     _any2} ->
                      :binary.list_to_bin(value)

                    _any ->
                      false
                  end)

                _any ->
                  false
              end)

            prg = parse_manufacturer_hardware2program_mapping(attribs, appprog_refid)
            Map.put(acc, prg.id, prg)

          _any, acc ->
            acc
        end)
      end

      @spec parse_manufacturer_hardware2program_mapping(term(), String.t()) :: map()
      defp parse_manufacturer_hardware2program_mapping(attribs, appprog_refid) do
        attribs
        |> Enum.reduce(
          %{
            id: nil,
            medium_types: [],
            hash: nil,
            application_program_refid: appprog_refid
          },
          fn
            {:xmlAttribute, name, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
            acc
            when name in [:Id, :Hash] ->
              # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
              key = String.to_atom(String.downcase("#{name}"))

              if Map.has_key?(acc, key) do
                Map.put(acc, key, xml_value_to_string(value))
              else
                acc
              end

            {:xmlAttribute, :MediumTypes, _list1, _list2, _list3, _list4, _any1, _list5, value,
             _any2},
            acc ->
              medium =
                value
                |> xml_value_to_string()
                |> String.split(" ")
                |> Enum.map(&parse_medium_type/1)

              %{acc | medium_types: medium}

            _any, acc ->
              acc
          end
        )
        |> KNXex.to_struct!(KNXex.EtsProject.Manufacturer.Hardware.Hardware2Program)
      end

      @spec parse_manufacturer_app_program(term(), map(), map()) :: map()
      defp parse_manufacturer_app_program(
             {:xmlElement, :ApplicationProgram, :ApplicationProgram, _list1, _namespace, _list3,
              _any2, attribs, subelements, _list4, _cwd, _atom},
             app_acc,
             opts
           ) do
        app = parse_manufacturer_app_program_attribs(attribs)

        static_element =
          Enum.find_value(subelements, fn
            {:xmlElement, :Static, :Static, _list1, _namespace, _list3, _any2, _attribs,
             subelements, _list4, _cwd, _atom} ->
              subelements

            _any ->
              false
          end)

        comobjects_element =
          Enum.find_value(static_element, fn
            {:xmlElement, :ComObjectTable, :ComObjectTable, _list1, _namespace, _list3, _any2,
             _attribs, subelements, _list4, _cwd, _atom} ->
              subelements

            _any ->
              false
          end) || []

        app_prg = %KNXex.EtsProject.Manufacturer.ApplicationProgram{
          app
          | com_objects: parse_manufacturer_app_com_objects(comobjects_element, %{}, app.id)
        }

        Map.put(app_acc, app_prg.id, app_prg)
      end

      defp parse_manufacturer_app_program(_any, acc, _opts), do: acc

      @spec parse_manufacturer_app_program_attribs(term()) ::
              KNXex.EtsProject.Manufacturer.ApplicationProgram.t()
      defp parse_manufacturer_app_program_attribs(attribs) do
        attribs
        |> Enum.reduce(
          %{
            id: nil,
            name: nil,
            description: nil,
            app_number: nil,
            app_version: nil,
            program_type: nil,
            mask_version: nil,
            dynamic_table_management: nil,
            linkable: nil,
            hash: nil,
            com_objects: %{}
          },
          fn
            {:xmlAttribute, name, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
            acc
            when name in [:Id, :Name, :Hash] ->
              # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
              key = String.to_atom(String.downcase("#{name}"))

              if Map.has_key?(acc, key) do
                Map.put(acc, key, xml_value_to_string(value))
              else
                acc
              end

            {:xmlAttribute, :VisibleDescription, _list1, _list2, _list3, _list4, _any1, _list5,
             value, _any2},
            acc ->
              %{acc | description: xml_value_to_string(value)}

            {:xmlAttribute, :ApplicationNumber, _list1, _list2, _list3, _list4, _any1, _list5,
             value, _any2},
            acc ->
              %{acc | app_number: xml_value_to_string(value)}

            {:xmlAttribute, :ApplicationVersion, _list1, _list2, _list3, _list4, _any1, _list5,
             value, _any2},
            acc ->
              %{acc | app_version: xml_value_to_string(value)}

            {:xmlAttribute, :ProgramType, _list1, _list2, _list3, _list4, _any1, _list5, value,
             _any2},
            acc ->
              %{acc | program_type: xml_value_to_string(value)}

            {:xmlAttribute, :MaskVersion, _list1, _list2, _list3, _list4, _any1, _list5, value,
             _any2},
            acc ->
              %{acc | mask_version: xml_value_to_string(value)}

            {:xmlAttribute, :DynamicTableManagement, _list1, _list2, _list3, _list4, _any1,
             _list5, value, _any2},
            acc ->
              %{acc | dynamic_table_management: xml_value_to_bool(value)}

            {:xmlAttribute, :Linkable, _list1, _list2, _list3, _list4, _any1, _list5, value,
             _any2},
            acc ->
              %{acc | linkable: xml_value_to_bool(value)}

            _any, acc ->
              acc
          end
        )
        |> KNXex.to_struct!(KNXex.EtsProject.Manufacturer.ApplicationProgram)
      end

      @spec parse_manufacturer_app_com_objects(term(), map(), String.t()) :: map()
      defp parse_manufacturer_app_com_objects(xml_elements, comobjects_map, app_id) do
        Enum.reduce(xml_elements, comobjects_map, fn
          {:xmlElement, :ComObject, :ComObject, _list1, _namespace, _list2, _any1, attribs,
           _elements, _list3, _any2, _any3},
          acc ->
            new_object =
              parse_manufacturer_app_com_object(
                attribs,
                %KNXex.EtsProject.Topology.Device.ComObject{},
                app_id
              )

            Map.put(acc, new_object.id, new_object)

          _any, acc ->
            acc
        end)
      end

      @spec parse_manufacturer_app_com_object(term(), map(), String.t()) ::
              KNXex.EtsProject.Topology.Device.ComObject.t()
      defp parse_manufacturer_app_com_object(xml_attribs, comobjects_map, app_id) do
        xml_attribs
        |> Enum.reduce(comobjects_map, fn
          {:xmlAttribute, :Id, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
          acc ->
            id =
              value
              |> xml_value_to_string()
              |> String.replace(app_id <> "_", "")

            %{acc | id: id}

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

          {:xmlAttribute, :Number, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
          acc ->
            %{acc | number: xml_value_to_int(value)}

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

          {:xmlAttribute, :ObjectSize, _list1, _list2, _list3, _list4, _any1, _list5, value,
           _any2},
          acc ->
            %{acc | object_size: parse_com_object_object_size(value)}

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

      @spec parse_com_object_object_size(charlist()) :: pos_integer()
      defp parse_com_object_object_size('LegacyVarData'), do: nil
      defp parse_com_object_object_size('14 Bytes'), do: 112
      defp parse_com_object_object_size('13 Bytes'), do: 104
      defp parse_com_object_object_size('12 Bytes'), do: 96
      defp parse_com_object_object_size('11 Bytes'), do: 88
      defp parse_com_object_object_size('10 Bytes'), do: 80
      defp parse_com_object_object_size('9 Bytes'), do: 72
      defp parse_com_object_object_size('8 Bytes'), do: 64
      defp parse_com_object_object_size('7 Bytes'), do: 56
      defp parse_com_object_object_size('6 Bytes'), do: 48
      defp parse_com_object_object_size('5 Bytes'), do: 40
      defp parse_com_object_object_size('4 Bytes'), do: 32
      defp parse_com_object_object_size('3 Bytes'), do: 24
      defp parse_com_object_object_size('2 Bytes'), do: 16
      defp parse_com_object_object_size('1 Byte'), do: 8
      defp parse_com_object_object_size('7 Bit'), do: 7
      defp parse_com_object_object_size('6 Bit'), do: 6
      defp parse_com_object_object_size('5 Bit'), do: 5
      defp parse_com_object_object_size('4 Bit'), do: 4
      defp parse_com_object_object_size('3 Bit'), do: 3
      defp parse_com_object_object_size('2 Bit'), do: 2
      defp parse_com_object_object_size('1 Bit'), do: 1

      @spec parse_xml_to_int_float(charlist()) :: integer()
      defp parse_xml_to_int_float(value) do
        xml_value_to_int(value)
      rescue
        ArgumentError ->
          value
          |> :binary.list_to_bin()
          |> String.to_float()
          |> trunc()
      end
    end
  end
end

------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--                    Copyright (C) 2019-2021, AdaCore                      --
--                                                                          --
-- This library is free software;  you can redistribute it and/or modify it --
-- under terms of the  GNU General Public License  as published by the Free --
-- Software  Foundation;  either version 3,  or (at your  option) any later --
-- version. This library is distributed in the hope that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE.                            --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
------------------------------------------------------------------------------

--  This package provides to GPR library the common attributes names
--  and attribute definition accessors.
--  Custom package's attributes definition can be added by custom tools.

with Ada.Containers.Indefinite_Ordered_Maps;
private with Ada.Containers.Ordered_Maps;
with Ada.Strings.Unbounded;

package GPR2.Project.Registry.Attribute is

   type Index_Kind is (No, Yes, Optional);

   type Index_Value_Type is
      (Name_Index,
       File_Index,
       FileGlob_Index,
       Language_Index,
       FileGlob_Or_Language_Index);

   subtype Index_Allowed is Index_Kind range Yes .. Optional;

   type Value_Kind is (Single, List);

   type Empty_Value_Status is (Allow, Ignore, Error);
   --  Allow  : an empty value is allowed for the attribute.
   --  Ignore : an empty value is ignored and reported as warning.
   --  Error  : an empty value is erroneous and reported as error.

   type Qualified_Name (<>) is private;
   --  A qualified name is an attribute name possibly prefixed with a package
   --  name. It is the only way to create a non-ambiguous reference to an
   --  attribute.

   function Create
     (Name : Attribute_Id;
      Pack : Optional_Package_Id := No_Package) return Qualified_Name;
   --  Returns a fully qualified name for the given attribute and package names

   function Image (Name : Qualified_Name) return String;
   --  Returns quailified name image

   type Allowed_In is array (Project_Kind) of Boolean with Pack;

   Everywhere : constant Allowed_In := (others => True);
   Nowhere    : constant Allowed_In := (others => False);

   type Default_Value (Is_Reference : Boolean := False) is record
      case Is_Reference is
         when True =>
            Attr : Attribute_Id;
         when False =>
            Value : Ada.Strings.Unbounded.Unbounded_String;
      end case;
   end record;

   package VSR is new Ada.Containers.Indefinite_Ordered_Maps
     (Name_Type, Default_Value);

   type Def is record
      Index                : Index_Kind         := Optional;
      Others_Allowed       : Boolean            := False;
      Index_Case_Sensitive : Boolean            := False;
      Value                : Value_Kind         := Single;
      Value_Case_Sensitive : Boolean            := False;
      Empty_Value          : Empty_Value_Status := Allow;
      Read_Only            : Boolean            := False;
      Is_Allowed_In        : Allowed_In         := (K_Abstract => True,
                                                    others     => False);
      Default              : VSR.Map;
      Has_Default_In       : Allowed_In         := (others => False);
      Is_Toolchain_Config  : Boolean            := False;
      --  When set, the attribute is used to during the gprconfig stage to
      --  configure toolchains (for example the attributes Target or Runtime
      --  are toolchain config attributes). Due to elaboration constraints,
      --  such attributes need to be global to the project tree, and so
      --  should not be modified after being referenced. So for example
      --  using "for Target use project'Target & "suffix"" is not allowed.
      Config_Concatenable  : Boolean            := False;
      --  When True the final value for the attribute is concatenated with the
      --  value found in the Config project (if it exists) rather than
      --  overriding it.

      Index_Type : Index_Value_Type             := Name_Index;
      --  Set the type for the index value

   end record
     with Dynamic_Predicate =>
       --  Either Index is allowed or the other parts are default
       (Def.Index in Index_Allowed
        or else (not Def.Others_Allowed
                 and then not Def.Index_Case_Sensitive))
     and then
       --  Must be usable somewhere
       Def.Is_Allowed_In /= (Project_Kind => False);

   type Default_Rules is private;

   function Exists (Q_Name : Qualified_Name) return Boolean;
   --  The qualified name comprise the package name and attribute name, both
   --  parts are separated by a dot which is mandatory even if the package
   --  name is empty (for a top level attribute).

   function Get (Q_Name : Qualified_Name) return Def
     with Pre => Exists (Q_Name);
   --  Returns the definition data for the given attribute fully qualified name

   function Get_Default_Rules
     (Pack : Optional_Package_Id) return Default_Rules;
   --  Get default rules by package name. If package name is empty get the root
   --  default rules.

   procedure For_Each_Default
     (Rules  : Default_Rules;
      Action : not null access procedure
        (Attribute : Attribute_Id; Definition : Def));
   --  Call Action routine for each definition with defaults in package.
   --  If Pack is empty, call Action for each root attribute with defaults.

   procedure Add
     (Name                 : Qualified_Name;
      Index                : Index_Kind;
      Others_Allowed       : Boolean;
      Index_Case_Sensitive : Boolean;
      Value                : Value_Kind;
      Value_Case_Sensitive : Boolean;
      Read_Only            : Boolean;
      Is_Allowed_In        : Allowed_In;
      Empty_Value          : Empty_Value_Status := Allow;
      Default              : VSR.Map            := VSR.Empty_Map;
      Has_Default_In       : Allowed_In         := Nowhere;
      Is_Toolchain_Config  : Boolean            := False;
      Config_Concatenable  : Boolean            := False;
      Index_Type           : Index_Value_Type   := Name_Index);
   --  add package/attribute definition in database for attribute checks

   --  Some common attribute names

   Additional_Patterns         : constant Attribute_Id :=
                                   +"additional_patterns";
   ALI_Subdir                  : constant Attribute_Id := +"ali_subdir";
   Active                      : constant Attribute_Id := +"active";
   Archive_Builder             : constant Attribute_Id := +"archive_builder";
   Archive_Builder_Append_Option : constant Attribute_Id :=
                                     +"archive_builder_append_option";
   Archive_Indexer             : constant Attribute_Id := +"archive_indexer";
   Archive_Suffix              : constant Attribute_Id := +"archive_suffix";
   Artifacts                   : constant Attribute_Id := +"artifacts";
   Artifacts_In_Exec_Dir       : constant Attribute_Id :=
                                   +"artifacts_in_exec_dir";
   Artifacts_In_Object_Dir     : constant Attribute_Id :=
                                   +"artifacts_in_object_dir";
   Body_N                      : constant Attribute_Id := +"body";
   Body_Suffix                 : constant Attribute_Id := +"body_suffix";
   Casing                      : constant Attribute_Id := +"casing";
   Canonical_Target            : constant Attribute_Id := +"canonical_target";
   Communication_Protocol      : constant Attribute_Id :=
                                   +"communication_protocol";
   Compiler_Command            : constant Attribute_Id := +"compiler_command";
   Config_Body_File_Name       : constant Attribute_Id :=
                                   +"config_body_file_name";
   Config_Body_File_Name_Index : constant Attribute_Id :=
                                   +"config_body_file_name_index";
   Config_Body_File_Name_Pattern : constant Attribute_Id :=
                                     +"config_body_file_name_pattern";
   Config_File_Switches        : constant Attribute_Id :=
                                   +"config_file_switches";
   Config_File_Unique          : constant Attribute_Id :=
                                   +"config_file_unique";
   Config_Spec_File_Name       : constant Attribute_Id :=
                                   +"config_spec_file_name";
   Config_Spec_File_Name_Index : constant Attribute_Id :=
                                   +"config_spec_file_name_index";
   Config_Spec_File_Name_Pattern : constant Attribute_Id :=
                                     +"config_spec_file_name_pattern";
   Create_Missing_Dirs         : constant Attribute_Id :=
                                   +"create_missing_dirs";
   Database_Directory          : constant Attribute_Id :=
                                   +"database_directory";
   Debugger_Command            : constant Attribute_Id := +"debugger_command";
   Default_Language            : constant Attribute_Id := +"default_language";
   Default_Switches            : constant Attribute_Id := +"default_switches";
   Dependency_Driver           : constant Attribute_Id := +"dependency_driver";
   Dependency_Kind             : constant Attribute_Id := +"dependency_kind";
   Dependency_Switches         : constant Attribute_Id :=
                                   +"dependency_switches";
   Documentation_Dir           : constant Attribute_Id := +"documentation_dir";
   Dot_Replacement             : constant Attribute_Id := +"dot_replacement";
   Driver                      : constant Attribute_Id := +"driver";
   Excluded_Patterns           : constant Attribute_Id := +"excluded_patterns";
   Excluded_Source_Files       : constant Attribute_Id :=
                                   +"excluded_source_files";
   Excluded_Source_Dirs        : constant Attribute_Id :=
                                   +"excluded_source_dirs";
   Excluded_Source_List_File   : constant Attribute_Id :=
                                   +"excluded_source_list_file";
   Exec_Dir                    : constant Attribute_Id := +"exec_dir";
   Exec_Subdir                 : constant Attribute_Id := +"exec_subdir";
   Executable                  : constant Attribute_Id := +"executable";
   Executable_Suffix           : constant Attribute_Id := +"executable_suffix";
   Export_File_Format          : constant Attribute_Id :=
                                   +"export_file_format";
   Export_File_Switch          : constant Attribute_Id :=
                                   +"export_file_switch";
   External                    : constant Attribute_Id := +"external";
   Externally_Built            : constant Attribute_Id := +"externally_built";
   Global_Compilation_Switches : constant Attribute_Id :=
                                   +"global_compilation_switches";
   Global_Config_File          : constant Attribute_Id :=
                                   +"global_config_file";
   Global_Configuration_Pragmas : constant Attribute_Id :=
                                    +"global_configuration_pragmas";
   Gnatlist                    : constant Attribute_Id := +"gnatlist";
   Ignore_Source_Sub_Dirs      : constant Attribute_Id :=
                                   +"ignore_source_sub_dirs";
   Implementation              : constant Attribute_Id := +"implementation";
   Implementation_Exceptions   : constant Attribute_Id :=
                                   +"implementation_exceptions";
   Implementation_Suffix       : constant Attribute_Id :=
                                   +"implementation_suffix";
   Included_Artifacts_Patterns : constant Attribute_Id :=
                                   +"included_artifacts_patterns";
   Included_Patterns           : constant Attribute_Id := +"included_patterns";
   Include_Switches_Via_Spec   : constant Attribute_Id :=
                                   +"include_switches_via_spec";
   Include_Path                : constant Attribute_Id := +"include_path";
   Include_Path_File           : constant Attribute_Id := +"include_path_file";
   Include_Switches            : constant Attribute_Id := +"include_switches";
   Included_Artifact_Patterns  : constant Attribute_Id :=
                                   +"included_artifact_patterns";
   Inherit_Source_Path         : constant Attribute_Id :=
                                   +"inherit_source_path";
   Install_Name                : constant Attribute_Id := +"install_name";
   Install_Project             : constant Attribute_Id := +"install_project";
   Interfaces                  : constant Attribute_Id := +"interfaces";
   Languages                   : constant Attribute_Id := +"languages";
   Language_Kind               : constant Attribute_Id := +"language_kind";
   Leading_Library_Options     : constant Attribute_Id :=
                                   +"leading_library_options";
   Leading_Required_Switches   : constant Attribute_Id :=
                                   +"leading_required_switches";
   Leading_Switches            : constant Attribute_Id := +"leading_switches";
   Lib_Subdir                  : constant Attribute_Id := +"lib_subdir";
   Library_Ali_Dir             : constant Attribute_Id := +"library_ali_dir";
   Library_Auto_Init           : constant Attribute_Id := +"library_auto_init";
   Library_Auto_Init_Supported : constant Attribute_Id :=
                                   +"library_auto_init_supported";
   Library_Dir                 : constant Attribute_Id := +"library_dir";
   Library_Builder             : constant Attribute_Id := +"library_builder";
   Library_Encapsulated_Options : constant Attribute_Id :=
                                    +"library_encapsulated_options";
   Library_Encapsulated_Supported : constant Attribute_Id :=
                                      +"library_encapsulated_supported";
   Library_Gcc                 : constant Attribute_Id := +"library_gcc";
   Library_Install_Name_Option : constant Attribute_Id :=
                                   +"library_install_name_option";
   Library_Interface           : constant Attribute_Id := +"library_interface";
   Library_Kind                : constant Attribute_Id := +"library_kind";
   Library_Major_Minor_Id_Supported : constant Attribute_Id :=
                                        +"library_major_minor_id_supported";
   Library_Name                : constant Attribute_Id := +"library_name";
   Library_Options             : constant Attribute_Id := +"library_options";
   Library_Partial_Linker      : constant Attribute_Id :=
                                   +"library_partial_linker";
   Library_Reference_Symbol_File : constant Attribute_Id :=
                                     +"library_reference_symbol_file";
   Library_Rpath_Options       : constant Attribute_Id :=
                                   +"library_rpath_options";
   Library_Src_Dir             : constant Attribute_Id := +"library_src_dir";
   Library_Standalone          : constant Attribute_Id :=
                                   +"library_standalone";
   Library_Support             : constant Attribute_Id := +"library_support";
   Library_Symbol_File         : constant Attribute_Id :=
                                   +"library_symbol_file";
   Library_Symbol_Policy       : constant Attribute_Id :=
                                   +"library_symbol_policy";
   Library_Version             : constant Attribute_Id := +"library_version";
   Library_Version_Switches    : constant Attribute_Id :=
                                   +"library_version_switches";
   Link_Lib_Subdir             : constant Attribute_Id := +"link_lib_subdir";
   Linker_Options              : constant Attribute_Id := +"linker_options";
   Locally_Removed_Files       : constant Attribute_Id :=
                                   +"locally_removed_files";
   Local_Config_File           : constant Attribute_Id := +"local_config_file";
   Local_Configuration_Pragmas : constant Attribute_Id :=
                                   +"local_configuration_pragmas";
   Main                        : constant Attribute_Id := +"main";
   Map_File_Option             : constant Attribute_Id := +"map_file_option";
   Mapping_Body_Suffix         : constant Attribute_Id :=
                                   +"mapping_body_suffix";
   Mapping_File_Switches       : constant Attribute_Id :=
                                   +"mapping_file_switches";
   Mapping_Spec_Suffix         : constant Attribute_Id :=
                                   +"mapping_spec_suffix";
   Max_Command_Line_Length     : constant Attribute_Id :=
                                   +"max_command_line_length";
   Message_Patterns            : constant Attribute_Id := +"message_patterns";
   Mode                        : constant Attribute_Id := +"mode";
   Multi_Unit_Object_Separator : constant Attribute_Id :=
                                   +"multi_unit_object_separator";
   Multi_Unit_Switches         : constant Attribute_Id :=
                                   +"multi_unit_switches";
   Name                        : constant Attribute_Id := +"name";
   Object_Dir                  : constant Attribute_Id := +"object_dir";
   Object_File_Suffix          : constant Attribute_Id :=
                                   +"object_file_suffix";
   Object_Generated            : constant Attribute_Id := +"object_generated";
   Objects_Linked              : constant Attribute_Id := +"objects_linked";
   Object_Lister               : constant Attribute_Id := +"object_lister";
   Object_Lister_Matcher       : constant Attribute_Id :=
                                   +"object_lister_matcher";
   Object_Artifact_Extensions  : constant Attribute_Id :=
                                   +"object_artifact_extensions";
   Object_File_Switches        : constant Attribute_Id :=
                                   +"object_file_switches";
   Object_Path_Switches        : constant Attribute_Id :=
                                   +"object_path_switches";
   Objects_Path                : constant Attribute_Id := +"objects_path";
   Objects_Path_File           : constant Attribute_Id := +"objects_path_file";
   Origin_Project              : constant Attribute_Id := +"origin_project";
   Only_Dirs_With_Sources      : constant Attribute_Id :=
                                   +"only_dirs_with_sources";
   Output_Directory            : constant Attribute_Id := +"output_directory";
   Path_Syntax                 : constant Attribute_Id := +"path_syntax";
   Pic_Option                  : constant Attribute_Id := +"pic_option";
   Prefix                      : constant Attribute_Id := +"prefix";
   Program_Host                : constant Attribute_Id := +"program_host";
   Project_Dir                 : constant Attribute_Id := +"project_dir";
   Project_Files               : constant Attribute_Id := +"project_files";
   Project_Path                : constant Attribute_Id := +"project_path";
   Project_Subdir              : constant Attribute_Id := +"project_subdir";
   Required_Artifacts          : constant Attribute_Id :=
                                   +"required_artifacts";
   Remote_Host                 : constant Attribute_Id := +"remote_host";
   Required_Switches           : constant Attribute_Id := +"required_switches";
   Required_Toolchain_Version  : constant Attribute_Id :=
                                   +"required_toolchain_version";
   Response_File_Format        : constant Attribute_Id :=
                                   +"response_file_format";
   Response_File_Switches      : constant Attribute_Id :=
                                   +"response_file_switches";
   Root_Dir                    : constant Attribute_Id := +"root_dir";
   Roots                       : constant Attribute_Id := +"roots";
   Run_Path_Option             : constant Attribute_Id := +"run_path_option";
   Run_Path_Origin             : constant Attribute_Id := +"run_path_origin";
   Runtime                     : constant Attribute_Id := +"runtime";
   Runtime_Dir                 : constant Attribute_Id := +"runtime_dir";
   Runtime_Library_Dir         : constant Attribute_Id :=
                                   +"runtime_library_dir";
   Runtime_Source_Dir          : constant Attribute_Id :=
                                   +"runtime_source_dir";
   Runtime_Source_Dirs         : constant Attribute_Id :=
                                   +"runtime_source_dirs";
   Separate_Suffix             : constant Attribute_Id := +"separate_suffix";
   Separate_Run_Path_Options   : constant Attribute_Id :=
                                   +"separate_run_path_options";
   Shared_Library_Minimum_Switches : constant Attribute_Id :=
                                       +"shared_library_minimum_switches";
   Shared_Library_Prefix       : constant Attribute_Id :=
                                   +"shared_library_prefix";
   Shared_Library_Suffix       : constant Attribute_Id :=
                                   +"shared_library_suffix";
   Side_Debug                  : constant Attribute_Id := +"side_debug";
   Source_Artifact_Extensions  : constant Attribute_Id :=
                                   +"source_artifact_extensions";
   Source_Dirs                 : constant Attribute_Id := +"source_dirs";
   Source_Files                : constant Attribute_Id := +"source_files";
   Source_File_Switches        : constant Attribute_Id :=
                                   +"source_file_switches";
   Source_List_File            : constant Attribute_Id := +"source_list_file";
   Sources_Subdir              : constant Attribute_Id := +"sources_subdir";
   Spec                        : constant Attribute_Id := +"spec";
   Spec_Suffix                 : constant Attribute_Id := +"spec_suffix";
   Specification               : constant Attribute_Id := +"specification";
   Specification_Exceptions    : constant Attribute_Id :=
                                   +"specification_exceptions";
   Specification_Suffix        : constant Attribute_Id :=
                                   +"specification_suffix";
   Symbolic_Link_Supported     : constant Attribute_Id :=
                                   +"symbolic_link_supported";
   Switches                    : constant Attribute_Id := +"switches";
   Target                      : constant Attribute_Id := +"target";
   Toolchain_Version           : constant Attribute_Id := +"toolchain_version";
   Toolchain_Name              : constant Attribute_Id := +"toolchain_name";
   Toolchain_Description       : constant Attribute_Id :=
                                   +"toolchain_description";
   Toolchain_Path              : constant Attribute_Id := +"toolchain_path";
   Trailing_Required_Switches  : constant Attribute_Id :=
                                   +"trailing_required_switches";
   Trailing_Switches           : constant Attribute_Id := +"trailing_switches";
   Vcs_File_Check              : constant Attribute_Id := +"vcs_file_check";
   Vcs_Kind                    : constant Attribute_Id := +"vcs_kind";
   Vcs_Log_Check               : constant Attribute_Id := +"vcs_log_check";
   Warning_Message             : constant Attribute_Id := +"warning_message";

private

   type Qualified_Name is record
      Pack : Optional_Package_Id;
      Attr : Attribute_Id;
   end record;

   function Image (Name : Qualified_Name) return String is
     (if Name.Pack = No_Package
      then Image (Name.Attr)
      else Image (Name.Pack) & "'" & Image (Name.Attr));

   function "<" (Left, Right : Qualified_Name) return Boolean is
     (if Left.Pack /= Right.Pack then Left.Pack < Right.Pack
      else Left.Attr < Right.Attr);

   package Attribute_Definitions is new Ada.Containers.Ordered_Maps
     (Qualified_Name, Def);

   type Def_Access is access constant Def;

   package Default_References is new Ada.Containers.Ordered_Maps
     (Attribute_Id, Def_Access);
   --  To keep references only to attribute definitions with default rules

   type Default_Rules is access constant Default_References.Map;

end GPR2.Project.Registry.Attribute;

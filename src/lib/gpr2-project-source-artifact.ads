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

--  The artifacts that are generated by the compilation of a source file of a
--  given project.

with Ada.Containers.Ordered_Maps;

with GPR2.Path_Name.Set;
with GPR2.Project.Source;

package GPR2.Project.Source.Artifact is

   type Artifact_Category is
     (Object_File_Artifact,
      Dependency_File_Artifact,
      Callgraph_Artifact,
      Switches_Artifact,
      Preprocessed_Source_Artifact,
      Coverage_Artifact);

   type Artifact_Filter is array (Artifact_Category) of Boolean;
   All_Artifacts : constant Artifact_Filter := (others => True);

   type Object is tagged private;

   Undefined : constant Object;
   --  This constant is equal to any object declared without an explicit
   --  initializer.

   type Dependency_Location is (In_Library, In_Objects, In_Both);
   --  Kind of the dependency files location.
   --  The Ada dependency files can be either in object durectory or/and
   --  in Library directory.

   function Is_Defined (Self : Object) return Boolean;
   --  Returns true if Self is defined

   function Create
     (Source     : Project.Source.Object;
      Force_Spec : Boolean := False;
      Filter     : Artifact_Filter := All_Artifacts) return Artifact.Object
     with Pre => Source.Is_Defined;
   --  Constructor for Object defining the artifacts for the given Source.
   --  Force_Spec is for the case when specification has implementation part
   --  but artefact names need to be created from specification base name. It
   --  is necessary when body and spec have different base names due to naming
   --  exception and gprinstall installing only specifications with -m option.

   function Source (Self : Object) return Project.Source.Object
     with Pre => Self.Is_Defined;
   --  The project's source used to generate the artifacts

   function Has_Object_Code
     (Self : Object; Index : Natural := 0) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True if an object-code path is defined at Index.
   --  If Index = 0 returns True on any object file defined.

   function Object_Code
     (Self : Object; Index : Natural) return GPR2.Path_Name.Object
     with Pre => Self.Is_Defined and then Self.Has_Object_Code (Index);
   --  The target-dependent code (generally .o or .obj).
   --  If Index = 0 then returns first available object file path.

   function Has_Dependency
     (Self     : Object;
      Index    : Natural             := 0;
      Location : Dependency_Location := In_Both) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True if a dependency path is defined.
   --  The Location parameter defines are we looking for dependency files in
   --  the object directory, library directory, or in both directories.
   --  If Index = 0 returns True if dependency exists at any index.

   function Dependency
     (Source      : Project.Source.Object;
      Index       : Natural := 0;
      Location    : Dependency_Location := In_Both;
      Actual_File : Boolean := False)
      return GPR2.Path_Name.Object;
   --  Retrieve just the dependency file (LI file) corresponding to the unit
   --- in Source at Index (if any).
   --  This file can be searched in Library_ALI_Dir or Object_Dir or in both,
   --  this is specified by the location parameter.
   --  If Actual_File is set, then only files that actually exist on the hard
   --  drive are returned. else file that could exist if a compilation occurred
   --  will also be returned, even if they're not available.

   function Dependency
     (Self        : Object;
      Index       : Natural;
      Location    : Dependency_Location := In_Both)
      return GPR2.Path_Name.Object
     with Pre  => Self.Is_Defined
                  and then Self.Has_Dependency (Index, Location),
          Post => Dependency'Result.Is_Defined;
   --  A file containing information (.ali for GNAT, .d for GCC) like
   --  cross-reference, units used by the source, etc.
   --  The Location parameter defines are we looking for dependency files in
   --  the object directory, library directory, or in both directories.
   --  In case of Location = In_Both, the returning priority is for existing
   --  files. If Index = 0 returns dependency with first available index.

   function Has_Preprocessed_Source (Self : Object) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True if a preprocessed-source is defined

   function Preprocessed_Source (Self : Object) return GPR2.Path_Name.Object
     with Pre => Self.Is_Defined and then Self.Has_Preprocessed_Source;
   --  Returns the file containing the pre-processed source

   function Has_Callgraph (Self : Object) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True if a callgraph is defined

   function Callgraph (Self : Object) return GPR2.Path_Name.Object
     with Pre => Self.Is_Defined and then Self.Has_Callgraph;
   --  Returns the callgraph file

   function Has_Coverage (Self : Object) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True if a coverage is defined

   function Coverage (Self : Object) return GPR2.Path_Name.Object
     with Pre => Self.Is_Defined and then Self.Has_Coverage;
   --  Returns the coverage file

   function List (Self : Object) return GPR2.Path_Name.Set.Object
     with Pre => Self.Is_Defined;
   --  Returns all artifacts

   function List_To_Clean (Self : Object) return GPR2.Path_Name.Set.Object
     with Pre => Self.Is_Defined;
   --  Returns artifacts for gprclean

private

   use type GPR2.Path_Name.Object;

   package Index_Path_Name_Map is new Ada.Containers.Ordered_Maps
     (Positive, GPR2.Path_Name.Object);

   type Object is tagged record
      Source           : Project.Source.Object;
      Object_Files     : Index_Path_Name_Map.Map;
      Deps_Lib_Files   : Index_Path_Name_Map.Map;
      Deps_Obj_Files   : Index_Path_Name_Map.Map;
      Callgraph        : GPR2.Path_Name.Object;
      Switches         : GPR2.Path_Name.Object;
      Preprocessed_Src : GPR2.Path_Name.Object;
      Coverage         : GPR2.Path_Name.Object;
   end record;

   Undefined : constant Object := (others => <>);

   function Is_Defined (Self : Object) return Boolean is
     (Self /= Undefined);

   function Has_Object_Code
     (Self : Object; Index : Natural := 0) return Boolean
   is
     (if Index = 0
      then not Self.Object_Files.Is_Empty
      else Self.Object_Files.Contains (Index));

   function Has_Preprocessed_Source (Self : Object) return Boolean is
     (Self.Preprocessed_Src.Is_Defined);

   function Has_Callgraph (Self : Object) return Boolean is
     (Self.Callgraph.Is_Defined);

   function Has_Coverage (Self : Object) return Boolean is
     (Self.Coverage.Is_Defined);

end GPR2.Project.Source.Artifact;

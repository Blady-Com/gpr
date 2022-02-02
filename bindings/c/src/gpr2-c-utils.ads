------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--                     Copyright (C) 2022, AdaCore                          --
--                                                                          --
-- This is  free  software;  you can redistribute it and/or modify it under --
-- terms of the  GNU  General Public License as published by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for more details.  You should have received  a copy of the  GNU  --
-- General Public License distributed with GNAT; see file  COPYING. If not, --
-- see <http://www.gnu.org/licenses/>.                                      --
--                                                                          --
------------------------------------------------------------------------------

--  High level Ada interface to GPR2 library. The goal is to ease writting of
--  the C binding and JSON translation

with GPR2.Context;
with GPR2.Containers;
with GPR2.Path_Name.Set;
with GPR2.Project.Source;
with GPR2.Project.Source.Set;
with GPR2.Project.Tree;
with GPR2.Project.View;
with GPR2.Project.View.Vector;
with GPR2.Project.Variable;
with GPR2.Project.Attribute_Index;
with GPR2.Project.Attribute;
with GPR2.Project.Registry.Attribute;
with GPR2.Project.Unit_Info;
with GPR2.Project.Unit_Info.Set;
with GPR2.Source_Reference;
with GPR2.Message;

package GPR2.C.Utils is

   Empty_String : constant String := "";

   -----------------
   -- GPR_Context --
   -----------------

   --  Contains the list of external variables along with their values. Mainly
   --  used to load a GPR_Tree with the right context.

   subtype GPR_Context is GPR2.Context.Object;

   Empty_Context : constant GPR_Context := GPR2.Context.Empty;

   procedure Set_External_Variable
     (Ctx : in out GPR_Context; Name : String; Value : String) with
      Pre => Name'Length > 0;
   --  Update context Ctx by adding variable Name and set its value to Value.
   --  If Name is already part of the context then its value is replaced.

   procedure Delete_External_Variable
     (Ctx : in out GPR_Context; Name : String) with
      Pre => Name'Length > 0;
   --  Remove variable Name from the context Ctx. If the variable is not
   --  present do nothing.

   --------------
   -- GPR_Path --
   --------------

   subtype GPR_Path is GPR2.Path_Name.Object;

   subtype GPR_Paths is GPR2.Path_Name.Set.Object;

   No_Paths : constant GPR_Paths := GPR2.Path_Name.Set.Empty_Set;

   procedure Add_Path (Paths : in out GPR_Paths; Path : String) with
      Pre => Path'Length > 0;
      --  Append a Path to Paths

   ------------------
   -- GPR_Runtimes --
   ------------------

   subtype GPR_Runtimes is GPR2.Containers.Lang_Value_Map;

   No_Runtimes : constant GPR_Runtimes :=
     GPR2.Containers.Lang_Value_Maps.Empty_Map;

   procedure Set_Runtime
     (Runtimes : in out GPR_Runtimes; Language : String; Runtime : String);
   --  Set Runtime for a given language

   subtype GPR_Tree is GPR2.Project.Tree.Object;

   subtype GPR_View is GPR2.Project.View.Object;

   Undefined_View : constant GPR_View := GPR2.Project.View.Undefined;

   subtype GPR_Views is GPR2.Project.View.Vector.Object;

   subtype GPR_Source is GPR2.Project.Source.Object;

   subtype GPR_Sources is GPR2.Project.Source.Set.Object;

   subtype GPR_Unit_Info is GPR2.Project.Unit_Info.Object;

   subtype GPR_Unit_Infos is GPR2.Project.Unit_Info.Set.Object;

   subtype GPR_Source_Reference is GPR2.Source_Reference.Object;

   --  Project paths. By default GPR2 looks into default project paths defined
   --  by the GPR_PROJECT_PATH_FILE, GPR_PROJECT_PATH and ADA_PROJECT_PATH.

   procedure Prepend_Search_Path (Tree : in out GPR_Tree; Path : String);
   --  Prepend a gpr project file search path. This function should be called
   --  before calling Load_Project.

   function Search_Paths (Tree : GPR_Tree) return GPR_Paths;
   --  Return the final list of PATH GPR2 is looking into

   procedure Load_Project
     (Tree             : in out GPR_Tree;
      Filename         : String;
      Context          : GPR_Context  := Empty_Context;
      Build_Path       : String       := Empty_String;
      Subdirs          : String       := Empty_String;
      Src_Subdirs      : String       := Empty_String;
      Project_Dir      : String       := Empty_String;
      Check_Shared_Lib : Boolean      := True;
      Absent_Dir_Error : Boolean      := False;
      Implicit_With    : GPR_Paths    := No_Paths;
      Config           : String       := Empty_String;
      Target           : String       := Empty_String;
      Runtimes         : GPR_Runtimes := No_Runtimes);

   function Root_View (Tree : GPR_Tree) return GPR_View;

   function Runtime_View (Tree : GPR_Tree) return GPR_View;

   function Archive_Suffix (Tree : GPR_Tree) return String;

   function Target (Tree : GPR_Tree) return String;

   procedure Update_Source_List (Tree : GPR_Tree);
   --  Update the source list associated with the tree.

   procedure Update_Source_Infos
     (Tree : GPR_Tree; Allow_Source_Parsing : Boolean := False);
   --  Update depencies informations associated with each source in the project
   --  tree. By default only use information generated by the compilers
   --  (.ali, .d, ...). If Allow_Source_Parsing is set to True then attempt to
   --  parse directly the sources for some languages.

   -------------------
   -- View Handling --
   -------------------

   function Get_View (Tree : GPR_Tree; Id : String) return GPR_View;
   --  Return view associated with Id in Tree.

   function Source (View : GPR_View; Path : String) return GPR_Source;
   --  Return GPR_Source for source in View located at Path

   function Library_Filename (View : GPR_View) return String;

   ----------------------
   --  Source Handling --
   ----------------------

   subtype Unit_Index is GPR2.Unit_Index;

   No_Unit_Index : constant Unit_Index := GPR2.No_Index;

   procedure Update_Source_Infos
     (Source : in out GPR_Source; Allow_Source_Parsing : Boolean := False);
   --  Update source information such as dependencies. If Allow_Source_Parsing
   --  is set to True then if available a source parser may be used in case no
   --  LI file is found (.ali, .d, ...).

   function Dependencies
     (Source : GPR_Source; Closure : Boolean := False) return GPR_Sources;
   --  Return the list of dependencies for the given Source. If Closure is set
   --  to False only direct dependencies are returned. Otherwise the full
   --  closure is returned.

   function Object_File
     (Source : GPR_Source; Index : Unit_Index := No_Unit_Index) return String;

   function Dependency_File
     (Source : GPR_Source; Index : Unit_Index := No_Unit_Index) return String;

   function Coverage_File (Source : GPR_Source) return String;

   function Callgraph_File (Source : GPR_Source) return String;

   subtype Project_Variable is GPR2.Project.Variable.Object;

   ------------------------
   -- Attribute Handling --
   ------------------------

   Invalid_Attribute : exception;

   subtype GPR_Attribute is GPR2.Project.Attribute.Object;

   type Index_Type is private;

   No_Index : constant Index_Type;

   function Language (Name : String) return Index_Type;
   --  Use a language (not case-sensitive) as index

   function Filename
     (Name : String; Position : Unit_Index := No_Unit_Index) return Index_Type;
   --  Use a filename as index

   function Name (Name : String) return Index_Type;
   --  Use a name (case-sensitive) as index

   Single_Value : constant GPR2.Project.Registry.Attribute.Value_Kind :=
     GPR2.Project.Registry.Attribute.Single;

   List_Value : constant GPR2.Project.Registry.Attribute.Value_Kind :=
     GPR2.Project.Registry.Attribute.List;

   function Attribute
     (View  : GPR_View;
      Name  : String;
      Pkg   : String     := Empty_String;
      Index : Index_Type := No_Index)
      return GPR_Attribute;
   --  Get the final attribute value for a given index

   subtype GPR_Message is GPR2.Message.Object;

private

   type Index_Kind is (Null_Index, Filename_Index, Language_Index, Name_Index);

   type Index_Type (Kind : Index_Kind := Filename_Index) is record
      GPR2_Index : GPR2.Project.Attribute_Index.Object;
      Position   : Unit_Index := No_Unit_Index;
   end record;

   No_Index : constant Index_Type :=
     (Kind => Null_Index, GPR2_Index => GPR2.Project.Attribute_Index.Undefined,
      Position => No_Unit_Index);

end GPR2.C.Utils;

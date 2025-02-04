--
--  Copyright (C) 2022, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0
--

with Ada.Containers.Indefinite_Ordered_Maps;

with GPR2.Path_Name;
with GPR2.Project.View;

package GPR2.Build.Compilation_Unit is

   type Unit_Location is record
      View  : Project.View.Object;
      Path  : Path_Name.Object;
      Index : Unit_Index := No_Index;
   end record;
   --  Identifies the location of a Unit (spec/body or separate)

   package Separate_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (Name_Type, Unit_Location);

   No_Unit : constant Unit_Location := (others => <>);

   type Object is tagged private;

   Undefined : constant Object;

   function Create (Name : Name_Type) return Object;
   --  Create a new compilation unit object with name Name

   function Is_Defined (Self : Object) return Boolean;
   --  Whether Self is defined

   function Is_Empty (Self : Object) return Boolean;
   --  False if compilation unit has any unit

   function Name (Self : Object) return Name_Type
     with Pre => Self.Is_Defined;

   function Has_Part
     (Self : Object;
      Kind : Unit_Kind) return Boolean
     with Pre => Self.Is_Defined;
   --  Whether a unit with Kind is defined for Self

   procedure Add
     (Self     : in out Object;
      Kind     : Unit_Kind;
      View     : GPR2.Project.View.Object;
      Path     : GPR2.Path_Name.Object;
      Index    : Unit_Index := No_Index;
      Sep_Name : Optional_Name_Type := "")
     with Pre => Self.Is_Defined
                   and then (Sep_Name'Length = 0) = (Kind /= S_Separate);

   function Get
     (Self     : Object;
      Kind     : Unit_Kind;
      Sep_Name : Optional_Name_Type) return Unit_Location
     with Pre => Self.Is_Defined
                   and then (Sep_Name'Length = 0) = (Kind /= S_Separate);

   procedure Remove
     (Self     : in out Object;
      Kind     : Unit_Kind;
      Sep_Name : Optional_Name_Type := "")
     with Pre => Self.Is_Defined
                   and then (Sep_Name'Length = 0) = (Kind /= S_Separate);

   function Spec (Self : Object) return Unit_Location
     with Pre => Self.Is_Defined and then Self.Has_Part (S_Spec);
   --  Returns the spec for the compilation unit

   function Main_Body (Self : Object) return Unit_Location
     with Pre => Self.Is_Defined and then Self.Has_Part (S_Body);
   --  Returns the body for the compilation unit. Note: body being a keyword
   --  we can't name the function "Body"

   function Separates (Self : Object) return Separate_Maps.Map
     with Pre => Self.Is_Defined and then Self.Has_Part (S_Separate);
   --  Returns the list of separates for this compilation unit, indexed by
   --  their identifiers relative to the compilation unit.

   function Main_Part (Self : Object) return Unit_Location
     with Pre => Self.Is_Defined
                  and then (Self.Has_Part (S_Spec)
                            or else Self.Has_Part (S_Body));
   --  Returns the body of the compilation unit if it exists, or the spec

   procedure Update_Spec
     (Self  : in out Object;
      View  : Project.View.Object;
      Path  : Path_Name.Object;
      Index : Unit_Index := No_Index)
     with Pre => Self.Is_Defined;

   procedure Update_Body
     (Self  : in out Object;
      View  : Project.View.Object;
      Path  : Path_Name.Object;
      Index : Unit_Index := No_Index)
     with Pre => Self.Is_Defined;

   procedure Add_Separate
     (Self  : in out Object;
      Name  : Name_Type;
      View  : Project.View.Object;
      Path  : Path_Name.Object;
      Index : Unit_Index := No_Index)
     with Pre => Self.Is_Defined;

   procedure Remove_Spec (Self : in out Object)
     with Pre => Self.Is_Defined and then Self.Has_Part (S_Spec);

   procedure Remove_Body (Self : in out Object)
     with Pre => Self.Is_Defined and then Self.Has_Part (S_Body);

   procedure Remove_Separate
     (Self : in out Object;
      Name : Name_Type)
     with Pre => Self.Is_Defined and then Self.Has_Part (S_Separate);

   procedure For_All_Part
     (Self : Object;
      Action : access procedure
        (Kind     : Unit_Kind;
         View     : Project.View.Object;
         Path     : Path_Name.Object;
         Index    : Unit_Index;
         Sep_Name : Optional_Name_Type))
     with Pre => Self.Is_Defined;
   --  Execute Action for all parts of the given compilation unit

   function Object_File (Self : Object) return Simple_Name;
   --  Returns the .o's simple name for Self.

private

   type Object is tagged record
      Name      : Unbounded_String;
      Spec      : Unit_Location;
      Implem    : Unit_Location;
      Separates : Separate_Maps.Map;
   end record;

   Undefined : constant Object := (others => <>);

   function Is_Defined (Self : Object) return Boolean is
      (Self /= Undefined);

   function Is_Empty (Self : Object) return Boolean is
     (Self.Spec = No_Unit
      and then Self.Implem = No_Unit
      and then Self.Separates.Is_Empty);

   function Name (Self : Object) return Name_Type is
     (Name_Type (-Self.Name));

   function Has_Part
     (Self : Object;
      Kind : Unit_Kind) return Boolean
   is (case Kind is
          when S_Spec => Self.Spec /= No_Unit,
          when S_Body => Self.Implem /= No_Unit,
          when S_Separate => not Self.Separates.Is_Empty);

   function Spec (Self : Object) return Unit_Location is
     (Self.Spec);

   function Main_Body (Self : Object) return Unit_Location is
     (Self.Implem);

   function Separates (Self : Object) return Separate_Maps.Map is
     (Self.Separates);

   function Main_Part (Self : Object) return Unit_Location is
     (if Self.Implem /= No_Unit then Self.Implem else Self.Spec);

end GPR2.Build.Compilation_Unit;

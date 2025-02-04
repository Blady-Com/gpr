--
--  Copyright (C) 2022, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0
--

with Ada.Calendar;
with Ada.Iterator_Interfaces;

private with Ada.Containers.Indefinite_Ordered_Maps;

with GPR2.Path_Name;
with GPR2.Project.View;
with GPR2.Source_Reference.Value;

package GPR2.Build.Source_Info is

   use type Ada.Containers.Count_Type;

   type Naming_Exception_Kind is (No, Yes, Multi_Unit);
   --  How source has been found:
   --  No: via naming schema
   --  Yes: via naming exception, no index
   --  Multi_Unit: naming exceptions with unit index

   subtype Naming_Exception_Value is
     Naming_Exception_Kind range Yes .. Multi_Unit;

   ----------------------
   -- UNITS IN SOURCES --
   ----------------------

   --  The handling of units is pretty complex due to the various situations
   --  we have and the data we need to cross-check. So here's a summary:
   --
   --  Sources can have no units (most languages don't have this notion).
   --  Ada can have multi-units (several units in a file).
   --  The GNAT standard is one unit per file.
   --
   --  Now a compilation unit is composed of several units: optional spec,
   --  optional body, optional separates. There's one object file generated
   --  per compilation unit, so one dependency file.
   --
   --  So one compilation unit has several units, one source has 1 to several
   --  units.
   --
   --  To handle all this:
   --  ??? continue design comment

   type Unit_Part (Name_Len     : Positive;
                   Separate_Len : Natural)
   is record
      Kind           : Build.Unit_Kind := S_Spec;
      --  Kind of unit
      Kind_Ambiguous : Boolean := False;
      --  Set to True when the kind of unit cannot be fully determined.
      --  In particular, in many situations we can't differentiate body and
      --  separates without parsing either the source or the dependencies
      --  information.
      Index          : Unit_Index;
      --  In case of multi-unit source, the index of the unit, else No_Index
      Unit_Name      : Name_Type (1 .. Name_Len);
      --  The compilation unit name
      Separate_Name  : Optional_Name_Type (1 .. Separate_Len);
      --  In case Kind is S_Separate, the name of the subunit (without the
      --  compilation unit name part).
   end record;
   --  Structure used to describe the unit(s) contained in the source.
   --  The corresponding Compilation Unit can be retrieved from the main
   --  tree_db object.

   function Create
     (Unit_Name      : Name_Type;
      Index          : Unit_Index;
      Kind           : Unit_Kind;
      Kind_Ambiguous : Boolean;
      Separate_Name  : Optional_Name_Type := No_Name) return Unit_Part;

   type Unit_List is tagged private
     with Constant_Indexing => Constant_Reference,
          Variable_Indexing => Reference,
          Default_Iterator  => Iterate,
          Iterator_Element  => Unit_Part;
   --  The list is used to store units. It handles single unit and multi-unit
   --  cases.

   Empty_List : constant Unit_List;

   function Is_Empty (Self : Unit_List) return Boolean;
   --  True if Self has no units

   function Length (Self : Unit_List) return Natural;
   --  Number of units in Self

   function Element
     (Self  : Unit_List;
      Index : Unit_Index) return Unit_Part;
   --  Get a single unit

   procedure Insert
     (Self    : in out Unit_List;
      Element : Unit_Part);

   type Cursor is private;

   No_Element : constant Cursor;

   function Has_Element (Position : Cursor) return Boolean;
   function Element (Position : Cursor) return Unit_Part;

   type Reference_Type (Element : not null access Unit_Part) is private
   with Implicit_Dereference => Element;

   type Constant_Reference_Type (Element : not null access constant Unit_Part)
   is private with Implicit_Dereference => Element;

   function Constant_Reference
     (Self     : aliased Unit_List;
      Position : Cursor) return Constant_Reference_Type;
   function Constant_Reference
     (Self     : aliased Unit_List;
      Position : Unit_Index) return Constant_Reference_Type;

   function Reference
     (Self     : aliased in out Unit_List;
      Position : Cursor) return Reference_Type;
   function Reference
     (Self     : aliased in out Unit_List;
      Position : Unit_Index) return Reference_Type;

   package Unit_Iterators is
     new Ada.Iterator_Interfaces (Cursor, Has_Element);

   function Iterate
     (Self : Unit_List) return Unit_Iterators.Forward_Iterator'Class;

   type Object is tagged private;
   --  Source_Info represents the data computed from the source filename and
   --  the project view only: in particular unit(s) and kind information come
   --  from naming schema and naming exceptions.
   --
   --  For Ada. it should be noted that the default naming schema is ambiguous,
   --  so the kind of unit can't be fully trusted (it can be a body or a
   --  separate).
   --  Unit names are also tentative names, deduced from the filename. As this
   --  relationship between filename and unit name, and can be very wrong
   --  in particular, but not only, if the filename is krunched.
   --  Naming exceptions give normally the good unit names, but they can also
   --  have typos, that are hard to report to the user.
   --
   --  Only the Object_Info object (so after parsing the ALI or the source)
   --  give correct results.

   Undefined : constant Object;

   function Is_Defined (Self : Object) return Boolean;
   --  Returns True if Self is defined

   function Create
     (Filename         : GPR2.Path_Name.Object;
      Language         : Language_Id;
      Kind             : Unit_Kind;
      Timestamp        : Ada.Calendar.Time;
      View             : GPR2.Project.View.Object;
      Naming_Exception : Naming_Exception_Kind;
      Source_Ref       : Source_Reference.Value.Object;
      Aggregated       : Project.View.Object := Project.View.Undefined)
      return Object
     with Pre  => Filename.Is_Defined and then Language /= Ada_Language,
          Post => Create'Result.Is_Defined;
   --  Constructor for a non-Ada source object

   function Create_Ada
     (Filename         : GPR2.Path_Name.Object;
      Timestamp        : Ada.Calendar.Time;
      View             : GPR2.Project.View.Object;
      Naming_Exception : Naming_Exception_Kind;
      Source_Ref       : Source_Reference.Value.Object;
      Units            : Unit_List'Class;
      Aggregated       : Project.View.Object := Project.View.Undefined)
      return Object
     with Pre  => Filename.Is_Defined,
          Post => Create_Ada'Result.Is_Defined;
   --  Constructor for a Ada source object. The unit information is added
   --  later via Add_Unit below.

   procedure Add_Unit
     (Self  : in out Object;
      Unit  : Unit_Part)
     with Pre => Self.Is_Defined
                   and then Self.Language = Ada_Language
                   and then not Self.Has_Unit_At (Unit.Index);

   procedure Update_Unit
     (Self  : in out Object;
      Unit  : Unit_Part)
     with Pre => Self.Is_Defined
                   and then Self.Language = Ada_Language
                   and then Self.Has_Unit_At (Unit.Index);

   function Path_Name (Self : Object) return GPR2.Path_Name.Object
     with Pre => Self.Is_Defined;
   --  Returns the path-name for the given source

   function Modification_Time
     (Self       : Object;
      ALI_Format : Boolean := False) return Ada.Calendar.Time
     with Inline, Pre => Self.Is_Defined;
   --  Returns last modification of the source file from the time point when
   --  the last successful build was done.
   --  If ALI_Format is set, the returned value is adjusted to match the
   --  ALI files time precision.

   procedure Update_Modification_Time
     (Self : in out Object;
      Time : Ada.Calendar.Time);
   --  Update the source modification time field.

   function Copy
     (Self    : Object;
      To_View : Project.View.Object) return Object
     with Pre => Self.Is_Defined and then To_View.Is_Defined;
   --  Copy Self, changing the owning view to To_View, in case of source
   --  inheritance.

   function Language (Self : Object) return Language_Id
     with Pre => Self.Is_Defined;
   --  Returns the language of the source

   function Has_Units (Self : Object) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True if source is unit-based (i.e. Ada)

   function Kind
     (Self  : Object;
      Index : Unit_Index := No_Index) return Unit_Kind
     with Pre => Self.Is_Defined
                 and then (not Self.Has_Units
                           or else Self.Has_Unit_At (Index))
                 and then (Self.Has_Units or else Index = No_Index);
   --  Returns the kind of Self's source at the given index

   function Has_Unit_At
     (Self : Object; Index : Unit_Index) return Boolean
     with Pre => Self.Is_Defined and then Self.Has_Units;
   --  Returns True if Self has a compilation unit at Index

   function Has_Single_Unit (Self : Object) return Boolean
     with Pre => Self.Is_Defined and then Self.Has_Units;
   --  Returns true if the source contains a single unit

   function Has_Index (Self : Object) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True if source contains one or more units declared in Naming
   --  package with "at" Index.

   function Unit (Self  : Object;
                  Index : Unit_Index := No_Index) return Unit_Part
     with Pre => Self.Is_Defined
                   and then Self.Has_Units and then Self.Has_Unit_At (Index);
   --  Return the unit object at specified index (use No_Index if the source
   --  is a single unit source.

   function Units (Self : Object) return Unit_List'Class
     with Inline,
          Pre  => Self.Is_Defined and then Self.Has_Units,
          Post => Units'Result.Length > 1
                  or else Self.Has_Single_Unit;
   --  Returns all compilation units for self

   --  function Is_Implementation_Required
   --    (Self : Object; Index : Unit_Index) return Boolean
   --    with Pre => Self.Is_Defined
   --                and then Self.Has_Unit_At (Index);
   --  Returns True if the source for the implementation is required for the
   --  compilation. This is the case for a generic package or a package having
   --  inlined routines.

   --  function Is_Aggregated (Self : Object) return Boolean
   --    with Pre => Self.Is_Defined;
   --  Returns True if the source is taken into aggregating library source set
   --  from the aggregated project.

   --  function Aggregated (Self : Object) return Project.View.Object
   --    with Pre  => Self.Is_Defined;
   --  The view where the source is aggregated from

   function Has_Naming_Exception (Self : Object) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns whether the source comes from a naming exception

   function Naming_Exception (Self : Object) return Naming_Exception_Kind
     with Pre  => Self.Is_Defined;
   --  Returns whether the source comes from a naming exception

   function Source_Reference
     (Self : Object) return Source_Reference.Value.Object
     with Pre => Self.Is_Defined;

private

   function Create
     (Unit_Name      : Name_Type;
      Index          : Unit_Index;
      Kind           : Unit_Kind;
      Kind_Ambiguous : Boolean;
      Separate_Name  : Optional_Name_Type := No_Name) return Unit_Part
   is (Name_Len       => Unit_Name'Length,
       Separate_Len   => Separate_Name'Length,
       Kind           => Kind,
       Kind_Ambiguous => Kind_Ambiguous,
       Index          => Index,
       Unit_Name      => Name_Type (Ada.Characters.Handling.To_Upper
                                      (String (Unit_Name))),
       Separate_Name  => Optional_Name_Type
                           (Ada.Characters.Handling.To_Upper
                              (String (Separate_Name))));

   package Unit_Map is new Ada.Containers.Indefinite_Ordered_Maps
     (Unit_Index, Unit_Part);

   type Reference_Type (Element : not null access Unit_Part) is record
      Ref : Unit_Map.Reference_Type (Element);
   end record;

   type Constant_Reference_Type (Element : not null access constant Unit_Part)
   is record
      Ref : Unit_Map.Constant_Reference_Type (Element);
   end record;

   type Unit_List is tagged record
      Has_Index : Boolean := False;
      Units     : Unit_Map.Map;
   end record;

   type Cursor is new Unit_Map.Cursor;

   Empty_List : constant Unit_List := (others => <>);
   No_Element : constant Cursor := Cursor (Unit_Map.No_Element);

   function Is_Empty (Self : Unit_List) return Boolean
   is (Self.Units.Is_Empty);

   function Length (Self : Unit_List) return Natural
   is (Natural (Self.Units.Length));

   function Element (Self  : Unit_List;
                     Index : Unit_Index) return Unit_Part
   is (Self.Units.Element (Index));

   overriding function Has_Element (Position : Cursor) return Boolean
   is (Unit_Map.Has_Element (Unit_Map.Cursor (Position)));

   overriding function Element (Position : Cursor) return Unit_Part
   is (Unit_Map.Element (Unit_Map.Cursor (Position)));

   function To_ALI_Timestamp (Stamp : Calendar.Time) return Calendar.Time;

   type Object is tagged record
      View              : Project.View.Object;
      --  View that owns the source
      Path_Name         : GPR2.Path_Name.Object;
      --  Source path
      Modification_Time : Calendar.Time := No_Time;
      --  Source file modification time
      Language          : Language_Id   := No_Language;
      --  Source's language
      Kind              : Unit_Kind := S_Separate;
      --  Source library unit kind in case the language is not unit-based
      CU_List           : Unit_List;
      --  Source's units in case of unit-based language
      Aggregated        : Project.View.Object;
      --  View where the source is aggregated from
      Inherited         : Boolean := False;
      --  Whether the source has been inherited by project extension
      Naming_Exception  : Naming_Exception_Kind := No;
      --  Whether a naming exception concerns this source
      SR                : GPR2.Source_Reference.Value.Object;
      --  The value of Source_Dirs responsible for loading this value
   end record;

   Undefined : constant Object := (others => <>);

   function Is_Defined (Self : Object) return Boolean is (Self /= Undefined);

   function Modification_Time
     (Self       : Object;
      ALI_Format : Boolean := False) return Ada.Calendar.Time
   is (if ALI_Format then To_ALI_Timestamp (Self.Modification_Time)
       else Self.Modification_Time);

   function Path_Name (Self : Object) return GPR2.Path_Name.Object is
     (Self.Path_Name);

   function Has_Units (Self : Object) return Boolean is
     (Self.Language = Ada_Language);
   --  For now, only supported language defining compilation units is Ada

   function Has_Single_Unit (Self : Object) return Boolean is
     (Self.CU_List.Length = 1);

   function Has_Index (Self : Object) return Boolean is
     (Self.CU_List.Has_Index);

   function Language (Self : Object) return Language_Id is
     (Self.Language);

   function Units (Self : Object) return Unit_List'Class is
     (Self.CU_List);

   function Unit (Self  : Object;
                  Index : Unit_Index := No_Index) return Unit_Part
   is (Self.CU_List.Element (Index));

   --  function Aggregated (Self : Object) return Project.View.Object is
   --    (Self.Aggregated);
   --
   --  function Is_Aggregated (Self : Object) return Boolean is
   --    (Self.Aggregated.Is_Defined);
   --
   function Has_Naming_Exception (Self : Object) return Boolean is
     (Self.Naming_Exception in Naming_Exception_Value);

   function Naming_Exception (Self : Object) return Naming_Exception_Kind is
     (Self.Naming_Exception);

   function Source_Reference
     (Self : Object) return GPR2.Source_Reference.Value.Object is
      (Self.SR);
end GPR2.Build.Source_Info;

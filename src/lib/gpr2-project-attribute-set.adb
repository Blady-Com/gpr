------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--                       Copyright (C) 2019, AdaCore                        --
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

with Ada.Characters.Handling;
with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;

with GPR2.Project.Definition;

package body GPR2.Project.Attribute.Set is

   package RA renames Registry.Attribute;

   type Iterator is new Attribute_Iterator.Forward_Iterator with record
      Name          : Unbounded_String;
      Index         : Unbounded_String;
      Set           : Object;
      With_Defaults : Boolean := False;
   end record;

   overriding function First
     (Iter : Iterator) return Cursor;

   overriding function Next
     (Iter : Iterator; Position : Cursor) return Cursor;

   function Is_Matching
     (Iter : Iterator'Class; Position : Cursor) return Boolean
     with Pre => Has_Element (Position);
   --  Returns True if the current Position is matching the Iterator

   procedure Set_Defaults
     (Self      : in out Object;
      Kind      : Project_Kind;
      Pack      : Optional_Name_Type;
      Languages : Containers.Source_Value_List);
   --  Set defaults for the attribute set

   -----------
   -- Clear --
   -----------

   procedure Clear (Self : in out Object) is
   begin
      Self.Attributes.Clear;
      Self.Length := 0;
   end Clear;

   ------------------------
   -- Constant_Reference --
   ------------------------

   function Constant_Reference
     (Self     : aliased Object;
      Position : Cursor) return Constant_Reference_Type
   is
      pragma Unreferenced (Self);
   begin
      return Constant_Reference_Type'
        (Attribute =>
           Set_Attribute.Constant_Reference
             (Position.Set.all, Position.CA).Element);
   end Constant_Reference;

   --------------
   -- Contains --
   --------------

   function Contains
     (Self  : Object;
      Name  : Name_Type;
      Index : Value_Type := No_Value) return Boolean
   is
      Position : constant Cursor := Self.Find (Name, Index);
   begin
      return Has_Element (Position);
   end Contains;

   function Contains
     (Self      : Object;
      Attribute : Project.Attribute.Object) return Boolean is
   begin
      return Self.Contains (Attribute.Name, Attribute.Index.Text);
   end Contains;

   -------------
   -- Element --
   -------------

   function Element (Position : Cursor) return Attribute.Object is
   begin
      return Set_Attribute.Element (Position.CA);
   end Element;

   function Element
     (Self  : Object;
      Name  : Name_Type;
      Index : Value_Type := No_Value) return Attribute.Object
   is
      Position : constant Cursor := Self.Find (Name, Index);
   begin
      if Set_Attribute.Has_Element (Position.CA) then
         return Element (Position);
      else
         return Project.Attribute.Undefined;
      end if;
   end Element;

   ------------
   -- Filter --
   ------------

   function Filter
     (Self  : Object;
      Name  : Optional_Name_Type := No_Name;
      Index : Value_Type := No_Value) return Object is
   begin
      if Name = No_Name and then Index = No_Value then
         return Self;
      end if;

      declare
         Result : Object;
      begin
         if Name = No_Name then
            for C in Self.Iterate (Name, Index) loop
               Result.Insert (Element (C));
            end loop;

            return Result;
         end if;

         --  If Name is defined we can use fast search for the attributes

         declare
            C : constant Set.Cursor := Self.Attributes.Find (Name);
         begin
            if not Set.Has_Element (C) then
               --  Result is empty here

               return Result;
            end if;

            declare
               Item : constant Set_Attribute.Map := Set.Element (C);
               CI   : Set_Attribute.Cursor;
               LI   : constant Value_Type :=
                        Ada.Characters.Handling.To_Lower (Index);
            begin
               if Index = No_Value then
                  --  All indexes

                  Result.Attributes.Insert (Name, Item);
                  Result.Length := Item.Length;
                  return Result;
               end if;

               --  Specific index only

               CI := Item.Find (Index);

               if Set_Attribute.Has_Element (CI) and then LI = Index then
                  Result.Insert (Set_Attribute.Element (CI));
                  return Result;
               end if;

               CI := Item.Find (LI);

               if Set_Attribute.Has_Element (CI) then
                  declare
                     E : constant Attribute.Object :=
                           Set_Attribute.Element (CI);
                  begin
                     if not E.Index_Case_Sensitive then
                        Result.Insert (E);
                     end if;
                  end;
               end if;
            end;
         end;

         return Result;
      end;
   end Filter;

   ----------
   -- Find --
   ----------

   function Find
     (Self  : Object;
      Name  : Name_Type;
      Index : Value_Type := No_Value) return Cursor
   is
      Result : Cursor :=
                 (CM  => Self.Attributes.Find (Name),
                  CA  => Set_Attribute.No_Element,
                  Set => null);
   begin
      if Set.Has_Element (Result.CM) then
         Result.Set := Self.Attributes.Constant_Reference (Result.CM).Element;

         --  If we have an attribute in the bucket let's check if the index
         --  is case sensitive or not.

         Result.CA := Result.Set.Find
           (if Index = No_Value
              or else Result.Set.Is_Empty
              or else Result.Set.First_Element.Index_Case_Sensitive
            then Index
            else Ada.Characters.Handling.To_Lower (Index));
      end if;

      return Result;
   end Find;

   -----------
   -- First --
   -----------

   overriding function First (Iter : Iterator) return Cursor is
      Position : Cursor :=
                   (Iter.Set.Attributes.First,
                    CA  => Set_Attribute.No_Element,
                    Set => null);
   begin
      if Set.Has_Element (Position.CM) then
         Position.Set :=
           Iter.Set.Attributes.Constant_Reference (Position.CM).Element;
         Position.CA := Position.Set.First;
      end if;

      if Has_Element (Position) and then not Is_Matching (Iter, Position) then
         return Next (Iter, Position);
      else
         return Position;
      end if;
   end First;

   -----------------
   -- Has_Element --
   -----------------

   function Has_Element (Position : Cursor) return Boolean is
   begin
      return Position.Set /= null
        and then Set_Attribute.Has_Element (Position.CA);
   end Has_Element;

   -------------
   -- Include --
   -------------

   procedure Include
     (Self : in out Object; Attribute : Project.Attribute.Object)
   is
      Position : constant Set.Cursor := Self.Attributes.Find (Attribute.Name);
      Present  : Boolean := False;
   begin
      if Set.Has_Element (Position) then
         declare
            A : Set_Attribute.Map := Set.Element (Position);
         begin
            Present := A.Contains (Attribute.Index.Text);
            A.Include  (Attribute.Case_Aware_Index, Attribute);
            Self.Attributes.Replace_Element (Position, A);
         end;

      else
         declare
            A : Set_Attribute.Map;
         begin
            Present := A.Contains (Attribute.Index.Text);
            A.Include (Attribute.Case_Aware_Index, Attribute);
            Self.Attributes.Insert (Attribute.Name, A);
         end;
      end if;

      if not Present then
         Self.Length := Self.Length + 1;
      end if;
   end Include;

   ------------
   -- Insert --
   ------------

   procedure Insert
     (Self : in out Object; Attribute : Project.Attribute.Object)
   is
      Position : constant Set.Cursor := Self.Attributes.Find (Attribute.Name);
   begin
      if Set.Has_Element (Position) then
         declare
            A : Set_Attribute.Map := Set.Element (Position);
         begin
            A.Insert (Attribute.Case_Aware_Index, Attribute);
            Self.Attributes.Replace_Element (Position, A);
         end;

      else
         declare
            A : Set_Attribute.Map;
         begin
            A.Insert (Attribute.Case_Aware_Index, Attribute);
            Self.Attributes.Insert (Attribute.Name, A);
         end;
      end if;

      Self.Length := Self.Length + 1;
   end Insert;

   --------------
   -- Is_Empty --
   --------------

   function Is_Empty (Self : Object) return Boolean is
   begin
      return Self.Length = 0;
   end Is_Empty;

   -----------------
   -- Is_Matching --
   -----------------

   function Is_Matching
     (Iter : Iterator'Class; Position : Cursor) return Boolean
   is
      A     : constant Attribute.Object := Position.Set.all (Position.CA);
      Name  : constant Optional_Name_Type :=
                Optional_Name_Type (To_String (Iter.Name));
      Index : constant Value_Type := To_String (Iter.Index);
   begin
      return
        (Name = No_Name or else A.Name = Name_Type (Name))
        and then (Index = No_Value or else A.Index_Equal (Index))
        and then (Iter.With_Defaults or else not A.Is_Default);
   end Is_Matching;

   -------------
   -- Iterate --
   -------------

   function Iterate
     (Self          : Object;
      Name          : Optional_Name_Type := No_Name;
      Index         : Value_Type := No_Value;
      With_Defaults : Boolean := False)
      return Attribute_Iterator.Forward_Iterator'Class is
   begin
      return It : Iterator do
         It.Set           := Self;
         It.Name          := To_Unbounded_String (String (Name));
         It.Index         := To_Unbounded_String (Index);
         It.With_Defaults := With_Defaults;
      end return;
   end Iterate;

   ------------
   -- Length --
   ------------

   function Length (Self : Object) return Containers.Count_Type is
   begin
      return Self.Length;
   end Length;

   ----------
   -- Next --
   ----------

   overriding function Next
     (Iter : Iterator; Position : Cursor) return Cursor
   is

      procedure Next (Position : in out Cursor)
        with Post => Position'Old /= Position;
      --  Move Position to next element

      ----------
      -- Next --
      ----------

      procedure Next (Position : in out Cursor) is
      begin
         Position.CA := Set_Attribute.Next (Position.CA);

         if not Set_Attribute.Has_Element (Position.CA) then
            Position.CM := Set.Next (Position.CM);

            if Set.Has_Element (Position.CM) then
               Position.Set :=
                 Iter.Set.Attributes.Constant_Reference (Position.CM).Element;
               Position.CA := Position.Set.First;

            else
               Position.Set := null;
            end if;
         end if;
      end Next;

      Result : Cursor := Position;
   begin
      loop
         Next (Result);
         exit when not Has_Element (Result) or else Is_Matching (Iter, Result);
      end loop;

      return Result;
   end Next;

   ---------------
   -- Reference --
   ---------------

   function Reference
     (Self     : aliased in out Object;
      Position : Cursor) return Reference_Type
   is
      pragma Unreferenced (Self);
   begin
      return Reference_Type'
        (Attribute =>
           Set_Attribute.Reference (Position.Set.all, Position.CA).Element);
   end Reference;

   ------------------
   -- Set_Defaults --
   ------------------

   procedure Set_Defaults
     (Self      : in out Object;
      Kind      : Project_Kind;
      Pack      : Optional_Name_Type;
      Languages : Containers.Source_Value_List)
   is
      Rules : constant RA.Default_Rules := RA.Get_Default_Rules (Pack);

      procedure Each_Default (Attr : Name_Type; Def : RA.Def);

      function Check_Default
        (Name   : Name_Type;
         Index  : Value_Type;
         Define : RA.Def;
         Result : out Attribute.Object) return Boolean;
      --  Lookup for default value of the attribute

      Lang : Containers.Source_Value_List;

      -------------------
      -- Check_Default --
      -------------------

      function Check_Default
        (Name   : Name_Type;
         Index  : Value_Type;
         Define : RA.Def;
         Result : out Attribute.Object) return Boolean
      is
         package SR renames Source_Reference;

         function Check_Reference return Boolean;
         --  Check default reference

         function Create_Name return SR.Identifier.Object is
           (SR.Identifier.Object (SR.Identifier.Create (SR.Builtin, Name)));

         function Create_Index return SR.Value.Object is
           (SR.Value.Object (SR.Value.Create (SR.Builtin, Index)));

         function Create_Value return SR.Value.Object is
           (SR.Value.Object
              (SR.Value.Create (SR.Builtin, Define.Default.First_Element)));

         ---------------------
         -- Check_Reference --
         ---------------------

         function Check_Reference return Boolean is
            Ref_Name : constant Name_Type :=
                         Name_Type (Define.Default.First_Element);
            Position : constant Cursor := Self.Find (Ref_Name, Index);
         begin
            if Has_Element (Position) then
               Result := Element (Position);
               return True;
            end if;

            return Check_Default
              (Ref_Name, Index, RA.Get (RA.Create (Ref_Name, Pack)), Result);
         end Check_Reference;

      begin
         if Define.Default.Is_Empty then
            return False;
         end if;

         if Define.Default_Is_Reference then
            return Check_Reference;

         elsif Define.Value = RA.List then
            Result := Project.Attribute.Create
              (Name    => Create_Name,
               Index   => Create_Index,
               Values  => Containers.Source_Value_Type_List.To_Vector
                 (Create_Value, 1),
               Default => True);
         else
            Result := Project.Attribute.Create
              (Create_Name, Create_Index, Create_Value, Default => True);
         end if;

         Result.Set_Case
           (Index_Is_Case_Sensitive => Define.Index_Case_Sensitive,
            Value_Is_Case_Sensitive => Define.Value_Case_Sensitive);

         return True;
      end Check_Default;

      ------------------
      -- Each_Default --
      ------------------

      procedure Each_Default (Attr : Name_Type; Def : RA.Def) is
         use type RA.Index_Kind;

         procedure Check_Default (Index : Value_Type);

         -------------------
         -- Check_Default --
         -------------------

         procedure Check_Default (Index : Value_Type) is
            DA : Attribute.Object;
         begin
            if not Self.Contains (Attr, Index)
              and then Check_Default (Attr, Index, Def, DA)
            then
               Self.Insert (DA.Rename (Attr));
            end if;
         end Check_Default;

      begin
         if not Def.Is_Allowed_In (Kind) then
            return;

         elsif Def.Index = RA.No then
            Check_Default (No_Value);

         else
            for L of Lang loop
               Check_Default (L.Text);
            end loop;
         end if;
      end Each_Default;

   begin
      if Languages.Is_Empty then
         --  Need set defaults for Languages first because another defaults
         --  indexed by them.

         Each_Default (RA.Languages, RA.Get_Default (Rules, RA.Languages));
         Lang := Self.Languages.Values;

      else
         Lang := Languages;
      end if;

      RA.For_Each_Default (Rules, Each_Default'Access);
   end Set_Defaults;

begin
   Definition.Set_Defaults := Set_Defaults'Access;
end GPR2.Project.Attribute.Set;

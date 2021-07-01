------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--                       Copyright (C) 2021, AdaCore                        --
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

with Ada.Text_IO;
with GPR2.Context;
with GPR2.Log;
with GPR2.Path_Name;
with GPR2.Project.Attribute;
with GPR2.Project.Attribute.Set;
with GPR2.Project.Registry;
with GPR2.Project.Registry.Attribute;
with GPR2.Project.Tree;
with GPR2.Project.Variable;
with GPR2.Project.View;
with GPR2.Source_Reference;
with GPR2.Source_Reference.Value;

procedure Main is
   Tree         : GPR2.Project.Tree.Object;
   Context      : GPR2.Context.Object;
   use GPR2;

   procedure Print_Messages is
   begin
      if Tree.Has_Messages then
         for C in Tree.Log_Messages.Iterate (Information => False)
         loop
            Ada.Text_IO.Put_Line (GPR2.Log.Element (C).Format);
         end loop;
      end if;
   end Print_Messages;

   procedure Print_Attributes (Pack : GPR2.Optional_Name_Type;
                               Name : GPR2.Optional_Name_Type) is
      Attributes : GPR2.Project.Attribute.Set.Object;
      use GPR2;
      Header     : String := (if Pack = ""
                              then String (Name)
                              else String (Pack) & "." & String (Name));
   begin
      if Pack = "" then
         Attributes := Tree.Root_Project.Attributes (Name);
      elsif Tree.Root_Project.Has_Packages (Pack) then
         Attributes := Tree.Root_Project.Pack (Pack).Attributes (Name);
      end if;
      for A of Attributes loop
         declare
            Attribute : GPR2.Project.Attribute.Object := A;
            use GPR2.Project.Registry.Attribute;
         begin
            Ada.Text_IO.Put (Header);
            if Attribute.Has_Index then
               Ada.Text_IO.Put ( "(" & Attribute.Index.Text & ")");
            end if;
            Ada.Text_IO.Put ("=");
            if Attribute.Kind = GPR2.Project.Registry.Attribute.Single then
               Ada.Text_IO.Put ("""");
               Ada.Text_IO.Put (String (Attribute.Value.Text));
               Ada.Text_IO.Put ("""");
            else
               declare
                  Separator : Boolean := False;
                  Value     : GPR2.Source_Reference.Value.Object;
               begin
                  Ada.Text_IO.Put ("(");
                  for V of Attribute.Values loop
                     Value := V;
                     if Separator then
                        Ada.Text_IO.Put (",");
                     end if;
                     Separator := True;
                     Ada.Text_IO.Put ("""");
                     Ada.Text_IO.Put (String (Value.Text));
                     Ada.Text_IO.Put ("""");
                  end loop;
                  Ada.Text_IO.Put (")");
               end;
            end if;
            Ada.Text_IO.Put_Line ("");
         end;

      end loop;
   end Print_Attributes;

   procedure Print_Variable (Name : Name_Type) is
      Var : constant GPR2.Project.Variable.Object :=
              Tree.Root_Project.Variable (Name);
      use type GPR2.Project.Registry.Attribute.Value_Kind;
   begin
      Ada.Text_IO.Put (String (Name) & "=");
      if Var.Kind = GPR2.Project.Registry.Attribute.Single then
         Ada.Text_IO.Put ("""");
         Ada.Text_IO.Put (String (Var.Value.Text));
         Ada.Text_IO.Put ("""");
      else
         declare
            Separator : Boolean := False;
            Value     : GPR2.Source_Reference.Value.Object;
         begin
            Ada.Text_IO.Put ("(");
            for V of Var.Values loop
               Value := V;
               if Separator then
                  Ada.Text_IO.Put (",");
               end if;
               Separator := True;
               Ada.Text_IO.Put ("""");
               Ada.Text_IO.Put (String (Value.Text));
               Ada.Text_IO.Put ("""");
            end loop;
            Ada.Text_IO.Put (")");
         end;
      end if;
      Ada.Text_IO.Put_Line ("");
   end Print_Variable;

   procedure Test is
   begin
      Print_Attributes (Pack => "", Name => "source_dirs");
      Print_Variable ("A");
      Print_Variable ("B");
      Print_Variable ("C");
      Print_Variable ("D");
      Print_Variable ("E");
   exception
      when Project_Error =>
         Print_Messages;
   end Test;

   procedure Load (Project_Name : GPR2.Filename_Type) is
   begin
      Tree.Unload;
      Tree.Load_Autoconf
        (Filename => GPR2.Path_Name.Create_File
           (GPR2.Project.Ensure_Extension (Project_Name),
            GPR2.Path_Name.No_Resolution),
         Context  => Context);
      Print_Messages;
   exception
      when Project_Error =>
         Print_Messages;
   end Load;

begin
   Load ("files/prj1.gpr");
   Test;
   Load ("files/prj2.gpr");
end Main;
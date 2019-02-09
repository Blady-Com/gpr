------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--          Copyright (C) 2016-2018, Free Software Foundation, Inc.         --
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

with Ada.Text_IO;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with GPR2.Context;
with GPR2.Context;
with GPR2.Log;
with GPR2.Message;
with GPR2.Path_Name;
with GPR2.Project.Attribute.Set;
with GPR2.Project.Tree;
with GPR2.Project.Variable.Set;
with GPR2.Project.View;

procedure Main is

   use Ada;
   use Ada.Strings;
   use Ada.Strings.Unbounded;
   use GPR2;
   use GPR2.Project;

   procedure Display (Prj : Project.View.Object; Full : Boolean := True);

   procedure Changed_Callback (Prj : Project.View.Object);

   ----------------------
   -- Changed_Callback --
   ----------------------

   procedure Changed_Callback (Prj : Project.View.Object) is
   begin
      Text_IO.Put_Line
        (">>> Changed_Callback for "
         & Directories.Simple_Name (Prj.Path_Name.Value));
   end Changed_Callback;

   -------------
   -- Display --
   -------------

   procedure Display (Prj : Project.View.Object; Full : Boolean := True) is
      use GPR2.Project.Attribute.Set;
      use GPR2.Project.Variable.Set.Set;
   begin
      Text_IO.Put (String (Prj.Name) & " ");
      Text_IO.Set_Col (10);
      Text_IO.Put_Line (Prj.Qualifier'Img);

      if Full then
         if Prj.Has_Attributes then
            for A in Prj.Attributes.Iterate loop
               Text_IO.Put ("A:   " & String (Attribute.Set.Element (A).Name));
               Text_IO.Put (" ->");

               for V of Attribute.Set.Element (A).Values loop
                  Text_IO.Put (" " & V.Text);
               end loop;
               Text_IO.New_Line;
            end loop;
         end if;

         if Prj.Has_Variables then
            for V in Prj.Variables.Iterate loop
               Text_IO.Put ("V:   " & String (Key (V)));
               Text_IO.Put (" -> ");
               Text_IO.Put (Element (V).Value.Text);
               Text_IO.New_Line;
            end loop;
         end if;
         Text_IO.New_Line;
      end if;
   end Display;

   Prj : Project.Tree.Object;
   Ctx : Context.Object;

begin
   Project.Tree.Load (Prj, Create ("demo.gpr"), Ctx);

exception
   when GPR2.Project_Error =>
      if Prj.Has_Messages then
         Text_IO.Put_Line ("Messages found:");

         for C in Prj.Log_Messages.Iterate
           (False, False, True, True, True)
         loop
            declare
               M : constant Message.Object := Log.Element (C);
               F : constant String := M.Sloc.Filename;
               I : constant Natural :=
                              Strings.Fixed.Index (F, "errors-syntax");
            begin
               Text_IO.Put_Line ("> " & F (I - 1 .. F'Last));
               Text_IO.Put_Line (M.Level'Img);
               Text_IO.Put_Line (M.Sloc.Line'Img);
               Text_IO.Put_Line (M.Sloc.Column'Img);
               Text_IO.Put_Line (M.Message);
               Text_IO.Put_Line (M.Format);
            end;
         end loop;
      end if;
end Main;

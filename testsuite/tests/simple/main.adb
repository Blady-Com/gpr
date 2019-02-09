------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--          Copyright (C) 2016-2019, Free Software Foundation, Inc.         --
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

with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings.Fixed;

with GPR2.Project.View;
with GPR2.Project.Tree;
with GPR2.Project.Attribute.Set;
with GPR2.Project.Variable.Set;
with GPR2.Context;

procedure Main is

   use Ada;
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

               for V of Element (A).Values loop
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

   Prj1, Prj2 : Project.Tree.Object;
   Ctx        : Context.Object;

begin
   Ctx.Include ("OS", "Linux");

   Project.Tree.Load (Prj1, Create ("demo.gpr"), Ctx);
   Project.Tree.Load (Prj2, Create ("demo.gpr"), Ctx);

   Ctx := Prj1.Context;
   Prj1.Set_Context (Ctx, Changed_Callback'Access);

   Ctx := Prj2.Context;
   Ctx.Include ("OS", "Windows");
   Prj2.Set_Context (Ctx, Changed_Callback'Access);

   Display (Prj1.Root_Project);
   Display (Prj2.Root_Project);

   Ctx.Clear;
   Ctx.Include ("OS", "Linux-2");
   Prj2.Set_Context (Ctx, Changed_Callback'Access);
   Display (Prj2.Root_Project);

   --  Iterator

   Text_IO.Put_Line ("**************** Iterator Prj1");

   for C in Project.Tree.Iterate
     (Prj1, Kind => (I_Project | I_Imported => True, others => False))
   loop
      Display (Project.Tree.Element (C), Full => False);
      if Project.Tree.Is_Root (C) then
         Text_IO.Put_Line ("   is root");
      end if;
   end loop;

   Prj1.Unload;

   Text_IO.Put_Line ("**************** Iterator Prj2");

   for C in Project.Tree.Iterate (Prj2) loop
      Display (Project.Tree.Element (C), Full => False);
   end loop;

   Text_IO.Put_Line ("**************** Iterator Prj3");

   for C in Project.Tree.Iterate (Prj2, Filter => Library_Filter) loop
      Display (Project.Tree.Element (C), Full => False);
   end loop;

   Text_IO.Put_Line ("**************** Iterator Prj4");

   for P of Prj2 loop
      Display (P, Full => False);
   end loop;

exception
   when GPR2.Project_Error =>
      if Prj1.Has_Messages then
         Text_IO.Put_Line ("Messages found:");

         for M of Prj1.Log_Messages.all loop
            declare
               Mes : constant String := M.Format;
               L   : constant Natural :=
                 Strings.Fixed.Index (Mes, "/simple");
            begin
               if L /= 0 then
                  Text_IO.Put_Line (Mes (L .. Mes'Last));
               else
                  Text_IO.Put_Line (Mes);
               end if;
            end;
         end loop;
      end if;
end Main;

------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--                     Copyright (C) 2019-2022, AdaCore                     --
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
with Ada.Exceptions;

with GPR2.Project.View;
with GPR2.Project.Tree;
with GPR2.Project.Attribute.Set;
with GPR2.Context;
with GPR2.Source_Reference.Value;
with GPR2.Message;
with GPR2.Log;

procedure Main is

   use Ada;
   use GPR2;
   use GPR2.Project;

   procedure Display (Prj : Project.View.Object; Full : Boolean := True);

   -------------
   -- Display --
   -------------

   procedure Display (Prj : Project.View.Object; Full : Boolean := True) is
      use GPR2.Project.Attribute.Set;

      procedure Display (Att : Project.Attribute.Object) is
      begin
         Text_IO.Put ("   " & String (Image (Att.Name.Id)));

         if Att.Has_Index then
            Text_IO.Put (" (" & Att.Index.Value & ")");
         end if;

         Text_IO.Put (" -> ");

         for V of Att.Values loop
            Text_IO.Put (V.Text & " ");
         end loop;
         Text_IO.New_Line;
      end Display;
   begin
      Text_IO.Put (String (Prj.Name) & " ");
      Text_IO.Set_Col (10);
      Text_IO.Put_Line (Prj.Qualifier'Img);

      if Full then
         for A of Prj.Attributes loop
            Display (A);
         end loop;
         Text_IO.New_Line;
      end if;
   end Display;

   Prj : Project.Tree.Object;
   Ctx : Context.Object;

   procedure Print_Messages is
   begin
      if Prj.Has_Messages then
         for C in Prj.Log_Messages.Iterate
           (False, True, True, True, True)
         loop
            Ada.Text_IO.Put_Line (GPR2.Log.Element (C).Format);
         end loop;
      end if;
   end Print_Messages;

begin
   Project.Tree.Load
     (Self => Prj, Filename => Create ("demo.gpr"), Context => Ctx);

   Ctx.Include ("CASESTMT_OS", "Linux");
   Prj.Set_Context (Ctx);
   Display (Prj.Root_Project);

   Ctx.Clear;
   Ctx.Include ("CASESTMT_OS", "Windows");
   Prj.Set_Context (Ctx);
   Display (Prj.Root_Project);

exception
   when Ex : others =>
      Text_IO.Put_Line (Ada.Exceptions.Exception_Message (Ex));
      Print_Messages;

end Main;

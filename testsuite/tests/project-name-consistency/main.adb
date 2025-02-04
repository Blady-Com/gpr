--
--  Copyright (C) 2019-2022, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0
--

with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings.Fixed;

with GPR2.Context;
with GPR2.Log;
with GPR2.Message;
with GPR2.Project.View;
with GPR2.Project.Tree;

procedure Main is

   use Ada;
   use GPR2;
   use GPR2.Project;
   use type GPR2.Message.Level_Value;

   Prj : Project.Tree.Object;
   Ctx : Context.Object;

   --------------------
   -- Print_Messages --
   --------------------

   procedure Print_Messages is
   begin
      if Prj.Log_Messages.Has_Element
        (Information => False, Lint => False)
      then
         Text_IO.Put_Line ("Messages found:");

         for M in Prj.Log_Messages.Iterate (Information => False) loop
            declare
               Mes : constant String := GPR2.Log.Element (M).Format;
               L   : constant Natural :=
                       Strings.Fixed.Index (Mes, "/demo");
            begin
               if L /= 0 then
                  Text_IO.Put_Line (Mes (L .. Mes'Last));
               else
                  Text_IO.Put_Line (Mes);
               end if;
            end;
         end loop;
      end if;
   end Print_Messages;

begin
   Project.Tree.Load (Prj, Create ("demo.gpr"), Ctx);

   Print_Messages;
exception
   when GPR2.Project_Error =>
      Print_Messages;
end Main;

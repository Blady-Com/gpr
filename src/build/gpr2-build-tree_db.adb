--
--  Copyright (C) 2022, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0
--

with GPR2.Build.View_Tables;

package body GPR2.Build.Tree_Db is

   ----------
   -- Load --
   ----------

   procedure Load (Self : in out Object; Tree : GPR2.Project.Tree.Object)
   is
      Db_Inst : View_Db.Object;

   begin

      Self.Self := Self'Unrestricted_Access;

      --  Source files are propagated from the source owner (e.g. the view that
      --  defines the source directory where we found the source) to
      --  the other views (aggregate libraries or extending projects).
      --
      --  So for this to work efficiently, we need to use a topological order
      --  to populate the sources.

      for V of Tree.Ordered_Views loop
         if V.Kind in With_Object_Dir_Kind then
            declare
               Db_Data : View_Tables.View_Data
                           (Is_Root => V.Is_Namespace_Root);
            begin
               Db_Data.View    := V;
               Db_Data.Tree_Db := Self.Self;
               Db_Inst := View_Tables.View_Base_For (Db_Data);
               Self.Build_Dbs.Insert (V.Id, Db_Inst);
               --  Db_Inst.Update;
            end;
         end if;
      end loop;

      for V of Tree.Ordered_Views loop
         if V.Kind in With_Object_Dir_Kind then
            View_Tables.Refresh (View_Tables.Get_Data (Self.Self, V));
         end if;
      end loop;
   end Load;

   ------------
   -- Unload --
   ------------

   procedure Unload (Self : in out Object)
   is
   begin
      Self.Build_Dbs.Clear;
      Self.Tree := null;
      Self.Self := null;
   end Unload;

   -------------------
   -- View_Database --
   -------------------

   function View_Database
     (Self : in out Object; View : GPR2.Project.View.Object)
      return Build.View_Db.Object
   is
   begin
      return Self.Build_Dbs.Element (View.Id);
   end View_Database;

end GPR2.Build.Tree_Db;

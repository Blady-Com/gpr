------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--            Copyright (C) 2018, Free Software Foundation, Inc.            --
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

with Ada.Strings.Fixed;
with Ada.Text_IO;

with GPR2.Context;
with GPR2.Path_Name;
with GPR2.Project.View;
with GPR2.Project.Tree;
with GPR2.Project.Attribute.Set;

procedure Main is

   use Ada;
   use GPR2;
   use GPR2.Project;

   procedure Display (Prj : Project.View.Object);

   function Filter_Path (Filename : Path_Name.Full_Name) return String;
   --  Remove the leading tmp directory

   -------------
   -- Display --
   -------------

   procedure Display (Prj : Project.View.Object) is
      use GPR2.Project.Attribute.Set;
   begin
      Text_IO.Put (String (Prj.Name) & " ");
      Text_IO.Set_Col (10);
      Text_IO.Put_Line (Prj.Kind'Img);
      Text_IO.Put_Line
        ("Library_Name : " & String (Prj.Library_Name));
      Text_IO.Put_Line
        ("Library_Directory : " & String (Prj.Library_Directory.Name));
      Text_IO.Put_Line
        ("                  : " & Filter_Path (Prj.Library_Directory.Value));
      Text_IO.Put_Line
        ("Library Filename : " & String (Prj.Library_Filename.Name));
      Text_IO.Put_Line
        ("                 : " & Filter_Path (Prj.Library_Filename.Value));
      Text_IO.Put_Line
        ("Library Version Filename : "
         & String (Prj.Library_Version_Filename.Name));
      Text_IO.Put_Line
        ("                         : "
         & Filter_Path (Prj.Library_Version_Filename.Value));
       Text_IO.Put_Line
        ("Library Major Version Filename : "
         & String (Prj.Library_Major_Version_Filename.Name));
       Text_IO.Put_Line
        ("                               : "
         & Filter_Path (Prj.Library_Major_Version_Filename.Value));
      Text_IO.Put_Line
        ("Library_Standalone : " & Prj.Library_Standalone'Img);
   end Display;

   -----------------
   -- Filter_Path --
   -----------------

   function Filter_Path (Filename : Path_Name.Full_Name) return String is
      D : constant String := "library-definitions";
      I : constant Positive := Strings.Fixed.Index (Filename, D);
   begin
      return Filename (I + D'Length .. Filename'Last);
   end Filter_Path;

   Prj : Project.Tree.Object;
   Ctx : Context.Object;

begin
   Project.Tree.Load (Prj, Create ("demo.gpr"), Ctx);
   Display (Prj.Root_Project);
end Main;
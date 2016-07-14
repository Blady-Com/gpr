------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--            Copyright (C) 2016, Free Software Foundation, Inc.            --
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

package GPR2.Project.Registry.Pack is

   function Exists (Name : Name_Type) return Boolean;
   --  Returns True if Name is a known package

   function Is_Allowed_In
     (Name    : Name_Type;
      Project : Project_Kind) return Boolean
     with Pre => Exists (Name);
   --  Returns True if the package is allowed in the given project

   --  Some common package names

   Builder  : constant Name_Type := "builder";
   Compiler : constant Name_Type := "compiler";
   Binder   : constant Name_Type := "binder";
   Linker   : constant Name_Type := "linker";
   Naming   : constant Name_Type := "naming";

end GPR2.Project.Registry.Pack;

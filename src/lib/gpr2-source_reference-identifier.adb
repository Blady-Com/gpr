------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--         Copyright (C) 2017-2018, Free Software Foundation, Inc.          --
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

package body GPR2.Source_Reference.Identifier is

   ------------
   -- Create --
   ------------

   function Create
     (Filename     : Path_Name.Full_Name;
      Line, Column : Natural;
      Identifier   : Name_Type)
      return Object'Class is
   begin
      return Object'
        (GPR2.Source_Reference.Object
           (GPR2.Source_Reference.Create (Filename, Line, Column))
         with Identifier => To_Unbounded_String (String (Identifier)));
   end Create;

   ----------------
   -- Identifier --
   ----------------

   function Identifier (Self : Object) return Name_Type is
   begin
      return Name_Type (To_String (Self.Identifier));
   end Identifier;

end GPR2.Source_Reference.Identifier;

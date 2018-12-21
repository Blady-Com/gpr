------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--         Copyright (C) 2016-2018, Free Software Foundation, Inc.          --
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

--  Some common containers for Name, Value

with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Containers.Indefinite_Ordered_Sets;

package GPR2.Containers is

   subtype Count_Type is Ada.Containers.Count_Type;

   package Name_Type_List is
     new Ada.Containers.Indefinite_Vectors (Positive, Name_Type);

   subtype Name_List is Name_Type_List.Vector;

   package Value_Type_List is
     new Ada.Containers.Indefinite_Vectors (Positive, Value_Type);

   subtype Value_List is Value_Type_List.Vector;
   subtype Extended_Index is Value_Type_List.Extended_Index;

   function Image (Values : Value_List) return String;
   --  Returns a string representation of the list of values

   package Value_Type_Set is
     new Ada.Containers.Indefinite_Ordered_Sets (Value_Type);

   subtype Value_Set is Value_Type_Set.Set;

   package Name_Value_Map_Package is
     new Ada.Containers.Indefinite_Ordered_Maps (Name_Type, Value_Type);

   subtype Name_Value_Map is Name_Value_Map_Package.Map;

   function Value_Or_Default
     (Map     : Name_Value_Map;
      Key     : Name_Type;
      Default : Value_Type := No_Value) return Value_Type
     with Post => (if not Map.Contains (Key)
                   then Value_Or_Default'Result = Default);
   --  Returns value by key if exists or Default value if key not found

end GPR2.Containers;

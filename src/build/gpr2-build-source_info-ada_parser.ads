--
--  Copyright (C) 2022, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0
--

package GPR2.Build.Source_Info.Ada_Parser is

   procedure Compute
     (Data             : in out Source_Info.Object'Class;
      Get_Withed_Units : Boolean);
   --  Setup Data with the information from parsing Ada source file

end GPR2.Build.Source_Info.Ada_Parser;

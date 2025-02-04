--
--  Copyright (C) 2022, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0
--

package GPR2.Build is

   type Unit_Kind is (S_Spec, S_Body, S_Separate);
   --  Used to identify the kind of source or unit is manipulated:
   --  S_Spec: spec or header
   --  S_Body: unit body or implementation source
   --  S_Separate: unit separated from a body

   type Unit_Origin is (Parsing, Naming_Exception, Naming_Schema);
   --  How we figured out the unit

end GPR2.Build;

with p6_0; use p6_0;
with p7_3; use p7_3;
package body p6_3 is
   function p6_3_0 (Item : Integer) return Integer is
      Result : Long_Long_Integer;
   begin
      if Item < 0 then
         return -Item;
      end if;
      Result := Long_Long_Integer (p6_0_0 (Item - 1)) + Long_Long_Integer (p7_3_0 (Item - 2));
      return Integer (Result rem Long_Long_Integer (Integer'Last));
   end p6_3_0;
   function p6_3_1 (Item : Integer) return Integer is
      Result : Long_Long_Integer;
   begin
      if Item < 0 then
         return -Item;
      end if;
      Result := Long_Long_Integer (p6_0_1 (Item - 1)) + Long_Long_Integer (p7_3_1 (Item - 2));
      return Integer (Result rem Long_Long_Integer (Integer'Last));
   end p6_3_1;
   function p6_3_2 (Item : Integer) return Integer is
      Result : Long_Long_Integer;
   begin
      if Item < 0 then
         return -Item;
      end if;
      Result := Long_Long_Integer (p6_0_2 (Item - 1)) + Long_Long_Integer (p7_3_2 (Item - 2));
      return Integer (Result rem Long_Long_Integer (Integer'Last));
   end p6_3_2;
end p6_3;

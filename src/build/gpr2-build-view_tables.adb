--
--  Copyright (C) 2022, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0
--

with GPR2.Build.Source_Info.Ada_Parser;
with GPR2.Build.Tree_Db;
with GPR2.Containers;
with GPR2.Message;
with GPR2.Project.Tree;

package body GPR2.Build.View_Tables is

   procedure Add_Unit_Part
     (Data     : in out View_Data;
      CU       : Name_Type;
      Kind     : Unit_Kind;
      Sep_Name : Optional_Name_Type;
      View     : Project.View.Object;
      Path     : Path_Name.Object;
      Index    : Unit_Index)
     with Pre => Data.Is_Root
                   and then (Kind = S_Separate) = (Sep_Name'Length > 0);

   procedure Remove_Unit_Part
     (Data     : in out View_Data;
      CU       : Name_Type;
      Kind     : Unit_Kind;
      Sep_Name : Optional_Name_Type)
     with Pre => Data.Is_Root
                   and then (Kind = S_Separate) = (Sep_Name'Length > 0);

   procedure Resolve_Visibility
     (Data   : in out View_Data;
      Cursor : in out Basename_Source_List_Maps.Cursor);

   package Update_Sources_List is
      procedure Process
        (Data             : in out View_Data;
         Stop_On_Error    : Boolean);
      --  Update the list of sources
   end Update_Sources_List;

   function "-" (Inst : Build.View_Db.Object) return View_Data_Ref
   is (Get_Ref (Inst));

   procedure Check_Separate
     (Root_Db : View_Tables.View_Data;
      File    : in out Source_Info.Object)
     with Pre => Root_Db.Is_Root
                   and then File.Has_Single_Unit
                   and then File.Unit.Kind = S_Separate;

   ----------------
   -- Add_Source --
   ----------------

   procedure Add_Source
     (Data            : in out View_Data;
      View_Owner      : GPR2.Project.View.Object;
      Path            : GPR2.Path_Name.Object;
      Extended_View   : GPR2.Project.View.Object;
      Aggregated_View : GPR2.Project.View.Object)
   is
      C_Overload : Basename_Source_List_Maps.Cursor;
      Done       : Boolean;
      Proxy      : constant Source_Proxy :=
                     (View      => View_Owner,
                      Path_Name => Path,
                      Inh_From  => Extended_View,
                      Agg_From  => Aggregated_View);

   begin
      Data.Overloaded_Srcs.Insert (Path.Simple_Name,
                                   Source_Proxy_Sets.Empty_Set,
                                   C_Overload,
                                   Done);
      Data.Overloaded_Srcs.Reference (C_Overload).Include (Proxy);

      Resolve_Visibility (Data, C_Overload);
   end Add_Source;

   -------------------
   -- Add_Unit_Part --
   -------------------

   procedure Add_Unit_Part
     (Data     : in out View_Data;
      CU       : Name_Type;
      Kind     : Unit_Kind;
      Sep_Name : Optional_Name_Type;
      View     : Project.View.Object;
      Path     : Path_Name.Object;
      Index    : Unit_Index)
   is
      Cursor : Compilation_Unit_Maps.Cursor;
      Done   : Boolean;
   begin
      Cursor := Data.CUs.Find (CU);

      if not Compilation_Unit_Maps.Has_Element (Cursor) then
         Data.CUs.Insert (CU, Compilation_Unit.Create (CU), Cursor, Done);
         pragma Assert (Done);
      end if;

      Data.CUs.Reference (Cursor).Add (Kind, View, Path, Index, Sep_Name);

      if Kind = S_Separate then
         declare
            Full_Name : constant Name_Type :=
                          GPR2."&" (GPR2."&" (CU, "."), Sep_Name);
         begin
            Data.Separates.Include (Full_Name, CU);
         end;
      end if;
   end Add_Unit_Part;

   --------------------
   -- Check_Separate --
   --------------------

   procedure Check_Separate
     (Root_Db : View_Tables.View_Data;
      File    : in out Source_Info.Object)
   is
      C : Name_Maps.Cursor;
   begin
      loop
         C := Root_Db.Separates.Find (File.Unit.Unit_Name);

         exit when not Name_Maps.Has_Element (C);

         --  The separate_from unit is in the separates map, this
         --  happens in case of separates of separates.
         --  We need to rebase on the actual compilation unit in this case.

         declare
            U            : constant Source_Info.Unit_Part := File.Unit;
            New_Name     : constant Name_Type := Name_Maps.Element (C);
            --  New compilation unit name
            P_Simple     : constant Name_Type := U.Unit_Name
                                         (New_Name'Length + 2 .. U.Name_Len);
            --  Simple unit name of the separate parent
            New_Sep_Name : constant Name_Type :=
                             GPR2."&" (GPR2."&" (P_Simple, "."),
                                       U.Separate_Name);
         begin
            File.Update_Unit
              (Source_Info.Create
                 (Unit_Name      => New_Name,
                  Index          => U.Index,
                  Kind           => U.Kind,
                  Kind_Ambiguous => False,
                  Separate_Name  => New_Sep_Name));
         end;
      end loop;
   end Check_Separate;

   --------------
   -- Get_Data --
   --------------

   function Get_Data
     (Db : access GPR2.Build.Tree_Db.Object;
      View : GPR2.Project.View.Object) return View_Data_Ref
   is
   begin
      return -Db.View_Database (View);
   end Get_Data;

   -------------
   -- Refresh --
   -------------

   procedure Refresh (Data : in out View_Data)
   is
   begin
      Update_Sources_List.Process (Data, False);

      --  Disambiguate unit kind for Ada bodies

      if not Data.View.Is_Extended
        and then Data.View.Kind in With_Object_Dir_Kind
      then
         --  Only look at "final" views: e.g. not inherited.
         --  That's because the compilation unit may not be complete until we
         --  reach the inheriting view that gathers together all the sources.

         for C_Proxy in Data.Sources.Iterate loop
            declare
               Proxy : constant Source_Proxy :=
                         Basename_Source_Maps.Element (C_Proxy);
               Db    : constant View_Data_Ref :=
                         Get_Data (Data.Tree_Db, Proxy.View);
               S_Ref : constant Src_Info_Maps.Reference_Type :=
                         Db.Src_Infos.Reference (Proxy.Path_Name);

            begin
               if S_Ref.Language = Ada_Language
                 and then not S_Ref.Has_Index
               then
                  declare
                     Unit : Source_Info.Unit_Part := S_Ref.Unit;

                  begin
                     if Unit.Kind_Ambiguous then
                        Root_Loop :
                        for Root_View of Data.View.Namespace_Roots loop
                           declare
                              Units : Compilation_Unit_Maps.Map renames
                                        Get_Data (Data.Tree_Db, Root_View).CUs;
                           begin
                              if Units (Unit.Unit_Name).Has_Part (S_Spec) then
                                 --  If it has a corresponding spec, then it's
                                 --  a body
                                 Unit.Kind_Ambiguous := False;
                                 S_Ref.Update_Unit (Unit);

                                 exit Root_Loop;
                              end if;
                           end;
                        end loop Root_Loop;
                     end if;

                     if Unit.Kind_Ambiguous then
                        --  If still ambiguous after the above path, we
                        --  have a body with no spec and dot_repl in the
                        --  filename: can be a child body-only, or a separate.
                        --  We need to parse the source to determine the
                        --  exact kind.
                        Build.Source_Info.Ada_Parser.Compute (S_Ref, False);

                        if S_Ref.Unit (No_Index).Unit_Name /= Unit.Unit_Name
                          or else S_Ref.Unit (No_Index).Kind /= Unit.Kind
                        then
                           for Root_View of Data.View.Namespace_Roots loop
                              declare
                                 Root_Db : constant View_Data_Ref :=
                                             Get_Data (Data.Tree_Db,
                                                       Root_View);
                              begin
                                 --  Remove old unit from the namespace root
                                 --  list.

                                 Remove_Unit_Part
                                   (Root_Db,
                                    Unit.Unit_Name,
                                    Unit.Kind,
                                    Unit.Separate_Name);

                                 --  And add the new one
                                 Add_Unit_Part
                                   (Root_Db,
                                    S_Ref.Unit.Unit_Name,
                                    S_Ref.Unit.Kind,
                                    S_Ref.Unit.Separate_Name,
                                    Data.View,
                                    S_Ref.Path_Name,
                                    S_Ref.Unit.Index);
                              end;
                           end loop;
                        end if;
                     end if;
                  end;
               end if;
            end;
         end loop;

         --  Now check separates of separates

         for C_Proxy in Data.Sources.Iterate loop
            declare
               Proxy : constant Source_Proxy :=
                         Basename_Source_Maps.Element (C_Proxy);
               Db    : constant View_Data_Ref :=
                         Get_Data (Data.Tree_Db, Proxy.View);
               S_Ref : constant Src_Info_Maps.Reference_Type :=
                         Db.Src_Infos.Reference (Proxy.Path_Name);
            begin
               if S_Ref.Has_Units
                 and then S_Ref.Has_Single_Unit
                 and then S_Ref.Unit.Kind = S_Separate
               then
                  for Root of Data.View.Namespace_Roots loop
                     declare
                        Root_Db : constant View_Data_Ref :=
                                    Get_Data (Data.Tree_Db, Root);
                        Old     : constant Source_Info.Unit_Part := S_Ref.Unit;
                     begin
                        Check_Separate (Root_Db, S_Ref);

                        if S_Ref.Unit.Unit_Name /= Old.Unit_Name then
                           Remove_Unit_Part
                             (Root_Db,
                              Old.Unit_Name,
                              Old.Kind,
                              Old.Separate_Name);

                           --  And add the new one
                           Add_Unit_Part
                             (Root_Db,
                              S_Ref.Unit.Unit_Name,
                              S_Ref.Unit.Kind,
                              S_Ref.Unit.Separate_Name,
                              Data.View,
                              S_Ref.Path_Name,
                              S_Ref.Unit.Index);
                        end if;
                     end;
                  end loop;
               end if;
            end;
         end loop;
      end if;
   end Refresh;

   -------------------
   -- Remove_Source --
   -------------------

   procedure Remove_Source
     (Data       : in out View_Data;
      View_Owner : GPR2.Project.View.Object;
      Path       : GPR2.Path_Name.Object)
   is
      Basename : constant Simple_Name := Path.Simple_Name;
      C_Overload : Basename_Source_List_Maps.Cursor;
      Proxy    : constant Source_Proxy := (View      => View_Owner,
                                           Path_Name => Path,
                                           others    => <>);

   begin
      C_Overload := Data.Overloaded_Srcs.Find (Basename);

      Data.Overloaded_Srcs.Reference (C_Overload).Delete (Proxy);
      Resolve_Visibility (Data, C_Overload);
   end Remove_Source;

   ----------------------
   -- Remove_Unit_Part --
   ----------------------

   procedure Remove_Unit_Part
     (Data     : in out View_Data;
      CU       : Name_Type;
      Kind     : Unit_Kind;
      Sep_Name : Optional_Name_Type)
   is
      Cursor : Compilation_Unit_Maps.Cursor;
   begin
      Cursor := Data.CUs.Find (CU);

      if not Compilation_Unit_Maps.Has_Element (Cursor) then
         return;
      end if;

      Data.CUs.Reference (Cursor).Remove (Kind, Sep_Name);

      if Data.CUs.Reference (Cursor).Is_Empty then
         Data.CUs.Delete (Cursor);
      end if;

      if Kind = S_Separate then
         declare
            Full_Name : constant Name_Type :=
                          GPR2."&" (GPR2."&" (CU, "."), Sep_Name);
         begin
            Data.Separates.Delete (Full_Name);
         end;
      end if;
   end Remove_Unit_Part;

   ------------------------
   -- Resolve_Visibility --
   ------------------------

   procedure Resolve_Visibility
     (Data   : in out View_Data;
      Cursor : in out Basename_Source_List_Maps.Cursor)
   is
      use type Ada.Containers.Count_Type;
      use type Project.View.Object;
      use type Source_Reference.Value.Object;

      procedure Propagate_Visible_Source_Removal (Src : Source_Proxy);
      procedure Propagate_Visible_Source_Added (Src : Source_Proxy);

      ------------------------------------
      -- Propagate_Visible_Source_Added --
      ------------------------------------

      procedure Propagate_Visible_Source_Added (Src : Source_Proxy) is
         View_Db  : constant View_Data_Ref :=
                      Get_Data (Data.Tree_Db, Src.View);
         Src_Info : constant Source_Info.Object :=
                      View_Db.Src_Infos (Src.Path_Name);

      begin
         if Data.View.Is_Extended then
            Add_Source
              (Get_Data (Data.Tree_Db, Data.View.Extending),
               Src.View,
               Src.Path_Name,
               Extended_View   => Data.View,
               Aggregated_View => Project.View.Undefined);
         end if;

         if Src_Info.Has_Units
           and then not Data.View.Is_Extended
         then
            --  Update unit information. Note that we do that on "final"
            --  views only, so not if the view is extended or aggregated in
            --  a library, since that's the extending or aggregating lib
            --  that will have the full picture on what is visible or not.

            for U of Src_Info.Units loop
               for Root of Src.View.Namespace_Roots loop
                  Add_Unit_Part
                    (Data     => Get_Data (Data.Tree_Db, Root),
                     CU       => U.Unit_Name,
                     Kind     => U.Kind,
                     Sep_Name => U.Separate_Name,
                     View     => Data.View,
                     Path     => Src_Info.Path_Name,
                     Index    => U.Index);
               end loop;
            end loop;
         end if;
      end Propagate_Visible_Source_Added;

      --------------------------------------
      -- Propagate_Visible_Source_Removal --
      --------------------------------------

      procedure Propagate_Visible_Source_Removal (Src : Source_Proxy) is
         View_Db  : constant View_Data_Ref :=
                      Get_Data (Data.Tree_Db, Src.View);
         Src_Info : constant Source_Info.Object :=
                      View_Db.Src_Infos (Src.Path_Name);

      begin
         if Src_Info.Has_Units
           and then not Data.View.Is_Extended
         then
            for U of Src_Info.Units loop
               for Root of Src.View.Namespace_Roots loop
                  Remove_Unit_Part
                    (Get_Data (Data.Tree_Db, Root),
                     CU       => U.Unit_Name,
                     Kind     => U.Kind,
                     Sep_Name => U.Separate_Name);
               end loop;
            end loop;
         end if;

         if Data.View.Is_Extended then
            Remove_Source
              (Get_Data (Data.Tree_Db, Data.View.Extending),
               Src.View,
               Src.Path_Name);
         end if;
      end Propagate_Visible_Source_Removal;

      Tree      : constant access Project.Tree.Object := Data.View.Tree;
      Basename  : constant Simple_Name :=
                    Basename_Source_List_Maps.Key (Cursor);
      Set       : constant Source_Proxy_Sets.Set :=
                    Basename_Source_List_Maps.Element (Cursor);
      Candidate : Source_Proxy;
      Current   : Source_Proxy;
      C_Src     : Basename_Source_Maps.Cursor :=
                    Data.Sources.Find (Basename);
      C_Info    : Src_Info_Maps.Cursor;
      C_Info2   : Src_Info_Maps.Cursor;
      SR1, SR2  : Source_Reference.Value.Object;

   begin
      if Set.Is_Empty then
         --  no source for the specified basenamne

         Candidate := No_Proxy;

      elsif Set.Length = 1 then
         --  Only one source in the set: just use it

         Candidate := Source_Proxy_Sets.Element (Set.First);

      elsif Data.View.Kind = K_Aggregate_Library then
         --  at least two sources with the same basename: error

         Data.View.Tree.Append_Message
           (Message.Create
              (Level   => Message.Warning,
               Message => Set.Length'Image & " sources with the same base " &
                          "name """ & String (Basename) &
                          """: cannot aggregate in the same library",
               Sloc    => Source_Reference.Create
                 (Data.View.Path_Name.Value, 0, 0)));

         for Proxy of Set loop
            Data.View.Tree.Append_Message
              (Message.Create
                 (Message.Warning,
                  Proxy.Path_Name.Value,
                  Sloc => Source_Reference.Create
                    (Proxy.View.Path_Name.Value, 0, 0)));
         end loop;

         Candidate := No_Proxy;

      else
         --  project extension case, or the same basename is found in
         --  different source dirs

         for C of Set loop
            if Candidate = No_Proxy then
               --  First value, consider it as a candidate

               Candidate := C;

               if Candidate.View = Data.View then
                  --  Own source, get Src_Info cursor
                  C_Info := Data.Src_Infos.Find (Candidate.Path_Name);
               end if;

            elsif C.View = Data.View
              and then Candidate.View /= Data.View
            then
               --  Candidate was inherited: own source overrides it
               Candidate := C;
               C_Info    := Data.Src_Infos.Find (Candidate.Path_Name);

            elsif Candidate.View = Data.View
              and then C.View /= Data.View
            then
               --  Candidate is owned by current view, so ignore inherited
               --  source
               null;

            elsif C.View = Data.View then
               --  Both candidates are owned by the view, check
               --  Source_Reference.

               C_Info2 := Data.Src_Infos.Find (C.Path_Name);

               SR1 := Src_Info_Maps.Element (C_Info).Source_Reference;
               SR2 := Src_Info_Maps.Element (C_Info2).Source_Reference;

               if SR1 = SR2 then
                  Tree.Append_Message
                    (Message.Create
                       (Message.Error,
                        '"' & String (Basename) & '"' &
                          " is found in several source directories",
                        SR1));

                  Candidate := No_Proxy;

                  exit;

               elsif SR2 < SR1 then
                  --  Source_Ref of C2 is declared before the one of
                  --  Candidate, so takes precedence.

                  Candidate := C;
                  C_Info := C_Info2;
               end if;

            else
               --  Remaining case: inheritance shows two candidate sources

               --  ??? We should raise an error only if those candidates are
               --  not overloaded by the View

               Tree.Append_Message
                 (Message.Create
                    (Message.Error,
                     '"' & String (Basename) & '"' &
                       " is found in several extended projects",
                     Source_Reference.Create
                       (Data.View.Path_Name.Value, 0, 0)));
               Tree.Append_Message
                 (Message.Create
                    (Message.Error,
                     C.Path_Name.Value,
                     Source_Reference.Create
                       (C.View.Path_Name.Value, 0, 0),
                     Indent => 1));
               Tree.Append_Message
                 (Message.Create
                    (Message.Error,
                     Candidate.Path_Name.Value,
                     Source_Reference.Create
                       (Candidate.View.Path_Name.Value, 0, 0),
                     Indent => 1));

               Candidate := No_Proxy;

               exit;

            end if;
         end loop;
      end if;

      if Basename_Source_Maps.Has_Element (C_Src) then
         Current := Basename_Source_Maps.Element (C_Src);
      else
         Current := No_Proxy;
      end if;

      if Current /= Candidate then
         --  Remove current visible source
         if Current /= No_Proxy then
            Propagate_Visible_Source_Removal (Current);

            if Candidate = No_Proxy then
               Data.Sources.Delete (C_Src);
            end if;
         end if;

         if Candidate /= No_Proxy then
            if Current = No_Proxy then
               Data.Sources.Insert (Basename, Candidate);
            else
               Data.Sources.Replace_Element (C_Src, Candidate);
            end if;

            Propagate_Visible_Source_Added (Candidate);
         end if;
      end if;
   end Resolve_Visibility;

   package body Update_Sources_List is separate;

end GPR2.Build.View_Tables;

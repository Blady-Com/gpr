------------------------------------------------------------------------------
--                                                                          --
--                             GPR TECHNOLOGY                               --
--                                                                          --
--                       Copyright (C) 2017, AdaCore                        --
--                                                                          --
-- This is  free  software;  you can redistribute it and/or modify it under --
-- terms of the  GNU  General Public License as published by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for more details.  You should have received  a copy of the  GNU  --
-- General Public License distributed with GNAT; see file  COPYING. If not, --
-- see <http://www.gnu.org/licenses/>.                                      --
--                                                                          --
------------------------------------------------------------------------------

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.Command_Line;
with GNAT.Exception_Traces;
with GNAT.OS_Lib;
with GNAT.Traceback.Symbolic;

with GPR.Opt;
with GPR.Util;
with GPR_Version;

with GPR2.Compilation.Protocol;
with GPR2.Compilation.Slave;
with GPR2.Compilation.Sync;
with GPR2.Context;
with GPR2.Project.Tree;

procedure GPRremote is

   use Ada;
   use Ada.Exceptions;
   use Ada.Strings.Unbounded;
   use Ada.Text_IO;

   use GPR2;

   use type GNAT.OS_Lib.String_Access;

   procedure Parse_Command_Line;
   --  Parse command line parameters

   procedure Activate_Symbolic_Traceback;
   --  Activate symbolic trace-back

   procedure Cmd_Info;

   procedure Cmd_Exec;

   procedure Cmd_Syncto;

   procedure Cmd_Syncfrom;

   procedure Cmd_Sync_Exec is null;

   Arg_Host         : constant := 1;
   Arg_Cmd          : constant := 2;
   Arg_Project      : constant := 3;
   Arg_First_Option : constant := 4;

   Help    : aliased Boolean := False;
   Verbose : aliased Boolean := False;
   Version : aliased Boolean := False;
   Args    : array (1 .. Command_Line.Argument_Count) of Unbounded_String;
   Last    : Natural := 0;

   Exit_Status : Natural := 0;
   --  GPRremote's exit status

   Project : GPR2.Project.Tree.Object;

   procedure Load_Project (Filename : String);
   --  Load a project file

   ---------------------------------
   -- Activate_Symbolic_Traceback --
   ---------------------------------

   procedure Activate_Symbolic_Traceback is
      use GNAT;
   begin
      Exception_Traces.Trace_On (Exception_Traces.Unhandled_Raise);
      Exception_Traces.Set_Trace_Decorator
        (Traceback.Symbolic.Symbolic_Traceback'Access);
   end Activate_Symbolic_Traceback;

   --------------
   -- Cmd_Exec --
   --------------

   procedure Cmd_Exec is
      use all type Compilation.Protocol.Command_Kind;

      Host         : constant String := To_String (Args (Arg_Host));
      Project_Name : constant String := To_String (Args (Arg_Project));
      Channel      : Compilation.Protocol.Communication_Channel;
      Root_Dir     : Unbounded_String;

      function Filter_Path
        (O   : String;
         Sep : String := Compilation.Protocol.WD_Path_Tag) return String;
      --  Make O PATH relative to RD. For option -gnatec and -gnatem makes
      --  the specified filename absolute in the slave environment and send
      --  the file to the slave.

      -----------------
      -- Filter_Path --
      -----------------

      function Filter_Path
        (O   : String;
         Sep : String := Compilation.Protocol.WD_Path_Tag) return String
      is
         RD  : constant String := To_String (Root_Dir);
         Pos : constant Natural := Strings.Fixed.Index (O, RD);
      begin
         if Pos = 0 then
            return O;
         else
            return O (O'First .. Pos - 1)
              & Sep & Filter_Path (O (Pos + RD'Length + 1 .. O'Last));
         end if;
      end Filter_Path;

      Options : GNAT.OS_Lib.Argument_List (1 .. Last - Arg_First_Option + 1);

   begin
      Load_Project (Project_Name);

      Root_Dir := To_Unbounded_String
        (Compilation.Slave.Remote_Root_Directory (Project.Root_Project));

      Compilation.Slave.Register_Remote_Slaves
        (Project, Synchronize => False);

      --  Get the channel for the given host

      Channel := Compilation.Slave.Channel (Host);

      --  Set options

      for K in Arg_First_Option .. Last loop
         Options (K - Arg_First_Option + 1) :=
           new String'(To_String (Args (K)));
      end loop;

      --  Send sync command to slave

      Compilation.Protocol.Send_Exec
        (Channel,
         Project_Name,
         ".",
         Language => "",
         Options  => Options,
         Obj_Name => "",
         Dep_Name => "",
         Env      => "",
         Filter   => Filter_Path'Access);

      --  Clear options

      for K in Options'Range loop
         GNAT.OS_Lib.Free (Options (K));
      end loop;

      Wait_Ack : declare
         Cmd : constant Compilation.Protocol.Command :=
                 Compilation.Protocol.Get_Command (Channel);
      begin
         if Cmd.Kind = AK then
            null;
         else
            raise Compilation.Protocol.Wrong_Command
              with "expected AK command, found " & Cmd.Kind'Img;
         end if;
      end Wait_Ack;

      --  In this mode the output will be sent first

      declare
         Cmd : constant Compilation.Protocol.Command :=
                 Compilation.Protocol.Get_Command (Channel);
      begin
         if Cmd.Kind = DP then
            Put_Line (To_String (Cmd.Output));
         else
            raise Compilation.Protocol.Wrong_Command
              with "expected DP command, found " & Cmd.Kind'Img;
         end if;
      end;

      --  And then a KO or OK depending on the exit status of the remote
      --  command is sent.

      declare
         Cmd : constant Compilation.Protocol.Command :=
                 Compilation.Protocol.Get_Command (Channel);
      begin
         if Cmd.Kind in OK then
            null;
         elsif Cmd.Kind = KO then
            Exit_Status := 1;
         else
            raise Compilation.Protocol.Wrong_Command
              with "expected OK/NOK command, found " & Cmd.Kind'Img;
         end if;
      end;

      Compilation.Slave.Unregister_Remote_Slaves;
   end Cmd_Exec;

   --------------
   -- Cmd_Info --
   --------------

   procedure Cmd_Info is
      use all type Compilation.Protocol.Command_Kind;

      Host    : constant String := To_String (Args (Arg_Host));
      Channel : Compilation.Protocol.Communication_Channel;

      Version_String   : Unbounded_String;
      Current_UTC_Time : GPR.Stamps.Time_Stamp_Type;
      GPR_Hash         : Unbounded_String;
      Success          : Boolean;
   begin
      Load_Project (To_String (Args (Arg_Project)));

      GPR2.Compilation.Slave.Register_Remote_Slaves
        (Project, Synchronize => False);

      --  Get the channel for the given host

      Channel := Compilation.Slave.Channel (Host);

      Compilation.Protocol.Send_Info_Request (Channel);

      Compilation.Protocol.Get_Info_Response
        (Channel, Version_String, Current_UTC_Time, GPR_Hash, Success);

      if Success then
         Put_Line ("version  : " & To_String (Version_String));
         Put_Line ("UTC time : " & String (Current_UTC_Time));

      else
         raise Compilation.Protocol.Wrong_Command
           with "cannot get information from slave";
      end if;

      Compilation.Slave.Unregister_Remote_Slaves;
   end Cmd_Info;

   ------------------
   -- Cmd_Syncfrom --
   ------------------

   procedure Cmd_Syncfrom is

      procedure Output (Message : String);

      ------------
      -- Output --
      ------------

      procedure Output (Message : String) is
      begin
         Text_IO.Put_Line (Message);
         Text_IO.Flush;
      end Output;

      Host    : constant String := To_String (Args (Arg_Host));
      Channel : Compilation.Protocol.Communication_Channel;
      Result  : Compilation.Protocol.Command_Kind with Unreferenced;

      Total_File        : Natural;
      Total_Transferred : Natural;
      Remote_Files      : Compilation.Sync.Files.Set;

   begin
      Load_Project (To_String (Args (Arg_Project)));

      GPR2.Compilation.Slave.Register_Remote_Slaves
        (Project, Synchronize => False);

      --  Get the channel for the given host

      Channel := Compilation.Slave.Channel (Host);

      --  Send sync command to slave

      Compilation.Protocol.Send_Sync_Request (Channel);

      --  Wait back for the files

      Result := Compilation.Sync.Receive_Files
        (Channel,
         Compilation.Slave.Remote_Root_Directory (Project.Root_Project),
         Total_File,
         Total_Transferred,
         Remote_Files,
         False, Output'Access);

      Compilation.Slave.Unregister_Remote_Slaves;
   end Cmd_Syncfrom;

   ----------------
   -- Cmd_Syncto --
   ----------------

   procedure Cmd_Syncto is
   begin
      Load_Project (To_String (Args (Arg_Project)));

      Compilation.Slave.Register_Remote_Slaves
        (Project, Synchronize => True);
      Compilation.Slave.Unregister_Remote_Slaves;
   end Cmd_Syncto;

   ------------------
   -- Load_Project --
   ------------------

   procedure Load_Project (Filename : String) is
      Pathname : constant GPR2.Path_Name_Type :=
                   GPR2.Create (GPR2.Optional_Name_Type (Filename));
      Context  : GPR2.Context.Object;
   begin
      if Verbose then
         Put_Line ("loading project: " & GPR2.Value (Pathname));
      end if;

      Project.Load (Pathname, Context);
   end Load_Project;

   ------------------------
   -- Parse_Command_Line --
   ------------------------

   procedure Parse_Command_Line is
      use GNAT.Command_Line;
      use GNAT.OS_Lib;
      use GPR.Util;

      procedure Usage;

      procedure Check_Version_And_Help is new
        Check_Version_And_Help_G (Usage);

      Config : Command_Line_Configuration;

      -----------
      -- Usage --
      -----------

      procedure Usage is
      begin
         Display_Help (Config);
      end Usage;

   begin
      Define_Switch
        (Config, Help'Access,
         "-h", Long_Switch => "--help",
         Help => "display this help message and exit");

      Define_Switch
        (Config, Version'Access,
         "-V", Long_Switch => "--version",
         Help => "display version and exit");

      Define_Switch
        (Config, Verbose'Access,
         "-v", Long_Switch => "--verbose",
         Help => "verbose mode, display extra information");

      Set_Usage (Config, Usage => "[switches] [host] [command] [parameters]");

      Check_Version_And_Help
        ("GPRREMOTE",
         "2017",
         Version_String => GPR_Version.Gpr_Version_String);

      Getopt (Config);

      --  Now read arguments

      Read_Arguments : loop
         declare
            Arg : constant String := Get_Argument;
         begin
            exit Read_Arguments when Arg = "";

            Last := Last + 1;
            Args (Last) := To_Unbounded_String (Arg);
         end;
      end loop Read_Arguments;

   exception
      when Invalid_Switch =>
         OS_Exit (1);

      when Exit_From_Command_Line =>
         OS_Exit (1);
   end Parse_Command_Line;

begin
   Parse_Command_Line;

   Activate_Symbolic_Traceback;

   --  Set corresponding slave environment

   if GPR.Util.Slave_Env = null then
      GPR.Util.Slave_Env := new String'
        (Compilation.Slave.Compute_Env (Project, GPR.Util.Slave_Env_Auto));

      if GPR.Util.Slave_Env_Auto and not GPR.Opt.Quiet_Output then
         Put ("slave environment is ");
         Put (GPR.Util.Slave_Env.all);
         New_Line;
      end if;
   end if;

   declare
      Host    : constant String := To_String (Args (Arg_Host));
      Command : constant String := To_String (Args (Arg_Cmd));
   begin
      --  First connect to the host

      Compilation.Slave.Record_Slaves (Host);

      if Command = "info" then
         Cmd_Info;

      elsif Command = "exec" then
         Cmd_Exec;

      elsif Command = "syncto" then
         Cmd_Syncto;

      elsif Command = "syncfrom" then
         Cmd_Syncfrom;

      elsif Command = "syncexec" then
         Cmd_Sync_Exec;

      else
         Put_Line ("GPRremote: unknown command '" & Command & ''');
      end if;
   end;

   GNAT.OS_Lib.OS_Exit (Exit_Status);

exception
   when E : others =>
      Put_Line
        ("Unrecoverable error in GPRremote :" & Exception_Information (E));
      GNAT.OS_Lib.OS_Exit (1);
end GPRremote;

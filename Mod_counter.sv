module counter(clk,rst,mode,load,data_in,data_out);
input clk,rst,load,mode;
input [3:0]data_in;
input d_in;
output reg [3:0]data_out;
always@(posedge clk)
 begin
 if(rst)
   data_out <= 4'd0;
     else if(load)
      data_out <= data_in;
      else if(mode)
       begin
         if(data_out == 4'd11)
          data_out <= 4'd0;
          else
           data_out <= data_out +1;
           end
         else
        begin
      if(data_out ==4'd0)
    data_out <= 4'd11;
else
 data_out <= data_out -1;
end
end
endmodule

//Package
package pkg;
int no_of_transactions =5;
endpackage

//Interface
interface count_if(input bit clk);
//logic rst,load,mode;
logic [3:0]data_in,data_out;

//clocking block for write Driver
clocking wr_drv@(posedge clk);
default input #1 output #1;
output rst;
output load;
output mode;
output data_in;
endclocking :wr_drv

//Clocking block for Write Monitor
clocking wr_mon@(posedge clk);
default input #1 output #1;
input rst;
input load;
input mode;
input data_in;
endclocking :wr_mon

//Clocking block for read monitior
clocking rd_mon@(posedge clk);
default input #1 output #1;
input data_out;
endclocking : rd_mon

// Modports Declaration for Write Driver ,REad Monitor and write Monitor
modport WR_DRV_MP(clocking wr_drv);
modport WR_MON_MP(clocking wr_mon);
modport RD_MON_MP(clocking rd_mon);
endinterface: count_if


//Class transaction
class count_trans;
rand bit rst,load,mode;
rand bit [3:0]data_in;
logic [3:0]data_out; 
constraint c1{rst dist{0:=10,1:=1};} 
constraint c2{load dist{0:=4,1:=1};}
constraint c3{mode dist{0:=10,1:=10};}
constraint c4{data_in inside{[1:10]};}


function void display(input string s);
$display("\n///////////////////////////////////////////////////////////");
$display("\n Input String Message : %s",s);
$display("\nrst : %0d",rst);
$display("\nload : %0d",load);
$display("\nmode : %0d",mode);
$display("\ndata_in : %0d",data_in);
$display("\ndata_out : %0d",data_out);
$display("\n///////////////////////////////////////////////////////////");
endfunction : display

function void post_randomize();
display("Randomization Completed");
endfunction : post_randomize
endclass

//Generator
class count_gen;
count_trans gen_trans;
count_trans data2send;

mailbox #(count_trans) gen2wr;

 function new( mailbox #(count_trans) gen2wr);
      this.gen2wr    = gen2wr;
       this.gen_trans = new;

   endfunction: new

virtual task start;
fork
begin
for(int i=0;i<no_of_transactions;i++)
 begin
 assert(gen_trans.randomize());
data2send = new gen_trans;
gen2wr.put(data2send);
end
end
join_none
endtask:start
endclass

//Write_driver
class count_drv;
virtual count_if.WR_DRV_MP wr_drv_vif;
count_trans data2duv = new();//changes made for object
mailbox #(count_trans) gen2wr;

function new(virtual count_if.WR_DRV_MP wr_drv_vif,
                mailbox #(count_trans) gen2wr);
      this.wr_drv_vif = wr_drv_vif;
      this.gen2wr   = gen2wr;
   endfunction: new
   
   virtual task drive;
   @(wr_drv_vif.wr_drv);
   begin
	wr_drv_vif.wr_drv.rst <= data2duv.rst;
	wr_drv_vif.wr_drv.mode    <= data2duv.mode;
	 wr_drv_vif.wr_drv.load    <= data2duv.load;
	 wr_drv_vif.wr_drv.data_in    <= data2duv.data_in;
	 end
	 endtask: drive
virtual task start();
fork
forever
begin
gen2wr.get(data2duv);
drive();
end
join_none
endtask
endclass

//Write Monitor

class count_wr_mon;
virtual count_if.WR_MON_MP wr_mon_vif;
count_trans data2rm;
mailbox #(count_trans) wr2rm;
 function new(virtual count_if.WR_MON_MP wr_mon_vif,
                mailbox #(count_trans) wr2rm);
      this.wr_mon_vif = wr_mon_vif;
      this.wr2rm    = wr2rm;
      this.data2rm    = new();
   endfunction: new

 task monitor;
      @(wr_mon_vif.wr_mon);
	  begin
    data2rm.rst = wr_mon_vif.wr_mon.rst;
    data2rm.load = wr_mon_vif.wr_mon.load;
repeat(10) data2rm.mode = wr_mon_vif.wr_mon.mode;
data2rm.data_in = wr_mon_vif.wr_mon.data_in;
data2rm.display("\nData from Write Monitor");
end
endtask: monitor

task start;
fork
forever
begin
monitor();
wr2rm.put(data2rm);
end
join_none
endtask: start
endclass

//read_monitor

class count_rd_mon;
virtual count_if.RD_MON_MP rd_mon_vif;
count_trans data2rm;
count_trans data2sb;
//mailbox#(transaction) mon2rm;
mailbox #(count_trans) mon2sb;

function new(virtual count_if.RD_MON_MP rd_mon_vif,
            mailbox #(count_trans) mon2sb);
	this.rd_mon_vif = rd_mon_vif;
//this.mon2rm = mon2rm;
this.mon2sb = mon2sb;
this.data2rm = new();
endfunction: new

task monitor;
@(rd_mon_vif.rd_mon);
begin
data2rm.data_out = rd_mon_vif.rd_mon.data_out;
data2rm.display("\nData from Read Monitor");
end
endtask: monitor

task start;
fork
   begin
    forever
     begin
      monitor();
       data2sb = new data2rm;
        mon2sb.put(data2sb);
        end
    end
join_none
endtask: start
endclass

//reference model

class count_ref_mod;

count_trans mon_data= new(); //changes made for object

mailbox #(count_trans) wr2rm;
mailbox #(count_trans) rm2sb;	

function new(mailbox #(count_trans) wr2rm,
            mailbox #(count_trans) rm2sb);
	this.wr2rm = wr2rm;
    this.rm2sb = rm2sb;
endfunction: new

task counter(count_trans mon_data);
begin
  if(mon_data.rst)
  mon_data.data_out <= 4'd0;
  else if(mon_data.load)
     mon_data.data_out <= mon_data.data_in;
	 else if(mon_data.mode)
	 begin
	if(mon_data.data_out == 4'd11)
	mon_data.data_out <=  4'd0;
	else
	mon_data.data_out <= mon_data.data_out + 1;
	end
	else
	begin
	if(mon_data.data_out == 4'd0)
	mon_data.data_out <= 4'd11;
	else
	mon_data.data_out <= mon_data.data_out - 1;
	end
	end
	endtask: counter

task start;
fork
  begin
   forever
    begin
     counter(mon_data);
wr2rm.get(mon_data);
rm2sb.put(mon_data);
end
end
join_none
endtask : start
endclass

//Scoreboard
class count_sb;

event DONE;

int data_verified = 0;
   int rm_data_count = 0;
   int mon_data_count = 0;

count_trans rmdata,sbdata,cov_data;

mailbox #(count_trans) rm2sb;
mailbox #(count_trans) rd2sb;

function new(mailbox #(count_trans) rm2sb,
mailbox #(count_trans) rd2sb);
this.rm2sb = rm2sb;
this.rd2sb = rd2sb;
coverage = new();
endfunction: new

//Coverage code

covergroup coverage;
RST : coverpoint cov_data.rst;
MODE : coverpoint cov_data.mode;
LOAD : coverpoint cov_data.load;
DATA_IN  : coverpoint cov_data.data_in{bins a= {[1:10]};}
endgroup: coverage

task start;
fork
while(1)
begin
rm2sb.get(rmdata);
rm_data_count++;
rd2sb.get(sbdata);
mon_data_count++;
check(sbdata);
end
join_none
endtask: start

virtual task check(count_trans rddata);
if(rmdata.data_out == rddata.data_out)
$display("\Data Verified");
else
$display("\Data Mismatch");
//shallow copy
cov_data= new rmdata;
coverage.sample();
data_verified++; 
if(data_verified == no_of_transactions)
begin
->DONE;
end
endtask : check

 function void report();
      $display(" ------------------------ SCOREBOARD REPORT ----------------------- \n ");
      $display(" %0d Read Data Generated, %0d Read Data Recevied, %0d Read Data Verified \n",
                                             rm_data_count,mon_data_count,data_verified);
      $display(" -----------------------SCOREBOARD REPORT------------------------------------------- \n ");
       endfunction: report

endclass 

//Environment

class count_env;

   virtual count_if.WR_DRV_MP wr_drv_vif;
   virtual count_if.WR_MON_MP wr_mon_vif;
   virtual count_if.RD_MON_MP rd_mon_vif;
   
    mailbox #(count_trans) gen2wr = new();
	mailbox #(count_trans) wr2rm = new();
	mailbox #(count_trans) mon2sb = new();
    mailbox #(count_trans) rm2sb = new();
		 
   count_gen       gen_h;
   count_drv       wr_drv_h;
   count_wr_mon   wr_mon_h;
   count_rd_mon   rd_mon_h;
   count_ref_mod      ref_mod_h;
   count_sb         sb_h;
   
   function new(virtual count_if.WR_DRV_MP wr_drv_vif,
   virtual count_if.WR_MON_MP wr_mon_vif,
   virtual count_if.RD_MON_MP rd_mon_vif);
      this.wr_drv_vif = wr_drv_vif;
      this.wr_mon_vif = wr_mon_vif;
      this.rd_mon_vif = rd_mon_vif;
	endfunction : new

task build;
       gen_h      = new(gen2wr);
      wr_drv_h   = new(wr_drv_vif,gen2wr);
      wr_mon_h   = new(wr_mon_vif,wr2rm);
      rd_mon_h   = new(rd_mon_vif,mon2sb);
      ref_mod_h  = new(wr2rm, rm2sb);
      sb_h       = new(rm2sb,mon2sb);
   endtask: build
	
    task start;
      gen_h.start();
      wr_drv_h.start();
      wr_mon_h.start();
      rd_mon_h.start();
      ref_mod_h.start();
      sb_h.start();
   endtask: start
   
     task stop;
      wait(sb_h.DONE.triggered);
   endtask: stop
   
     task run;
      start();
      stop();
      sb_h.report();
   endtask
endclass

import pkg::*;

class count_trans_extnd1 extends count_trans;
constraint random_data1 {rst == 1;}
endclass: count_trans_extnd1

class testcase;
 virtual count_if.WR_DRV_MP wr_drv_vif;
   virtual count_if.WR_MON_MP wr_mon_vif;
   virtual count_if.RD_MON_MP rd_mon_vif;
   count_env env_h;
   
 function new(virtual count_if.WR_DRV_MP wr_drv_vif,
   virtual count_if.WR_MON_MP wr_mon_vif,
   virtual count_if.RD_MON_MP rd_mon_vif);
      this.wr_drv_vif = wr_drv_vif;
      this.wr_mon_vif = wr_mon_vif;
      this.rd_mon_vif = rd_mon_vif;
	  env_h = new(wr_drv_vif,wr_mon_vif,rd_mon_vif);
	endfunction : new 
	
/*	task build_and_run;
	   no_of_transactions = 10;
               env_h.build();
               env_h.run();
               $finish;
            endtask : build_and_run*/

task build();
no_of_transactions = 10;
env_h.build();
endtask:build

task run();
env_h.run();
endtask:run
	endclass : testcase

class count_test_extnd1 extends testcase;
 count_test_extnd1 data_h1;

function new(virtual count_if.WR_DRV_MP wr_drv_vif,
   virtual count_if.WR_MON_MP wr_mon_vif,
   virtual count_if.RD_MON_MP rd_mon_vif);
super.new(wr_drv_vif,wr_mon_vif,rd_mon_vif);
endfunction : new

 task build();
super.build();
endtask: build

task run();
 data_h1 = new();
   env_h.gen_h.gen_trans = data_h1;
super.run();
endtask: run

endclass: count_test_extnd1

//import pkg::*;

module top;
parameter cycle = 10;
bit clk;
count_if DUV_IF(clk);
//declaration of handle for testcase class
testcase test_h;
count_trans_extnd1 ext_test_h1;

counter MOD12(.clk(clk),
          .rst(DUV_IF.rst),.mode(DUV_IF.mode),.load(DUV_IF.load),.data_in(DUV_IF.data_in),.data_out(DUV_IF.data_out));

initial
 begin
  test_h = new(DUV_IF,DUV_IF,DUV_IF);
  test_h.build();
test_h.run();
  end
initial
 begin
  ext_test_h1 = new(DUV_IF,DUV_IF,DUV_IF);
   no_of_transactions = 10;
   ext_test_h1.build();
 ext_test_h1 .run();
end 
  initial
   begin
     clk = 1'b0;
         forever #(cycle/2) clk = ~clk;
      end
	  endmodule : top

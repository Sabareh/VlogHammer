
Vivado handling of partly out-of-bounds parts select
====================================================

~OPEN~ Vivado 2014.2

Consider the following test case:

    :::Verilog
    module issue_057(a, y);
      input [2:0] a;
      output [3:0] y;
      localparam [5:15] p = 51681708;
      assign y = p[15 + a -: 5];
    endmodule

This is expected to set **y[3]=1** for **a=1**, but the vivado 2014.2 synthesis output 
sets **y[3]=0**.

Crosscheck: Verific 35_463_32_140722, Modelsim 10.1e, XSim 2014.2 and Icarus Verilog
(git 1572dcd) implement this correctly. Quartus 14.0 suffers from the same bug.

**History:**  
2014-09-27 [Reported](http://forums.xilinx.com/t5/Synthesis/Vivado-bug-in-handling-of-partly-out-of-bounds-parts-select/td-p/524661) bug in Xilinx Support Forum  

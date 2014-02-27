
Icarus only using the lowest 32 bits of right shift operand
===========================================================

~OPEN~ Icarus GIT ed2e339

The following module should set the output to constant **4'b0000**:

    :::Verilog
    module issue_029(y);
      output [3:0] y;
      assign y = 4'b1 << 33'h100000000;
    endmodule

But Icarus Verilog (git ed2e339) assigns **4'b0001** instead.

**History:**  
2014-02-27 [Reported](https://github.com/steveicarus/iverilog/issues/19) bug on GitHub  


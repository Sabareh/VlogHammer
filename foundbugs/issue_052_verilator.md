
Strange Verilator "Unsupported" Error
=====================================

~OPEN~ Verilator GIT f705f9b

Verilator f705f9b prints "%Error: rtl.v:4: Unsupported: 4-state numbers in this context"
for the following input:

    :::Verilog
    module issue_052(y);
      output [3:0] y;
      assign y = ((0/0) ? 1 : 2) % ^8'b10101010;
    endmodule

The strange part is this: If I change any bit in 8'b10101010 then Verilator accepts the code.

**History:**  
2014-05-24 Reported as [Issue #775](http://www.veripool.org/issues/775-Verilator-Strange-Verilator-Unsupported-Error)

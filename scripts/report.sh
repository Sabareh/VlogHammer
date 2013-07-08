#!/bin/bash
#
#  Vlog-Hammer -- A Verilog Synthesis Regression Test
#
#  Copyright (C) 2013  Clifford Wolf <clifford@clifford.at>
#  
#  Permission to use, copy, modify, and/or distribute this software for any
#  purpose with or without fee is hereby granted, provided that the above
#  copyright notice and this permission notice appear in all copies.
#  
#  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
#  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
#  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
#  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
#  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
#  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

keep=false
if [ "$1" = "-keep" ]; then
	keep=true
	shift
fi

if [ $# -ne 1 ]; then
	echo "Usage: $0 <job_name>" >&2
	exit 1
fi

job="$1"
set -ex --

test -n "$SYN_LIST"
test -n "$SIM_LIST"
test -n "$ISE_SETTINGS"
test -n "$MODELSIM_DIR"

rm -rf temp/report_${job}
mkdir -p temp/report_${job}
cd temp/report_${job}

cp ../../rtl/$job.v rtl.v
cp rtl.v syn_rtl.v

for p in ${SYN_LIST}; do
	cp ../../syn_$p/$job.v syn_$p.v
	cp ../../cache_$p/$job.il syn_$p.il
done

{
	egrep '^ *(module|input|output)' rtl.v | sed 's/ y/ y1, y2/'
	sed "/^ *module/ ! d; s/.*(//; s/[a-w0-9]\+/.\0(\0)/g; s/y[0-9]*/.\0(\01)/g; s/^/  ${job}_1 ${job}_1 (/;" rtl.v
	sed "/^ *module/ ! d; s/.*(//; s/[a-w0-9]\+/.\0(\0)/g; s/y[0-9]*/.\0(\02)/g; s/^/  ${job}_2 ${job}_2 (/;" rtl.v
	echo "endmodule"
} > top.v

echo -n > fail_patterns.txt
for p in ${SYN_LIST} rtl; do
for q in ${SYN_LIST} rtl; do
	if test -f result.${q}.${p}.txt; then
		cp result.${q}.${p}.txt result.${p}.${q}.txt
		continue
	fi

	{
		if [ $p = rtl ]; then
			echo "read_verilog rtl.v"
		else
			echo "read_ilang syn_$p.il"
		fi
		echo "rename $job ${job}_1"

		if [ $q = rtl ]; then
			echo "read_verilog rtl.v"
		else
			echo "read_ilang syn_$q.il"
		fi
		echo "rename $job ${job}_2"

		echo "read_verilog top.v"
		echo "proc; opt_clean"
		echo "flatten ${job}"

		echo "! touch test.$p.$q.input_ok"

		ports=$( grep ^module top.v | tr '()' '::' | cut -f2 -d: | tr -d ' ' )
		echo "sat -timeout 10 -verify-no-timeout -show $ports -prove y1 y2 ${job}"
	} > test.$p.$q.ys

	if yosys -l test.$p.$q.log test.$p.$q.ys; then
		if grep TIMEOUT test.$p.$q.log; then
			echo TIMEOUT > result.${p}.${q}.txt
		else
			echo PASS > result.${p}.${q}.txt
		fi
	else
		echo $( grep '^ *\\[ab][0-9]* ' test.$p.$q.log | gawk '{ print $4; }' | tr -d '\n' ) >> fail_patterns.txt
		echo FAIL > result.${p}.${q}.txt
	fi

	# this fails if an error was encountered before the 'sat' command
	rm test.$p.$q.input_ok
done; done

extra_patterns=""
bits=$( echo $( grep '^ *input' rtl.v | sed 's/.*\[//; s/:.*/+1+/;' )0 | bc; )
inputs=$( echo "{" $( grep '^ *input' rtl.v | sed 's,.* ,,; y/;/,/; s/\n//;' ) "}" | sed 's/, }/ }/;' )
for x in 1 2 3 4 5 6 7 8 9 0; do
	extra_patterns="$extra_patterns $( echo $job$x | sha1sum | gawk "{ print \"160'h\" \$1; }" )"
done

{
	echo "module testbench;"

	sed -r '/^ *input / !d; s/input/reg/;' rtl.v
	for p in ${SYN_LIST} rtl; do
		sed -r "/^ *output / !d; s/output/wire/; s/ y;/ ${p}_y;/;" rtl.v
		sed "/^ *module/ ! d; s/.*(//; s/[a-w0-9]\+/.\0(\0)/g; s/y[0-9]*/.\0(${p}_\0)/g; s/^/  ${job}_$p ${job}_$p (/;" rtl.v
	done

	echo "  initial begin"
	for pattern in $bits\'b0 ~$bits\'b0 $( sort -u fail_patterns.txt | sed "s/^/$bits'b/;" ) $extra_patterns; do
		echo "    $inputs <= $pattern; #1;"
		for p in ${SYN_LIST} rtl; do
			echo "    \$display(\"++RPT++ %b $p\", ${p}_y);"
		done
		echo "    \$display(\"++RPT++ ----\");"
	done
	echo "  end"

	echo "endmodule"

	for p in ${SYN_LIST} rtl; do
		sed "s/^module ${job}/module ${job}_${p}/; /^\`timescale/ d;" < syn_$p.v
	done

	cat ../../scripts/cells_cyclone_iii.v
	cat ../../scripts/cells_xilinx_7.v
} > testbench.v

{
	echo "module ${job}_tb;"
	sed -r '/^ *input / !d; s/input/reg/;' rtl.v
	sed -r "/^ *output / !d; s/output/wire/;" rtl.v
	sed "/^ *module/ ! d; s/.*(/  ${job} uut (/;" rtl.v

	echo "  task test_pattern;"
	echo "    input [$bits-1:0] pattern;"
	echo "    begin"
	echo "      $inputs <= pattern; #1;"
	echo "      \$display(\"++RPT++ %b\", y);"
	echo "    end"
	echo "  endtask"

	echo "  initial begin"
	for pattern in $bits\'b0 ~$bits\'b0 $( sort -u fail_patterns.txt | sed "s/^/$bits'b/;" ) $extra_patterns; do
		echo "    test_pattern( $pattern );"
	done
	echo "  end"
	echo "endmodule"
} > simple_tb.v

if [[ " ${SIM_LIST} " == *" isim "* ]]; then
	(
	set +x
	. ${ISE_SETTINGS}
	set -x
	vlogcomp testbench.v
	fuse -o testbench testbench
	{ echo "run all"; echo "exit"; } > run-all.tcl
	./testbench -tclbatch run-all.tcl | tee sim_isim.log
	)
fi

if [[ " ${SIM_LIST} " == *" modelsim "* ]]; then
	${MODELSIM_DIR}/vlib work
	${MODELSIM_DIR}/vlog testbench.v
	${MODELSIM_DIR}/vsim -c -do "run; exit" work.testbench | tee sim_modelsim.log
fi

if [[ " ${SIM_LIST} " == *" icarus "* ]]; then
	iverilog testbench.v
	./a.out | tee sim_icarus.log
fi

for p in ${SYN_LIST} rtl; do
for q in ${SIM_LIST}; do
	echo $( grep '++RPT++' sim_$q.log | sed 's,.*++RPT++ ,,' | grep " $p\$" | gawk '{ print $1; }' | md5sum | gawk '{ print $1; }' ) > result.${p}.${q}.txt
done; done

echo "#00ff00" > color_PASS.txt
echo "#ff0000" > color_FAIL.txt

if cmp result.rtl.isim.txt result.rtl.modelsim.txt; then
	echo "#00ff00" > color_$( cat result.rtl.isim.txt ).txt
else
	echo "#00ff00" > color_NO_SIM_COMMON.txt
fi

{
	echo "<h3>Vlog-Hammer Report: $job</h3>"
	echo "<table border>"
	echo "<tr><th width=\"100\"></th>"
	for q in ${SYN_LIST} rtl ${SIM_LIST}; do
		echo "<th width=\"100\">$q</th>"
	done
	echo "</tr>"
	for p in ${SYN_LIST} rtl; do
		echo "<tr><th>$p</th>"
		for q in ${SYN_LIST} rtl ${SIM_LIST}; do
			read result < result.${p}.${q}.txt
			if ! test -f color_$result.txt; then
				case $( ls color_*.txt | wc -l ) in
					3) echo "#ffff00" > color_$result.txt ;;
					4) echo "#ff00ff" > color_$result.txt ;;
					5) echo "#00ffff" > color_$result.txt ;;
					*) echo "#888888" > color_$result.txt ;;
				esac
			fi
			echo "<td align=\"center\" bgcolor=\"$( cat color_$result.txt )\">$( echo $result | cut -c1-8 )</td>"
		done
		echo "</tr>"
	done
	echo "<tr><td colspan=\"$( echo left ${SYN_LIST} rtl ${SIM_LIST} | wc -w )\"><pre><small>$( perl -pe 's/([<>&])/"&#".ord($1).";"/eg;' rtl.v <( echo ) simple_tb.v |
			perl -pe 's!([^\w#]|^)([\w'\'']+|\$display|".*?")!$x = $1; $y = $2; sprintf("%s<span style=\"color: %s;\">%s</span>", $x, $y =~ /^[0-9"]/ ? "#663333;" :
			$y =~ /^(module|input|wire|reg|output|assign|signed|begin|end|task|endtask|initial|endmodule|\$display)$/ ? "#008800;" : "#000088;", $y)!eg' )</small></pre></td></tr>"
	echo "</table>"
} > report.html

mkdir -p ../../report
cp report.html ../../report/${job}.html

if ! $keep; then
	rm -rf ../report_${job}
fi
echo READY.


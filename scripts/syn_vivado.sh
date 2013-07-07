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

if [ $# -ne 1 ]; then
	echo "Usage: $0 <job_name>" >&2
	exit 1
fi

job="$1"
set -ex --

test -n "${VIVADO_BIN}"

rm -rf temp/syn_vivado_$job
mkdir -p temp/syn_vivado_$job
cd temp/syn_vivado_$job

sed 's/^module/(* use_dsp48="no" *) module/;' < ../../rtl/$job.v > rtl.v
cat > $job.tcl <<- EOT
	read_verilog rtl.v
	synth_design -part xc7k70t -top $job
	write_verilog -force synth.v
EOT

${VIVADO_BIN} -mode batch -source $job.tcl

mkdir -p ../../syn_vivado
cp synth.v ../../syn_vivado/$job.v

rm -rf ../syn_vivado_$job
echo READY.

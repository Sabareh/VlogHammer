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

SYN_LIST     := vivado quartus xst yosys
SIM_LIST     := isim modelsim icarus
RTL_LIST     := $(shell ls rtl 2> /dev/null | sort -u | cut -f1 -d.)
REPORT_LIST  := $(shell ls check_vivado check_quartus check_xst check_yosys 2> /dev/null | grep '\.err$$' | sort -u | cut -f1 -d.)
ISE_SETTINGS := /opt/Xilinx/14.5/ISE_DS/settings64.sh
MODELSIM_DIR := /opt/altera/13.0/modelsim_ase/bin
QUARTUS_DIR  := /opt/altera/13.0/quartus/bin
VIVADO_BIN   := /opt/Xilinx/Vivado/2013.2/bin/vivado
MAKE_JOBS    := -j4 -l6
REPORT_OPTS  :=

export SYN_LIST SIM_LIST ISE_SETTINGS MODELSIM_DIR QUARTUS_DIR VIVADO_BIN

help:
	@echo ""
	@echo "  make clean  ..............................  remove temp files"
	@echo "  make purge  ..............................  remove results"
	@echo ""
	@echo "  make generate  ...........................  generate rtl files"
	@echo ""
	@echo "  make syn  ................................  run all synthesis"
	@echo "  make syn_vivado  .........................  run only vivado"
	@echo "  make syn_quartus  ........................  run only quartus"
	@echo "  make syn_xst  ............................  run only xst"
	@echo "  make syn_yosys  ..........................  run only yosys"
	@echo ""
	@echo "  make check  ..............................  check all"
	@echo "  make check_vivado  .......................  check only vivado"
	@echo "  make check_quartus  ......................  check only quartus"
	@echo "  make check_xst  ..........................  check only xst"
	@echo "  make check_yosys  ........................  check only yosys"
	@echo ""
	@echo "  make report ..............................  generate reports"
	@echo ""
	@echo ""
	@echo "Example usage:"
	@echo "  make purge generate ONLY_SAMPLES=1"
	@echo "  make -j4 -l6 syn"
	@echo "  make -j4 -l6 check"
	@echo "  make -j4 -l6 report"
	@echo ""

sh:
	FORCE_PS1='<\[\e[1;31m\]VlogHammer\[\e[0m\]> \w\$$ ' bash

world:
	$(MAKE) $(MAKE_JOBS) syn
	$(MAKE) $(MAKE_JOBS) check
	$(MAKE) $(MAKE_JOBS) report

# -------------------------------------------------------------------------------------------

backup:
	mkdir -p ~/.vloghammer
	tar czf ~/.vloghammer/backup_syn.tar.gz syn_*
	tar czf ~/.vloghammer/backup_check.tar.gz check_*
	tar czf ~/.vloghammer/backup_cache.tar.gz cache_*
	tar czf ~/.vloghammer/backup_report.tar.gz report

clean:
	rm -f monitor.html monitor.txt
	rm -rf temp ./scripts/generate

purge: clean
	rm -rf rtl report report.html
	rm -rf syn_vivado syn_quartus syn_xst syn_yosys
	rm -rf check_vivado check_quartus check_xst check_yosys
	rm -rf cache_vivado cache_quartus cache_xst cache_yosys

# -------------------------------------------------------------------------------------------

generate:
ifdef ONLY_SAMPLES
	clang -DONLY_SAMPLES -Wall -Wextra -O2 -o scripts/generate scripts/generate.cc -lstdc++
else
	clang -Wall -Wextra -O2 -o scripts/generate scripts/generate.cc -lstdc++
endif
	./scripts/generate
	cp archive/* rtl/

# -------------------------------------------------------------------------------------------

syn: $(addprefix syn_,$(SYN_LIST))

syn_vivado: $(addprefix syn_vivado/,$(addsuffix .v,$(RTL_LIST)))

ifndef DEPS
syn_vivado/%.v:
else
syn_vivado/%.v: rtl/%.v
endif
	bash scripts/syn_vivado.sh $(notdir $(basename $@))

syn_quartus: $(addprefix syn_quartus/,$(addsuffix .v,$(RTL_LIST)))

ifndef DEPS
syn_quartus/%.v:
else
syn_quartus/%.v: rtl/%.v
endif
	bash scripts/syn_quartus.sh $(notdir $(basename $@))

syn_xst: $(addprefix syn_xst/,$(addsuffix .v,$(RTL_LIST)))

ifndef DEPS
syn_xst/%.v:
else
syn_xst/%.v: rtl/%.v
endif
	bash scripts/syn_xst.sh $(notdir $(basename $@))

syn_yosys: $(addprefix syn_yosys/,$(addsuffix .v,$(RTL_LIST)))

ifndef DEPS
syn_yosys/%.v:
else
syn_yosys/%.v: rtl/%.v
endif
	bash scripts/syn_yosys.sh $(notdir $(basename $@))

# -------------------------------------------------------------------------------------------

check: $(addprefix check_,$(SYN_LIST))

check_vivado: $(addprefix check_vivado/,$(addsuffix .txt,$(RTL_LIST)))

ifndef DEPS
check_vivado/%.txt:
else
check_vivado/%.txt: syn_vivado/%.v
endif
	bash scripts/check.sh vivado $(notdir $(basename $@))

check_quartus: $(addprefix check_quartus/,$(addsuffix .txt,$(RTL_LIST)))

ifndef DEPS
check_quartus/%.txt:
else
check_quartus/%.txt: syn_quartus/%.v
endif
	bash scripts/check.sh quartus $(notdir $(basename $@))

check_xst: $(addprefix check_xst/,$(addsuffix .txt,$(RTL_LIST)))

ifndef DEPS
check_xst/%.txt:
else
check_xst/%.txt: syn_xst/%.v
endif
	bash scripts/check.sh xst $(notdir $(basename $@))

check_yosys: $(addprefix check_yosys/,$(addsuffix .txt,$(RTL_LIST)))

ifndef DEPS
check_yosys/%.txt:
else
check_yosys/%.txt: syn_yosys/%.v
endif
	bash scripts/check.sh yosys $(notdir $(basename $@))

# -------------------------------------------------------------------------------------------

report: $(addprefix report/,$(addsuffix .html,$(REPORT_LIST)))
	-cat report/* > report.html

ifndef DEPS
report/%.html:
else
report/%.html: $(addprefix check_,$(addsuffix /%.txt,$(SYN_LIST)))
endif
	bash scripts/report.sh $(REPORT_OPTS) $(notdir $(basename $@))

# -------------------------------------------------------------------------------------------

.PHONY: help sh world backup clean purge generate report
.PHONY: syn syn_vivado syn_quartus syn_xst syn_yosys
.PHONY: check check_vivado check_quartus check_xst check_yosys

.PRECIOUS: rtl/%.v report/%.html
.PRECIOUS: syn_vivado/%.v syn_quartus/%.v syn_xst/%.v syn_yosys/%.v
.PRECIOUS: check_vivado/%.txt check_quartus/%.txt check_xst/%.txt check_yosys/%.txt


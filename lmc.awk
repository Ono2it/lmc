#  http://en.wikipedia.org/wiki/Little_man_computer
#
#  Copyright (C) 2015 Anton Onopko
# 
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

BEGIN {

	MAXMEM = 100	# Memory size
	MAXINSTR = 999	# Max instruction value

	commands["HLT"] = 000
	commands["ADD"] = 100
	commands["SUB"] = 200
	commands["STA"] = 300
	commands["LDA"] = 500
	commands["BRA"] = 600
	commands["BRZ"] = 700
	commands["BRP"] = 800
	commands["INP"] = 901
	commands["OUT"] = 902

	errors["NONE"] = "No errors"
	errors["NPRG"] = "No program code"
       	errors["BPRG"] = "Program too big"
	errors["ICOD"] = "Invalid code"	
	errors["IINP"] = "Invalid input"
	errors["ICMD"] = "Invalid command"
	errors["OVER"] = "Overflow"
	errors["ULBL"] = "Label not defined"
	errors["RLBL"] = "Label redefined"
	errors["FRED"] = "File read error"

	init_memory()
	
}

function set_error(code) { _error = code }
function get_error() { return _error }

function error(code,text) {
	if (code in errors) {
		if (text) {
			print errors[code] ": " text
		} else {
			print errors[code]
		}
	} else {
		print code ": " text
	}
	set_error(code)
}

#Init computer memory
function init_memory( i) {
	set_error("NONE")
	for(i=0;i < MAXMEM;i++) {
		mem[i] = commands["HLT"];
	}
}

#Dump memory
function dump( i) {
	for(i=0;i < MAXMEM;i++) {
		if ((i % 10) == 0 )  printf "%02d:",i 
		printf " %3d",mem[i]
		if ((i % 10) == 9 ) printf "\n"
	}
}

function code_valid(code) {
	return ((code ~/[0-9]+/) && (0+code<= MAXINSTR) )
}

#Load program from text
#Text format is "LOAD code[ code ...]"
function load(text, i, iarray, count, instruction) {
	count = split(text,iarray)
	if (count == 1) {
		error("NPRG")
		return
	}
	if ((count-1) > MAXMEM) {
		error("BPRG")
		return
	}
	init_memory()
	# Skip LOAD, index from 1
	for(i=2;i <= count; i++) { 
		instruction = iarray[i]  
		if (code_valid(instruction)) {
			mem[i-2] = instruction
		} else {
			error("ICOD", instruction)
			return
		}
	}
}

function get_flag(value) {
	if (value == 0) {
		return 0
	} else if (value > 0) {
		return 1
	} else {
		return -1
	}
}

#Run program 
function run( program_counter, instruction, accumulator, instr_type,instr_addr, flag_sign) {
	program_counter = 0
	accumulator = 0
	flag_sign = 0
	do {
		instruction =  mem[program_counter]
		program_counter++
		if (instruction == commands["HLT"]) {
			break
		} else if (instruction == commands["INP"]) {
			printf "INP:"
			getline accumulator
			if (code_valid(accumulator)) {
				flag_sign = get_flag(accumulator)
			} else {
				error("IINP",accumulator)
				break
			}
		} else if (instruction == commands["OUT"]) {
			printf "OUT:"
			print accumulator
		} else {
			instr_type = int(instruction / MAXMEM) * MAXMEM
			instr_addr = instruction % MAXMEM
			#printf("instruction %d %d\n",instr_type,instr_addr)
			if (instr_type == commands["ADD"]) {
				accumulator += mem[instr_addr]
				flag_sign = get_flag(accumulator)
				if (!code_valid(accumulator)) {
					error("OVER",accumulator)
					break
				}
			} else if ( instr_type == commands["SUB"]) {
				if ( accumulator <  mem[instr_addr]) {
					flag_sign = -1
				} else if (flag_sign != -1)  {
					accumulator -= mem[instr_addr]
					flag_sign = get_flag(accumulator)
				}
			} else if ( instr_type == commands["STA"]) {
				mem[instr_addr] = accumulator
			} else if ( instr_type == commands["LDA"]) {
				accumulator = mem[instr_addr]
				flag_sign = get_flag(accumulator)
			} else if ( instr_type == commands["BRA"]) {
				program_counter = instr_addr
			} else if ( instr_type == commands["BRZ"]) {
				if(flag_sign == 0) {
					program_counter = instr_addr
				}
			} else if ( instr_type == commands["BRP"]) {
				if(flag_sign != -1) {
					program_counter = instr_addr
				}
			} else {
				error("ICOD", instruction)
				break
			}
		}
	} while ( program_counter < MAXMEM )
	# Clear error flag for runtime errors
	run_err["IINP"] = 1
	run_err["OVER"] = 1
	if (get_error() in run_err) {
		set_error("NONE")
	}
}

function usage() {
	print "Little man computer emulator ver 1.0"
	print "Commands (case ignored) :"
	print "ASM file\n\tCompile assembler program file and load code into memory"
	print "LOAD code[ code...]\n\tLoad code into memory, code separated by space"
	print "RUN\n\tRun code from memory"
	print "DUMP\n\tDump computer memory to output"
}

function init_asm() {
	init_memory()
	_program_counter = 0
	for (l in _labels) delete _labels[l]
	for (l in _label_counter) delete _label_counter[l]
}	

function write_command(command) {
	mem[_program_counter] = commands[command]
	_program_counter++
}

function write_value(value) {
	if (code_valid(value)) {
		mem[_program_counter] = value
		_program_counter++
	} else {
		error("ICOD",value)
	}
}

function add_label(label) {
	if (label in _label_counter) {
		_label_counter[label] = _label_counter[label] " " _program_counter
	} else {
		_label_counter[label] = _program_counter
	}
}

function set_label(label,counter) {
	if ( label in _labels) {
		error("RLBL",label)
	} else {
		_labels[label] = _program_counter
	}
}

function strip_comment(line,i,d,delims) {
	sub(/^[ \t]*/,"",line) # Strip leading whites
        sub(/[ \t]*$/,"",line) # Strip trailing whites
	split("# ; //",delims)
	for (d in delims) {
 		i = index(line,delims[d])
		if (i > 0)  {
			if (i > 1) {
				return substr(line,1,i-1)
			} else {
				return ""
			}
		}
	}		
	return line
}

# Compile assembler file into memory
function compile(fname, err,line,count,i,label,n) {
	init_asm()
	do {
		err = (getline line < fname)
		if ( err == -1) {
			error("FRED",fname)
			return
		}
		if ( err == 1) {
			printf "%02d: %s\n",_program_counter,line
			line = strip_comment(line)
		 	count = split(line,parts)
			if ( count == 0) { # Comment
				continue 
			} else if ( count == 1) { # CMD
				if (parts[1] in commands) {
					write_command(parts[1])
				} else {
					error("ICMD", parts[1])
				}
			} else if ( count == 2) {
				if (parts[1] in commands) { # COMMAND LABEL
					add_label(parts[2])
					write_command(parts[1])
				} else if (parts[2] in commands) { #LABEL COMMAND 
					set_label(parts[1])
					write_command(parts[2])
				} else if (parts[2] == "DAT") { #LABEL DAT
					set_label(parts[1])
					write_value(0)
				} else {
					error("ICMD", line)
				}
			} else if (count == 3) {
				set_label(parts[1]) #LABEL
				if (parts[2] in commands) { # CMD LABEL
					add_label(parts[3])
					write_command(parts[2])
				} else if (parts[2] == "DAT") { # DAT VALUE
					write_value(parts[3])
				} else {
					error("ICMD", line)
				}
			} else {
				error("ICMD", line)
			}
		}
	} while ( err == 1)
	close(fname)

	# Compile info
	print "\nLabels:"
	for (label in _labels) {
		printf "%s\t%02d\n",label,_labels[label]
	}
	print "\nXrefs:"
	for (label in _label_counter) {
		printf  "%s\t%s\n",label,_label_counter[label]
	}
	# Set address from labels
	for (label in _label_counter) {
		if (label in _labels) {
			addr = _labels[label]
		} else {
			error("ULBL",label)
		}
		n = split(_label_counter[label],addrs)
		for(i=1; i <= n;i++ ) {
			mem[addrs[i]] += addr
		}
	}
	# LOAD command
	printf "\nLOAD"
	for ( i=0; i < _program_counter; i++) {
		printf(" %d",mem[i])
	}
	printf "\n"
}

{	cmd = toupper($1)
	if (cmd == "LOAD") {
		load($0)
	} else if (cmd == "RUN" ) {
		if (get_error() == "NONE") {
			run()
		} else {
			print "Check errors"
		}
	} else if (cmd == "DUMP") {
		dump()
	} else if (cmd == "ASM") {
		compile($2)
	} else {
		usage()
	}
}

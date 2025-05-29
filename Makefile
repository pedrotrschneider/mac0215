arguments = -vet -vet-cast -vet-semicolon -vet-style -vet-using-param -vet-using-stmt -strict-style -warnings-as-errors# -sanitize:address
super_strict_arguments = -vet-packages:main -vet-unused-procedures
compile = odin build
run = odin run

define_trace = -define:DEBUG_TRACE_EXECUTION=true
define_print = -define:DEBUG_PRINT_CODE=true
define_cli = -define:YUPII_CLI=true

pong_file = src/scripts/pong.yp

##### RUN #####

run_file: build
	@./bin/main -i $(pong_file)

transpile_file: build
	@./bin/main -t $(pong_file) pong.odin
	@odin run pong.odin -file
	@rm pong.odin pong

debug_file: build_debug
	@./bin/main-debug $(pong_file)

##### BUILD #####

build:
	@$(compile) src $(arguments) -out=bin/main

build_debug:
	@$(compile) src $(arguments) -out=bin/main-debug $(define_trace) $(define_print) -o:none -debug

build_cli:
	@$(compile) src/yupii $(arguments) -out=bin/yupii $(define_cli)

##### TOOLS #####

run_keyword_rune_generator:
	@$(run) tools/keyword-rune-generator/main.odin -file $(arguments) < tools/keyword-rune-generator/keywords.txt

arguments = -vet -vet-cast -vet-semicolon -vet-style -vet-using-param -vet-using-stmt -strict-style -warnings-as-errors -sanitize:address
super_strict_arguments = -vet-packages:main -vet-unused-procedures
compile = odin build
run = odin run

define_trace = -define:DEBUG_TRACE_EXECUTION=true
define_print = -define:DEBUG_PRINT_CODE=true
define_test_case = -define:EXECUTE_TEST_CASE=true

run: build
	@./bin/main

run_file: build
	@./bin/main test.yp

debug: build_debug
	@./bin/main-debug

debug_file: build_debug
	@./bin/main-debug test.yp

test: build_test
	@./bin/main-debug

run_keyword_rune_generator:
	@$(run) tools/keyword-rune-generator/main.odin -file $(arguments) < tools/keyword-rune-generator/keywords.txt

build:
	@$(compile) src $(arguments) -out=bin/main

build_debug:
	@$(compile) src $(arguments) -out=bin/main-debug $(define_trace) $(define_print) -o:none -debug

build_test:
	@$(compile) src $(arguments) -out=bin/main-debug $(define_trace) $(define_print) $(define_test_case) -o:none -debug


run: build
	./bin/main

debug: build_debug
	./bin/main-debug

test: build_test
	./bin/main-debug < test.file

build:
	odin build src -out=bin/main

build_debug:
	odin build src -out=bin/main-debug -define:DEBUG_TRACE_EXECUTION=true -define:DEBUG_PRINT_CODE=true -o:none -debug

build_test:
	odin build src -out=bin/main-debug -define:DEBUG_TRACE_EXECUTION=true -define:DEBUG_PRINT_CODE=true -define:EXECUTE_TEST_CASE=true -o:none -debug
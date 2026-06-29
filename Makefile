.PHONY: test test-core test-file

# Run the whole suite headless via plenary's busted runner.
test:
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

# Run a single spec file: make test-file FILE=tests/schema_spec.lua
test-file:
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedFile $(FILE)"

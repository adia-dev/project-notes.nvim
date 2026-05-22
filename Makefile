.PHONY: test fmt check

TEST_HOME ?= /tmp/project-notes.nvim-test

test:
	mkdir -p $(TEST_HOME)/data $(TEST_HOME)/state $(TEST_HOME)/cache
	XDG_DATA_HOME=$(TEST_HOME)/data XDG_STATE_HOME=$(TEST_HOME)/state XDG_CACHE_HOME=$(TEST_HOME)/cache nvim --headless -n -i NONE -u tests/minimal_init.lua -c "lua require('tests.project_notes_spec').run()" +qa!

fmt:
	stylua lua tests

check:
	stylua --check lua tests
	$(MAKE) test

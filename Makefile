REBAR:=./rebar3

## If rebar.config file doesn't exist, just default to cowboy backend
all: cowboy

help:
	@(echo)
	@(echo "Build NitrogenProject.com with a custom backend")
	@(echo)
	@(echo "   make [cowboy|inets|mochiweb|webmachine|yaws]")
	@(echo)
	@(echo "Execute NitrogenProject.com")
	@(echo)
	@(echo "   make [run_dev|run_release]"
	@(echo)
	@(echo "Upgrade a Running Production Release")
	@(echo)
	@(echo "   make upgrade_release"
	@(echo)

compile:
	$(REBAR) compile

link-static:
	@(./copy_static.escript link)
	#(rm -fr priv/static/nitrogen; ln -s `pwd`/_build/default/lib/nitrogen_core/www priv/static/nitrogen)
	#(rm -fr priv/static/doc; ln -s `pwd`/_build/default/lib/nitrogen_core/doc/markdown priv/static/doc)

copy-static:
	@(./copy_static.escript copy)
	#(rm -rf priv/static/nitrogen; mkdir priv/static/nitrogen; cp -r `pwd`/_build/default/lib/nitrogen_core/www/* priv/static/nitrogen)
	#(rm -rf priv/static/doc; mkdir priv/static/doc; cp -r `pwd`/_build/default/lib/nitrogen_core/doc/markdown/* priv/static/doc)

deps:
	$(REBAR) deps

clean:
	$(REBAR) clean

unlock:
	$(REBAR) unlock --all

cowboy:
	@($(MAKE) platform PLATFORM=cowboy)

inets:
	@($(MAKE) platform PLATFORM=inets)

mochiweb:
	@($(MAKE) platform PLATFORM=mochiweb)

webmachine:
	@($(MAKE) platform PLATFORM=webmachine)

yaws:
	@($(MAKE) platform PLATFORM=yaws)

platform: unlock
	@(echo $(PLATFORM) > last_platform)
	@(echo "Updating app.config...")
	@(sed 's/{backend, [a-z]*}/{backend, $(PLATFORM)}/' < etc/app.config > etc/app.config.temp)
	@(mv etc/app.config.temp etc/app.config)
	$(REBAR) as $(PLATFORM) deps
	make link-static
	$(REBAR) as $(PLATFORM) compile

upgrade: update-deps compile copy-static


dialyzer:
	$(REBAR) dialyzer

travis: test

TESTLOG:=testlog.log

last_platform: cowboy

release: last_platform
	./make_version_file.escript go && \
	$(REBAR) as `cat last_platform` release && \
	make finish_version

run_release: last_platform
	$(REBAR) as `cat last_platform` run

run_dev: last_platform
	$(REBAR) as `cat last_platform` shell --name nitrogen@127.0.0.1

run_test: last_platform
	$(REBAR) as `cat last_platform` shell --name nitrogen@127.0.0.1 --eval "wf_test:start_all(nitrogen_core)."

upgrade_running:
	./make_version_file.escript go && \
	./upgrade_release.sh && \
	make finish_version

finish_version:
	./make_version_file.escript finish

revert_version:
	./make_version_file.escript revert

test: run_test
#test:
#
#	make run_dev -name nitrogen@127.0.0.1 EXTRA_ARGS="-eval \"wf_test:start_all(nitrogen_core).\""
#	erl -pa ebin ./deps/*/ebin ./deps/*/include \
#	-config "app.config" \
#	-name nitrogen@127.0.0.1 \
#	-env ERL_FULLSWEEP_AFTER 0 \
#	-testlog "$(TESTLOG)" \
#	-eval "inets:start()" \
#	-eval "application:start(nitrogen_website)." \
#	-eval "wf_test:start_all(nitrogen_core)."

TESTLOGDIR:=testlogs/$(shell date +"%Y-%m-%d.%H%M%S")

test_inets:
	$(MAKE) inets test TESTLOG="$(TESTLOGDIR)/inets.log"

test_cowboy:
	$(MAKE) cowboy test TESTLOG="$(TESTLOGDIR)/cowboy.log"

test_mochiweb:
	$(MAKE) mochiweb test TESTLOG="$(TESTLOGDIR)/mochiweb.log"

test_webmachine:
	$(MAKE) webmachine test TESTLOG="$(TESTLOGDIR)/webmachine.log"

test_yaws:
	$(MAKE) yaws test TESTLOG="$(TESTLOGDIR)/yaws.log"

test_all:
	$(MAKE) test_cowboy test_inets test_mochiweb test_webmachine test_yaws TESTLOGDIR=$(TESTLOGDIR)
	@(grep SUMMARY $(TESTLOGDIR)/*.log)
	@(echo "All tests summarized in $(TESTLOGDIR)")

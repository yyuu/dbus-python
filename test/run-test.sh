#! /bin/bash

function die() 
{
    if ! test -z "$DBUS_SESSION_BUS_PID" ; then
        echo "killing message bus $DBUS_SESSION_BUS_PID" >&2
        kill -9 "$DBUS_SESSION_BUS_PID"
    fi
    echo "$SCRIPTNAME: $*" >&2
    exit 1
}

if test -z "$PYTHON"; then
    echo "Warning: \$PYTHON not set, assuming 'python'" >&2
    export PYTHON=python
fi

if test -z "$DBUS_TOP_SRCDIR" ; then
    die "Must set DBUS_TOP_SRCDIR"
fi

if test -z "$DBUS_TOP_BUILDDIR" ; then
    die "Must set DBUS_TOP_BUILDDIR"
fi

SCRIPTNAME=$0

## so the tests can complain if you fail to use the script to launch them
export DBUS_TEST_PYTHON_RUN_TEST_SCRIPT=1
# Rerun ourselves with tmp session bus if we're not already
if test -z "$DBUS_TEST_PYTHON_IN_RUN_TEST"; then
  DBUS_TEST_PYTHON_IN_RUN_TEST=1
  export DBUS_TEST_PYTHON_IN_RUN_TEST
  exec "$DBUS_TOP_SRCDIR"/test/run-with-tmp-session-bus.sh $SCRIPTNAME
fi  
echo "running test-standalone.py"
$PYTHON "$DBUS_TOP_SRCDIR"/test/test-standalone.py || die "test-standalone.py failed"
echo "running test-client.py"
$PYTHON "$DBUS_TOP_SRCDIR"/test/test-client.py || die "test-client.py failed"
echo "running test-signals.py"
$PYTHON "$DBUS_TOP_SRCDIR"/test/test-signals.py || die "test-signals.py failed"

echo "running cross-test (for better diagnostics use mjj29's dbus-test)"

${MAKE:-make} -s cross-test-server > "$DBUS_TOP_BUILDDIR"/test/cross-server.log&
sleep 1
${MAKE:-make} -s cross-test-client > "$DBUS_TOP_BUILDDIR"/test/cross-client.log

if grep . "$DBUS_TOP_BUILDDIR"/test/cross-client.log >/dev/null; then
  :     # OK
else
  die "cross-test client produced no output"
fi
if grep . "$DBUS_TOP_BUILDDIR"/test/cross-server.log >/dev/null; then
  :     # OK
else
  die "cross-test server produced no output"
fi

if grep fail "$DBUS_TOP_BUILDDIR"/test/cross-client.log; then
  die "^^^ Cross-test client reports failures, see test/cross-client.log"
else
  echo "  - cross-test client reported no failures"
fi
if grep untested "$DBUS_TOP_BUILDDIR"/test/cross-server.log; then
  die "^^^ Cross-test server reports incomplete test coverage"
else
  echo "  - cross-test server reported no untested functions"
fi

echo "running the examples"

$PYTHON "$DBUS_TOP_SRCDIR"/examples/example-service.py &
$PYTHON "$DBUS_TOP_SRCDIR"/examples/example-signal-emitter.py &
$PYTHON "$DBUS_TOP_SRCDIR"/examples/list-system-services.py --session ||
  die "list-system-services.py --session failed!"
$PYTHON "$DBUS_TOP_SRCDIR"/examples/example-async-client.py ||
  die "example-async-client failed!"
$PYTHON "$DBUS_TOP_SRCDIR"/examples/example-client.py --exit-service ||
  die "example-client failed!"
$PYTHON "$DBUS_TOP_SRCDIR"/examples/example-signal-recipient.py --exit-service ||
  die "example-signal-recipient failed!"

rm -f "$DBUS_TOP_BUILDDIR"/test/test-service.log
rm -f "$DBUS_TOP_BUILDDIR"/test/cross-client.log
rm -f "$DBUS_TOP_BUILDDIR"/test/cross-server.log
exit 0

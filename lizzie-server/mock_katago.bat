@echo off
REM Wrapper that invokes the Python mock KataGo. Used only for
REM lizzie-server smoke tests; production deployments point
REM --katago at a real KataGo binary.
REM
REM lizzie-server passes its own --config <path> after our name, but
REM Python interprets --config as its own flag and dies. Insert -- so
REM Python stops option processing and treats the rest as positional
REM args (which we ignore, since the script reads no config file).
python "%~dp0mock_katago.py" %*

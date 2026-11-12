@echo off
setlocal EnableExtensions

REM Always run from the repository root
cd /d "%~dp0"

REM ── Check for .env.local ──────────────────────────────────────────────────
if not exist ".env.local" (
    echo [ERROR] .env.local not found. Copy .env.example to .env.local and fill in your values.
    pause
    exit /b 1
)

REM ── Check for worker\.env ─────────────────────────────────────────────────
if not exist "worker\.env" (
    echo [ERROR] worker\.env not found. Copy worker\.env.example to worker\.env and fill in your values.
    pause
    exit /b 1
)

REM ── Check Node.js / npm ───────────────────────────────────────────────────
where npm >nul 2>&1
if errorlevel 1 (
    echo [ERROR] npm was not found in PATH. Install Node.js LTS and try again.
    pause
    exit /b 1
)

REM ── Start the Python worker in a new window ───────────────────────────────
netstat -ano | findstr /R /C:":8000 .*LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo [INFO] Python worker is already listening on http://localhost:8000
) else (
    set "WORKER_PY="
    if exist "%CD%\worker\.venv\Scripts\python.exe" (
        set "WORKER_PY=%CD%\worker\.venv\Scripts\python.exe"
    ) else (
        where py >nul 2>&1
        if not errorlevel 1 (
            set "WORKER_PY=py"
        ) else (
            where python >nul 2>&1
            if not errorlevel 1 set "WORKER_PY=python"
        )
    )

    if not defined WORKER_PY (
        echo [ERROR] Python executable not found. Create worker\.venv or install Python 3.11+.
        pause
        exit /b 1
    )

    if exist "%CD%\worker\.packages" (
        if defined PYTHONPATH (
            set "PYTHONPATH=%CD%\worker\.packages;%PYTHONPATH%"
        ) else (
            set "PYTHONPATH=%CD%\worker\.packages"
        )
    )

    echo Starting Python worker on http://localhost:8000 ...
    if exist "%CD%\worker\.venv\Scripts\activate.bat" (
        start "TransitIQ Worker" /D "%CD%\worker" cmd /k "call ".venv\Scripts\activate.bat" && "%WORKER_PY%" -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload --env-file .env"
    ) else (
        start "TransitIQ Worker" /D "%CD%\worker" cmd /k ""%WORKER_PY%" -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload --env-file .env"
    )
)

REM ── Install Node dependencies if needed ──────────────────────────────────
if not exist "node_modules" (
    echo Installing Node dependencies...
    call npm install
    if errorlevel 1 (
        echo [ERROR] npm install failed.
        pause
        exit /b 1
    )
)

REM ── Guard against duplicate Next.js instances / stale dev lock ─────────────
netstat -ano | findstr /R /C:":3000 .*LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo [WARN] Port 3000 is already in use at http://localhost:3000.
    echo Close the existing Next.js server window first if you want to restart it.
    pause
    exit /b 0
)

if exist ".next\dev\lock" (
    echo Cleaning stale Next.js dev lock...
    del /f /q ".next\dev\lock" >nul 2>&1
)

REM ── Start Next.js dev server ──────────────────────────────────────────────
echo Starting Next.js on http://localhost:3000 ...
call npm run dev
if errorlevel 1 (
    echo [ERROR] Next.js exited with an error.
    pause
    exit /b 1
)

@echo off
REM 啟動 Python 虛擬環境 .venv

REM 切換到專案目錄 (可選)
cd /d %~dp0

REM 啟動虛擬環境
call venv\Scripts\activate.bat

REM 保持在虛擬環境中執行互動式命令
cmd

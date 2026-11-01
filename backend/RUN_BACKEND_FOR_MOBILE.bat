@echo off
cd /d "%~dp0QuanLyPhongTro\Quanlyphongtro"
echo Starting ASP.NET Core backend for Android/phone access...
dotnet run --urls "http://0.0.0.0:5129"
pause

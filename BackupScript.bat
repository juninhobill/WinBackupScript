@ECHO OFF

REM Setting up date and time formats to have it inserted in the backup file and log names.
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do set datetime=%%I
set datetime=%datetime:~0,8%-%datetime:~8,6%

REM Creating log file.
call :sub > D:\Backup\LogFile_%datetime%.log 2>&1

exit /b

:sub
ECHO.
ECHO ==============================BackupScript============================
ECHO.
ECHO ===================Version 1.5, Updated: 2019-08-22===================
ECHO.
ECHO =======================By Milton P. Silva Junior======================
ECHO.
ECHO Performs full backups of folders and files configured by the user,
ECHO to a Server folder, OneDrive folder and Google Drive folder, deleting
ECHO the old files from all of these places.
ECHO.
ECHO.

REM Usage---
REM   > BackupScript

SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

REM ---Configuration Options---

REM Folder locations where you want to store the resulting backup archive.
REM Those folders must exist. Do not put a '\' at the end, this will be added automatically.
REM You can enter a local path, an external drive letter (ex. F:) or a network location (ex. \\server\backups)

REM Setting up drivers to be used to copy backup and log files.
SET BackupStorage="D:\Backup"
SET BackupFolder="\\server02\juninho$\BackupFolder"
SET BackupOneDrive="C:\Users\juninho\OneDrive\Backup"
SET BackupGoogleDrive="D:\GDrive\Backup"

REM Location where 7-Zip is installed on your computer.
REM The default is in a folder, '7-Zip' in your Program Files directory.
SET InstallLocationOf7Zip=%ProgramFiles%\7-Zip

REM +-----------------------------------------------------------------------+
REM | Do not change anything below here unless you know what you are doing. |
REM +-----------------------------------------------------------------------+

REM Usage variables.
SET exe7Zip=%InstallLocationOf7Zip%\7z.exe
SET dirTempBackup=%TEMP%\backup
SET filBackupConfig=BackupConfig.txt

CD %BackupStorage%

ECHO Deleting backed up files and logs older than 1 day from local machine.
FORFILES -p %BackupStorage% -s -m *.7z /D -1 /C "CMD /c del @path"
FORFILES -p %BackupStorage% -s -m *.log /D -1 /C "CMD /c del @path"
ECHO Done deleting old backed up files from local machine.
ECHO.
ECHO.

REM Validation.
IF NOT EXIST %filBackupConfig% (
  ECHO No configuration file found, missing: %filBackupConfig%
  GOTO End
)
IF NOT EXIST "%exe7Zip%" (
  ECHO 7-Zip is not installed in the location: %dir7Zip%
  ECHO Please update the directory where 7-Zip is installed.
  GOTO End
)

ECHO Starting to copy files.
IF NOT EXIST "%dirTempBackup%" MKDIR "%dirTempBackup%"
FOR /f "skip=1 tokens=1,2" %%A IN (%filBackupConfig%) DO (
  SET Current=%%~A
  IF NOT EXIST "!Current!" (
    ECHO ERROR! Not found: !Current!
  ) ELSE (
    ECHO Copying: !Current!
    SET Destination=%dirTempBackup%\!Current:~0,1!%%~pnxA
    REM Determine if the entry is a file or directory.
    IF "%%~xA"=="" (
      REM Directory.
      ROBOCOPY "!Current!" "!Destination!" /E
    ) ELSE (
      REM File.
      COPY /v /y "!Current!" "!Destination!"
    )
  )
)

ECHO Done copying files.
ECHO.

SET BackupFile="%BackupStorage%\BackupFull_%datetime%.7z"

ECHO Compressing backed up files. (New window)
REM Compress files using 7-Zip in a lower priority process.
START "Compressing Backup. DO NOT CLOSE" /belownormal /wait "%exe7Zip%" a -tzip -r -mx5 "%BackupFile%" "%dirTempBackup%\"
ECHO Done compressing backed up files.

ECHO Copying to server and deleting backed up files and logs older than 1 day.
PushD "\\server02\milton$\BackupFolder" &&(forfiles -s -m *.7z -d -1 -c "cmd /c del /q @path") & PopD
PushD "\\server02\milton$\BackupFolder" &&(forfiles -s -m *.log -d -1 -c "cmd /c del /q @path") & PopD
COPY /y %BackupFile% %BackupFolder%
ECHO Done copying backed up files to server.

ECHO Copying to OneDrive and deleting backed up files and logs older than 1 day.
FORFILES -p %BackupOneDrive% -s -m *.7z /D -1 /C "CMD /c del @path"
FORFILES -p %BackupOneDrive% -s -m *.log /D -1 /C "CMD /c del @path"
COPY /y %BackupFile% %BackupOneDrive%
ECHO Done copying backed up files to OneDrive.

ECHO Copying to GoogleDrive and deleting backed up files and logs older than 1 day.
FORFILES -p %BackupGoogleDrive% -s -m *.7z /D -1 /C "CMD /c del @path"
FORFILES -p %BackupGoogleDrive% -s -m *.log /D -1 /C "CMD /c del @path"
COPY /y %BackupFile% %BackupGoogleDrive%
ECHO Done copying backed up files to GoogleDrive.

ECHO.

ECHO Cleaning up.
IF EXIST "%dirTempBackup%" RMDIR /s /q "%dirTempBackup%"
ECHO.

:End
ECHO Finished.
ECHO.

COPY /y %BackupStorage%\*.log %BackupFolder%
COPY /y %BackupStorage%\*.log %BackupOneDrive%
COPY /y %BackupStorage%\*.log %BackupGoogleDrive%

ENDLOCAL
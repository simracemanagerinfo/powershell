#ifndef PROFILE_NAME
#error PROFILE_NAME must be defined before including launcher_impl.h
#endif

#ifndef LAUNCHER_NAME
#define LAUNCHER_NAME L"PowerShell Customization"
#endif

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#define BUFFER_CHARS 32768

static BOOL FileExists(const WCHAR *path)
{
    DWORD attributes = GetFileAttributesW(path);
    return attributes != INVALID_FILE_ATTRIBUTES &&
           (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

static BOOL ResolveWindowsTerminal(WCHAR *path, DWORD capacity)
{
    DWORD found = SearchPathW(NULL, L"wt.exe", NULL, capacity, path, NULL);
    if (found > 0 && found < capacity && FileExists(path)) {
        return TRUE;
    }

    WCHAR localAppData[BUFFER_CHARS];
    DWORD length = GetEnvironmentVariableW(L"LOCALAPPDATA", localAppData, BUFFER_CHARS);
    static const WCHAR suffix[] = L"\\Microsoft\\WindowsApps\\wt.exe";

    if (length == 0 || length >= BUFFER_CHARS || length + ARRAYSIZE(suffix) >= capacity) {
        return FALSE;
    }

    lstrcpyW(path, localAppData);
    lstrcatW(path, suffix);
    return FileExists(path);
}

static void ShowLaunchError(DWORD errorCode)
{
    WCHAR message[1024];
    wsprintfW(
        message,
        L"Impossibile avviare Windows Terminal.\n\n"
        L"Verificare che Windows Terminal sia installato e che wt.exe sia disponibile.\n\n"
        L"Errore Windows: %lu",
        errorCode);

    MessageBoxW(NULL, message, LAUNCHER_NAME, MB_OK | MB_ICONERROR);
}

int WINAPI wWinMain(
    HINSTANCE instance,
    HINSTANCE previousInstance,
    PWSTR commandLineArguments,
    int showCommand)
{
    (void)instance;
    (void)previousInstance;
    (void)commandLineArguments;
    (void)showCommand;

#ifdef PRE_LAUNCH_ACTION
    if (!PRE_LAUNCH_ACTION()) {
        return 1;
    }
#endif

    WCHAR wtPath[BUFFER_CHARS];
    if (!ResolveWindowsTerminal(wtPath, BUFFER_CHARS)) {
        ShowLaunchError(ERROR_FILE_NOT_FOUND);
        return 1;
    }

    if ((DWORD)lstrlenW(wtPath) + (DWORD)lstrlenW(PROFILE_NAME) + 10 >= BUFFER_CHARS) {
        ShowLaunchError(ERROR_BUFFER_OVERFLOW);
        return 1;
    }

    WCHAR commandLine[BUFFER_CHARS];
    lstrcpyW(commandLine, L"\"");
    lstrcatW(commandLine, wtPath);
    lstrcatW(commandLine, L"\" -p \"");
    lstrcatW(commandLine, PROFILE_NAME);
    lstrcatW(commandLine, L"\"");

    STARTUPINFOW startupInfo;
    PROCESS_INFORMATION processInfo;
    ZeroMemory(&startupInfo, sizeof(startupInfo));
    ZeroMemory(&processInfo, sizeof(processInfo));
    startupInfo.cb = sizeof(startupInfo);

    if (!CreateProcessW(
            NULL,
            commandLine,
            NULL,
            NULL,
            FALSE,
            CREATE_UNICODE_ENVIRONMENT | CREATE_NEW_PROCESS_GROUP,
            NULL,
            NULL,
            &startupInfo,
            &processInfo)) {
        ShowLaunchError(GetLastError());
        return 1;
    }

    CloseHandle(processInfo.hThread);
    CloseHandle(processInfo.hProcess);
    return 0;
}

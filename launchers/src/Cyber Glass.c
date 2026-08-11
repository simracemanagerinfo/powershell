#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>

#define PROFILE_NAME L"Cyber Glass"
#define LAUNCHER_NAME L"Cyber Glass"

static BOOL PrepareCyberGlassBackground(void);
#define PRE_LAUNCH_ACTION() PrepareCyberGlassBackground()
#include "launcher_impl.h"

#define BACKGROUND_COUNT 6

static const WCHAR *const backgroundNames[BACKGROUND_COUNT] = {
    L"01_roma_vaticano_neon.png",
    L"02_simrace_pitlane_neon.png",
    L"03_roma_colosseo_future.png",
    L"04_simrace_garage_future.png",
    L"05_roma_colosseo_rain.png",
    L"06_simrace_night_race.png"
};

static BOOL AppendChecked(WCHAR *destination, DWORD capacity, const WCHAR *suffix)
{
    if ((DWORD)lstrlenW(destination) + (DWORD)lstrlenW(suffix) + 1 >= capacity) {
        SetLastError(ERROR_BUFFER_OVERFLOW);
        return FALSE;
    }
    lstrcatW(destination, suffix);
    return TRUE;
}

static BOOL BuildRootPath(WCHAR *destination, DWORD capacity)
{
    DWORD length = GetEnvironmentVariableW(L"LOCALAPPDATA", destination, capacity);
    if (length == 0 || length >= capacity) {
        return FALSE;
    }
    return AppendChecked(destination, capacity, L"\\PowerShellCustomization\\assets\\backgrounds");
}

static void ShowBackgroundError(const WCHAR *message, const WCHAR *path)
{
    WCHAR detail[2048];
    wsprintfW(detail, L"%s\n\n%s\n\nErrore Windows: %lu", message, path, GetLastError());
    MessageBoxW(NULL, detail, LAUNCHER_NAME, MB_OK | MB_ICONERROR);
}

static int ReadPreviousIndex(const WCHAR *statePath)
{
    FILE *file = _wfopen(statePath, L"rt");
    if (file == NULL) {
        return -1;
    }
    int value = -1;
    if (fwscanf(file, L"%d", &value) != 1) {
        value = -1;
    }
    fclose(file);
    return value;
}

static void SavePreviousIndex(const WCHAR *statePath, int value)
{
    FILE *file = _wfopen(statePath, L"wt");
    if (file != NULL) {
        fwprintf(file, L"%d", value);
        fclose(file);
    }
}

static BOOL PrepareCyberGlassBackground(void)
{
    WCHAR backgroundRoot[BUFFER_CHARS];
    if (!BuildRootPath(backgroundRoot, BUFFER_CHARS)) {
        ShowBackgroundError(L"Impossibile determinare la directory degli asset Cyber Glass.", L"%LOCALAPPDATA%\\PowerShellCustomization\\assets\\backgrounds");
        return FALSE;
    }

    WCHAR poolPath[BUFFER_CHARS];
    WCHAR currentPath[BUFFER_CHARS];
    WCHAR statePath[BUFFER_CHARS];
    lstrcpyW(poolPath, backgroundRoot);
    lstrcpyW(currentPath, backgroundRoot);
    lstrcpyW(statePath, backgroundRoot);

    if (!AppendChecked(poolPath, BUFFER_CHARS, L"\\pool") ||
        !AppendChecked(currentPath, BUFFER_CHARS, L"\\current.png") ||
        !AppendChecked(statePath, BUFFER_CHARS, L"\\.last-background")) {
        ShowBackgroundError(L"Percorso Cyber Glass troppo lungo.", backgroundRoot);
        return FALSE;
    }

    int available[BACKGROUND_COUNT];
    int availableCount = 0;

    for (int index = 0; index < BACKGROUND_COUNT; ++index) {
        WCHAR candidate[BUFFER_CHARS];
        lstrcpyW(candidate, poolPath);
        if (!AppendChecked(candidate, BUFFER_CHARS, L"\\") ||
            !AppendChecked(candidate, BUFFER_CHARS, backgroundNames[index])) {
            continue;
        }

        DWORD attributes = GetFileAttributesW(candidate);
        if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0) {
            available[availableCount++] = index;
        }
    }

    if (availableCount == 0) {
        SetLastError(ERROR_FILE_NOT_FOUND);
        ShowBackgroundError(L"Nessun wallpaper Cyber Glass disponibile nel pool.", poolPath);
        return FALSE;
    }

    int previous = ReadPreviousIndex(statePath);
    ULONGLONG entropy = GetTickCount64();
    LARGE_INTEGER counter;
    if (QueryPerformanceCounter(&counter)) {
        entropy ^= (ULONGLONG)counter.QuadPart;
    }
    entropy ^= ((ULONGLONG)GetCurrentProcessId() << 16);

    int selectedPosition = (int)(entropy % (ULONGLONG)availableCount);
    int selected = available[selectedPosition];

    if (availableCount > 1 && selected == previous) {
        selectedPosition = (selectedPosition + 1 + (int)(entropy % (ULONGLONG)(availableCount - 1))) % availableCount;
        selected = available[selectedPosition];
        if (selected == previous) {
            selected = available[(selectedPosition + 1) % availableCount];
        }
    }

    WCHAR selectedPath[BUFFER_CHARS];
    lstrcpyW(selectedPath, poolPath);
    if (!AppendChecked(selectedPath, BUFFER_CHARS, L"\\") ||
        !AppendChecked(selectedPath, BUFFER_CHARS, backgroundNames[selected])) {
        ShowBackgroundError(L"Percorso wallpaper troppo lungo.", poolPath);
        return FALSE;
    }

    if (!CopyFileW(selectedPath, currentPath, FALSE)) {
        ShowBackgroundError(L"Impossibile impostare il wallpaper Cyber Glass corrente.", currentPath);
        return FALSE;
    }

    SavePreviousIndex(statePath, selected);
    return TRUE;
}

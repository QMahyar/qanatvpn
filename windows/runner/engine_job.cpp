#include "engine_job.h"

#include <cstdio>

// Job object that owns every sing-box.exe the Flutter app spawns
// (audit W4.2: app exit, crash, or force-quit previously orphaned the
// engine — TUN and routes stayed up with a config containing private keys
// in %TEMP%). The job is created with KILL_ON_JOB_CLOSE: when the app
// process dies — cleanly or not — the kernel terminates every process in
// the job. Job objects also survive the parent better than taskkill-from-
// Dart, because the OS enforces the kill even when the app is killed by
// Task Manager.
//
// Auto-add every child: sing-box.exe is spawned via CreateProcess by
// Dart's Process.start, which inherits the job (JOB_OBJECT_LIMIT_BREAKAWAY
// is not requested), so the OS puts it in automatically.

namespace {

HANDLE g_job = nullptr;

}  // namespace

bool CreateEngineJob() {
  if (g_job != nullptr) {
    return true;  // Already installed.
  }
  g_job = ::CreateJobObjectW(nullptr, nullptr);
  if (g_job == nullptr) {
    return false;
  }
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
  limits.BasicLimitInformation.LimitFlags =
      JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE |
      JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK;  // Debugger/CI escape hatch.
  if (!::SetInformationJobObject(g_job, JobObjectExtendedLimitInformation,
                                 &limits, sizeof(limits))) {
    ::CloseHandle(g_job);
    g_job = nullptr;
    return false;
  }
  // Put THIS process in the job: every child of this process (sing-box.exe
  // via Process.start) joins automatically. KILL_ON_JOB_CLOSE fires when
  // the last handle closes — which happens at process death.
  if (!::AssignProcessToJobObject(g_job, ::GetCurrentProcess())) {
    ::CloseHandle(g_job);
    g_job = nullptr;
    return false;
  }
  return true;
}

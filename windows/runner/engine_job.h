#ifndef ENGINE_JOB_H_
#define ENGINE_JOB_H_

// Installs the kernel job object that owns sing-box.exe children
// (audit W4.2). Call once from wWinMain before any child can spawn; every
// subsequent process the app starts joins the job and dies with it.
bool CreateEngineJob();

#endif  // ENGINE_JOB_H_

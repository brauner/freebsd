#!/bin/sh

# Kernel page fault with the following non-sleepable locks held:
# exclusive sleep mutex so_rcv (so_rcv) r = 0 (0xfffffe012b5ee300) locked @ kern/uipc_usrreq.c:1272
# exclusive sleep mutex socket (socket) r = 0 (0xfffffe012b5ee1a8) locked @ kern/uipc_usrreq.c:1265
# shared rw unp_link_rwlock (unp_link_rwlock) r = 0 (0xffffffff81d99640) locked @ kern/uipc_usrreq.c:1334
# stack backtrace:
# #0 0xffffffff80c35701 at witness_debugger+0x71
# #1 0xffffffff80c3669d at witness_warn+0x40d
# #2 0xffffffff8106fb90 at trap_pfault+0x80
# #3 0xffffffff8106f1a5 at trap+0x2a5
# #4 0xffffffff810450d8 at calltrap+0x8
# #5 0xffffffff80bc6fcc at sendfile_iodone+0x1ac
# #6 0xffffffff80f3d98a at vnode_pager_generic_getpages_done_async+0x3a
# #7 0xffffffff80c8236c at bufdone+0x6c
# #8 0xffffffff80b0c06e at g_io_deliver+0x25e
# #9 0xffffffff80b0c06e at g_io_deliver+0x25e
# #10 0xffffffff80b08dfd at g_disk_done+0xed
# #11 0xffffffff803ac1f3 at dadone+0x603
# #12 0xffffffff8037ddf2 at xpt_done_process+0x382
# #13 0xffffffff8037fdb5 at xpt_done_td+0xf5
# #14 0xffffffff80b85b10 at fork_exit+0x80
# #15 0xffffffff8104611e at fork_trampoline+0xe
# 
# 
# Fatal trap 12: page fault while in kernel mode
# cpuid = 23; apic id = 2b
# fault virtual address   = 0x8
# fault code              = supervisor read data, page not present
# instruction pointer     = 0x20:0xffffffff80c74bc0
# stack pointer           = 0x0:0xfffffe0126b118e0
# frame pointer           = 0x0:0xfffffe0126b11920
# code segment            = base 0x0, limit 0xfffff, type 0x1b
#                         = DPL 0, pres 1, long 1, def32 0, gran 1
# processor eflags        = interrupt enabled, resume, IOPL = 0
# current process         = 32 (doneq0)
# trap number             = 12
# panic: page fault
# cpuid = 23
# time = 1591531029
# KDB: stack backtrace:
# db_trace_self_wrapper() at db_trace_self_wrapper+0x2b/frame 0xfffffe0126b11590
# vpanic() at vpanic+0x182/frame 0xfffffe0126b115e0
# panic() at panic+0x43/frame 0xfffffe0126b11640
# trap_fatal() at trap_fatal+0x387/frame 0xfffffe0126b116a0
# trap_pfault() at trap_pfault+0x99/frame 0xfffffe0126b11700
# trap() at trap+0x2a5/frame 0xfffffe0126b11810
# calltrap() at calltrap+0x8/frame 0xfffffe0126b11810
# --- trap 0xc, rip = 0xffffffff80c74bc0, rsp = 0xfffffe0126b118e0, rbp = 0xfffffe0126b11920 ---
# uipc_ready() at uipc_ready+0x1f0/frame 0xfffffe0126b11920
# sendfile_iodone() at sendfile_iodone+0x1ac/frame 0xfffffe0126b11960
# vnode_pager_generic_getpages_done_async() at vnode_pager_generic_getpages_done_async+0x3a/frame 0xfffffe0126b11980
# bufdone() at bufdone+0x6c/frame 0xfffffe0126b119f0
# g_io_deliver() at g_io_deliver+0x25e/frame 0xfffffe0126b11a40
# g_io_deliver() at g_io_deliver+0x25e/frame 0xfffffe0126b11a90
# g_disk_done() at g_disk_done+0xed/frame 0xfffffe0126b11ad0
# dadone() at dadone+0x603/frame 0xfffffe0126b11b20
# xpt_done_process() at xpt_done_process+0x382/frame 0xfffffe0126b11b60
# xpt_done_td() at xpt_done_td+0xf5/frame 0xfffffe0126b11bb0
# fork_exit() at fork_exit+0x80/frame 0xfffffe0126b11bf0
# fork_trampoline() at fork_trampoline+0xe/frame 0xfffffe0126b11bf0
# --- trap 0, rip = 0, rsp = 0, rbp = 0 ---
# KDB: enter: panic
# [ thread pid 32 tid 100163 ]
# Stopped at      kdb_enter+0x37: movq    $0,0x10c72c6(%rip)
# db>

# $FreeBSD$

# Reproduced on r361889

[ `uname -p` = "i386" ] && exit 0

. ../default.cfg
cat > /tmp/syzkaller13.c <<EOF
// https://syzkaller.appspot.com/bug?id=8a63fce7c52d85d6fca9aca543ce5a77cdd15f25
// autogenerated by syzkaller (https://github.com/google/syzkaller)
// Reported-by: syzbot+6a689cc9c27bd265237a@syzkaller.appspotmail.com

#define _GNU_SOURCE

#include <sys/types.h>

#include <dirent.h>
#include <pwd.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/endian.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static unsigned long long procid;

static void kill_and_wait(int pid, int* status)
{
  kill(pid, SIGKILL);
  while (waitpid(-1, status, 0) != pid) {
  }
}

static void sleep_ms(uint64_t ms)
{
  usleep(ms * 1000);
}

static uint64_t current_time_ms(void)
{
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts))
    exit(1);
  return (uint64_t)ts.tv_sec * 1000 + (uint64_t)ts.tv_nsec / 1000000;
}

static void use_temporary_dir(void)
{
  char tmpdir_template[] = "./syzkaller.XXXXXX";
  char* tmpdir = mkdtemp(tmpdir_template);
  if (!tmpdir)
    exit(1);
  if (chmod(tmpdir, 0777))
    exit(1);
  if (chdir(tmpdir))
    exit(1);
}

static void remove_dir(const char* dir)
{
  DIR* dp;
  struct dirent* ep;
  dp = opendir(dir);
  if (dp == NULL)
    exit(1);
  while ((ep = readdir(dp))) {
    if (strcmp(ep->d_name, ".") == 0 || strcmp(ep->d_name, "..") == 0)
      continue;
    char filename[FILENAME_MAX];
    snprintf(filename, sizeof(filename), "%s/%s", dir, ep->d_name);
    struct stat st;
    if (lstat(filename, &st))
      exit(1);
    if (S_ISDIR(st.st_mode)) {
      remove_dir(filename);
      continue;
    }
    if (unlink(filename))
      exit(1);
  }
  closedir(dp);
  if (rmdir(dir))
    exit(1);
}

static void execute_one(void);

#define WAIT_FLAGS 0

static void loop(void)
{
  int iter;
  for (iter = 0;; iter++) {
    char cwdbuf[32];
    sprintf(cwdbuf, "./%d", iter);
    if (mkdir(cwdbuf, 0777))
      exit(1);
    int pid = fork();
    if (pid < 0)
      exit(1);
    if (pid == 0) {
      if (chdir(cwdbuf))
        exit(1);
      execute_one();
      exit(0);
    }
    int status = 0;
    uint64_t start = current_time_ms();
    for (;;) {
      if (waitpid(-1, &status, WNOHANG | WAIT_FLAGS) == pid)
        break;
      sleep_ms(1);
      if (current_time_ms() - start < 5 * 1000)
        continue;
      kill_and_wait(pid, &status);
      break;
    }
    remove_dir(cwdbuf);
  }
}

uint64_t r[5] = {0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff,
                 0xffffffffffffffff, 0xffffffffffffffff};

void execute_one(void)
{
  intptr_t res = 0;
  memcpy((void*)0x20000100, "./file0\000", 8);
  res = syscall(SYS_open, 0x20000100ul, 0x40000400000002c2ul, 0ul);
  if (res != -1)
    r[0] = res;
  syscall(SYS_fcntl, r[0], 4ul, 0x10048ul);
  *(uint64_t*)0x20000340 = 0x20000180;
  *(uint64_t*)0x20000348 = 0x81700;
  syscall(SYS_writev, r[0], 0x20000340ul, 0x1000000000000013ul);
  res = syscall(SYS_socket, 2ul, 2ul, 0x88);
  if (res != -1)
    r[1] = res;
  res = syscall(SYS_socketpair, 1ul, 1ul, 0, 0x20000000ul);
  if (res != -1)
    r[2] = *(uint32_t*)0x20000000;
  res = syscall(SYS_dup2, r[2], r[1]);
  if (res != -1)
    r[3] = res;
  memcpy((void*)0x20000140, "./file0\000", 8);
  res = syscall(SYS_open, 0x20000140ul, 0ul, 0ul);
  if (res != -1)
    r[4] = res;
  syscall(SYS_sendfile, r[4], r[3], 0ul, 1ul, 0ul, 0ul, 0ul);
}
int main(void)
{
  syscall(SYS_mmap, 0x20000000ul, 0x1000000ul, 7ul, 0x1012ul, -1, 0ul);
  for (procid = 0; procid < 4; procid++) {
    if (fork() == 0) {
      use_temporary_dir();
      loop();
    }
  }
  sleep(1000000);
  return 0;
}
EOF
mycc -o /tmp/syzkaller13 -Wall -Wextra -O2 /tmp/syzkaller13.c -lpthread ||
    exit 1

(cd ../testcases/swap; ./swap -t 1m -i 20 -h > /dev/null 2>&1) &
(cd /tmp; ./syzkaller13) &
sleep 60
pkill -9 syzkaller13 swap
wait

rm -f /tmp/syzkaller13 /tmp/syzkaller13.c /tmp/syzkaller13.core /tmp/file0
exit 0

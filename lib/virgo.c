/*
 *  Copyright 2012 Rackspace
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

#include "virgo.h"
#include "virgo_paths.h"
#include "virgo_exec.h"
#include "virgo_versions.h"
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#ifndef _WIN32
#include <unistd.h>
#include <errno.h>
#else
#include <io.h>
#endif

static void
handle_error(virgo_t *v, const char *msg, virgo_error_t *err)
{
  char buf[256];

  snprintf(buf, sizeof(buf), "%s: %s", msg, "[%s:%d] (%d) %s");
  if (err) {
    if (v) {
      virgo_log_errorf(v, buf, err->file, err->line, err->err, err->msg);
    }
    fprintf(stderr, buf, err->file, err->line, err->err, err->msg);
  }
  fputs("\n", stderr);
  fflush(stderr);
}

static void
show_help()
{
  /* TODO: improve for windows */
  printf("Usage: " PKG_NAME " [options] [--setup] \n"
         "\n"
         "Options:\n"
         "  -v, --version         Print version.\n"
         "  -c, --config val      Set configuration file path.\n"
         "  -e val                Enter at module specified.\n"
         "  -o                    Do not attempt upgrade.\n"
         "  -l, --logfile val     Log to specified file path.\n"
#ifndef _WIN32
         "  -p, --pidfile val     Path and filename to pidfile.\n"
#endif
         "  --setup               Initial setup wizard.\n"
         "    --username          Rackspace Cloud username for setup.\n"
         "    --apikey            Rackspace Cloud API Key or Password for setup.\n"
         "  -d, --debug           Log at debug level.\n"
         "  -i, --insecure        Use insecure SSL CA cert (for testing/debugging).\n"
         "  -D, --detach          Detach the process and run the agent in the background.\n"
         "  --production          Write debug information to disk when the agent crahes.\n"
         "  --crash               Crash the agent.\n"
         "  --exit-on-upgrade     On a successful upgrade exit.\n"
#ifndef _WIN32
         "  --restart-sysv-on-upgrade  Attempt to restart on upgrade. (System V)\n"
#endif
         "\n"
         DOCUMENTATION_LINK "\n");

  fflush(stdout);
}

static void
service_maintenance(virgo_t *v)
{
  const char *msg = "Service Maintenance Complete";
  virgo_log_debugf(v, "%s", msg);
  printf("%s\n", msg);
  fflush(stdout);
}

static void
show_version(virgo_t *v)
{
  printf("%s-%s", VERSION_FULL, VERSION_RELEASE);
  fflush(stdout);
}

virgo_t*
virgo_context_new(int argc, char *argv[], const char *process_title) {
  virgo_t *v;
  virgo_error_t *err;

  err = virgo_create(&v, "./init", argc, argv);

  if (err) {
    handle_error(v, "Error in startup", err);
    exit(EXIT_FAILURE);
  }

  if (1 == virgo_argv_has_help(v)) {
    show_help();
    exit(0);
  }

  /* Set Service Name */
  err = virgo_conf_service_name(v, process_title);
  if (err) {
    handle_error(v, "Error setting service name", err);
    exit(EXIT_FAILURE);
  }

  /* Read command-line arguments */
  err = virgo_conf_args(v);
  if (err) {
    handle_error(v, "Error in settings args", err);
    exit(EXIT_FAILURE);
  }

  err = virgo_log_rotate(v);

  if (err) {
    handle_error(v, "Error rotating logs", err);
    exit(EXIT_FAILURE);
  }

  return v;
}


virgo_error_t*
main_wrapper(virgo_t *v)
{
  virgo_error_t *err = NULL;

  /* Setup Lua Contexts for Luvit and Libuv runloop */
  err = virgo_init(v);
  if (err) {
    if (err->err == VIRGO_EHELPREQ) {
      show_help();
      virgo_error_clear(err);
      return VIRGO_SUCCESS;
    }
    else if (err->err == VIRGO_EVERSIONREQ) {
      show_version(v);
      virgo_error_clear(err);
      return VIRGO_SUCCESS;
    }
    else if (err->err == VIRGO_MAINTREQ) {
      service_maintenance(v);
      virgo_error_clear(err);
      return VIRGO_SUCCESS;
    }

    handle_error(v, "Error in init", err);
    return err;
  }

  err = virgo_agent_conf_set(v, "version", VERSION_FULL);
  if (err) {
    handle_error(v, "Error setting agent version", err);
    return err;
  }

  /* Enter Luvit and Execute */
  err = virgo_run(v);
  if (err) {
    handle_error(v, "Runtime Error", err);
    return err;
  }

  /* Cleanup */
  virgo_destroy(v);
  return VIRGO_SUCCESS;
}

int main(int argc, char* argv[])
{
  virgo_t *v;
  virgo_error_t *err = NULL;
  int ret;

  v = virgo_context_new(argc, argv, "Rackspace Monitoring Agent");

#ifdef _WIN32
  err = virgo_service_handler(v, main_wrapper);
#else
  err = main_wrapper(v);
#endif

  handle_error(v, "Main exiting", err);
  virgo_error_clear(err);

  if (err == VIRGO_SUCCESS) {
    ret = 0;
  } else {
    ret = EXIT_FAILURE;
  }
  return ret;
}

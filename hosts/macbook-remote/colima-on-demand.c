// Headless Docker socket proxy for the macbook-remote Colima VM.
// The stable listener is owned by launchd; this process is socket activated.

#include <errno.h>
#include <fcntl.h>
#include <launch.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static const char *colima_bin;
static const char *docker_bin;
static const char *upstream_socket;
static unsigned idle_seconds = 1800;
static pthread_mutex_t active_mutex = PTHREAD_MUTEX_INITIALIZER;
static unsigned active_connections = 0;

static void log_error(const char *what) {
  fprintf(stderr, "colima-on-demand: %s: %s\n", what, strerror(errno));
}

static int run_command(char *const argv[], char *output, size_t output_size) {
  int pipefd[2] = {-1, -1};
  if (output != NULL && pipe(pipefd) != 0) {
    log_error("pipe");
    return -1;
  }

  pid_t child = fork();
  if (child < 0) {
    log_error("fork");
    if (pipefd[0] >= 0) close(pipefd[0]);
    if (pipefd[1] >= 0) close(pipefd[1]);
    return -1;
  }
  if (child == 0) {
    if (output != NULL) {
      close(pipefd[0]);
      if (dup2(pipefd[1], STDOUT_FILENO) < 0) _exit(126);
      close(pipefd[1]);
    }
    execv(argv[0], argv);
    _exit(127);
  }

  bool has_output = false;
  if (output != NULL) {
    close(pipefd[1]);
    char buffer[256];
    ssize_t count;
    while ((count = read(pipefd[0], buffer, sizeof(buffer))) > 0) {
      if (output_size > 1 && !has_output) {
        output[0] = buffer[0];
        output[1] = '\0';
        has_output = true;
      }
    }
    close(pipefd[0]);
  }

  int status = 0;
  while (waitpid(child, &status, 0) < 0) {
    if (errno != EINTR) {
      log_error("waitpid");
      return -1;
    }
  }
  if (output != NULL && !has_output && output_size > 0) output[0] = '\0';
  return WIFEXITED(status) ? WEXITSTATUS(status) : 128;
}

static int colima_action(const char *action) {
  char *const start_args[] = {
      (char *)colima_bin, "start", "default", "--activate=false",
      "--save-config=false", NULL};
  char *const stop_args[] = {
      (char *)colima_bin, "stop", "default", NULL};
  return run_command(strcmp(action, "start") == 0 ? start_args : stop_args,
                     NULL, 0);
}

static bool docker_api_ready(void) {
  char *args[] = {(char *)docker_bin, "--host", NULL, "version", "--format",
                  "{{.Server.Version}}", NULL};
  char endpoint[sizeof("unix://") + sizeof(((struct sockaddr_un *)0)->sun_path)];
  snprintf(endpoint, sizeof(endpoint), "unix://%s", upstream_socket);
  args[2] = endpoint;
  char output[2];
  return run_command(args, output, sizeof(output)) == 0 && output[0] != '\0';
}

static bool has_running_containers(void) {
  char *args[] = {(char *)docker_bin, "--host", NULL, "ps", "-q", NULL};
  char endpoint[sizeof("unix://") + sizeof(((struct sockaddr_un *)0)->sun_path)];
  snprintf(endpoint, sizeof(endpoint), "unix://%s", upstream_socket);
  args[2] = endpoint;
  char output[2];
  int status = run_command(args, output, sizeof(output));
  // On an API or CLI failure, keep the VM alive. An uncertain state is not idle.
  return status != 0 || output[0] != '\0';
}

static int connect_upstream(void) {
  int fd = socket(AF_UNIX, SOCK_STREAM, 0);
  if (fd < 0) return -1;
  struct sockaddr_un address = {.sun_family = AF_UNIX};
  if (strlen(upstream_socket) >= sizeof(address.sun_path)) {
    errno = ENAMETOOLONG;
    close(fd);
    return -1;
  }
  strlcpy(address.sun_path, upstream_socket, sizeof(address.sun_path));
  if (connect(fd, (struct sockaddr *)&address, sizeof(address)) != 0) {
    close(fd);
    return -1;
  }
  return fd;
}

static void *proxy_connection(void *opaque) {
  int client_fd = *(int *)opaque;
  free(opaque);
  int upstream_fd = connect_upstream();
  if (upstream_fd < 0) {
    log_error("connect to Colima Docker socket");
    close(client_fd);
    pthread_mutex_lock(&active_mutex);
    active_connections--;
    pthread_mutex_unlock(&active_mutex);
    return NULL;
  }

  struct pollfd pollfds[2] = {
      {.fd = client_fd, .events = POLLIN}, {.fd = upstream_fd, .events = POLLIN}};
  char buffer[64 * 1024];
  bool open[2] = {true, true};
  while (open[0] || open[1]) {
    int result = poll(pollfds, 2, -1);
    if (result < 0) {
      if (errno == EINTR) continue;
      break;
    }
    for (int i = 0; i < 2; i++) {
      if (!open[i] || !(pollfds[i].revents & (POLLIN | POLLHUP | POLLERR))) continue;
      int source = pollfds[i].fd;
      int destination = pollfds[1 - i].fd;
      ssize_t count = recv(source, buffer, sizeof(buffer), 0);
      if (count <= 0) {
        shutdown(destination, SHUT_WR);
        open[i] = false;
      } else {
        ssize_t sent = 0;
        while (sent < count) {
          ssize_t written = send(destination, buffer + sent, (size_t)(count - sent), 0);
          if (written < 0) {
            if (errno == EINTR) continue;
            open[0] = open[1] = false;
            break;
          }
          sent += written;
        }
      }
    }
  }

  close(client_fd);
  close(upstream_fd);
  pthread_mutex_lock(&active_mutex);
  active_connections--;
  pthread_mutex_unlock(&active_mutex);
  return NULL;
}

static void fail_queued_requests(int listener_fd) {
  const char body[] = "{\"message\":\"Colima failed to start\"}";
  char response[256];
  int response_size = snprintf(
      response, sizeof(response),
      "HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\n"
      "Content-Type: application/json\r\nContent-Length: %zu\r\n\r\n%s",
      sizeof(body) - 1, body);
  if (response_size < 0 || (size_t)response_size >= sizeof(response)) return;
  struct pollfd pfd = {.fd = listener_fd, .events = POLLIN};
  while (poll(&pfd, 1, 0) > 0 && (pfd.revents & POLLIN)) {
    int fd = accept(listener_fd, NULL, NULL);
    if (fd < 0) break;
    (void)send(fd, response, (size_t)response_size, 0);
    close(fd);
  }
}

static int set_nonblocking(int fd) {
  int flags = fcntl(fd, F_GETFL, 0);
  return flags < 0 ? -1 : fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

static int parse_args(int argc, char **argv) {
  for (int i = 1; i < argc; i++) {
    if (i + 1 >= argc) return -1;
    if (strcmp(argv[i], "--colima") == 0) colima_bin = argv[++i];
    else if (strcmp(argv[i], "--docker") == 0) docker_bin = argv[++i];
    else if (strcmp(argv[i], "--upstream") == 0) upstream_socket = argv[++i];
    else if (strcmp(argv[i], "--idle-seconds") == 0) idle_seconds = (unsigned)strtoul(argv[++i], NULL, 10);
    else return -1;
  }
  return colima_bin != NULL && docker_bin != NULL && upstream_socket != NULL && idle_seconds > 0 ? 0 : -1;
}

int main(int argc, char **argv) {
  if (parse_args(argc, argv) != 0) {
    fprintf(stderr, "colima-on-demand: invalid command line\n");
    return 64;
  }
  signal(SIGPIPE, SIG_IGN);

  int *listeners = NULL;
  size_t listener_count = 0;
  kern_return_t result = launch_activate_socket("DockerOnDemand", &listeners, &listener_count);
  if (result != 0 || listener_count == 0) {
    fprintf(stderr, "colima-on-demand: launch_activate_socket failed (%d)\n", result);
    free(listeners);
    return 70;
  }
  int listener_fd = listeners[0];
  for (size_t i = 1; i < listener_count; i++) close(listeners[i]);
  free(listeners);
  if (set_nonblocking(listener_fd) != 0) {
    log_error("set listener nonblocking");
    close(listener_fd);
    return 70;
  }

  fprintf(stderr, "colima-on-demand: activated on launchd DockerOnDemand socket\n");
  if (colima_action("start") != 0) {
    fprintf(stderr, "colima-on-demand: Colima failed to start\n");
    fail_queued_requests(listener_fd);
    close(listener_fd);
    return 1;
  }

  // Colima may return before the Docker API accepts requests; hold clients in
  // launchd's backlog until the daemon responds to a real API probe.
  bool ready = false;
  for (int i = 0; i < 60 && !ready; i++) {
    ready = docker_api_ready();
    if (!ready) sleep(1);
  }
  if (!ready) {
    fprintf(stderr, "colima-on-demand: Docker API did not become ready\n");
    fail_queued_requests(listener_fd);
    close(listener_fd);
    return 1;
  }

  time_t idle_since = time(NULL);
  time_t next_container_check = idle_since;
  bool container_running = false;
  for (;;) {
    struct pollfd pfd = {.fd = listener_fd, .events = POLLIN};
    int event = poll(&pfd, 1, 1000);
    if (event < 0 && errno != EINTR) {
      log_error("poll launchd listener");
      break;
    }
    if (event > 0 && (pfd.revents & POLLIN)) {
      for (;;) {
        int client_fd = accept(listener_fd, NULL, NULL);
        if (client_fd < 0) {
          if (errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR) log_error("accept");
          break;
        }
        int *argument = malloc(sizeof(*argument));
        if (argument == NULL) {
          close(client_fd);
          continue;
        }
        *argument = client_fd;
        pthread_mutex_lock(&active_mutex);
        active_connections++;
        pthread_mutex_unlock(&active_mutex);
        pthread_t thread;
        if (pthread_create(&thread, NULL, proxy_connection, argument) != 0) {
          close(client_fd);
          free(argument);
          pthread_mutex_lock(&active_mutex);
          active_connections--;
          pthread_mutex_unlock(&active_mutex);
        } else {
          pthread_detach(thread);
        }
        idle_since = time(NULL);
      }
    }

    time_t now = time(NULL);
    pthread_mutex_lock(&active_mutex);
    unsigned connections = active_connections;
    pthread_mutex_unlock(&active_mutex);
    if (connections > 0) idle_since = now;
    if (now >= next_container_check) {
      container_running = has_running_containers();
      next_container_check = now + 15;
      if (container_running) idle_since = now;
    }

    if (!container_running && connections == 0 && now - idle_since >= (time_t)idle_seconds) {
      // Do not stop if a client is already queued on the launchd listener.
      if (poll(&pfd, 1, 0) > 0 && (pfd.revents & POLLIN)) continue;
      if (has_running_containers()) {
        container_running = true;
        idle_since = now;
        continue;
      }
      fprintf(stderr, "colima-on-demand: idle for %u seconds; stopping Colima\n", idle_seconds);
      if (colima_action("stop") == 0) break;
      fprintf(stderr, "colima-on-demand: Colima stop failed; retrying\n");
      idle_since = now;
    }
  }

  close(listener_fd);
  return 0;
}

#include "systemcalls.h"
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <stdarg.h>

/**
 * @param cmd the command to execute with system()
 * @return true if the command in @param cmd was executed
 *   successfully using the system() call, false if an error occurred,
 *   either in invocation of the system() call, or if a non-zero return
 *   value was returned by the command issued in @param cmd.
*/
bool do_system(const char *cmd)
{

    if (cmd == NULL) return false;

    int ret = system(cmd);
    return (ret != -1 && WIFEXITED(ret) && WEXITSTATUS(ret) == 0);

}

/**
* @param count -The numbers of variables passed to the function. The variables are command to execute.
*   followed by arguments to pass to the command
*   Since exec() does not perform path expansion, the command to execute needs
*   to be an absolute path.
* @param ... - A list of 1 or more arguments after the @param count argument.
*   The first is always the full path to the command to execute with execv()
*   The remaining arguments are a list of arguments to pass to the command in execv()
* @return true if the command @param ... with arguments @param arguments were executed successfully
*   using the execv() call, false if an error occurred, either in invocation of the
*   fork, waitpid, or execv() command, or if a non-zero return value was returned
*   by the command issued in @param arguments with the specified arguments.
*/

bool do_exec(int count, ...)
{
    if (count < 1) return false;

    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;
    // this line is to avoid a compile warning before your implementation is complete
    // and may be removed
    command[count] = command[count];

    va_end(args);

    pid_t pid = fork();
    if (pid < 0) return false;

    if (pid == 0) {
        execv(command[0], command);
        exit(EXIT_FAILURE);  // exec failed
    }

    int status;
    if (waitpid(pid, &status, 0) == -1) return false;

    return (WIFEXITED(status) && WEXITSTATUS(status) == 0);
}

/**
* @param outputfile - The full path to the file to write with command output.
*   This file will be closed at completion of the function call.
* All other parameters, see do_exec above
*/
bool do_exec_redirect(const char *outputfile, int count, ...)
{
    if (outputfile == NULL || count < 1) return false;

    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;
    va_end(args);

    pid_t pid = fork();
    if (pid < 0) return false;

    if (pid == 0) {
        int fd = open(outputfile, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd < 0) exit(EXIT_FAILURE);

        dup2(fd, STDOUT_FILENO);
        dup2(fd, STDERR_FILENO);
        close(fd);

        execv(command[0], command);
        exit(EXIT_FAILURE);  // exec failed
    }

    int status;
    if (waitpid(pid, &status, 0) == -1) return false;

    return (WIFEXITED(status) && WEXITSTATUS(status) == 0);
}

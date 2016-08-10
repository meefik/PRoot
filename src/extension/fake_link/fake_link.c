#include <unistd.h>    /* IO */
#include <sys/stat.h>  /* fstat(2), */
#include <sys/mman.h>  /* mmap */
#include <errno.h>     /* E*, */
#include <limits.h>    /* PATH_MAX, */

#include "extension/extension.h"
#include "tracee/tracee.h"
#include "tracee/mem.h"
#include "syscall/syscall.h"
#include "syscall/sysnum.h"
#include "path/path.h"
#include "arch.h"
#include "attribute.h"

/**
 * Copy file with access permissions.
 */
int copy_file(const char *from, const char *to)
{
	int fd_to = -1;
	int fd_from = -1;

	fd_from = open(from, O_RDONLY);
	if (fd_from < 0)
		goto out_error;

	struct stat sbuf;
	if (fstat(fd_from, &sbuf) < 0)
		goto out_error;

	fd_to = open(to, O_WRONLY | O_CREAT | O_EXCL, sbuf.st_mode);
	if (fd_to < 0)
		goto out_error;

	if (sbuf.st_size > 0) {
		void *mem = mmap(NULL, sbuf.st_size, PROT_READ, MAP_SHARED, fd_from, 0);
		if(mem == MAP_FAILED)
			goto out_error;

		ssize_t nwritten = write(fd_to, mem, sbuf.st_size);
		if (nwritten < sbuf.st_size)
			goto out_error;
	}

	if (close(fd_to) < 0) {
		fd_to = -1;
		goto out_error;
	}
	close(fd_from);

	/* Success! */
	return 0;

out_error:
	if (fd_from >= 0)
		close(fd_from);
	if (fd_to >= 0)
		close(fd_to);

	return errno ? -errno : -1;
}

/**
 * Handler for this @extension.  It is triggered each time an @event
 * occurred.  See ExtensionEvent for the meaning of @data1 and @data2.
 */
int fake_link_callback(Extension *extension, ExtensionEvent event,
			intptr_t data1 UNUSED, intptr_t data2 UNUSED)
{
	Tracee *tracee = TRACEE(extension);
	int status;
	char oldpath[PATH_MAX];
	char newpath[PATH_MAX];

	switch (event) {
	case INITIALIZATION: {
		/* List of syscalls handled by this extensions.  */
		static FilteredSysnum filtered_sysnums[] = {
				{ PR_link,		FILTER_SYSEXIT },
			{ PR_linkat,		FILTER_SYSEXIT },
			FILTERED_SYSNUM_END,
		};
		extension->filtered_sysnums = filtered_sysnums;
		return 0;
	}

	case SYSCALL_ENTER_END: {
		word_t sysnum = get_sysnum(tracee, ORIGINAL);
		switch (sysnum) {
		case PR_link:
			status = get_sysarg_path(tracee, oldpath, SYSARG_1);
			if (status < 0)
				return status;

			status = get_sysarg_path(tracee, newpath, SYSARG_2);
			if (status < 0)
				return status;

			status = copy_file(oldpath, newpath);
			if (status < 0)
				return status;

			set_sysnum(tracee, PR_void);
			break;

		case PR_linkat:
			status = get_sysarg_path(tracee, oldpath, SYSARG_2);
			if (status < 0)
				return status;

			status = get_sysarg_path(tracee, newpath, SYSARG_4);
			if (status < 0)
				return status;

			status = copy_file(oldpath, newpath);
			if (status < 0)
				return status;
				
			set_sysnum(tracee, PR_void);
			break;
		}
		return 0;
	}

	case SYSCALL_EXIT_END: {
		word_t sysnum = get_sysnum(tracee, ORIGINAL);
		switch (sysnum) {
		case PR_link:
		case PR_linkat:
			/* These syscalls are fully emulated */
			if (tracee->status >= 0)
				poke_reg(tracee, SYSARG_RESULT, 0);
			break;
		}
		return 0;
	}

	default:
		return 0;
	}
}

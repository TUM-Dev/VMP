/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#ifndef VMP_ERROR_H
#define VMP_ERROR_H

#include <glib.h>

G_BEGIN_DECLS

typedef enum _VMPError
{
    VMP_ERROR_UNKNOWN = 0,
    VMP_ERROR_ARGUMENTS_MISSING,
    VMP_ERROR_V4L2_ERRNO,
    VMP_ERROR_V4L2_NOT_SUPPORTED,
    VMP_ERROR_INVALID_DEVICE_PATH
} VMPError;

/**
 * vmp_error_quark:
 *
 * Returns the #GQuark used to identify #VMPError.
 */
GQuark vmp_error_quark(void);

/**
 * vmp_error_get_message:
 * @error: a #VMPError
 *
 * Returns the message associated with the #VMPError.
 */
gchar *vmp_error_get_message(VMPError error);

G_END_DECLS

#endif // VMP_ERROR_H
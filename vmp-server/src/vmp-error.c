/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include "vmp-error.h"

gchar *vmp_error_get_message(VMPError error)
{
    switch (error)
    {
    case VMP_ERROR_UNKNOWN:
        return g_strdup("Unknown error");
        break;
    case VMP_ERROR_ARGUMENTS_MISSING:
        return g_strdup("Missing arguments");
    case VMP_ERROR_V4L2_ERRNO:
        return g_strdup("V4L2 error");
    case VMP_ERROR_V4L2_NOT_SUPPORTED:
        return g_strdup("V4L2 device is not a video output device");
    default:
        g_assert_not_reached();
    }
}

G_DEFINE_QUARK(vmp_error_quark, vmp_error);
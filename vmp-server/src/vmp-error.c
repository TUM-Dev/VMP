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
        return "Unknown error";
        break;
    case VMP_ERROR_ARGUMENTS_MISSING:
        return "Missing arguments";
    case VMP_ERROR_V4L2_ERRNO:
        return "V4L2 error";
    case VMP_ERROR_ALSA_ERRNO:
        return "ALSA error";
    case VMP_ERROR_V4L2_NOT_SUPPORTED:
        return "V4L2 device is not a video output device";
    case VMP_ERROR_DEVICE_NOT_AVAILABLE:
        return "Device is not available!";
    case VMP_ERROR_INVALID_DEVICE_PATH:
        return "Path is not a valid device path! Does not have prefix '/dev/'";
    default:
        g_assert_not_reached();
    }
}

G_DEFINE_QUARK(vmp_error_quark, vmp_error);
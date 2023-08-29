/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include "vmp-common.h"

void vmp_common_event_log(const gchar *title, const gchar *format, ...)
{
    va_list args;
    va_start(args, format);
    gchar *new_format = g_strconcat("[Event] ", title, ": ", format, NULL);
    g_logv(VMP_LOG_DOMAIN, G_LOG_LEVEL_INFO, new_format, args);
    g_free(new_format);
    va_end(args);
}

void vmp_common_event_log_debug(const gchar *title, const gchar *format, ...)
{
    va_list args;
    va_start(args, format);
    gchar *new_format = g_strconcat("[Event] ", title, ": ", format, NULL);
    g_logv(VMP_LOG_DOMAIN, G_LOG_LEVEL_DEBUG, new_format, args);
    g_free(new_format);
    va_end(args);
}
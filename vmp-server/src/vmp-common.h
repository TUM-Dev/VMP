/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#ifndef VMP_COMMON_H
#define VMP_COMMON_H

#include <glib.h>

#define VMP_LOG_DOMAIN "com.hugomelder.vmp-server"

/**
 * vmp_common_event_log:
 * @title: Title of the event
 * @format: Format string
 *
 * Logs an event in the VMP_LOG_DOMAIN.
 */
void vmp_common_event_log(const gchar *title, const gchar *format, ...);

/**
 * vmp_common_event_log_debug:
 *
 * Same as vmp_common_event_log, but on debug log.
 */
void vmp_common_event_log_debug(const gchar *title, const gchar *format, ...);

#endif // VMP_COMMON_H
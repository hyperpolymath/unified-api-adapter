/* SPDX-License-Identifier: MPL-2.0 */
/* Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> */
#ifndef UAA_REGISTRY_H
#define UAA_REGISTRY_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct uaa_registry uaa_registry;
typedef int (*uaa_callback)(void *context, const uint8_t *bytes, size_t len);
/* Caller serializes access, supplies a live handle, and destroys it once.
 * Registration borrows callback/context until unregister/destroy. Input is a
 * readable span for the synchronous call; NULL is valid only at length zero.
 * No pointers are retained from an invocation. Callbacks must not unwind across
 * the C ABI. Mutation, recursion and destruction during a callback return 6.
 * Status codes are Abi.Status: 0 success, 2 unknown tag, 4 null argument,
 * 6 invocation failure/reentrancy, 9 duplicate registration, 11 unsupported.
 * Unregister returns 8 for an empty slot. Call returns 11 for an unregistered
 * REST/MCP slot (or another known, unsupported protocol).
 * Success from call is the callback's report, not proof of remote delivery.
 */
uaa_registry *uaa_registry_create(void);
int uaa_registry_destroy(uaa_registry *registry);
int uaa_registry_register(uaa_registry *registry, uint8_t tag,
                          uaa_callback callback, void *context);
int uaa_registry_unregister(uaa_registry *registry, uint8_t tag);
int uaa_registry_call(uaa_registry *registry, uint8_t tag,
                     const uint8_t *bytes, size_t len);
#ifdef __cplusplus
}
#endif
#endif

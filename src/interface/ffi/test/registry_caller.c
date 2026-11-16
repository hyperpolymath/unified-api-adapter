/* SPDX-License-Identifier: MPL-2.0 */
/* Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> */
#include "uaa_registry.h"
#include <stdio.h>
#include <stdlib.h>

#define CHECK(x) do { if (!(x)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #x); exit(1); } } while (0)
struct context { unsigned endpoint; unsigned seen; unsigned calls; int result; uaa_registry *registry; };
static int record(void *raw, const uint8_t *bytes, size_t len) {
    struct context *ctx = raw;
    CHECK(len == 3 && bytes != NULL);
    CHECK(bytes[0] == 0 && bytes[1] == 13 && bytes[2] == 255);
    ctx->seen = ctx->endpoint;
    ctx->calls++;
    if (ctx->registry != NULL) {
        CHECK(uaa_registry_destroy(ctx->registry) == 6);
        CHECK(uaa_registry_unregister(ctx->registry, 1) == 6);
        CHECK(uaa_registry_register(ctx->registry, 9, record, ctx) == 6);
        CHECK(uaa_registry_call(ctx->registry, 1, bytes, len) == 6);
    }
    return ctx->result;
}
static int empty(void *raw, const uint8_t *bytes, size_t len) {
    (void)raw;
    CHECK(bytes == NULL && len == 0);
    return 0;
}
int main(void) {
    const uint8_t payload[] = {0, 13, 255};
    CHECK(uaa_registry_call(NULL, 1, payload, sizeof payload) == 4);
    for (unsigned rest = 0; rest < 2; ++rest) {
        for (unsigned mcp = 0; mcp < 2; ++mcp) {
            uaa_registry *registry = uaa_registry_create();
            CHECK(registry != NULL);
            struct context rc = {9,0,0,0,NULL}, mc = {1,0,0,0,NULL};
            if (rest) CHECK(uaa_registry_register(registry, 9, record, &rc) == 0);
            if (mcp) CHECK(uaa_registry_register(registry, 1, record, &mc) == 0);
            for (unsigned tag = 0; tag < 256; ++tag) {
                rc.seen = mc.seen = 0;
                int status = uaa_registry_call(registry, (uint8_t)tag, payload, sizeof payload);
                printf("case,%u,%u,%d,%u\n", rest + 2*mcp, tag, status, rc.seen + mc.seen);
            }
            CHECK(rc.calls == rest && mc.calls == mcp);
            CHECK(uaa_registry_destroy(registry) == 0);
        }
    }
    uaa_registry *registry = uaa_registry_create();
    CHECK(registry != NULL);
    struct context ctx = {1,0,0,7,registry};
    CHECK(uaa_registry_register(registry, 0, record, &ctx) == 2);
    CHECK(uaa_registry_register(registry, 2, record, &ctx) == 11);
    CHECK(uaa_registry_register(registry, 1, NULL, &ctx) == 4);
    CHECK(uaa_registry_unregister(registry, 1) == 8);
    CHECK(uaa_registry_register(registry, 1, record, &ctx) == 0);
    CHECK(uaa_registry_register(registry, 1, empty, NULL) == 9);
    CHECK(uaa_registry_call(registry, 1, NULL, 1) == 4);
    CHECK(ctx.calls == 0);
    CHECK(uaa_registry_call(registry, 1, payload, sizeof payload) == 7);
    ctx.result = 99;
    CHECK(uaa_registry_call(registry, 1, payload, sizeof payload) == 6);
    CHECK(uaa_registry_unregister(registry, 1) == 0);
    CHECK(uaa_registry_call(registry, 1, payload, sizeof payload) == 11);
    CHECK(ctx.calls == 2);
    CHECK(uaa_registry_register(registry, 1, empty, NULL) == 0);
    CHECK(uaa_registry_call(registry, 1, NULL, 0) == 0);
    CHECK(uaa_registry_destroy(registry) == 0);
    return 0;
}

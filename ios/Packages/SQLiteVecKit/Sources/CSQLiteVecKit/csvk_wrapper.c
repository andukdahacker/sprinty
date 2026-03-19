#include "include/CSQLiteVecKit.h"
#include "internal/sqlite3.h"
#include "internal/sqlite-vec.h"

int csvk_initialize(void) {
    return sqlite3_auto_extension((void (*)(void))sqlite3_vec_init);
}

int csvk_open(const char *path, sqlite3 **db) {
    return sqlite3_open(path, db);
}

void csvk_close(sqlite3 *db) {
    sqlite3_close(db);
}

const char *csvk_errmsg(sqlite3 *db) {
    return sqlite3_errmsg(db);
}

int csvk_exec(sqlite3 *db, const char *sql) {
    return sqlite3_exec(db, sql, NULL, NULL, NULL);
}

int csvk_prepare(sqlite3 *db, const char *sql, sqlite3_stmt **stmt) {
    return sqlite3_prepare_v2(db, sql, -1, stmt, NULL);
}

void csvk_finalize(sqlite3_stmt *stmt) {
    sqlite3_finalize(stmt);
}

int csvk_step(sqlite3_stmt *stmt) {
    return sqlite3_step(stmt);
}

void csvk_bind_int64(sqlite3_stmt *stmt, int index, int64_t value) {
    sqlite3_bind_int64(stmt, index, value);
}

void csvk_bind_int(sqlite3_stmt *stmt, int index, int value) {
    sqlite3_bind_int(stmt, index, value);
}

void csvk_bind_blob(sqlite3_stmt *stmt, int index, const void *data, int size) {
    sqlite3_bind_blob(stmt, index, data, size, SQLITE_TRANSIENT);
}

int64_t csvk_column_int64(sqlite3_stmt *stmt, int index) {
    return sqlite3_column_int64(stmt, index);
}

double csvk_column_double(sqlite3_stmt *stmt, int index) {
    return sqlite3_column_double(stmt, index);
}

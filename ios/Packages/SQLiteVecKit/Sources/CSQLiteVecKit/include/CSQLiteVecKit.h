#ifndef CSQLITEVECKIT_H
#define CSQLITEVECKIT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque SQLite types
typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;

// Return codes
#define CSVK_OK          0
#define CSVK_ERROR       1
#define CSVK_ROW         100
#define CSVK_DONE        101

// Initialize sqlite-vec extension (must call before opening any database)
int csvk_initialize(void);

// Database operations
int csvk_open(const char *path, sqlite3 **db);
void csvk_close(sqlite3 *db);
const char *csvk_errmsg(sqlite3 *db);

// Execute SQL without results
int csvk_exec(sqlite3 *db, const char *sql);

// Prepared statement operations
int csvk_prepare(sqlite3 *db, const char *sql, sqlite3_stmt **stmt);
void csvk_finalize(sqlite3_stmt *stmt);
int csvk_step(sqlite3_stmt *stmt);

// Bind parameters
void csvk_bind_int64(sqlite3_stmt *stmt, int index, int64_t value);
void csvk_bind_int(sqlite3_stmt *stmt, int index, int value);
void csvk_bind_blob(sqlite3_stmt *stmt, int index, const void *data, int size);

// Read columns
int64_t csvk_column_int64(sqlite3_stmt *stmt, int index);
double csvk_column_double(sqlite3_stmt *stmt, int index);

#ifdef __cplusplus
}
#endif

#endif /* CSQLITEVECKIT_H */

package middleware

import (
	"context"
	"log/slog"
	"net/http"
	"time"
)

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

// LogFields holds mutable fields that inner middleware can populate for logging.
type LogFields struct {
	DeviceID string
}

type logFieldsKeyType string

const logFieldsKey logFieldsKeyType = "logFields"

// LogFieldsFromContext retrieves the shared LogFields from the request context.
func LogFieldsFromContext(ctx context.Context) *LogFields {
	if fields, ok := ctx.Value(logFieldsKey).(*LogFields); ok {
		return fields
	}
	return nil
}

func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Store mutable LogFields in context for inner middleware to populate.
		fields := &LogFields{}
		r = r.WithContext(context.WithValue(r.Context(), logFieldsKey, fields))

		slog.Info("request started",
			"method", r.Method,
			"path", r.URL.Path,
		)

		rw := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
		next.ServeHTTP(rw, r)

		duration := time.Since(start)
		attrs := []any{
			"method", r.Method,
			"path", r.URL.Path,
			"status", rw.statusCode,
			"duration", duration.String(),
		}

		if fields.DeviceID != "" {
			attrs = append(attrs, "deviceId", fields.DeviceID)
		}

		if rw.statusCode >= 400 {
			slog.Warn("request completed", attrs...)
		} else {
			slog.Info("request completed", attrs...)
		}
	})
}

package handlers

import (
	"net/http"
	"os"
	"time"
)

var serverStartTime = time.Now()

func HealthHandler(w http.ResponseWriter, r *http.Request) {
	resp := map[string]any{
		"status": "ok",
		"uptime": time.Since(serverStartTime).String(),
	}

	if commitSHA := os.Getenv("RAILWAY_GIT_COMMIT_SHA"); commitSHA != "" {
		resp["commitSha"] = commitSHA
	}

	WriteJSON(w, http.StatusOK, resp)
}

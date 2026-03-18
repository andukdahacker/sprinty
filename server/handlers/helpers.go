package handlers

import (
	"net/http"

	"github.com/ducdo/sprinty/server/httputil"
)

func WriteJSON(w http.ResponseWriter, status int, data any) {
	httputil.WriteJSON(w, status, data)
}

func WriteError(w http.ResponseWriter, status int, code string, message string) {
	httputil.WriteError(w, status, code, message)
}

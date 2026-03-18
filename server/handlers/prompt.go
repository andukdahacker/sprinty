package handlers

import (
	"net/http"

	"github.com/ducdo/sprinty/server/prompts"
)

func PromptVersionHandler(builder *prompts.Builder) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		WriteJSON(w, http.StatusOK, map[string]string{
			"version": builder.ContentHash(),
		})
	}
}

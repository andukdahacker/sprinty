package appstore

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// --- Story 8.1 Tests ---

func buildSignedTransactionInfo(productID string, expiresDate *int64, revocationDate *int64) string {
	info := transactionInfo{
		ProductID:      productID,
		ExpiresDate:    expiresDate,
		RevocationDate: revocationDate,
	}
	payload, _ := json.Marshal(info)

	// Build a fake JWS (header.payload.signature) — only payload matters for our decode
	header := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"ES256"}`))
	payloadB64 := base64.RawURLEncoding.EncodeToString(payload)
	signature := base64.RawURLEncoding.EncodeToString([]byte("fake-signature"))

	return fmt.Sprintf("%s.%s.%s", header, payloadB64, signature)
}

func TestValidateTransaction_ValidActiveSubscription(t *testing.T) {
	future := time.Now().Add(30 * 24 * time.Hour).UnixMilli()
	signed := buildSignedTransactionInfo(expectedProductID, &future, nil)

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := transactionInfoResponse{SignedTransactionInfo: signed}
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	client := &Client{
		httpClient: server.Client(),
		baseURL:    server.URL,
	}

	tier, err := client.ValidateTransaction(12345)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if tier != "premium" {
		t.Errorf("expected premium, got %q", tier)
	}
}

func TestValidateTransaction_ExpiredSubscription(t *testing.T) {
	past := time.Now().Add(-24 * time.Hour).UnixMilli()
	signed := buildSignedTransactionInfo(expectedProductID, &past, nil)

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := transactionInfoResponse{SignedTransactionInfo: signed}
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	client := &Client{
		httpClient: server.Client(),
		baseURL:    server.URL,
	}

	tier, err := client.ValidateTransaction(12345)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if tier != "free" {
		t.Errorf("expected free, got %q", tier)
	}
}

func TestValidateTransaction_RevokedSubscription(t *testing.T) {
	future := time.Now().Add(30 * 24 * time.Hour).UnixMilli()
	revoked := time.Now().Add(-1 * time.Hour).UnixMilli()
	signed := buildSignedTransactionInfo(expectedProductID, &future, &revoked)

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := transactionInfoResponse{SignedTransactionInfo: signed}
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	client := &Client{
		httpClient: server.Client(),
		baseURL:    server.URL,
	}

	tier, err := client.ValidateTransaction(12345)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if tier != "free" {
		t.Errorf("expected free, got %q", tier)
	}
}

func TestValidateTransaction_WrongProductID(t *testing.T) {
	future := time.Now().Add(30 * 24 * time.Hour).UnixMilli()
	signed := buildSignedTransactionInfo("com.other.product", &future, nil)

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := transactionInfoResponse{SignedTransactionInfo: signed}
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	client := &Client{
		httpClient: server.Client(),
		baseURL:    server.URL,
	}

	tier, err := client.ValidateTransaction(12345)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if tier != "free" {
		t.Errorf("expected free, got %q", tier)
	}
}

func TestValidateTransaction_AppleAPIUnreachable(t *testing.T) {
	// Use a server that closes immediately to simulate unreachable
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Close connection without responding
		hj, ok := w.(http.Hijacker)
		if ok {
			conn, _, _ := hj.Hijack()
			conn.Close()
			return
		}
		// Fallback: return 500
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	client := &Client{
		httpClient: server.Client(),
		baseURL:    server.URL,
	}

	_, err := client.ValidateTransaction(12345)
	if err == nil {
		t.Fatal("expected error for unreachable API")
	}
}

func TestValidateTransaction_AppleReturns404(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
		w.Write([]byte(`{"errorCode": 4040010, "errorMessage": "TransactionIdNotFoundError"}`))
	}))
	defer server.Close()

	client := &Client{
		httpClient: server.Client(),
		baseURL:    server.URL,
	}

	tier, err := client.ValidateTransaction(99999)
	// Non-200 returns "free" with an error
	if err == nil {
		t.Fatal("expected error for 404 response")
	}
	if tier != "free" {
		t.Errorf("expected free on 404, got %q", tier)
	}
}

func TestNewClient_EmptyCredentials(t *testing.T) {
	client := NewClient("", "", "", "")
	if client != nil {
		t.Error("expected nil client for empty credentials")
	}
}

func TestNewClient_InvalidBase64Key(t *testing.T) {
	client := NewClient("key", "issuer", "bundle", "not-valid-base64!!!")
	if client != nil {
		t.Error("expected nil client for invalid base64 key")
	}
}

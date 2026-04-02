package appstore

import (
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	productionURL = "https://api.storekit.itunes.apple.com"
	sandboxURL    = "https://api.storekit-sandbox.itunes.apple.com"
	expectedProductID = "com.ducdo.sprinty.premium.monthly"
)

// Client communicates with the Apple App Store Server API v2.
type Client struct {
	httpClient *http.Client
	keyID      string
	issuerID   string
	bundleID   string
	privateKey *ecdsa.PrivateKey
	baseURL    string
}

// NewClient creates a new App Store Server API client.
// privateKeyBase64 is the base64-encoded PEM private key.
// Returns nil if credentials are empty (dev mode — skip validation).
func NewClient(keyID, issuerID, bundleID, privateKeyBase64 string) *Client {
	if keyID == "" || issuerID == "" || bundleID == "" || privateKeyBase64 == "" {
		return nil
	}

	pemBytes, err := base64.StdEncoding.DecodeString(privateKeyBase64)
	if err != nil {
		slog.Error("appstore: failed to decode private key base64", "error", err)
		return nil
	}

	block, _ := pem.Decode(pemBytes)
	if block == nil {
		slog.Error("appstore: failed to parse PEM block")
		return nil
	}

	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		slog.Error("appstore: failed to parse private key", "error", err)
		return nil
	}

	ecKey, ok := key.(*ecdsa.PrivateKey)
	if !ok {
		slog.Error("appstore: private key is not ECDSA")
		return nil
	}

	return &Client{
		httpClient: &http.Client{Timeout: 10 * time.Second},
		keyID:      keyID,
		issuerID:   issuerID,
		bundleID:   bundleID,
		privateKey: ecKey,
		baseURL:    productionURL,
	}
}

// ValidateTransaction checks a transaction with Apple and returns the tier.
// Returns "premium" if the transaction is a valid, active subscription.
// Returns "free" if the transaction is expired, revoked, or wrong product.
// Returns an error only if Apple's API is unreachable.
func (c *Client) ValidateTransaction(transactionID uint64) (string, error) {
	url := fmt.Sprintf("%s/inApps/v1/transactions/%d", c.baseURL, transactionID)
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", fmt.Errorf("appstore: failed to create request: %w", err)
	}

	if c.privateKey != nil {
		token, err := c.generateToken()
		if err != nil {
			return "", fmt.Errorf("appstore: failed to generate token: %w", err)
		}
		req.Header.Set("Authorization", "Bearer "+token)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("appstore: request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "free", fmt.Errorf("appstore: unexpected status %d: %s", resp.StatusCode, string(body))
	}

	var txnResp transactionInfoResponse
	if err := json.NewDecoder(resp.Body).Decode(&txnResp); err != nil {
		return "free", fmt.Errorf("appstore: failed to decode response: %w", err)
	}

	info, err := c.decodeSignedTransaction(txnResp.SignedTransactionInfo)
	if err != nil {
		return "free", fmt.Errorf("appstore: failed to decode signed transaction: %w", err)
	}

	if info.ProductID != expectedProductID {
		slog.Warn("appstore: product mismatch", "expected", expectedProductID, "got", info.ProductID)
		return "free", nil
	}

	if info.RevocationDate != nil && *info.RevocationDate > 0 {
		slog.Info("appstore: transaction revoked", "transactionId", transactionID)
		return "free", nil
	}

	if info.ExpiresDate != nil && time.UnixMilli(*info.ExpiresDate).Before(time.Now()) {
		slog.Info("appstore: subscription expired", "transactionId", transactionID)
		return "free", nil
	}

	return "premium", nil
}

func (c *Client) generateToken() (string, error) {
	now := time.Now()
	claims := jwt.MapClaims{
		"iss": c.issuerID,
		"iat": now.Unix(),
		"exp": now.Add(5 * time.Minute).Unix(),
		"aud": "appstoreconnect-v1",
		"bid": c.bundleID,
	}

	token := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	token.Header["kid"] = c.keyID
	return token.SignedString(c.privateKey)
}

func (c *Client) decodeSignedTransaction(signedInfo string) (*transactionInfo, error) {
	// The signed transaction info is a JWS (3 parts separated by dots).
	// We only need the payload (part 2) — Apple signs with their own key.
	parts := strings.SplitN(signedInfo, ".", 3)
	if len(parts) != 3 {
		return nil, fmt.Errorf("appstore: invalid JWS format")
	}

	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, fmt.Errorf("appstore: failed to decode JWS payload: %w", err)
	}

	var info transactionInfo
	if err := json.Unmarshal(payload, &info); err != nil {
		return nil, fmt.Errorf("appstore: failed to unmarshal transaction info: %w", err)
	}

	return &info, nil
}

type transactionInfoResponse struct {
	SignedTransactionInfo string `json:"signedTransactionInfo"`
}

type transactionInfo struct {
	ProductID      string `json:"productId"`
	ExpiresDate    *int64 `json:"expiresDate"`
	RevocationDate *int64 `json:"revocationDate"`
}

// SetBaseURL overrides the base URL (for testing).
func (c *Client) SetBaseURL(url string) {
	c.baseURL = url
}

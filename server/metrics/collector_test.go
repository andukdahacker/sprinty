package metrics

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
)

// --- Story 10.5 Tests ---

func TestCollectorRecordRequestIncrementsCounts(t *testing.T) {
	c := NewCollector(100)

	c.RecordRequest("anthropic", "free", 200, 50.0, "green")
	c.RecordRequest("anthropic", "free", 200, 100.0, "green")
	c.RecordRequest("openai", "premium", 500, 200.0, "yellow")

	snap := c.Snapshot()

	if snap["requestCount"].(int64) != 3 {
		t.Errorf("expected requestCount=3, got %v", snap["requestCount"])
	}
	if snap["errorCount"].(int64) != 1 {
		t.Errorf("expected errorCount=1, got %v", snap["errorCount"])
	}
}

func TestCollectorLatencyPercentiles(t *testing.T) {
	c := NewCollector(100)

	// Record 100 latencies: 1, 2, 3, ..., 100
	for i := 1; i <= 100; i++ {
		c.RecordRequest("anthropic", "free", 200, float64(i), "green")
	}

	snap := c.Snapshot()
	latency, ok := snap["latency"].(map[string]float64)
	if !ok {
		t.Fatal("expected latency map in snapshot")
	}

	// p50 should be ~50.5
	if latency["p50"] < 49 || latency["p50"] > 52 {
		t.Errorf("expected p50 ~50.5, got %v", latency["p50"])
	}
	// p95 should be ~95.05
	if latency["p95"] < 93 || latency["p95"] > 97 {
		t.Errorf("expected p95 ~95, got %v", latency["p95"])
	}
	// p99 should be ~99.01
	if latency["p99"] < 97 || latency["p99"] > 101 {
		t.Errorf("expected p99 ~99, got %v", latency["p99"])
	}
}

func TestCollectorByProviderBreakdown(t *testing.T) {
	c := NewCollector(100)

	c.RecordRequest("anthropic", "free", 200, 10.0, "green")
	c.RecordRequest("anthropic", "free", 200, 20.0, "green")
	c.RecordRequest("openai", "premium", 200, 30.0, "green")

	snap := c.Snapshot()
	byProvider := snap["byProvider"].(map[string]int64)

	if byProvider["anthropic"] != 2 {
		t.Errorf("expected anthropic=2, got %v", byProvider["anthropic"])
	}
	if byProvider["openai"] != 1 {
		t.Errorf("expected openai=1, got %v", byProvider["openai"])
	}
}

func TestCollectorByTierBreakdown(t *testing.T) {
	c := NewCollector(100)

	c.RecordRequest("anthropic", "free", 200, 10.0, "green")
	c.RecordRequest("anthropic", "premium", 200, 20.0, "green")
	c.RecordRequest("anthropic", "premium", 200, 30.0, "yellow")

	snap := c.Snapshot()
	byTier := snap["byTier"].(map[string]int64)

	if byTier["free"] != 1 {
		t.Errorf("expected free=1, got %v", byTier["free"])
	}
	if byTier["premium"] != 2 {
		t.Errorf("expected premium=2, got %v", byTier["premium"])
	}
}

func TestCollectorByStatusBreakdown(t *testing.T) {
	c := NewCollector(100)

	c.RecordRequest("anthropic", "free", 200, 10.0, "green")
	c.RecordRequest("anthropic", "free", 401, 20.0, "green")
	c.RecordRequest("anthropic", "free", 502, 30.0, "green")

	snap := c.Snapshot()
	byStatus := snap["byStatus"].(map[string]int64)

	if byStatus["2xx"] != 1 {
		t.Errorf("expected 2xx=1, got %v", byStatus["2xx"])
	}
	if byStatus["4xx"] != 1 {
		t.Errorf("expected 4xx=1, got %v", byStatus["4xx"])
	}
	if byStatus["5xx"] != 1 {
		t.Errorf("expected 5xx=1, got %v", byStatus["5xx"])
	}
}

func TestCollectorBySafetyLevelBreakdown(t *testing.T) {
	c := NewCollector(100)

	c.RecordRequest("anthropic", "free", 200, 10.0, "green")
	c.RecordRequest("anthropic", "free", 200, 20.0, "green")
	c.RecordRequest("anthropic", "free", 200, 30.0, "yellow")
	c.RecordRequest("anthropic", "free", 200, 40.0, "red")
	c.RecordRequest("anthropic", "free", 200, 50.0, "") // empty safety level not counted

	snap := c.Snapshot()
	bySafety := snap["bySafetyLevel"].(map[string]int64)

	if bySafety["green"] != 2 {
		t.Errorf("expected green=2, got %v", bySafety["green"])
	}
	if bySafety["yellow"] != 1 {
		t.Errorf("expected yellow=1, got %v", bySafety["yellow"])
	}
	if bySafety["red"] != 1 {
		t.Errorf("expected red=1, got %v", bySafety["red"])
	}
	if _, exists := bySafety[""]; exists {
		t.Error("empty safety level should not be counted")
	}
}

func TestCollectorRingBufferOverflow(t *testing.T) {
	c := NewCollector(5)

	// Record more than capacity
	for i := 0; i < 10; i++ {
		c.RecordRequest("anthropic", "free", 200, float64(i*10), "green")
	}

	snap := c.Snapshot()
	latency, ok := snap["latency"].(map[string]float64)
	if !ok {
		t.Fatal("expected latency map in snapshot")
	}

	// Should still have valid percentiles even after overflow
	if latency["p50"] <= 0 {
		t.Errorf("expected positive p50, got %v", latency["p50"])
	}
}

func TestCollectorConcurrentAccess(t *testing.T) {
	c := NewCollector(1000)

	var wg sync.WaitGroup
	for i := 0; i < 100; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			c.RecordRequest("anthropic", "free", 200, float64(i), "green")
		}(i)
	}
	wg.Wait()

	snap := c.Snapshot()
	if snap["requestCount"].(int64) != 100 {
		t.Errorf("expected requestCount=100, got %v", snap["requestCount"])
	}
}

func TestCollectorSnapshotEmptyState(t *testing.T) {
	c := NewCollector(100)

	snap := c.Snapshot()
	if snap["requestCount"].(int64) != 0 {
		t.Errorf("expected requestCount=0, got %v", snap["requestCount"])
	}
	if snap["errorCount"].(int64) != 0 {
		t.Errorf("expected errorCount=0, got %v", snap["errorCount"])
	}
	if _, ok := snap["latency"]; ok {
		t.Error("expected no latency key for empty collector")
	}
}

func TestCollectorHandlerReturnsValidJSON(t *testing.T) {
	c := NewCollector(100)
	c.RecordRequest("anthropic", "free", 200, 42.5, "green")

	req := httptest.NewRequest("GET", "/debug/metrics", nil)
	w := httptest.NewRecorder()

	c.Handler()(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	contentType := w.Header().Get("Content-Type")
	if contentType != "application/json" {
		t.Errorf("expected Content-Type application/json, got %q", contentType)
	}

	var result map[string]any
	if err := json.NewDecoder(w.Body).Decode(&result); err != nil {
		t.Fatalf("failed to decode JSON response: %v", err)
	}

	// Verify expected structure
	requiredKeys := []string{"requestCount", "errorCount", "byProvider", "byTier", "byStatus", "bySafetyLevel", "latency"}
	for _, key := range requiredKeys {
		if _, ok := result[key]; !ok {
			t.Errorf("expected key %q in response", key)
		}
	}
}

func TestCollectorDefaultCapacity(t *testing.T) {
	c := NewCollector(0)
	if c.latencyCap != 1000 {
		t.Errorf("expected default latencyCap=1000, got %d", c.latencyCap)
	}
}

func TestPercentileSingleValue(t *testing.T) {
	result := percentile([]float64{42.0}, 0.50)
	if result != 42.0 {
		t.Errorf("expected 42.0, got %v", result)
	}
}

func TestPercentileEmpty(t *testing.T) {
	result := percentile([]float64{}, 0.50)
	if result != 0 {
		t.Errorf("expected 0, got %v", result)
	}
}

func TestStatusKey(t *testing.T) {
	tests := []struct {
		code     int
		expected string
	}{
		{100, "1xx"},
		{200, "2xx"},
		{301, "3xx"},
		{404, "4xx"},
		{500, "5xx"},
		{503, "5xx"},
	}

	for _, tt := range tests {
		got := statusKey(tt.code)
		if got != tt.expected {
			t.Errorf("statusKey(%d) = %q, want %q", tt.code, got, tt.expected)
		}
	}
}

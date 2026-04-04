package metrics

import (
	"encoding/json"
	"net/http"
	"sort"
	"sync"
	"sync/atomic"
)

// Collector gathers in-process request metrics using atomic counters and a ring-buffer histogram.
type Collector struct {
	requestCount atomic.Int64
	errorCount   atomic.Int64

	mu           sync.Mutex
	latencies    []float64 // ring buffer
	latencyIdx   int
	latencyCap   int

	byProvider   sync.Map // map[string]*atomic.Int64
	byTier       sync.Map
	byStatus     sync.Map // map[int]*atomic.Int64 stored as map[string]*atomic.Int64 for JSON keys
	bySafety     sync.Map
}

// NewCollector creates a Collector with a ring-buffer histogram of the given capacity.
func NewCollector(latencyCap int) *Collector {
	if latencyCap <= 0 {
		latencyCap = 1000
	}
	return &Collector{
		latencies:  make([]float64, 0, latencyCap),
		latencyCap: latencyCap,
	}
}

// RecordRequest records a completed request's metrics.
func (c *Collector) RecordRequest(provider, tier string, status int, latencyMs float64, safetyLevel string) {
	c.requestCount.Add(1)
	if status >= 400 {
		c.errorCount.Add(1)
	}

	// Record latency in ring buffer
	c.mu.Lock()
	if len(c.latencies) < c.latencyCap {
		c.latencies = append(c.latencies, latencyMs)
	} else {
		c.latencies[c.latencyIdx%c.latencyCap] = latencyMs
	}
	c.latencyIdx++
	c.mu.Unlock()

	// Increment dimension counters
	incrementCounter(&c.byProvider, provider)
	incrementCounter(&c.byTier, tier)
	incrementCounter(&c.byStatus, statusKey(status))
	if safetyLevel != "" {
		incrementCounter(&c.bySafety, safetyLevel)
	}
}

// Snapshot returns a JSON-serializable metrics summary.
func (c *Collector) Snapshot() map[string]any {
	snap := map[string]any{
		"requestCount": c.requestCount.Load(),
		"errorCount":   c.errorCount.Load(),
	}

	// Latency percentiles
	c.mu.Lock()
	latCopy := make([]float64, len(c.latencies))
	copy(latCopy, c.latencies)
	c.mu.Unlock()

	if len(latCopy) > 0 {
		sort.Float64s(latCopy)
		snap["latency"] = map[string]float64{
			"p50": percentile(latCopy, 0.50),
			"p95": percentile(latCopy, 0.95),
			"p99": percentile(latCopy, 0.99),
		}
	}

	snap["byProvider"] = syncMapToCountMap(&c.byProvider)
	snap["byTier"] = syncMapToCountMap(&c.byTier)
	snap["byStatus"] = syncMapToCountMap(&c.byStatus)
	snap["bySafetyLevel"] = syncMapToCountMap(&c.bySafety)

	return snap
}

// Handler returns an http.HandlerFunc serving the metrics snapshot as JSON.
func (c *Collector) Handler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(c.Snapshot()); err != nil {
			http.Error(w, "failed to encode metrics", http.StatusInternalServerError)
		}
	}
}

func incrementCounter(m *sync.Map, key string) {
	if key == "" {
		return
	}
	val, _ := m.LoadOrStore(key, &atomic.Int64{})
	val.(*atomic.Int64).Add(1)
}

func syncMapToCountMap(m *sync.Map) map[string]int64 {
	result := make(map[string]int64)
	m.Range(func(key, value any) bool {
		result[key.(string)] = value.(*atomic.Int64).Load()
		return true
	})
	return result
}

func statusKey(code int) string {
	switch {
	case code < 200:
		return "1xx"
	case code < 300:
		return "2xx"
	case code < 400:
		return "3xx"
	case code < 500:
		return "4xx"
	default:
		return "5xx"
	}
}

func percentile(sorted []float64, p float64) float64 {
	if len(sorted) == 0 {
		return 0
	}
	idx := p * float64(len(sorted)-1)
	lower := int(idx)
	upper := lower + 1
	if upper >= len(sorted) {
		return sorted[len(sorted)-1]
	}
	frac := idx - float64(lower)
	return sorted[lower]*(1-frac) + sorted[upper]*frac
}

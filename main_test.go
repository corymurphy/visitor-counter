package main

import (
	"log"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestVisitorCount(t *testing.T) {
	count := VisitorCount{
		Count:     42,
		LastVisit: time.Now(),
		IP:        "127.0.0.1",
	}

	if count.Count != 42 {
		t.Errorf("Expected count to be 42, got %d", count.Count)
	}

	if count.IP != "127.0.0.1" {
		t.Errorf("Expected IP to be 127.0.0.1, got %s", count.IP)
	}
}

func TestHealthEndpoint(t *testing.T) {
	req, err := http.NewRequest("GET", "/health", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(handleHealth)

	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusOK)
	}

	expected := "application/json"
	if rr.Header().Get("Content-Type") != expected {
		t.Errorf("handler returned wrong content type: got %v want %v", rr.Header().Get("Content-Type"), expected)
	}
}

func TestIncrementVisitorCount(t *testing.T) {
	app := &App{
		count: &VisitorCount{
			Count:     0,
			LastVisit: time.Now(),
			IP:        "",
		},
	}

	count := app.incrementVisitorCount("127.0.0.1")
	if count.Count != 1 {
		t.Errorf("Expected count to be 1, got %d", count.Count)
	}

	count = app.incrementVisitorCount("192.168.1.1")
	if count.Count != 2 {
		t.Errorf("Expected count to be 2, got %d", count.Count)
	}

	if count.IP != "192.168.1.1" {
		t.Errorf("Expected IP to be 192.168.1.1, got %s", count.IP)
	}
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_, err := w.Write([]byte(`{"status":"healthy","time":"2023-01-01T00:00:00Z"}`))
	if err != nil {
		log.Printf("Error writing response: %v", err)
	}
}

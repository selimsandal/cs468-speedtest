package main

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
)

// CORS middleware to allow frontend access
func corsMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

		// Handle preflight requests
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next(w, r)
	}
}

// PingResponse represents the ping endpoint response
type PingResponse struct {
	Timestamp int64  `json:"timestamp"`
	Message   string `json:"message"`
}

// pingHandler handles latency/ping measurement
// Client should record time before request and after response to calculate RTT
func pingHandler(w http.ResponseWriter, r *http.Request) {
	response := PingResponse{
		Timestamp: time.Now().UnixNano() / int64(time.Millisecond),
		Message:   "pong",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// downloadHandler generates random data for download speed testing
// Query parameters:
//   - size: number of bytes to download (default: 10MB)
func downloadHandler(w http.ResponseWriter, r *http.Request) {
	// Parse size parameter (in bytes)
	sizeStr := r.URL.Query().Get("size")
	size := 10 * 1024 * 1024 // Default 10MB

	if sizeStr != "" {
		if parsedSize, err := strconv.Atoi(sizeStr); err == nil && parsedSize > 0 {
			size = parsedSize
		}
	}

	// Limit maximum size to prevent abuse (100MB)
	if size > 100*1024*1024 {
		size = 100 * 1024 * 1024
	}

	// Set headers
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Length", strconv.Itoa(size))
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")

	// Generate and send random data in chunks for memory efficiency
	chunkSize := 64 * 1024 // 64KB chunks
	buffer := make([]byte, chunkSize)
	remaining := size

	for remaining > 0 {
		currentChunk := chunkSize
		if remaining < chunkSize {
			currentChunk = remaining
			buffer = make([]byte, currentChunk)
		}

		// Generate random data
		rand.Read(buffer)

		// Write to response
		if _, err := w.Write(buffer); err != nil {
			log.Printf("Error writing download data: %v", err)
			return
		}

		remaining -= currentChunk
	}
}

// uploadHandler receives data for upload speed testing
// Simply reads and discards the data to measure upload speed
func uploadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Read the entire request body and discard it
	bytesReceived, err := io.Copy(io.Discard, r.Body)
	if err != nil {
		http.Error(w, "Error reading upload data", http.StatusInternalServerError)
		log.Printf("Error reading upload data: %v", err)
		return
	}
	defer r.Body.Close()

	// Send response with bytes received
	response := map[string]interface{}{
		"bytesReceived": bytesReceived,
		"message":       "Upload successful",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// healthHandler for basic health check
func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "healthy",
		"time":   time.Now().Format(time.RFC3339),
	})
}

func main() {
	// Register handlers with CORS middleware
	http.HandleFunc("/ping", corsMiddleware(pingHandler))
	http.HandleFunc("/download", corsMiddleware(downloadHandler))
	http.HandleFunc("/upload", corsMiddleware(uploadHandler))
	http.HandleFunc("/health", corsMiddleware(healthHandler))

	// Serve the frontend HTML file
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		http.ServeFile(w, r, "index.html")
	})

	// Get port from environment variable or use default
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	fmt.Printf("========================================\n")
	fmt.Printf("Speed Test Server starting...\n")
	fmt.Printf("========================================\n")
	fmt.Printf("Listening on: 0.0.0.0:%s\n", port)
	fmt.Printf("\nLocal access:\n")
	fmt.Printf("  http://localhost:%s\n", port)
	fmt.Printf("\nAPI Endpoints:\n")
	fmt.Printf("  GET  /           - Web interface\n")
	fmt.Printf("  GET  /ping       - Latency test\n")
	fmt.Printf("  GET  /download   - Download speed test\n")
	fmt.Printf("  POST /upload     - Upload speed test\n")
	fmt.Printf("  GET  /health     - Health check\n")
	fmt.Printf("========================================\n\n")

	log.Printf("Server started successfully on port %s", port)

	if err := http.ListenAndServe("0.0.0.0:"+port, nil); err != nil {
		log.Fatal(err)
	}
}

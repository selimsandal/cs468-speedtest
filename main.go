package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"log"
	mathrand "math/rand"
	"net"
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

// Pre-generate a large buffer of random data to avoid repeated generation
// This is initialized once at startup for performance.
// We use math/rand instead of crypto/rand because:
// 1. Speed testing doesn't require cryptographically secure randomness
// 2. math/rand is significantly faster, improving throughput
// 3. The data pattern doesn't affect speed measurement accuracy
var randomDataBuffer []byte

func init() {
	// Generate 1MB of random data once at startup
	// This buffer is reused for all download requests to maximize performance
	randomDataBuffer = make([]byte, 1024*1024)
	mathrand.Read(randomDataBuffer)
}

// downloadHandler generates random data for download speed testing
// The client requests a large stream size but will abort the connection
// once speed stabilizes, minimizing actual data transferred.
// Query parameters:
//   - size: number of bytes to download (default: 100MB, client will abort when done)
func downloadHandler(w http.ResponseWriter, r *http.Request) {
	// Parse size parameter from query string (in bytes)
	sizeStr := r.URL.Query().Get("size")
	size := 100 * 1024 * 1024 // Default 100MB

	if sizeStr != "" {
		if parsedSize, err := strconv.Atoi(sizeStr); err == nil && parsedSize > 0 {
			size = parsedSize
		}
	}

	// Limit maximum size to prevent abuse
	// Client will abort when speed stabilizes, so full size rarely transferred
	maxSize := 2 * 1024 * 1024 * 1024 // 2GB max
	if size > maxSize {
		size = maxSize
	}

	// Set response headers
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Length", strconv.Itoa(size))
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate") // Prevent caching

	// Use buffered writer for better throughput
	// Buffering reduces system calls and improves performance
	bw := bufio.NewWriterSize(w, 256*1024) // 256KB write buffer
	defer bw.Flush()

	// Send pre-generated random data in large chunks for maximum speed
	bufferSize := len(randomDataBuffer)
	remaining := size

	for remaining > 0 {
		if remaining >= bufferSize {
			// Send full buffer
			if _, err := bw.Write(randomDataBuffer); err != nil {
				log.Printf("Error writing download data: %v", err)
				return
			}
			remaining -= bufferSize
		} else {
			// Send remaining bytes
			if _, err := bw.Write(randomDataBuffer[:remaining]); err != nil {
				log.Printf("Error writing download data: %v", err)
				return
			}
			remaining = 0
		}
	}
}

// uploadHandler receives data for upload speed testing
// The actual data content doesn't matter - we just need to receive it
// at maximum speed to measure the upload bandwidth accurately.
// The data is discarded (not stored) as we only care about transfer rate.
func uploadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Read the entire request body and discard it efficiently
	// io.Discard is optimized for discarding data without allocating memory
	bytesReceived, err := io.Copy(io.Discard, r.Body)
	if err != nil {
		http.Error(w, "Error reading upload data", http.StatusInternalServerError)
		log.Printf("Error reading upload data: %v", err)
		return
	}
	defer r.Body.Close()

	// Send confirmation response with bytes received
	// Client uses this to verify the upload completed successfully
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
	fmt.Printf("  GET  /download   - Download speed test (dynamic)\n")
	fmt.Printf("  POST /upload     - Upload speed test (dynamic)\n")
	fmt.Printf("  GET  /health     - Health check\n")
	fmt.Printf("========================================\n\n")

	log.Printf("Server started successfully on port %s", port)

	// Create optimized HTTP server with appropriate timeouts
	// These settings balance performance with resource management
	server := &http.Server{
		Addr:         "0.0.0.0:" + port,
		ReadTimeout:  30 * time.Second,  // Prevent slow-read attacks
		WriteTimeout: 30 * time.Second,  // Enough time for large transfers
		IdleTimeout:  120 * time.Second, // Keep connections alive for reuse
	}

	// Create custom TCP listener with performance optimizations
	listener, err := net.Listen("tcp", server.Addr)
	if err != nil {
		log.Fatal(err)
	}

	// Wrap listener to apply TCP tuning to each accepted connection
	listener = &tcpKeepAliveListener{listener.(*net.TCPListener)}

	if err := server.Serve(listener); err != nil {
		log.Fatal(err)
	}
}

// tcpKeepAliveListener wraps the TCP listener to optimize each connection
// for high-throughput speed testing. These optimizations are crucial for
// achieving accurate speed measurements on high-bandwidth connections.
type tcpKeepAliveListener struct {
	*net.TCPListener
}

func (ln tcpKeepAliveListener) Accept() (net.Conn, error) {
	tc, err := ln.AcceptTCP()
	if err != nil {
		return nil, err
	}

	// Enable TCP keep-alive to detect dead connections
	// Helps clean up stale connections from aborted tests
	tc.SetKeepAlive(true)
	tc.SetKeepAlivePeriod(3 * time.Minute)

	// Set larger TCP buffers for better throughput
	// Default buffers are often too small for high-speed connections
	// 1MB buffers allow TCP window to scale properly for high bandwidth-delay product
	tc.SetReadBuffer(1024 * 1024)  // 1MB read buffer
	tc.SetWriteBuffer(1024 * 1024) // 1MB write buffer

	// Disable Nagle's algorithm (TCP_NODELAY)
	// Nagle's algorithm batches small writes, which increases latency
	// For speed testing, we want data sent immediately for accurate measurements
	tc.SetNoDelay(true)

	return tc, nil
}

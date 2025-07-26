package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"sync"
	"time"
)

type VisitorCount struct {
	Count     int       `json:"count"`
	LastVisit time.Time `json:"last_visit"`
	IP        string    `json:"ip"`
}

type App struct {
	mu    sync.RWMutex
	count *VisitorCount
}

func main() {
	app := &App{
		count: &VisitorCount{
			Count:     0,
			LastVisit: time.Now(),
			IP:        "",
		},
	}

	http.HandleFunc("/", app.handleHome)
	http.HandleFunc("/api/visit", app.handleVisit)
	http.HandleFunc("/api/count", app.handleGetCount)
	http.HandleFunc("/health", app.handleHealth)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Starting server on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func (app *App) handleHome(w http.ResponseWriter, r *http.Request) {
	app.mu.RLock()
	count := app.count
	app.mu.RUnlock()

	html := fmt.Sprintf(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Visitor Counter</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
            margin: 0;
            padding: 0;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 500px;
            width: 90%%;
        }
        h1 {
            color: #333;
            margin-bottom: 30px;
            font-size: 2.5em;
        }
        .counter {
            font-size: 4em;
            font-weight: bold;
            color: #667eea;
            margin: 20px 0;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.1);
        }
        .last-visit {
            color: #666;
            font-size: 1.1em;
            margin-top: 20px;
        }
        .refresh-btn {
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
            color: white;
            border: none;
            padding: 15px 30px;
            border-radius: 25px;
            font-size: 1.1em;
            cursor: pointer;
            margin-top: 20px;
            transition: transform 0.2s;
        }
        .refresh-btn:hover {
            transform: translateY(-2px);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>👋 Welcome!</h1>
        <div class="counter">%d</div>
        <p>visitors have been here</p>
        <div class="last-visit">
            Last visit: %s
        </div>
        <button class="refresh-btn" onclick="location.reload()">🔄 Refresh</button>
    </div>
    <script>
        // Auto-refresh every 30 seconds
        setTimeout(() => {
            location.reload();
        }, 30000);
    </script>
</body>
</html>`, count.Count, count.LastVisit.Format("Jan 2, 2006 at 3:04 PM"))

	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(html))
}

func (app *App) handleVisit(w http.ResponseWriter, r *http.Request) {
	ip := r.Header.Get("X-Forwarded-For")
	if ip == "" {
		ip = r.Header.Get("X-Real-IP")
	}
	if ip == "" {
		ip = r.RemoteAddr
	}

	log.Println(ip)

	count := app.incrementVisitorCount(ip)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(count)
}

func (app *App) handleGetCount(w http.ResponseWriter, r *http.Request) {
	app.mu.RLock()
	count := app.count
	app.mu.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(count)
}

func (app *App) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "healthy",
		"time":   time.Now().Format(time.RFC3339),
	})
}

func (app *App) incrementVisitorCount(ip string) *VisitorCount {
	app.mu.Lock()
	defer app.mu.Unlock()

	app.count.Count++
	app.count.LastVisit = time.Now()
	app.count.IP = ip

	return app.count
}

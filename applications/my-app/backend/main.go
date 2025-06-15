package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/gorilla/mux"
	_ "github.com/go-sql-driver/mysql"
)

type TextData struct {
	Text string `json:"text"`
}

var db *sql.DB

func main() {
	// Initialize database connection
	initDB()
	defer db.Close()

	// Create router
	r := mux.NewRouter()
	r.HandleFunc("/api/save", saveTextHandler).Methods("POST")

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Server starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}

func initDB() {
	var err error
	mysqlUser := os.Getenv("MYSQL_USER")
	mysqlPassword := os.Getenv("MYSQL_PASSWORD")
	mysqlDatabase := os.Getenv("MYSQL_DATABASE")
	mysqlHost := os.Getenv("MYSQL_HOST")

	dsn := fmt.Sprintf("%s:%s@tcp(%s:3306)/%s", mysqlUser, mysqlPassword, mysqlHost, mysqlDatabase)
	db, err = sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("Error opening database: %v", err)
	}

	// Create table if not exists
	createTableSQL := `
	CREATE TABLE IF NOT EXISTS texts (
		id INT AUTO_INCREMENT PRIMARY KEY,
		content TEXT NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	)`
	_, err = db.Exec(createTableSQL)
	if err != nil {
		log.Fatalf("Error creating table: %v", err)
	}
}

func saveTextHandler(w http.ResponseWriter, r *http.Request) {
	var data TextData
	err := json.NewDecoder(r.Body).Decode(&data)
	if err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Insert text into database
	_, err = db.Exec("INSERT INTO texts (content) VALUES (?)", data.Text)
	if err != nil {
		http.Error(w, "Failed to save text", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "success"})
}


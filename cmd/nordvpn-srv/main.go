package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/thoeni/nordvpn-mux/internal/router"
	"github.com/thoeni/nordvpn-mux/pkg/nordvpn"
)

func main() {
	filesLocation := os.Getenv("OVPN_FILES_LOCATION")
	log.Println("OVPN files location:", filesLocation)
	nordVPN, close, err := nordvpn.New()
	if err != nil {
		log.Fatal("failed NordVPN initialisation", err)
	}
	defer func() {
		_ = close.Close()
	}()
	ctx, cancel := context.WithCancel(context.Background())
	var wg sync.WaitGroup
	wg.Add(2)
	go interruptListener(&wg, cancel)
	go serversDBRefresher(ctx, &wg, nordVPN)
	go func() {
		log.Println("ListenAndServe(): start")
		//The certificate is at "./localhost+2.pem" and the key at "./localhost+2-key.pem"
		if err := http.ListenAndServeTLS(":8080", "./localhost+2.pem", "./localhost+2-key.pem", router.HttpHandler(nordVPN, filesLocation)); err != http.ErrServerClosed {
			log.Fatalf("ListenAndServe(): %v", err)
		}
		log.Println("ListenAndServe(): stop")
	}()
	wg.Wait()
}

func interruptListener(wg *sync.WaitGroup, cancel context.CancelFunc) {
	defer wg.Done()
	done := make(chan os.Signal, 1)
	signal.Notify(done, syscall.SIGINT, syscall.SIGTERM)
	<-done
	cancel()
}

func serversDBRefresher(ctx context.Context, wg *sync.WaitGroup, nordVPN *nordvpn.NordVPN) {
	defer wg.Done()
	if err := nordVPN.RefreshServersDB(ctx); err != nil {
		log.Println("error refreshing servers", err)
	}
	ticker := time.NewTicker(5 * time.Minute)
	for {
		select {
		case <-ticker.C:
			if err := nordVPN.RefreshServersDB(ctx); err != nil {
				log.Println("error refreshing servers", err)
			}
		case <-ctx.Done():
			log.Println("context cancelled, stopping DB Refresher...")
			return
		}
	}
}

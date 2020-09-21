package main

import (
	"context"
	"log"

	"github.com/thoeni/nordvpn-mux/pkg/nordvpn"
)

func main() {
	ctx := context.Background()
	nordVPN, closer, err := nordvpn.New()
	if err != nil {
		log.Println(err)
		return
	}
	defer func() {
		if err := closer.Close(); err != nil {
			log.Println(err)
		}
	}()
	if err := nordVPN.RefreshServersDB(ctx); err != nil {
		log.Println(err)
		return
	}
	s, err := nordVPN.FindClosestServer(ctx, 51.53, -0.1854, 10)
	if err != nil {
		log.Println(err)
		return
	}
	for i := range s {
		log.Printf("%v\n", s[i])
	}
}

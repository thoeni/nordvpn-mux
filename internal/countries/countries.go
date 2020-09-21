package countries

import (
	"context"
	"log"

	"github.com/thoeni/nordlynx-mux/pkg/nordvpn"
)

func GetCountries(ctx context.Context, nordVPN *nordvpn.NordVPN) ([]string, error) {
	log.Println("/countries")
	return nordVPN.GetCountries(ctx)
}
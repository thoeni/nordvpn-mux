package servers

import (
	"context"
	"io"
	"log"
	"os"

	"github.com/thoeni/nordlynx-mux/pkg/nordvpn"
)

func GetConfiguration(filesLocation, serverDomain string) (io.ReadCloser, error) {
	log.Printf("/servers/%s/configuration\n", serverDomain)
	filename := filesLocation + "/" + serverDomain + ".tcp.ovpn"
	return os.OpenFile(filename, os.O_RDONLY, os.ModePerm)
}

func GetServersForCountry(ctx context.Context, nordVPN *nordvpn.NordVPN, countryName string) ([]nordvpn.ServerProperties, error) {
	log.Printf("/servers?country=%s\n", countryName)
	return nordVPN.GetServersForCountry(ctx, countryName)
}

func GetServersForCoordinates(ctx context.Context, nordVPN *nordvpn.NordVPN, lat, long float64, limit int) ([]nordvpn.ServerProperties, error) {
	log.Printf("/servers?lat=%f&long=%f&limit=%d\n", lat, long, limit)
	return nordVPN.FindClosestServer(ctx, lat, long, limit)
}

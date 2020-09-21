package router

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
	"strconv"

	"github.com/thoeni/nordvpn-mux/internal/countries"
	"github.com/thoeni/nordvpn-mux/internal/servers"
	"github.com/thoeni/nordvpn-mux/pkg/nordvpn"

	"github.com/julienschmidt/httprouter"
)

func Servers(nordVPN *nordvpn.NordVPN) func(http.ResponseWriter, *http.Request, httprouter.Params) {
	return func(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
		q := r.URL.Query()
		country := q.Get("country")
		lat, long, limit := q.Get("lat"), q.Get("long"), q.Get("limit")

		srvrs := []nordvpn.ServerProperties{}
		var err error

		switch {
		case len(lat+long+limit) > 3:
			x, err1 := strconv.ParseFloat(lat, 64)
			y, err2 := strconv.ParseFloat(long, 64)
			if err1 != nil || err2 != nil {
				w.WriteHeader(http.StatusBadRequest)
				_, _ = w.Write([]byte("failed parsing lat/long into float64"))
				return
			}
			l, err := strconv.Atoi(limit)
			if err != nil {
				w.WriteHeader(http.StatusBadRequest)
				_, _ = w.Write([]byte("failed parsing limit into int"))
				return
			}
			srvrs, err = servers.GetServersForCoordinates(r.Context(), nordVPN, x, y, l)
			if err != nil {
				w.WriteHeader(http.StatusInternalServerError)
				_, _ = w.Write([]byte(err.Error()))
				return
			}
		case len(country) > 0:
			srvrs, err = servers.GetServersForCountry(r.Context(), nordVPN, country)
			if err != nil {
				w.WriteHeader(http.StatusInternalServerError)
				_, _ = w.Write([]byte(err.Error()))
				return
			}
		}

		b, err := json.Marshal(srvrs)
		w.Header().Set("ContentType", "application/json")
		_, _ = w.Write(b)
	}
}

func ServerConfiguration(filesLocation string) func(http.ResponseWriter, *http.Request, httprouter.Params) {
	return func(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
		f, err := servers.GetConfiguration(filesLocation, ps.ByName("server_domain"))
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			_, _ = w.Write([]byte(err.Error()))
			return
		}
		defer func() {
			_ = f.Close()
		}()
		w.Header().Set("ContentType", "application/ovpn")
		n, err := io.Copy(w, f)
		if err != nil {
			log.Println("failed copying")
			w.WriteHeader(http.StatusInternalServerError)
			_, _ = w.Write([]byte(err.Error()))
			return
		}
		log.Printf("copied %d bytes", n)
	}
}

func Countries(nordVPN *nordvpn.NordVPN) func(http.ResponseWriter, *http.Request, httprouter.Params) {
	return func(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
		countries, err := countries.GetCountries(r.Context(), nordVPN)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			_, _ = w.Write([]byte(err.Error()))
			return
		}
		b, err := json.Marshal(countries)
		w.Header().Set("ContentType", "application/json")
		_, _ = w.Write(b)
	}
}

func HttpHandler(nordVPN *nordvpn.NordVPN, filesLocation string) http.Handler {
	router := httprouter.New()
	router.GET("/countries", Countries(nordVPN))
	router.GET("/servers/:server_domain/configuration", ServerConfiguration(filesLocation))
	router.GET("/servers", Servers(nordVPN))

	return router
}

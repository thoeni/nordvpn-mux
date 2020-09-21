package nordvpn

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"time"

	_ "github.com/mattn/go-sqlite3"
	_ "github.com/shaxbee/go-spatialite"
	"github.com/shaxbee/go-spatialite/wkb"
)

const (
	ServersURL             = "https://nordvpn.com/api/server"
	ServersRecommendations = `https://nordvpn.com/wp-admin/admin-ajax.php?action=servers_recommendations`
	ServersConfigurations  = `https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip`
)

var (
	errNoSuchTableServers = errors.New("no such table: servers")
)

type NordVPN struct {
	db *sql.DB
}

func New() (*NordVPN, io.Closer, error) {
	db, err := sql.Open("spatialite", "file:servers.db?mode=memory&cache=shared")
	//db, err := sql.Open("spatialite", "file:servers.db")
	if err != nil {
		return nil, nil, err
	}

	var tables int
	if err := db.QueryRow("SELECT count(*) FROM sqlite_master WHERE type='table' AND name='servers';").Scan(&tables); err != nil {
		return nil, nil, fmt.Errorf("unexpected error whilst checking whether table server exists: %w", err)
	}
	if tables == 0 {
		if _, err := db.Exec(`
					SELECT InitSpatialMetadata(1);
					CREATE TABLE IF NOT EXISTS servers (
					    'id' INT PRIMARY KEY,
						'ip_address' VARCHAR(45),
					    'name' VARCHAR(255),
					    'domain' VARCHAR(255),
					    'country' VARCHAR(255),
					    'load' INT,
					    'f_openvpn_udp' INT,
					    'f_openvpn_tcp' INT,
					    'f_wireguard_udp' INT,
					    'updated_at' TEXT
					);
					SELECT AddGeometryColumn('servers', 'loc', 4326, 'POINT');
					SELECT CreateSpatialIndex('servers', 'loc');
				`); err != nil {
			return nil, nil, fmt.Errorf("unexpected error whilst initialising DB tables: %w", err)
		}

	}

	return &NordVPN{db: db}, db, nil
}

func (n *NordVPN) FindClosestServer(ctx context.Context, x, y float64, limit int) ([]ServerProperties, error) {
	rows, err := n.db.QueryContext(ctx, `
		SELECT id, ip_address, name, domain, country, updated_at, ST_AsBinary(loc), f_openvpn_udp, f_openvpn_tcp, f_wireguard_udp,
			load,
		    ST_Distance(ST_PointFromWKB(?, 4326), loc, 1) as distance
		FROM servers
		WHERE f_openvpn_udp = ? AND f_openvpn_tcp = ? AND f_wireguard_udp = ?
		ORDER BY distance, load LIMIT ?;
	`, wkb.Point{x, y}, 1, 1, 1, limit)
	if err != nil {
		return nil, err
	}
	var serverProperties []ServerProperties
	for rows.Next() {
		s := ServerProperties{
			Features: make(map[string]bool),
		}
		var fOpenVPNUDP, fOpenVPNTCP, fWireguardUDP bool
		var point wkb.Point
		if err := rows.Scan(
			&s.ID,
			&s.IPAddr,
			&s.Name,
			&s.Domain,
			&s.Country,
			&s.UpdatedAt,
			&point,
			&fOpenVPNUDP,
			&fOpenVPNTCP,
			&fWireguardUDP,
			&s.Load,
			&s.Distance,
		); err != nil {
			return nil, fmt.Errorf("failed scanning server properties: %w", err)
		}
		s.Features[FeatureOpenVPNUDP] = fOpenVPNUDP
		s.Features[FeatureOpenVPNTCP] = fOpenVPNTCP
		s.Features[FeatureWireguard] = fWireguardUDP
		s.Location.Lat = point.X
		s.Location.Long = point.Y
		serverProperties = append(serverProperties, s)
	}
	return serverProperties, nil
}

func (n *NordVPN) GetCountries(ctx context.Context) ([]string, error) {
	rows, err := n.db.QueryContext(ctx, `
		SELECT DISTINCT country FROM servers order by country;
	`)
	if err != nil {
		return nil, err
	}
	var countries []string
	for rows.Next() {
		var s string
		if err := rows.Scan(&s); err != nil {
			return nil, fmt.Errorf("failed scanning country name: %w", err)
		}
		countries = append(countries, s)
	}
	return countries, nil
}

func (n *NordVPN) GetServersForCountry(ctx context.Context, countryName string) ([]ServerProperties, error) {
	rows, err := n.db.QueryContext(ctx, `
		SELECT id,ip_address,name,domain,country,load, ST_AsBinary(loc), f_openvpn_udp, f_openvpn_tcp, f_wireguard_udp, updated_at 
		FROM servers 
		WHERE country = ? ORDER BY load;
	`, countryName)
	if err != nil {
		return nil, err
	}
	var serverProperties []ServerProperties
	for rows.Next() {
		s := ServerProperties{
			Features: make(map[string]bool),
		}
		var fOpenVPNUDP, fOpenVPNTCP, fWireguardUDP bool
		var point wkb.Point
		if err := rows.Scan(
			&s.ID,
			&s.IPAddr,
			&s.Name,
			&s.Domain,
			&s.Country,
			&s.Load,
			&point,
			&fOpenVPNUDP,
			&fOpenVPNTCP,
			&fWireguardUDP,
			&s.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed scanning server properties: %w", err)
		}
		s.Features[FeatureOpenVPNUDP] = fOpenVPNUDP
		s.Features[FeatureOpenVPNTCP] = fOpenVPNTCP
		s.Features[FeatureWireguard] = fWireguardUDP
		s.Location.Lat = point.X
		s.Location.Long = point.Y
		serverProperties = append(serverProperties, s)
	}
	return serverProperties, nil
}

func (n *NordVPN) RefreshServersDB(ctx context.Context) (err error) {
	start := time.Now()
	var tx *sql.Tx
	defer func() {
		if err != nil && tx != nil {
			_ = tx.Rollback()
		}
	}()

	serverDefinitions, err := fetchServerDefinitions(ctx)
	if err != nil {
		return fmt.Errorf("failed refreshing servers DB: %w", err)
	}

	log.Printf("%d server definitions downloaded...\n", len(serverDefinitions))
	tx, err = n.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed opening transaction: %w", err)
	}
	for _, v := range serverDefinitions {
		_, err := tx.ExecContext(ctx, `
			INSERT OR REPLACE INTO servers 
			    ("id","ip_address","name","domain","country","load", "loc", "f_openvpn_udp", "f_openvpn_tcp", "f_wireguard_udp", "updated_at")
			    VALUES (?, ?, ?, ?, ?, ?, ST_PointFromWKB(?, 4326), ?, ?, ?, datetime('now'))
		`, v.ID, v.IPAddr, v.Name, v.Domain, v.Country, v.Load, wkb.Point{v.Location.Lat, v.Location.Long}, v.Features[FeatureOpenVPNUDP], v.Features[FeatureOpenVPNTCP], v.Features[FeatureWireguard])
		if err != nil {
			return fmt.Errorf("failed inserting server %s: %w", v.Name, err)
		}
	}
	log.Println("ServersDB updated in", time.Since(start))
	return tx.Commit()
}

func fetchServerDefinitions(ctx context.Context) ([]ServerProperties, error) {
	httpClient := http.DefaultClient
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, ServersURL, nil)
	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed fetching server definitions: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed fetching server definitions: status code was %s", resp.Status)
	}

	var serverProperties []ServerProperties
	b, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed reading server definitions payload: %w", err)
	}
	if err := json.Unmarshal(b, &serverProperties); err != nil {
		return nil, fmt.Errorf("failed unmarshalling server definitions: %w", err)
	}
	return serverProperties, nil
}

package nordvpn

const (
	FeatureOpenVPNUDP = "openvpn_udp"
	FeatureOpenVPNTCP = "openvpn_tcp"
	FeatureWireguard  = "wireguard_udp"
)

// ServerProperties defines a NordVPN server properties.
//{
//    "id": 974480,
//    "ip_address": "104.200.131.122",
//    "search_keywords": [
//      "sha512",
//      "P2P"
//    ],
//    "categories": [
//      {
//        "name": "Standard VPN servers"
//      },
//      {
//        "name": "P2P"
//      }
//    ],
//    "name": "United States #8144",
//    "domain": "us8144.nordvpn.com",
//    "price": 0,
//    "flag": "US",
//    "country": "United States",
//    "location": {
//      "lat": 40.7608333,
//      "long": -111.8902778
//    },
//    "load": 10,
//    "features": {
//      "ikev2": true,
//      "openvpn_udp": true,
//      "openvpn_tcp": true,
//      "socks": false,
//      "proxy": false,
//      "pptp": false,
//      "l2tp": false,
//      "openvpn_xor_udp": false,
//      "openvpn_xor_tcp": false,
//      "proxy_cybersec": false,
//      "proxy_ssl": true,
//      "proxy_ssl_cybersec": true,
//      "ikev2_v6": false,
//      "openvpn_udp_v6": false,
//      "openvpn_tcp_v6": false,
//      "wireguard_udp": true,
//      "openvpn_udp_tls_crypt": false,
//      "openvpn_tcp_tls_crypt": false,
//      "openvpn_dedicated_udp": false,
//      "openvpn_dedicated_tcp": false,
//      "skylark": false
//    }
//  }
type ServerProperties struct {
	ID       int64  `json:"id"`
	Country  string `json:"country"`
	Domain   string `json:"domain"`
	Distance float64
	Features map[string]bool `json:"features"`
	IPAddr   string          `json:"ip_address"`
	Load     uint8           `json:"load"`
	Location struct {
		Lat  float64 `json:"lat"`
		Long float64 `json:"long"`
	} `json:"location"`
	Name      string `json:"name"`
	UpdatedAt string `json:"updated_at"`
}

package mylego

type CertConfig struct {
	CertMode         string            `mapstructure:"CertMode" toml:"CertMode"` // none, file, http, dns
	CertDomain       string            `mapstructure:"CertDomain" toml:"CertDomain"`
	CertFile         string            `mapstructure:"CertFile" toml:"CertFile"`
	CaFile           string            `mapstructure:"CaFile" toml:"CaFile"`
	KeyFile          string            `mapstructure:"KeyFile" toml:"KeyFile"`
	Provider         string            `mapstructure:"Provider" toml:"Provider"` // alidns, cloudflare, gandi, godaddy....
	Email            string            `mapstructure:"Email" toml:"Email"`
	DNSEnv           map[string]string `mapstructure:"DNSEnv" toml:"DNSEnv"`
	RejectUnknownSni bool              `mapstructure:"RejectUnknownSni" toml:"RejectUnknownSni"`
	UpdatePeriodic   int               `mapstructure:"Refresh" toml:"Refresh"`
}

type LegoCMD struct {
	C    *CertConfig
	path string
}

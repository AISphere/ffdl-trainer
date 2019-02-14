//-------------------------------------------------------------
// IBM Confidential
// OCO Source Materials
// (C) Copyright IBM Corp. 2018
// The source code for this program is not published or
// otherwise divested of its trade secrets, irrespective of
// what has been deposited with the U.S. Copyright Office.
//-------------------------------------------------------------

package client

import (
	"fmt"
	"google.golang.org/grpc"

	"github.com/AISphere/ffdl-commons/config"
	"github.com/AISphere/ffdl-commons/logger"
	"github.com/AISphere/ffdl-commons/util"
	"github.com/AISphere/ffdl-trainer/plugins/ratelimiter/service/grpc_ratelimiter_v1"

	log "github.com/sirupsen/logrus"
	"github.com/spf13/viper"
)

const (
	disabled = "disabled"

	// LocalAddress exposes the local address that is used if we run with DNS disabled
	LocalAddress = ":30025"
)

// RatelimiterClient is a client interface for interacting with the training metrics service.
type RatelimiterClient interface {
	Client() grpc_ratelimiter_v1.RatelimiterClient
	Close() error
}

type ratelimiterClient struct {
	client grpc_ratelimiter_v1.RatelimiterClient
	conn   *grpc.ClientConn
}

// NewRatelimiterClient create a new load-balanced client to talk to the ratelimiter
// service. If the dns_server config option is set to 'disabled', it will
// default to the pre-defined LocalPort of the service.
func NewRatelimiterClient() (RatelimiterClient, error) {
	return NewRatelimiterClientWithAddress(LocalAddress)
}

// NewRatelimiterClientFromExisting creates a wrapper around an existing client.  Used at least for mock clients.
//noinspection GoUnusedExportedFunction
func NewRatelimiterClientFromExisting(rl grpc_ratelimiter_v1.RatelimiterClient) (RatelimiterClient, error) {
	return &ratelimiterClient{
		conn:   nil,
		client: rl,
	}, nil
}

// NewRatelimiterClientWithAddress create a new load-balanced client to talk to the ratelimiter
// service. If the dns_server config option is set to 'disabled', it will
// default to the pre-defined LocalPort of the service.
func NewRatelimiterClientWithAddress(addr string) (RatelimiterClient, error) {
	logr := logger.LocLogger(logger.LogServiceBasic("ratelimiter"))
	logr.Debugf("function entry")

	var address string
	dnsServer := viper.GetString("dns_server")
	if dnsServer == disabled { // for local testing without DNS server
		address = addr
		logr.Debugf("DNS disabled: Running passed in address: %v", address)
	} else {
		address = fmt.Sprintf("%s.%s.svc.cluster.local:80", config.GetRatelimiterServiceName(), config.GetPodNamespace())
		logr.Debugf("dlaas-ratelimiter address: %v", address)
	}
	logr.Debugf("IsTLSEnabled: %t", config.IsTLSEnabled())
	logr.Debugf("final address: %v", address)

	dialOpts, err := util.CreateClientDialOpts()
	if err != nil {
		return nil, err
	}
	for i, v := range dialOpts {
		log.Printf("dialOpts[%d]: %+v", i, v)
	}

	// dial non-blocking if ratelimiter is not deployed
	conn, err := grpc.Dial(address, dialOpts...)
	if err != nil {
		log.Errorf("Could not connect to ratelimiter service: %v", err)
		return nil, err
	}

	logr.Debugf("function exit")

	return &ratelimiterClient{
		conn:   conn,
		client: grpc_ratelimiter_v1.NewRatelimiterClient(conn),
	}, nil
}

func (c *ratelimiterClient) Client() grpc_ratelimiter_v1.RatelimiterClient {
	return c.client
}

func (c *ratelimiterClient) Close() error {
	if c.conn != nil {
		return c.conn.Close()
	}
	return nil
}

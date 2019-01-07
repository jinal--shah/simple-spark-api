/* 
	Test App A endpoints.
	By default, also tests exposed endpoint via load balancer.

	To get junit xml output, use go-junit-report

	USAGE:
	run all: `go test`
	run appA `go test run -AppA`
	run load balancer tests: `go test run -LoadBalanced`
*/
package main

import (
	"fmt"
	"io/ioutil"
	"math/rand"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"
)

var cl *http.Client

type testData struct {
	desc          string
	uri_path      string
	expected_code int
	expected_body string
}

var appATests = []testData{
	{"appA /health - OK", "/health", 200, `OK`},
	{"appA /message - hello world", "/message", 200, `{"message":"hola mundo"}`},
}

var loadBalancedTests = []testData{
	{"lb /message - proxy to appA - OK", "/message", 200, `{"message":"hola mundo"}`},
}

func init() {
	rand.Seed(time.Now().UnixNano())

	cl = &http.Client{
		Timeout:   time.Second * 30,
		Transport: http.DefaultTransport,
	}
}

func TestAppAEndpoints(t *testing.T) {
	var host string

	if host = os.Getenv("APP_A_HOST"); host == "" {
		t.Fatal("You must set APP_A_HOST in env")
	}

	for _, tc := range appATests {
		tc.callApi(t, host)
	}
}

func TestLoadBalancedEndpoint(t *testing.T) {
	var host string

	if host = os.Getenv("LB_HOST"); host == "" {
		t.Fatal("You must set LB_HOST in env")
	}

	for _, tc := range loadBalancedTests {
		tc.callApi(t, host)
	}
}

func (tc *testData) callApi(t *testing.T, host string) {
	desc := tc.desc
	uri_path := tc.uri_path
	uri := "http://" + host + uri_path
	expected_code := tc.expected_code
	expected_body := tc.expected_body

	request, err := http.NewRequest("GET", uri, nil)
	if err != nil {
		t.Fatal(err)
	}

	resp, err := retryReq(request, uri)
	if err != nil { // not checking resp code, only http transport
		t.Fatal(err)
	}

	if p, err := ioutil.ReadAll(resp.Body); err != nil {
		t.Fail()
	} else {
		if resp.StatusCode != expected_code {
			t.Errorf("%s: response code should be %d, not %d", desc, expected_code, resp.StatusCode)
		} else if !strings.Contains(string(p), expected_body) {
			t.Errorf("%s: response doen't match:\n%s\nexpected: %s", desc, p, expected_body)
		}
	}
}

func retryReq(request *http.Request, url string) (resp *http.Response, err error) {

	attempt := 1
	sleep := time.Second
	for attempt <= 3 {
		resp, err = cl.Do(request)
		if resp != nil && resp.StatusCode < 500 {
			break // success or client err so retry unnecessary
		}

		if attempt < 3 {
			fmt.Printf("Remote failure. Will retry call to %s\n", url)
		}

		attempt++
		jitter := time.Duration(rand.Int63n(int64(sleep)))
		time.Sleep(sleep + jitter/2)
		sleep = sleep * 2

	}

	return
}

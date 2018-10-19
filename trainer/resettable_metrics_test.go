/*
 * Copyright 2018. IBM Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package trainer

import (
	"io/ioutil"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	stdprometheus "github.com/prometheus/client_golang/prometheus"
	"github.com/AISphere/ffdl-commons/metricsmon"
)

var (
	wg sync.WaitGroup
)

const (
	port              = "8081"
	timeToStartTicker = 10
	timeToReset       = 5
	isLocal           = false
)

func initTest(gaugeName string) (done chan struct{}) {
	myResettableMetrics := NewResettableMetrics()
	myResettableMetrics.startTicker = time.NewTimer(time.Second * timeToStartTicker)
	myResettableMetrics.resetEvery = time.Second * timeToReset //overriding value, reset after every x seconds, for testing purposes

	myResettableGauge := myResettableMetrics.NewGauge(gaugeName, "Test metrics (should reset every custom amount of time)")
	//not creating through resettable metrics since we cannot reset a metric with complex labels yet
	myResettableGaugeWithLabels := metricsmon.NewGauge(gaugeName+"_with_labels", "Test metrics (should reset every custom amount of time)", []string{"framework", "version", "gpus", "gpuType"})

	done = make(chan struct{})

	go func() {
		for {
			select {
			case <-done:
				myResettableMetrics.done <- struct{}{}
				return
			default:
				time.Sleep(time.Second)
				myResettableGaugeWithLabels.With("framework", "tensorflow", "version", "1.0.1", "gpus", "10", "gpuType", "nvidia-TeslaP100").Add(1)
				myResettableGauge.Add(1)

			}
		}
	}()

	return done
}

func TestCancelResetMetrics(t *testing.T) {

	done := initTest("resettable_gauge_cancel")
	done <- struct{}{}
	//Shutting down resettable metrics should not trigger panic
	// Need a better way to test this
	t.Log("Canceling resettable metrics before starting was successful")
}

//can only be done locally
func TestResettableMetrics(t *testing.T) {

	gaugeName := "resettable_gauge"

	done := initTest(gaugeName)

	http.Handle("/metrics", stdprometheus.Handler())
	go func() {
		t.Fatal(http.ListenAndServe(":"+port, nil))
	}()

	wg.Add(1)

	//CHECK 1: initial check to see if gauge started from 0
	if isLocal {
		resp, err := http.Get("http://:" + port + "/metrics")

		if err != nil {
			t.Fatal("error ", err)
		}
		defer resp.Body.Close()
		respBody, err := ioutil.ReadAll(resp.Body)

		if resp.StatusCode != http.StatusOK {
			t.Error("Wrong error code returned")
		}

		if isValueCorrect := checkForMetricValue(gaugeName, respBody, 0); !isValueCorrect {
			t.Error("Numbers not matching for resettable gauge! \n", string(respBody))
		}

		//CHECK 2
		time.AfterFunc(timeToStartTicker*time.Second, func() {
			//for {
			resp, err := http.Get("http://:" + port + "/metrics")

			if err != nil {
				t.Fatal("error ", err)
			}
			defer resp.Body.Close()
			respBody, err := ioutil.ReadAll(resp.Body)

			if resp.StatusCode != http.StatusOK {
				t.Error("Wrong error code returned")
			}

			if isValueCorrect := checkForMetricValue(gaugeName, respBody, timeToStartTicker-1); !isValueCorrect {
				t.Error("Numbers not matching for resettable gauge! \n", string(respBody))
			}
		})
		// 	log.Println(string(respBody))
		// 	time.Sleep(time.Second)
		// }

		//CHECK 3
		time.AfterFunc((timeToStartTicker+timeToReset)*time.Second, func() {
			resp, err := http.Get("http://:" + port + "/metrics")

			if err != nil {
				t.Fatal("error ", err)
			}
			defer resp.Body.Close()
			respBody, err := ioutil.ReadAll(resp.Body)

			if resp.StatusCode != http.StatusOK {
				t.Error("Wrong error code returned", resp.StatusCode)
			}

			//Asserting that resettable metrics were indeed reset
			if isValueCorrect := checkForMetricValue(gaugeName, respBody, 0); !isValueCorrect {
				t.Error("Numbers not matching for resettable gauge! \n", string(respBody))
			}

			done <- struct{}{}
			wg.Done()
		})

		wg.Wait()
	}
}

func checkForMetricValue(gaugeName string, body []byte, val int) bool {
	stringToFind := gaugeName + " " + strconv.Itoa(val)
	return strings.Contains(string(body), stringToFind)
}

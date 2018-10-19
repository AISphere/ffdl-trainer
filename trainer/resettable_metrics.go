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
	"time"

	"github.com/go-kit/kit/metrics"
	"github.com/AISphere/ffdl-commons/logger"
	"github.com/AISphere/ffdl-commons/metricsmon"
)

var logr = logger.LogServiceBasic(logger.LogkeyTrainerService)

const (
	hourToTick   int = 00
	minuteToTick int = 00
	secondToTick int = 00
)

//ResettableMetrics ... Struct of resettable metrics
type ResettableMetrics struct {
	startTicker          *time.Timer               //Once this timer finishes, the actual resettable ticker will start ticking according to the `resetEvery` value
	resetEvery           time.Duration             //The frequency with which we want to reset the metrics
	ticker               *time.Ticker              //The main ticker which resets the metrics according to the `resetEvery` value
	resettableMetricsMap map[string]*metrics.Gauge //The map which holds all metrics to reset
	done                 chan struct{}             //The channel which will close the resettable metrics ticker
}

//NewGauge ... Creating resettable gauges
func (r *ResettableMetrics) NewGauge(name string, help string) metrics.Gauge {
	gauge := metricsmon.NewGauge(name, help, []string{})
	gauge.Set(0)
	r.resettableMetricsMap[name] = &gauge
	return gauge
}

//NewResettableMetrics ... Creating a new instance of resettable metrics
func NewResettableMetrics() *ResettableMetrics {

	//next tick happens on the set hour, minute and second of the next day.
	timeToStartTicker := time.Date(time.Now().Year(), time.Now().Month(), time.Now().Day()+1, hourToTick, minuteToTick, secondToTick, 0, time.UTC)

	resettableMetrics := ResettableMetrics{
		startTicker:          time.NewTimer(timeToStartTicker.Sub(time.Now())), //tick on the set time
		resetEvery:           time.Hour * 24,
		resettableMetricsMap: make(map[string]*metrics.Gauge),
		done:                 make(chan struct{}),
	}

	go func() {
		for {
			select {
			case <-resettableMetrics.startTicker.C:
				defer resettableMetrics.startTicker.Stop()
				logr.Info("Starting the resettable metrics ticker!")
				resettableMetrics.ticker = time.NewTicker(resettableMetrics.resetEvery)
				go func() {
					for {
						select {
						case <-resettableMetrics.ticker.C:
							logr.Info("Resetting metrics to 0!")
							resettableMetrics.reset()
						case <-resettableMetrics.done:
							resettableMetrics.stop()
							logr.Info("Shutting down resettable metrics ticker")
							return
						}
					}
				}()
				return

			// In case stop is called before ticker ticks
			case <-resettableMetrics.done:
				resettableMetrics.stop()
				logr.Info("Resettable metrics ticker was stopped before it could start")
				return
			}
		}
	}()

	return &resettableMetrics
}

func (r *ResettableMetrics) reset() {
	for _, gaugePointer := range r.resettableMetricsMap {
		gauge := *gaugePointer
		gauge.Set(0)
	}
}

func (r *ResettableMetrics) stop() {
	if r.ticker != nil {
		r.ticker.Stop()
	}
}

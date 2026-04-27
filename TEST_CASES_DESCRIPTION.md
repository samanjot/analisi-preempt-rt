# Test Cases Description

This document describes the test cases executed to analyze cyclic latency performance across different system configurations and load scenarios.

---

## Execution Environments

The test cases have been executed on three different configurations:

### 1. **Baremetal (preempt_rt)**
- Direct hardware execution with Linux kernel PREEMPT_RT patch
- No virtualization layer
- Baseline for comparing virtualization overhead

### 2. **Xen Hypervisor**
- Linux PREEMPT_RT running as Dom0 under Xen hypervisor
- Includes hypervisor scheduling overhead
- Standard Xen configuration with multiple guest domains possible

### 3. **Xen Static (Dom0less)**
- Xen hypervisor in static configuration (no Dom0)
- Reduced overhead compared to standard Xen
- Pre-configured static domain layout without Dom0 management domain

---

## Test Case Categories

### Category A: Standard CPU Timer Latency Tests

These tests measure cyclic latency under different interrupt/timer stress loads, executed across all CPU cores.

#### **Test Case 1: Baseline**
**Description:** Cyclic test without additional load on all cores

- **Workload:** Only cyclictest running on all available cores
- **Load Level:** Minimal (no additional stress)
- **Purpose:** Establish baseline latency measurements under normal operating conditions
- **Expected Behavior:** Lowest latency values; represents best-case scenario
- **Key Metrics:**
  - Minimum latency (µs)
  - Maximum latency (µs)
  - Average latency (µs)
  - 99th percentile latency (µs)

#### **Test Case 2: Stress 100k**
**Description:** Cyclic test with stress-ng interrupt load (100k interrupts) on all cores

- **Workload:** cyclictest + stress-ng with 100,000 interrupts per second on all cores
- **Load Level:** Moderate interrupt load
- **Purpose:** Evaluate latency degradation under moderate timer interrupt pressure
- **Expected Behavior:** Latency increase due to interrupt handling overhead
- **Key Metrics:**
  - Latency percentiles (min, max, avg, p99)
  - Latency distribution histogram
  - Jitter analysis

#### **Test Case 3: Stress 1M**
**Description:** Cyclic test with stress-ng interrupt load (1M interrupts) on all cores

- **Workload:** cyclictest + stress-ng with 1,000,000 interrupts per second on all cores
- **Load Level:** Heavy interrupt load
- **Purpose:** Stress test latency behavior under extreme interrupt pressure
- **Expected Behavior:** Significant latency increase; potential tail latencies
- **Key Metrics:**
  - Latency percentiles (min, max, avg, p99)
  - Maximum observed latency
  - Latency distribution histogram

---

### Category B: Memory Interference Tests (HeSoC Mark)

These tests measure latency on a single measurement core while other cores generate memory interference using **HeSoC mark** benchmark. This simulates realistic scenarios with competing memory traffic.

#### **Test Case 4: HeSoC Memory Interference**
**Description:** 1 core runs cyclic test while other cores generate memory interference (HeSoC mark)

- **Measurement Core:** Single CPU core running cyclictest
- **Interference Pattern:** Other cores running HeSoC mark benchmark (1 to N-1 cores, where N = total cores)
- **Load Type:** Memory bandwidth interference
- **Purpose:** Analyze impact of memory hierarchy contention on latency
- **Scanning Pattern:** Progressive core count increases (1, 2, 3, ... cores executing HeSoC)
- **Expected Behavior:** Gradual latency degradation as more cores contend for memory
- **Key Metrics:**
  - Latency vs. number of interfering cores
  - Memory bandwidth impact analysis
  - Cache contention effects

#### **Test Case 5: HeSoC + Stress 100k**
**Description:** 1 core runs cyclic test with 100k interrupt load, while other cores generate memory interference (HeSoC mark)

- **Measurement Core:** Single CPU core running cyclictest + stress-ng (100k interrupts)
- **Interference Pattern:** Other cores running HeSoC mark benchmark (1 to N-1 cores)
- **Combined Load:** Both timer interrupts and memory bandwidth interference
- **Purpose:** Evaluate combined effects of interrupt load and memory contention
- **Expected Behavior:** Multiplicative effect of two stress sources on latency
- **Key Metrics:**
  - Latency vs. number of interfering cores
  - Impact of combined interrupt + memory load
  - Latency distribution histogram

#### **Test Case 6: HeSoC + Stress 1M**
**Description:** 1 core runs cyclic test with 1M interrupt load, while other cores generate memory interference (HeSoC mark)

- **Measurement Core:** Single CPU core running cyclictest + stress-ng (1M interrupts)
- **Interference Pattern:** Other cores running HeSoC mark benchmark (1 to N-1 cores)
- **Combined Load:** Heavy timer interrupts + memory bandwidth interference
- **Purpose:** Extreme stress test evaluating latency under worst-case combined load
- **Expected Behavior:** Severe latency degradation; potential system saturation
- **Key Metrics:**
  - Maximum and extreme latencies (p99.9)
  - System saturation point
  - Latency distribution histogram

---

## Test Execution Parameters

### Common Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Measurement Duration** | 30 seconds (default) | Per test case run |
| **Cyclictest Configuration** | Default (1 µs interval) | Measures timer wakeup latency |
| **Stress-ng Configuration** | CPU stress with timer interrupts | 100k and 1M variants |
| **HeSoC Mark Configuration** | Memory bandwidth benchmark | Progressive core scaling |
| **Histogram Range** | Platform-dependent | Captures full latency spectrum |

---

## Analysis Goals

1. **Baseline Performance:** Establish latency baseline for each platform
2. **Interrupt Overhead:** Quantify latency increase due to timer interrupt stress
3. **Memory Contention Impact:** Measure effect of memory bandwidth interference
4. **Combined Stress Effects:** Analyze interaction between interrupt and memory load
5. **Platform Comparison:** Compare preempt_rt baremetal vs Xen variants
6. **Virtualization Overhead:** Quantify performance cost of Xen hypervisor
7. **Configuration Impact:** Evaluate benefit of dom0less configuration

---

## Metrics and Analysis

### Primary Metrics

- **Minimum Latency:** Best-case response time
- **Maximum Latency:** Worst-case response time
- **Average Latency:** Mean response time
- **Jitter:** Standard deviation of latency measurements

### Secondary Metrics

- **Latency Distribution:** Histogram of measured latencies
- **Memory Bandwidth:** System memory throughput during HeSoC tests

---

## Notes

- **HeSoC Mark:** Memory interference benchmark from https://git.hipert.unimore.it/mem-prof/hesoc-mark/
- **Stress-ng:** Used for CPU timer interrupt generation and system stress
- **Cyclictest:** Part of rt-tests package; measures wakeup latency
- **Platform-Specific:** Results vary by hardware (IMX8P, IMX95, ZCU102, etc.)
- **Statistical Significance:** Each test typically run multiple times for statistical analysis


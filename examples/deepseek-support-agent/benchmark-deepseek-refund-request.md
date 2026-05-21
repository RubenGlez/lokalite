# DeepSeek Demo Benchmark

Scenario: ./examples/scenarios/deepseek-refund-request.yaml
Model: deepseek-v4-flash
Iterations: 1
Total locale checks: 4
Pass rate: 4/4 (100%)
Average run duration: 6109 ms

| Locale | Passes |
| --- | ---: |
| en | 1/1 |
| es | 1/1 |
| fr | 1/1 |
| ja | 1/1 |

## Runs

### Iteration 1

Duration: 6109 ms
Exit code: 0

```text
Lokalite run

Scenario: deepseek_refund_request
Target: http://127.0.0.1:3001/api/agent

Locale  Status  Detail
en      pass    create_refund_ticket
es      pass    create_refund_ticket
fr      pass    create_refund_ticket
ja      pass    create_refund_ticket

Result: passed, 0 of 4 locales failed
```

# DeepSeek Demo Benchmark

Scenario: ./examples/scenarios/deepseek-indirect-intent.yaml
Model: deepseek-v4-flash
Iterations: 1
Total locale checks: 8
Pass rate: 8/8 (100%)
Average run duration: 11624 ms

| Locale | Passes |
| --- | ---: |
| en | 1/1 |
| de | 1/1 |
| pt | 1/1 |
| ar | 1/1 |
| hi | 1/1 |
| tr | 1/1 |
| ko | 1/1 |
| nl | 1/1 |

## Runs

### Iteration 1

Duration: 11624 ms
Exit code: 0

```text
Lokalite run

Scenario: deepseek_indirect_intent
Target: http://127.0.0.1:3001/api/agent

Locale  Status  Detail
en      pass    create_refund_ticket
de      pass    create_refund_ticket
pt      pass    create_refund_ticket
ar      pass    create_refund_ticket
hi      pass    create_refund_ticket
tr      pass    create_refund_ticket
ko      pass    create_refund_ticket
nl      pass    create_refund_ticket

Result: passed, 0 of 8 locales failed
```

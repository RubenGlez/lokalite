# DeepSeek Demo Benchmark

Scenario: ./examples/scenarios/deepseek-lowresource-refund.yaml
Model: deepseek-v4-flash
Iterations: 1
Total locale checks: 8
Pass rate: 8/8 (100%)
Average run duration: 13957 ms

| Locale | Passes |
| --- | ---: |
| en | 1/1 |
| sw | 1/1 |
| bn | 1/1 |
| is | 1/1 |
| cy | 1/1 |
| eu | 1/1 |
| mn | 1/1 |
| yo | 1/1 |

## Runs

### Iteration 1

Duration: 13957 ms
Exit code: 0

```text
Lokalite run

Scenario: deepseek_lowresource_refund
Target: http://127.0.0.1:3001/api/agent

Locale  Status  Detail
en      pass    create_refund_ticket
sw      pass    create_refund_ticket
bn      pass    create_refund_ticket
is      pass    create_refund_ticket
cy      pass    create_refund_ticket
eu      pass    create_refund_ticket
mn      pass    create_refund_ticket
yo      pass    create_refund_ticket

Result: passed, 0 of 8 locales failed
```

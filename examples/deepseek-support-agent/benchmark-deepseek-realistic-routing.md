# DeepSeek Realistic Routing Benchmark

Scenario: ./examples/scenarios/deepseek-realistic-routing.yaml
Model: deepseek-chat
Iterations: 3
Total locale checks: 24
Pass rate: 17/24 (71%)
Average run duration: 21983 ms

| Locale | Passes |
| --- | ---: |
| en | 3/3 |
| fr | 3/3 |
| ar | 3/3 |
| sw | 0/3 |
| cy | 3/3 |
| yo | 2/3 |
| eu | 3/3 |
| mn | 0/3 |

## Runs

### Iteration 1

Duration: 24307 ms
Exit code: 1

```text
Lokalite run

Scenario: deepseek_realistic_routing
Target: http://127.0.0.1:3002/api/agent

Locale  Status  Detail
en      pass    create_refund_ticket
fr      pass    create_refund_ticket
ar      pass    create_refund_ticket
sw      fail    expected create_refund_ticket, got check_payment_status
cy      pass    create_refund_ticket
yo      fail    expected create_refund_ticket, got no tool calls
eu      pass    create_refund_ticket
mn      fail    expected create_refund_ticket, got check_payment_status

Result: failed, 3 of 8 locales failed
```

### Iteration 2

Duration: 20831 ms
Exit code: 1

```text
Lokalite run

Scenario: deepseek_realistic_routing
Target: http://127.0.0.1:3002/api/agent

Locale  Status  Detail
en      pass    create_refund_ticket
fr      pass    create_refund_ticket
ar      pass    create_refund_ticket
sw      fail    expected create_refund_ticket, got check_payment_status
cy      pass    create_refund_ticket
yo      pass    create_refund_ticket
eu      pass    create_refund_ticket
mn      fail    expected create_refund_ticket, got check_payment_status

Result: failed, 2 of 8 locales failed
```

### Iteration 3

Duration: 20811 ms
Exit code: 1

```text
Lokalite run

Scenario: deepseek_realistic_routing
Target: http://127.0.0.1:3002/api/agent

Locale  Status  Detail
en      pass    create_refund_ticket
fr      pass    create_refund_ticket
ar      pass    create_refund_ticket
sw      fail    expected create_refund_ticket, got check_payment_status
cy      pass    create_refund_ticket
yo      pass    create_refund_ticket
eu      pass    create_refund_ticket
mn      fail    expected create_refund_ticket, got check_payment_status

Result: failed, 2 of 8 locales failed
```

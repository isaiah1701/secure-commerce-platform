# SOC lab architecture

```mermaid
flowchart LR
  U[Analyst / k6] --> C[Commerce Container App]
  C --> P[(Azure PostgreSQL Flexible Server)]
  C --> L[Log Analytics workspace]
  L --> S[Microsoft Sentinel scheduled rules]
  S -. blocked until durable GLPI .-> G[GLPI Container App]
  G -. TLS .-> M[(External managed MySQL)]
  G --> F[(Azure Files attachments)]
```

The commerce path is active. Sentinel and Log Analytics are active. GLPI and the external MySQL handoff remain disabled until a durable database endpoint is supplied and persistence is proven.

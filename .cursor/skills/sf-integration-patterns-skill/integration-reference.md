# Integration Patterns — Reference Tables

## Inbound Integration Mechanisms Comparison

| Mechanism | Type | Max Payload | Throughput | Auth | Best For |
|---|---|---|---|---|---|
| REST API (standard) | Sync | 5MB request | ~1K records/call | OAuth 2.0 | Real-time CRUD; small batch |
| REST API (Bulk 2.0) | Async | 150MB/job | 150M records/job | OAuth 2.0 | Mass load; ETL; migration |
| SOAP API | Sync | 5MB | 200 records/call | OAuth/Session | Legacy; enterprise middleware |
| Apex REST | Sync | 5MB | Apex limits | OAuth 2.0 | Custom endpoint with business logic |
| Platform Events (publish) | Async | 1MB/event | 250K events/day | OAuth 2.0 | Decoupled event push; fire-and-forget |
| Streaming API | Async (subscribe) | 1MB/event | Varies | OAuth 2.0 | Client-side real-time (browser/mobile) |

## Outbound Integration Mechanisms Comparison

| Mechanism | Trigger | Delivery Guarantee | Retry | Best For |
|---|---|---|---|---|
| Outbound Messages | Declarative (Workflow/Process Builder) | At-least-once | Yes (up to 24h) | Simple field-change notifications; no code |
| Apex Callout (sync) | Code | At-most-once | No | Immediate response needed; custom logic |
| Apex Callout (Queueable) | Async | At-most-once | Manual chaining | Async callout with retry logic |
| Platform Events | Code / Flow | At-least-once (72h retain) | Consumer handles | EDA; decoupled; multiple consumers |
| Change Data Capture | Automatic on data change | At-least-once (72h retain) | Consumer handles | Replication; audit; data sync |
| Streaming API (PushTopic) | Data change query match | At-most-once | No | Browser/mobile real-time updates |

## Platform Event Limits

| Limit | Standard (Sales/Service Cloud) | High-Volume Add-On |
|---|---|---|
| Published events per day | 250,000 | Up to millions |
| Subscribers per event | No hard limit | No hard limit |
| Event retention | 72 hours | 72 hours |
| Max payload size | 1 MB per event | 1 MB per event |
| Event replay window | 72 hours (Replay ID) | 72 hours |

## Change Data Capture Limits

| Limit | Value |
|---|---|
| Change events per 24h (default) | 25,000 |
| Retention | 72 hours |
| Objects supported | Selected standard + custom objects |
| Included fields | Changed fields + headers (EntityChanges) |

## Bulk API 2.0 Key Facts

| Aspect | Value |
|---|---|
| Max records per job | 150,000,000 |
| Max file size | 150 MB |
| Supported operations | Insert, Update, Upsert, Delete, HardDelete, Query |
| Parallel jobs | Up to 10 concurrent |
| Triggers fire | Yes (designed for bulk: 200 records/batch) |
| Best practice scope | 10,000–50,000 records per batch |

## REST API Governor Limits (per Salesforce org per 24h)

| Limit | Developer | Professional | Enterprise | Unlimited |
|---|---|---|---|---|
| API calls per day | 15,000 | 1,000/user (min 10K) | 1,000/user (min 40K) | 1,000/user (min 40K) |
| Bulk API calls | 5,000 | 5,000 | 5,000 | 5,000 |

## Callout Limits (per Apex Transaction)

| Limit | Value |
|---|---|
| Max callouts | 100 |
| Max timeout per callout | 120 seconds |
| Total callout timeout | 120 seconds |
| Callout after DML | Error (use async boundary) |

## Integration User Best Practices

| Do | Don't |
|---|---|
| Dedicated integration profile with minimum access | Use System Admin user for integration |
| Named Credentials for endpoint + credentials | Store credentials in Custom Settings or CMT |
| OAuth 2.0 JWT Bearer for server-to-server | Username/Password OAuth flow for new integrations |
| Separate integration user per external system | Share one integration user across systems |
| Monitor API usage via Setup > API Usage Metrics | Ignore API limit warnings |
